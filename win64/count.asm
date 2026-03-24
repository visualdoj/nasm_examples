bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern WriteFile
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree

STD_OUTPUT_HANDLE equ -11

section .bss
stdout_h resb 8
argW     resb 8
argc_val resb 8
buf      resb 22               ; 20 digits + CR + LF

section .text
main:
    ; Alignment(8) + bytesWritten(8) + 5th arg(8) + Shadow Space(32)
    sub  rsp, 8+8+8+32

    ; stdout_h = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  QWORD [stdout_h], rax

    ; rax = GetCommandLineW()
    call GetCommandLineW

    ; argW = CommandLineToArgvW(rax, &argc_val)
    mov  rcx, rax
    lea  rdx, QWORD [argc_val]
    call CommandLineToArgvW
    mov  QWORD [argW], rax

    ; need exactly one argument (argc == 2)
    cmp  QWORD [argc_val], 2
    jne  .exit_error

    ; parse argv[1] (UTF-16 digits) to integer N -> r12
    mov  rsi, [rax + 8]
    xor  r12, r12

.parse:
    movzx rcx, word [rsi]     ; UTF-16: 2 bytes per character
    test cx, cx
    jz   .parse_done
    imul r12, r12, 10
    sub  cx, '0'
    add  r12, rcx
    add  rsi, 2
    jmp  .parse

.parse_done:
    mov  r13, 1                ; counter

.loop:
    cmp  r13, r12
    jg   .cleanup

    ; integer-to-string: divide by 10 repeatedly, write remainders as digits right-to-left
    lea  rdi, [buf + 20]
    mov  byte [rdi], 13        ; CR
    mov  byte [rdi + 1], 10    ; LF
    mov  rax, r13
    mov  rcx, 10

.to_string:
    dec  rdi
    xor  rdx, rdx
    div  rcx                   ; rax = quotient, rdx = remainder
    add  dl, '0'
    mov  [rdi], dl
    test rax, rax
    jnz  .to_string

    ; WriteFile(stdout_h, rdi, len, &bytesWritten, NULL)
    lea  rax, [buf + 22]
    sub  rax, rdi              ; total length including CRLF
    mov  rcx, [stdout_h]      ; argument 1: handle
    mov  rdx, rdi              ; argument 2: buffer
    mov  r8,  rax              ; argument 3: length
    lea  r9,  [rsp + 40]      ; argument 4: &bytesWritten
    mov  QWORD [rsp + 32], 0  ; argument 5: lpOverlapped = NULL
    call WriteFile

    inc  r13
    jmp  .loop

.cleanup:
    mov  rcx, QWORD [argW]
    call LocalFree

    mov  rcx, 0
    call ExitProcess
    hlt

.exit_error:
    mov  rcx, QWORD [argW]
    call LocalFree

    mov  rcx, 1
    call ExitProcess
    hlt
