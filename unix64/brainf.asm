; brainf.asm — Brainfuck JIT compiler
;
; Reads a BF program from argv[1], compiles it to x86-64 machine code
; at runtime, then executes the generated code.  Uses mmap/mprotect
; for W^X code generation.
;
; Usage: brainf '<program>'

bits 64
default rel

global main

section .text

SYS_READ     equ 0
SYS_WRITE    equ 1
SYS_MMAP     equ 9
SYS_MPROTECT equ 10
SYS_EXIT     equ 60

PROT_RW      equ 3           ; PROT_READ | PROT_WRITE
PROT_RX      equ 5           ; PROT_READ | PROT_EXEC
MAP_ANON     equ 0x22        ; MAP_PRIVATE | MAP_ANONYMOUS

CODE_SIZE    equ 65536        ; 64 KiB code buffer
TAPE_SIZE    equ 30000        ; standard BF tape
STACK_MAX    equ 256          ; max bracket nesting

main:
    cmp  rdi, 2
    jl   .usage
    mov  r14, [rsi + 8]       ; r14 = BF source (argv[1])

    ; allocate tape — zeroed by mmap
    mov  eax, SYS_MMAP
    xor  edi, edi
    mov  esi, TAPE_SIZE
    mov  edx, PROT_RW
    mov  r10d, MAP_ANON
    mov  r8d, -1
    xor  r9d, r9d
    syscall
    mov  r15, rax             ; r15 = tape

    ; allocate code buffer (RW)
    mov  eax, SYS_MMAP
    xor  edi, edi
    mov  esi, CODE_SIZE
    mov  edx, PROT_RW
    mov  r10d, MAP_ANON
    mov  r8d, -1
    xor  r9d, r9d
    syscall
    mov  r13, rax             ; r13 = code base
    mov  r12, rax             ; r12 = write cursor

    ; --- emit prologue: push r12 ; mov r12, rdi ---
    mov  word [r12], 0x5441   ; push r12               (41 54)
    mov  byte [r12+2], 0x49
    mov  byte [r12+3], 0x89
    mov  byte [r12+4], 0xFC   ; mov  r12, rdi           (49 89 FC)
    add  r12, 5

    xor  ebp, ebp             ; bracket stack depth

    ; --- compile: walk source, emit machine code ---
.compile:
    movzx eax, byte [r14]
    test al,  al
    jz   .done

    cmp  al,  '>'
    je   .right
    cmp  al,  '<'
    je   .left
    cmp  al,  '+'
    je   .inc
    cmp  al,  '-'
    je   .dec
    cmp  al,  '.'
    je   .out
    cmp  al,  ','
    je   .in
    cmp  al,  '['
    je   .open
    cmp  al,  ']'
    je   .close
    jmp  .next                ; skip non-BF characters

.right:                       ; > : inc r12              (49 FF C4)
    mov  byte [r12],   0x49
    mov  byte [r12+1], 0xFF
    mov  byte [r12+2], 0xC4
    add  r12, 3
    jmp  .next

.left:                        ; < : dec r12              (49 FF CC)
    mov  byte [r12],   0x49
    mov  byte [r12+1], 0xFF
    mov  byte [r12+2], 0xCC
    add  r12, 3
    jmp  .next

.inc:                         ; + : inc byte [r12]       (41 FE 04 24)
    mov  dword [r12], 0x2404FE41
    add  r12, 4
    jmp  .next

.dec:                         ; - : dec byte [r12]       (41 FE 0C 24)
    mov  dword [r12], 0x240CFE41
    add  r12, 4
    jmp  .next

.out:                         ; . : write(1, r12, 1) via syscall
    mov  byte  [r12],    0xB8       ; mov eax, SYS_WRITE
    mov  dword [r12+1],  SYS_WRITE
    mov  byte  [r12+5],  0xBF      ; mov edi, 1 (stdout)
    mov  dword [r12+6],  1
    mov  byte  [r12+10], 0x4C      ; mov rsi, r12
    mov  byte  [r12+11], 0x89
    mov  byte  [r12+12], 0xE6
    mov  byte  [r12+13], 0xBA      ; mov edx, 1
    mov  dword [r12+14], 1
    mov  word  [r12+18], 0x050F    ; syscall
    add  r12, 20
    jmp  .next

.in:                          ; , : read(0, r12, 1) via syscall
    mov  word  [r12],    0xC031    ; xor eax, eax (SYS_READ = 0)
    mov  word  [r12+2],  0xFF31    ; xor edi, edi (stdin)
    mov  byte  [r12+4],  0x4C     ; mov rsi, r12
    mov  byte  [r12+5],  0x89
    mov  byte  [r12+6],  0xE6
    mov  byte  [r12+7],  0xBA     ; mov edx, 1
    mov  dword [r12+8],  1
    mov  word  [r12+12], 0x050F   ; syscall
    add  r12, 14
    jmp  .next

.open:                        ; [ : if *ptr == 0, jump forward past ]
    mov  byte  [r12],   0x41      ; cmp byte [r12], 0     (41 80 3C 24 00)
    mov  dword [r12+1], 0x00243C80
    mov  byte  [r12+5], 0x0F      ; jz  rel32             (0F 84 xx xx xx xx)
    mov  byte  [r12+6], 0x84
    mov  dword [r12+7], 0         ; placeholder

    lea  rax, [r12 + 7]           ; address of the rel32 to patch later
    lea  rcx, [bstack]
    mov  [rcx + rbp*8], rax
    inc  ebp

    add  r12, 11
    jmp  .next

.close:                       ; ] : if *ptr != 0, jump back to [
    test ebp, ebp
    jz   .fail                    ; unmatched ]

    dec  ebp
    lea  rcx, [bstack]
    mov  rbx, [rcx + rbp*8]      ; rbx = address of ['s jz rel32

    mov  byte  [r12],   0x41     ; cmp byte [r12], 0      (41 80 3C 24 00)
    mov  dword [r12+1], 0x00243C80
    mov  byte  [r12+5], 0x0F     ; jnz rel32              (0F 85 xx xx xx xx)
    mov  byte  [r12+6], 0x85

    ; ]'s jnz target = rbx+4 (after [), current = r12+11 (after ])
    mov  rax, rbx
    add  rax, 4
    mov  rdx, r12
    add  rdx, 11
    sub  rax, rdx
    mov  [r12+7], eax

    ; patch ['s jz: target = r12+11 (after ]), current = rbx+4 (after [)
    mov  rax, r12
    add  rax, 11
    sub  rax, rbx
    sub  eax, 4
    mov  [rbx], eax

    add  r12, 11
    jmp  .next

.next:
    inc  r14
    jmp  .compile

    ; --- done: emit epilogue, mprotect, execute ---
.done:
    test ebp, ebp
    jnz  .fail                ; unmatched [

    ; emit epilogue: pop r12 ; ret
    mov  word [r12], 0x5C41   ; pop  r12                (41 5C)
    mov  byte [r12+2], 0xC3  ; ret                     (C3)

    ; mprotect: RW → RX
    mov  eax, SYS_MPROTECT
    mov  rdi, r13
    mov  esi, CODE_SIZE
    mov  edx, PROT_RX
    syscall
    test eax, eax
    jnz  .fail

    ; execute the generated code
    mov  rdi, r15             ; tape pointer as first argument
    call r13

    xor  edi, edi
    mov  eax, SYS_EXIT
    syscall

.usage:
    mov  eax, SYS_WRITE
    mov  edi, 2               ; stderr
    lea  rsi, [USAGE]
    mov  edx, USAGE_LEN
    syscall

.fail:
    mov  edi, 1
    mov  eax, SYS_EXIT
    syscall

section .data
USAGE:     db "Usage: brainf <program>",10
USAGE_LEN equ $ - USAGE

section .bss
bstack: resq STACK_MAX
