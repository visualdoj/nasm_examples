bits 64
default rel

global main

section .text
main:
    ; argc is in rdi, argv is in rsi

    cmp  rdi, 2
    jne  .exit_error

    ; parse argv[1] to integer N -> r12
    mov  rsi, [rsi + 8]
    xor  r12, r12

.parse:
    movzx rcx, byte [rsi]
    test cl, cl
    jz   .parse_done
    imul r12, r12, 10
    sub  cl, '0'
    add  r12, rcx
    inc  rsi
    jmp  .parse

.parse_done:
    mov  r13, 1                ; counter

.loop:
    cmp  r13, r12
    jg   .exit_ok

    ; integer-to-string: divide by 10 repeatedly, write remainders as digits right-to-left
    lea  rdi, [buf + 20]
    mov  rax, r13
    mov  rcx, 10

.to_string:
    xor  rdx, rdx
    div  rcx                   ; rax = quotient, rdx = remainder
    dec  rdi
    add  dl, '0'
    mov  [rdi], dl
    test rax, rax
    jnz  .to_string

    mov  byte [buf + 20], 10   ; newline
    lea  rdx, [buf + 21]
    sub  rdx, rdi              ; total length including newline

    ; write(stdout, rdi, rdx)
    mov  rsi, rdi
    mov  rax, 1                ; syscall: write
    mov  rdi, 1                ; fd: stdout
    syscall

    inc  r13
    jmp  .loop

.exit_ok:
    mov  rax, 60               ; syscall: exit
    mov  rdi, 0
    syscall

.exit_error:
    mov  rax, 60
    mov  rdi, 1
    syscall

section .bss
buf resb 21                    ; 20 digits + newline
