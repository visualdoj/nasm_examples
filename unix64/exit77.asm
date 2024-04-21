bits 64

global main

main:
    mov rax, 60 ; syscall for exit
    mov rdi, 77 ; exit code
    syscall
