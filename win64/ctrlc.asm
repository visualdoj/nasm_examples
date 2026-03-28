bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern SetConsoleCtrlHandler
extern Sleep
extern WriteFile

STD_OUTPUT_HANDLE equ -11
INFINITE equ 0xFFFFFFFF

section .text
main:
    ; Alignment + Local variables (bytes) + Arguments + Shadow Space
    sub  rsp, 12+4+8+32

    ; rax = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  [stdout], rax

    ; SetConsoleCtrlHandler(handler, TRUE)
    lea  rcx, [handler]
    mov  rdx, 1
    call SetConsoleCtrlHandler

    ; WriteFile(stdout, MSG_PROMPT, MSG_PROMPT_LEN, &bytes, NULL)
    mov  rcx, [stdout]
    lea  rdx, [MSG_PROMPT]
    mov  r8,  MSG_PROMPT_LEN
    lea  r9,  [rsp+40]
    mov  QWORD [rsp+32], 0
    call WriteFile

.wait:
    ; Sleep(INFINITE) — block until Ctrl+C terminates the process
    mov  rcx, INFINITE
    call Sleep
    jmp  .wait

; Console control handler — called on an injected thread by the OS.
; RCX = dwCtrlType (0 = CTRL_C_EVENT, 1 = CTRL_BREAK_EVENT, ...)
handler:
    sub  rsp, 12+4+8+32

    ; Choose message: CTRL_C_EVENT (0) → "Received Ctrl+C", else → "Received kill signal"
    lea  rdx, [MSG_KILL]
    mov  r8,  MSG_KILL_LEN
    test ecx, ecx
    jnz  .print
    lea  rdx, [MSG_CTRLC]
    mov  r8,  MSG_CTRLC_LEN

.print:
    ; WriteFile(stdout, msg, len, &bytes, NULL)
    mov  rcx, [stdout]
    lea  r9,  [rsp+40]
    mov  QWORD [rsp+32], 0
    call WriteFile

    ; Return FALSE — let the default handler call ExitProcess(STATUS_CONTROL_C_EXIT)
    xor  eax, eax
    add  rsp, 12+4+8+32
    ret

section .data
MSG_PROMPT: db "Press Ctrl+C to exit...",13,10
MSG_PROMPT_LEN equ $ - MSG_PROMPT
MSG_CTRLC: db "Received Ctrl+C",13,10
MSG_CTRLC_LEN equ $ - MSG_CTRLC
MSG_KILL: db "Received kill signal",13,10
MSG_KILL_LEN equ $ - MSG_KILL

section .bss
stdout: resq 1
