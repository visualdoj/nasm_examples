; brainf.asm — Brainfuck JIT compiler
;
; Reads a BF program from argv[1], compiles it to x86-64 machine code
; at runtime, then executes the generated code.  Uses mmap/mprotect
; for W^X code generation.
;
; Usage: brainf '<program>'

bits 64
default rel

global _main

section .text

SYS_READ     equ 0x02000003
SYS_WRITE    equ 0x02000004
SYS_MMAP     equ 0x020000C5
SYS_MPROTECT equ 0x0200004A
SYS_EXIT     equ 0x02000001

PROT_RW      equ 3           ; PROT_READ | PROT_WRITE
PROT_RX      equ 5           ; PROT_READ | PROT_EXEC
MAP_ANON     equ 0x1002      ; MAP_PRIVATE | MAP_ANON

CODE_SIZE    equ 65536
TAPE_SIZE    equ 30000
STACK_MAX    equ 256

_main:
    cmp  rdi, 2
    jl   .usage
    mov  r14, [rsi + 8]       ; r14 = BF source (argv[1])

    ; allocate tape — zeroed by mmap
    mov  rax, SYS_MMAP
    mov  rdi, 0
    mov  rsi, TAPE_SIZE
    mov  rdx, PROT_RW
    mov  r10, MAP_ANON
    mov  r8,  -1
    mov  r9,  0
    syscall
    mov  r15, rax             ; r15 = tape

    ; allocate code buffer (RW)
    mov  rax, SYS_MMAP
    mov  rdi, 0
    mov  rsi, CODE_SIZE
    mov  rdx, PROT_RW
    mov  r10, MAP_ANON
    mov  r8,  -1
    mov  r9,  0
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
    jmp  .next

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
    mov  byte  [r12],    0xB8      ; mov eax, SYS_READ
    mov  dword [r12+1],  SYS_READ
    mov  word  [r12+5],  0xFF31    ; xor edi, edi (stdin)
    mov  byte  [r12+7],  0x4C     ; mov rsi, r12
    mov  byte  [r12+8],  0x89
    mov  byte  [r12+9],  0xE6
    mov  byte  [r12+10], 0xBA     ; mov edx, 1
    mov  dword [r12+11], 1
    mov  word  [r12+15], 0x050F   ; syscall
    add  r12, 17
    jmp  .next

.open:                        ; [ : if *ptr == 0, jump forward past ]
    mov  byte  [r12],   0x41
    mov  dword [r12+1], 0x00243C80   ; cmp byte [r12], 0
    mov  byte  [r12+5], 0x0F        ; jz  rel32
    mov  byte  [r12+6], 0x84
    mov  dword [r12+7], 0           ; placeholder

    lea  rax, [r12 + 7]
    lea  rcx, [bstack]
    mov  [rcx + rbp*8], rax
    inc  ebp

    add  r12, 11
    jmp  .next

.close:                       ; ] : if *ptr != 0, jump back to [
    test ebp, ebp
    jz   .fail

    dec  ebp
    lea  rcx, [bstack]
    mov  rbx, [rcx + rbp*8]

    mov  byte  [r12],   0x41
    mov  dword [r12+1], 0x00243C80   ; cmp byte [r12], 0
    mov  byte  [r12+5], 0x0F        ; jnz rel32
    mov  byte  [r12+6], 0x85

    mov  rax, rbx
    add  rax, 4
    mov  rdx, r12
    add  rdx, 11
    sub  rax, rdx
    mov  [r12+7], eax

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
    jnz  .fail

    mov  word [r12], 0x5C41   ; pop  r12                (41 5C)
    mov  byte [r12+2], 0xC3  ; ret                     (C3)

    ; mprotect: RW → RX
    mov  rax, SYS_MPROTECT
    mov  rdi, r13
    mov  rsi, CODE_SIZE
    mov  rdx, PROT_RX
    syscall
    test eax, eax
    jnz  .fail

    mov  rdi, r15
    call r13

    xor  edi, edi
    mov  rax, SYS_EXIT
    syscall

.usage:
    mov  rax, SYS_WRITE
    mov  rdi, 2               ; stderr
    lea  rsi, [USAGE]
    mov  rdx, USAGE_LEN
    syscall

.fail:
    mov  rdi, 1
    mov  rax, SYS_EXIT
    syscall

section .data
USAGE:     db "Usage: brainf <program>",10
USAGE_LEN equ $ - USAGE

section .bss
bstack: resq STACK_MAX
