; brainf.asm — Brainfuck JIT compiler
;
; Reads a BF program from argv[1], compiles it to x86-64 machine code
; at runtime, then executes the generated code.  Uses VirtualAlloc /
; VirtualProtect for W^X code generation.
;
; Usage: brainf '<program>'

bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree
extern VirtualAlloc
extern VirtualFree
extern VirtualProtect
extern WriteFile
extern ReadFile

STD_INPUT_HANDLE   equ -10
STD_OUTPUT_HANDLE  equ -11

MEM_COMMIT_RESERVE equ 0x3000      ; MEM_COMMIT | MEM_RESERVE
MEM_RELEASE        equ 0x8000
PAGE_READWRITE     equ 0x04
PAGE_EXECUTE_READ  equ 0x20

CODE_SIZE          equ 65536
TAPE_SIZE          equ 30000
STACK_MAX          equ 256

section .bss
argc:     resq 1
argW:     resq 1
old_prot: resd 1
bstack:   resq STACK_MAX

section .text
main:
    ; align(8) + locals(8) + 5th-arg(8) + shadow(32) = 56
    sub  rsp, 56

    ; --- parse command line ---
    call GetCommandLineW
    mov  rcx, rax
    lea  rdx, [argc]
    call CommandLineToArgvW
    mov  [argW], rax

    cmp  QWORD [argc], 2
    jl   .usage

    mov  r14, [rax + 8]       ; r14 = argv[1] (wide string)

    ; --- allocate tape (zeroed by VirtualAlloc) ---
    mov  rcx, 0
    mov  rdx, TAPE_SIZE
    mov  r8,  MEM_COMMIT_RESERVE
    mov  r9,  PAGE_READWRITE
    call VirtualAlloc
    mov  r15, rax             ; r15 = tape

    ; --- allocate code buffer (RW) ---
    mov  rcx, 0
    mov  rdx, CODE_SIZE
    mov  r8,  MEM_COMMIT_RESERVE
    mov  r9,  PAGE_READWRITE
    call VirtualAlloc
    mov  r13, rax             ; r13 = code base
    mov  r12, rax             ; r12 = write cursor

    ; --- emit prologue ---
    ;   push r12 ; push r13 ; push r14
    ;   mov r12, rcx ; mov r13, rdx ; mov r14, r8
    mov  word [r12],    0x5441     ; push r12   (41 54)
    mov  word [r12+2],  0x5541     ; push r13   (41 55)
    mov  word [r12+4],  0x5641     ; push r14   (41 56)
    mov  byte [r12+6],  0x49       ; mov r12, rcx (49 89 CC)
    mov  byte [r12+7],  0x89
    mov  byte [r12+8],  0xCC
    mov  byte [r12+9],  0x49       ; mov r13, rdx (49 89 D5)
    mov  byte [r12+10], 0x89
    mov  byte [r12+11], 0xD5
    mov  byte [r12+12], 0x4D       ; mov r14, r8  (4D 89 C6)
    mov  byte [r12+13], 0x89
    mov  byte [r12+14], 0xC6
    add  r12, 15

    xor  ebp, ebp             ; bracket stack depth

    ; --- compile: walk source (UTF-16), emit machine code ---
.compile:
    movzx eax, word [r14]     ; read UTF-16 char
    test ax,  ax
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

.out:                         ; . : call r13 (putchar)   (41 FF D5)
    mov  byte [r12],   0x41
    mov  byte [r12+1], 0xFF
    mov  byte [r12+2], 0xD5
    add  r12, 3
    jmp  .next

.in:                          ; , : call r14 (getchar)   (41 FF D6)
    mov  byte [r12],   0x41
    mov  byte [r12+1], 0xFF
    mov  byte [r12+2], 0xD6
    add  r12, 3
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
    add  r14, 2               ; advance by 2 (UTF-16)
    jmp  .compile

    ; --- done: emit epilogue, VirtualProtect, execute ---
.done:
    test ebp, ebp
    jnz  .fail

    ; emit epilogue: pop r14 ; pop r13 ; pop r12 ; ret
    mov  word [r12],   0x5E41      ; pop r14    (41 5E)
    mov  word [r12+2], 0x5D41      ; pop r13    (41 5D)
    mov  word [r12+4], 0x5C41      ; pop r12    (41 5C)
    mov  byte [r12+6], 0xC3       ; ret         (C3)

    ; VirtualProtect: RW → RX
    mov  rcx, r13
    mov  rdx, CODE_SIZE
    mov  r8,  PAGE_EXECUTE_READ
    lea  r9,  [old_prot]
    call VirtualProtect
    test eax, eax
    jz   .fail

    ; get I/O handles — stored in callee-saved regs for the helpers
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  rbx, rax             ; rbx = stdout (used by bf_putchar)

    mov  rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov  rbp, rax             ; rbp = stdin  (used by bf_getchar)

    ; call generated code(tape, &bf_putchar, &bf_getchar)
    mov  rcx, r15
    lea  rdx, [bf_putchar]
    lea  r8,  [bf_getchar]
    call r13

    ; cleanup
    mov  rcx, [argW]
    call LocalFree

    mov  rcx, 0
    call ExitProcess
    hlt

.usage:
    mov  rcx, [argW]
    call LocalFree

.fail:
    mov  rcx, 1
    call ExitProcess
    hlt


; --- helpers called by generated code via register ---
; rbx = stdout handle, rbp = stdin handle (callee-saved, set before call)
; r12 = tape pointer  (callee-saved, set by generated prologue)

bf_putchar:
    ; WriteFile(stdout, r12, 1, &written, NULL)
    sub  rsp, 56               ; shadow(32) + arg5(8) + local(8) + align(8)
    mov  rcx, rbx
    mov  rdx, r12
    mov  r8,  1
    lea  r9,  [rsp + 40]
    mov  QWORD [rsp + 32], 0
    call WriteFile
    add  rsp, 56
    ret

bf_getchar:
    ; ReadFile(stdin, r12, 1, &bytesRead, NULL)
    sub  rsp, 56
    mov  rcx, rbp
    mov  rdx, r12
    mov  r8,  1
    lea  r9,  [rsp + 40]
    mov  QWORD [rsp + 32], 0
    call ReadFile
    add  rsp, 56
    ret
