bits 64
default rel

global main

extern ExitProcess

section .text
main:
    sub  rsp, 8+32       ; Alignment + Shadow Space
 
    mov  rcx, 77
    call ExitProcess
    hlt
