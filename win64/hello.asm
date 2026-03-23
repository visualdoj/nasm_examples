bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern WriteFile

STD_OUTPUT_HANDLE equ -11

section .text
main:
    ; Alignment + Local variables (bytes) + Arguments + Shadow Space
    sub  rsp, 12+4+8+32
 
    ; rax = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE  ; argument 1: identifier of a standard device
    call GetStdHandle
 
    ; rax = WriteFile(rax, &MSG, MSG_LEN, &bytes, NULL)
    mov  rcx, rax            ; argument 1: file handle returned from GetStdHandle
    lea  rdx, [MSG]          ; argument 2: string
    mov  r8, MSG_LEN         ; argument 3: string length
    lea  r9, DWORD [rsp+32]  ; argument 4: &bytes
    mov  QWORD [rsp], 0      ; argument 5: lpOverlapped
    call WriteFile
 
    ; ExitProcess(0)
    mov  rcx, 0
    call ExitProcess
    hlt

section .data
MSG: db "Hello world!",13,10
MSG_LEN equ $ - MSG
