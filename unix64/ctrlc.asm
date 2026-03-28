bits 64
default rel

global main

SIGINT  equ 2
SIGTERM equ 15

section .text
main:
    ; rt_sigprocmask(SIG_BLOCK, &block_set, NULL, 8) — block SIGINT and SIGTERM
    mov  rax, 14               ; syscall: rt_sigprocmask
    xor  edi, edi              ; SIG_BLOCK = 0
    lea  rsi, [block_set]
    xor  edx, edx              ; oset = NULL
    mov  r10, 8                ; sigsetsize
    syscall

    ; write(stdout, MSG_PROMPT, MSG_PROMPT_LEN)
    mov  rax, 1                ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [MSG_PROMPT]
    mov  rdx, MSG_PROMPT_LEN
    syscall

    ; rt_sigtimedwait(&block_set, NULL, NULL, 8) — wait for a blocked signal
    mov  rax, 128              ; syscall: rt_sigtimedwait
    lea  rdi, [block_set]
    xor  esi, esi              ; info = NULL
    xor  edx, edx              ; timeout = NULL (wait forever)
    mov  r10, 8                ; sigsetsize
    syscall
    mov  r12d, eax             ; save received signal number

    ; Choose message: SIGINT → "Received Ctrl+C", else → "Received kill signal"
    lea  rsi, [MSG_KILL]
    mov  rdx, MSG_KILL_LEN
    cmp  r12d, SIGINT
    jne  .print
    lea  rsi, [MSG_CTRLC]
    mov  rdx, MSG_CTRLC_LEN

.print:
    ; write(stdout, msg, len)
    mov  rax, 1
    mov  rdi, 1
    syscall

    ; rt_sigprocmask(SIG_UNBLOCK, &block_set, NULL, 8) — unblock before re-raise
    mov  rax, 14
    mov  edi, 1                ; SIG_UNBLOCK
    lea  rsi, [block_set]
    xor  edx, edx
    mov  r10, 8
    syscall

    ; kill(getpid(), sig) — re-raise to exit via standard signal
    mov  rax, 39               ; syscall: getpid
    syscall
    mov  rdi, rax              ; pid
    mov  rax, 62               ; syscall: kill
    mov  esi, r12d             ; signal
    syscall
    hlt                        ; should not reach here

section .data
; Signal mask: bits for SIGINT(2) and SIGTERM(15)
block_set: dq (1 << (SIGINT-1)) | (1 << (SIGTERM-1))

MSG_PROMPT: db "Press Ctrl+C to exit...",10
MSG_PROMPT_LEN equ $ - MSG_PROMPT
MSG_CTRLC: db "Received Ctrl+C",10
MSG_CTRLC_LEN equ $ - MSG_CTRLC
MSG_KILL: db "Received kill signal",10
MSG_KILL_LEN equ $ - MSG_KILL
