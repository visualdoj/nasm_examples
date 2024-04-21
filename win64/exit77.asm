bits 64
default rel

global main

extern ExitProcess

section .code
main:
  sub rsp, 8+32 ; &bytes, shadow space
  and rsp, ~0xf ; 16-byte alignment

  mov rcx, 77
  call ExitProcess
  hlt
