bits 64
default rel

global _main

section .text
_main:
    ; write(stdout, MSG, MSG_LEN)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [MSG]            ; buf: message address
    mov  rdx, MSG_LEN          ; count: message length
    syscall

    mov  rax, 0x02000001       ; syscall: exit
    mov  rdi, 0                ; status: success
    syscall

section .data
MSG: db "Hello world!",10
MSG_LEN equ $ - MSG
