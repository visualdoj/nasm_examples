bits 64
default rel

global _main

section .text
_main:
.read:
    ; read(stdin, &char, 1)
    mov  rax, 0x02000003    ; syscall: read
    mov  rdi, 0             ; fd: stdin
    lea  rsi, [char]        ; buf
    mov  rdx, 1             ; count
    syscall

    ; if rax <= 0, we're done (EOF or error)
    cmp  rax, 0
    jle  .done

    ; convert 'a'-'z' to 'A'-'Z'
    mov  cl,  BYTE [char]
    cmp  cl,  'a'
    jb   .write
    cmp  cl,  'z'
    ja   .write
    sub  cl,  32
    mov  BYTE [char], cl

.write:
    ; write(stdout, &char, 1)
    mov  rax, 0x02000004    ; syscall: write
    mov  rdi, 1             ; fd: stdout
    lea  rsi, [char]        ; buf
    mov  rdx, 1             ; count
    syscall

    jmp  .read

.done:
    ; exit(0)
    mov  rax, 0x02000001    ; syscall: exit
    mov  rdi, 0             ; status: success
    syscall

section .bss
char resb 1
