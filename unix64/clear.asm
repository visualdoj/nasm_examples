bits 64
default rel

global main

section .text
main:
    ; write(stdout, SEQ, SEQ_LEN)
    mov  rax, 1
    mov  rdi, 1
    lea  rsi, [SEQ]
    mov  rdx, SEQ_LEN
    syscall

    ; exit(0)
    mov  rax, 60
    xor  edi, edi
    syscall

section .data
SEQ: db 0x1b,"[H",0x1b,"[2J",0x1b,"[3J"
SEQ_LEN equ $ - SEQ
