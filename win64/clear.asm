bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetConsoleMode
extern SetConsoleMode
extern WriteFile

STD_OUTPUT_HANDLE equ -11
ENABLE_VIRTUAL_TERMINAL_PROCESSING equ 0x0004

section .text
main:
    ; Alignment + Local variables (bytes) + Arguments + Shadow Space
    sub  rsp, 12+4+8+32

    ; stdout = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  [stdout], rax

    ; GetConsoleMode(stdout, &terminalMode)
    mov  rcx, rax
    lea  rdx, [terminalMode]
    call GetConsoleMode

    ; SetConsoleMode(stdout, terminalMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    mov  rcx, [stdout]
    mov  edx, [terminalMode]
    or   edx, ENABLE_VIRTUAL_TERMINAL_PROCESSING
    call SetConsoleMode

    ; WriteFile(stdout, &SEQ, SEQ_LEN, &bytes, NULL)
    mov  rcx, [stdout]
    lea  rdx, [SEQ]
    mov  r8,  SEQ_LEN
    lea  r9,  [rsp+40]
    mov  QWORD [rsp+32], 0
    call WriteFile

    ; ExitProcess(0)
    mov  rcx, 0
    call ExitProcess
    hlt

section .data
SEQ: db 0x1b,"[H",0x1b,"[2J",0x1b,"[3J"
SEQ_LEN equ $ - SEQ

section .bss
stdout:       resq 1
terminalMode: resd 1
