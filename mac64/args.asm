bits 64
default rel

global _main

section .text
_main:
    ; argc is in rdi, argv is in rsi

    add  rsi, 8                ; skip argv[0] (program name)
    dec  rdi
    jle  .exit

.loop:
    push rdi                   ; preserve remaining argc
    push rsi                   ; preserve argv pointer

    ; strlen: scan for null terminator to find argument length
    mov  rsi, [rsi]            ; rsi = pointer to current argument
    mov  rcx, rsi              ; cursor
    xor  rdx, rdx              ; length = 0

.strlen:
    mov  r8b, [rcx]
    test r8b, r8b
    jz   .strlen_done
    inc  rdx
    inc  rcx
    jmp  .strlen

.strlen_done:
    ; write(stdout, argument, length)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    syscall

    ; write(stdout, "\n", 1)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [NEWLINE]        ; buf: newline character
    mov  rdx, 1                ; count: one byte
    syscall

    pop  rsi                   ; restore argv pointer
    pop  rdi                   ; restore remaining argc

    add  rsi, 8                ; advance to next argument
    dec  rdi                   ; one fewer argument remaining
    jnz  .loop

.exit:
    mov  rax, 0x02000001       ; syscall: exit
    mov  rdi, 0                ; status: success
    syscall

section .data
NEWLINE: db 10
