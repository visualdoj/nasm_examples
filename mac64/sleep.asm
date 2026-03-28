bits 64
default rel

global _main

section .text
_main:
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
    ; select(0, NULL, NULL, NULL, &timeval) — sleep for N seconds
    sub  rsp, 16               ; struct timeval { tv_sec(8), tv_usec(8) }
    mov  [rsp], r12            ; tv_sec = N
    mov  QWORD [rsp+8], 0     ; tv_usec = 0

    mov  rax, 0x0200005D       ; syscall: select (93)
    xor  edi, edi              ; nfds = 0
    xor  esi, esi              ; readfds = NULL
    xor  edx, edx              ; writefds = NULL
    xor  r10d, r10d            ; exceptfds = NULL
    lea  r8,  [rsp]            ; timeout = &timeval
    syscall

    ; exit(0)
    mov  rax, 0x02000001       ; syscall: exit
    xor  edi, edi
    syscall

.exit_error:
    mov  rax, 0x02000001
    mov  rdi, 1
    syscall
