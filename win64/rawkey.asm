bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetConsoleMode
extern SetConsoleMode
extern ReadConsoleInputA
extern ReadFile
extern WriteFile

STD_INPUT_HANDLE  equ -10
STD_OUTPUT_HANDLE equ -11
ENABLE_LINE_INPUT equ 0x0002
ENABLE_ECHO_INPUT equ 0x0004
KEY_EVENT         equ 0x0001

section .text
main:
    ; 5th arg (8) + Shadow Space (32) = 40
    sub  rsp, 8+32

    ; r12 = GetStdHandle(STD_INPUT_HANDLE)
    mov  rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov  r12, rax

    ; r13 = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  r13, rax

    ; r14d = GetConsoleMode(stdin, &oldMode) — nonzero if stdin is a console
    mov  rcx, r12
    lea  rdx, [oldMode]
    call GetConsoleMode
    mov  r14d, eax

    test r14d, r14d
    jz   .loop

    ; Console: disable line buffering and echo
    mov  rcx, r12
    mov  edx, [oldMode]
    and  edx, ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)
    call SetConsoleMode

.loop:
    test r14d, r14d
    jz   .read_pipe

    ; Console path: ReadConsoleInputA(stdin, &record, 1, &nread)
    mov  rcx, r12
    lea  rdx, [record]
    mov  r8,  1
    lea  r9,  [nread]
    call ReadConsoleInputA

    ; Skip non-key events, key-up events, and non-character keys
    cmp  WORD [record], KEY_EVENT
    jne  .loop
    cmp  DWORD [record + 4], 0        ; bKeyDown
    je   .loop
    movzx eax, byte [record + 14]     ; AsciiChar
    test al, al
    jz   .loop
    jmp  .got_byte

.read_pipe:
    ; Pipe path: ReadFile(stdin, &keybyte, 1, &nread, NULL)
    mov  rcx, r12
    lea  rdx, [keybyte]
    mov  r8,  1
    lea  r9,  [nread]
    mov  QWORD [rsp+32], 0
    call ReadFile
    cmp  DWORD [nread], 0
    je   .restore
    movzx eax, byte [keybyte]

.got_byte:
    ; Save byte value for ESC check after conversion
    mov  r15d, eax

    ; Convert byte to decimal string
    lea  rdi, [numbuf + 3]
    mov  byte [rdi], 13               ; CR
    mov  byte [rdi + 1], 10           ; LF
    mov  ecx, 10
.to_str:
    xor  edx, edx
    div  ecx
    dec  rdi
    add  dl, '0'
    mov  [rdi], dl
    test eax, eax
    jnz  .to_str

    ; WriteFile(stdout, rdi, len, &nwritten, NULL)
    mov  rcx, r13
    mov  rdx, rdi
    lea  r8,  [numbuf + 5]
    sub  r8,  rdx
    lea  r9,  [nwritten]
    mov  QWORD [rsp+32], 0
    call WriteFile

    ; Exit on ESC (27)
    cmp  r15d, 27
    jne  .loop

.restore:
    ; Restore console mode if it was changed
    test r14d, r14d
    jz   .exit
    mov  rcx, r12
    mov  edx, [oldMode]
    call SetConsoleMode

.exit:
    mov  rcx, 0
    call ExitProcess
    hlt

section .bss
oldMode:  resd 1
nread:    resd 1
nwritten: resd 1
record:   resb 20
keybyte:  resb 1
numbuf:   resb 5
