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
MSG: db \
        0x1b,"[97mWhite ",0x1b,"[91mRed ",0x1b,"[92mGreen ",0x1b,"[93mYellow ",0x1b,"[94mBlue ",0x1b,"[95mMagenta ",0x1b,"[96mCyan ",0x1b,"[0m",10,\
        0x1b,"[37mWhite ",0x1b,"[31mRed ",0x1b,"[32mGreen ",0x1b,"[33mYellow ",0x1b,"[34mBlue ",0x1b,"[35mMagenta ",0x1b,"[36mCyan ",0x1b,"[0m",10
MSG_LEN equ $ - MSG
