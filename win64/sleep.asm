bits 64
default rel

global main

extern ExitProcess
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree
extern Sleep

section .text
main:
    ; Alignment + Shadow Space
    sub  rsp, 8+32

    ; rax = GetCommandLineW()
    call GetCommandLineW

    ; argW = CommandLineToArgvW(rax, &argc)
    mov  rcx, rax
    lea  rdx, [argc]
    call CommandLineToArgvW
    mov  [argW], rax

    ; need exactly one argument (argc == 2)
    cmp  QWORD [argc], 2
    jne  .exit_error

    ; parse argv[1] (UTF-16 digits) to integer N -> r12
    mov  rsi, [rax + 8]
    xor  r12, r12

.parse:
    movzx rcx, word [rsi]     ; UTF-16: 2 bytes per character
    test cx,  cx
    jz   .parse_done
    imul r12, r12, 10
    sub  cx,  '0'
    add  r12, rcx
    add  rsi, 2
    jmp  .parse

.parse_done:
    ; Sleep(N * 1000) — argument is in milliseconds
    imul rcx, r12, 1000
    call Sleep

    mov  rcx, [argW]
    call LocalFree

    mov  rcx, 0
    call ExitProcess
    hlt

.exit_error:
    mov  rcx, [argW]
    call LocalFree

    mov  rcx, 1
    call ExitProcess
    hlt

section .bss
argW: resq 1
argc: resq 1
