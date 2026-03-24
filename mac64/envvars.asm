bits 64
default rel

global _main

section .text
_main:
    ; envp is in rdx (third argument to _main)

    mov  rdi, rdx              ; rdi = envp array pointer

.loop:
    mov  rsi, [rdi]            ; rsi = current env string
    test rsi, rsi              ; NULL marks end of envp array
    jz   .exit

    push rdi                   ; preserve envp position

    ; strlen: scan for null terminator to find string length
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
    ; write(stdout, env_string, length)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    syscall

    ; write(stdout, "\n", 1)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [NEWLINE]        ; buf: newline character
    mov  rdx, 1                ; count: one byte
    syscall

    pop  rdi                   ; restore envp position

    add  rdi, 8                ; advance to next env pointer
    jmp  .loop

.exit:
    mov  rax, 0x02000001       ; syscall: exit
    mov  rdi, 0                ; status: success
    syscall

section .data
NEWLINE: db 10
