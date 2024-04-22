bits 64
default rel

global main

section .text
main:
    mov rax, 1          ; syscall for write
    mov rdi, 1          ; argument 1: file handle 1 which is stdout
    lea rsi, [MSG]      ; argument 2: pointer to data to output
    mov rdx, MSG_LEN    ; argument 3: number of bytes to output
    syscall

    mov rax, 60         ; syscall for exit
    mov rdi, 0          ; exit code
    syscall

section .data
MSG: db "Hello world!",10
MSG_LEN equ $ - MSG
