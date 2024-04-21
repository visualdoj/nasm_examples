bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern WriteFile

STD_OUTPUT_HANDLE equ -11

section .code
main:
  sub rsp, 8+32 ; &bytes, shadow space
  and rsp, ~0xf ; 16-byte alignment

  mov rcx, STD_OUTPUT_HANDLE
  call GetStdHandle

  mov rcx, rax            ; argument 1: file handle returned from GetStdHandle
  lea rdx, [MSG]          ; argument 2: string
  mov r8, MSG_LEN         ; argument 3: string length
  lea r9, qword [rsp+32]  ; argument 4: &bytes
  mov qword [rsp], 0      ; argument 5: lpOverlapped
  call WriteFile

  mov rcx, 0
  call ExitProcess
  hlt

section .data
MSG: db "Hello world!",13,10
MSG_LEN equ $ - MSG
