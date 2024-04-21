bits 64

global _main

section .text
_main:
    mov rax, 0x02000001 ; syscall for exit
    mov rdi, 77         ; exit code
    syscall
