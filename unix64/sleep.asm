bits 64
default rel

global main

section .text
main:
    ; argc is in rdi, argv is in rsi

    cmp  rdi, 2
    jne  .exit_error

    ; parse argv[1] to integer N -> r12
    mov  rsi, [rsi + 8]
    xor  r12, r12

.parse:
    movzx rcx, byte [rsi]
    test cl,  cl
    jz   .parse_done
    imul r12, r12, 10
    sub  cl,  '0'
    add  r12, rcx
    inc  rsi
    jmp  .parse

.parse_done:
    ; nanosleep({N, 0}, NULL)
    sub  rsp, 16               ; struct timespec { tv_sec(8), tv_nsec(8) }
    mov  [rsp], r12            ; tv_sec = N
    mov  QWORD [rsp+8], 0     ; tv_nsec = 0

    mov  rax, 35               ; syscall: nanosleep
    lea  rdi, [rsp]            ; req
    xor  esi, esi              ; rem = NULL
    syscall

    ; exit(0)
    mov  rax, 60               ; syscall: exit
    xor  edi, edi
    syscall

.exit_error:
    mov  rax, 60
    mov  rdi, 1
    syscall
