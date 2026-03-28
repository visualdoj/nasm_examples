bits 64
default rel

global _main

SIGINT  equ 2
SIGTERM equ 15

section .text
_main:
    sub  rsp, 8                ; align stack + local storage for __sigwait result

    ; sigprocmask(SIG_BLOCK, &block_set, NULL) — block SIGINT and SIGTERM
    mov  rax, 0x02000030       ; syscall: sigprocmask (48)
    mov  rdi, 1                ; SIG_BLOCK
    lea  rsi, [block_set]
    xor  edx, edx              ; omask = NULL
    syscall

    ; write(stdout, MSG_PROMPT, MSG_PROMPT_LEN)
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [MSG_PROMPT]
    mov  rdx, MSG_PROMPT_LEN
    syscall

    ; __sigwait(&block_set, &sig) — wait for a blocked signal
    mov  rax, 0x020001AD       ; syscall: sigwait (429)
    lea  rdi, [block_set]
    lea  rsi, [rsp]            ; &sig (receives signal number)
    syscall
    mov  r12d, [rsp]           ; save received signal number

    ; Choose message: SIGINT → "Received Ctrl+C", else → "Received kill signal"
    lea  rsi, [MSG_KILL]
    mov  rdx, MSG_KILL_LEN
    cmp  r12d, SIGINT
    jne  .print
    lea  rsi, [MSG_CTRLC]
    mov  rdx, MSG_CTRLC_LEN

.print:
    ; write(stdout, msg, len)
    mov  rax, 0x02000004
    mov  rdi, 1
    syscall

    ; sigprocmask(SIG_UNBLOCK, &block_set, NULL) — unblock before re-raise
    mov  rax, 0x02000030
    mov  rdi, 2                ; SIG_UNBLOCK
    lea  rsi, [block_set]
    xor  edx, edx
    syscall

    ; kill(getpid(), sig) — re-raise to exit via standard signal
    mov  rax, 0x02000014       ; syscall: getpid (20)
    syscall
    mov  rdi, rax              ; pid
    mov  rax, 0x02000025       ; syscall: kill (37)
    mov  esi, r12d             ; signal
    syscall
    hlt                        ; should not reach here

section .data
; Signal mask: bits for SIGINT(2) and SIGTERM(15)
block_set: dd (1 << (SIGINT-1)) | (1 << (SIGTERM-1))

MSG_PROMPT: db "Press Ctrl+C to exit...",10
MSG_PROMPT_LEN equ $ - MSG_PROMPT
MSG_CTRLC: db "Received Ctrl+C",10
MSG_CTRLC_LEN equ $ - MSG_CTRLC
MSG_KILL: db "Received kill signal",10
MSG_KILL_LEN equ $ - MSG_KILL
