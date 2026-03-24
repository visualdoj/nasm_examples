bits 64
default rel

global _main

section .text
_main:
    ; write(stdout, MSG, MSG_LEN)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [MSG]            ; buf: color escape sequences
    mov  rdx, MSG_LEN          ; count: message length
    syscall

    mov  rax, 0x02000001       ; syscall: exit
    mov  rdi, 0                ; status: success
    syscall

section .data
MSG: db \
        0x1b,"[97mWhite ",0x1b,"[91mRed ",0x1b,"[92mGreen ",0x1b,"[93mYellow ",0x1b,"[94mBlue ",0x1b,"[95mMagenta ",0x1b,"[96mCyan ",0x1b,"[0m",10,\
        0x1b,"[37mWhite ",0x1b,"[31mRed ",0x1b,"[32mGreen ",0x1b,"[33mYellow ",0x1b,"[34mBlue ",0x1b,"[35mMagenta ",0x1b,"[36mCyan ",0x1b,"[0m",10
MSG_LEN equ $ - MSG
