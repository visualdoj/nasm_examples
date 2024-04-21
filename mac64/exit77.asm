bits 64

global start

section .text
start:
    mov rax, 0x02000001 ; syscall for exit
    mov rdi, 77         ; exit code
    syscall
