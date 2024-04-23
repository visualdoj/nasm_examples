bits 64
default rel

global main

section .text
main:
    ; argc is in rdi
    ; argv is in rsi

    ; skip the program name
    add rsi, 8
    dec rdi

.loop:
        cmp rdi, 0
        jle .loop_end

        push rdi
        push rsi

        mov rax, 1              ; syscall for write
        mov rdi, 1              ; argument 1: file handle 1 which is stdout
        mov rsi, [rsi]          ; argument 2: pointer to data to output

        mov rdx, 0              ; argument 3: number of bytes to output 
        mov rcx, rsi            ; rcx is for temporary string cursor
    .strlen:
        mov r8b, [rcx]          ; r8 is for current character
        cmp r8b, 0
        je .strlen_end
        inc rdx
        inc rcx
        jmp .strlen
    .strlen_end:

        syscall                 ; output the argument

        mov rax, 1
        mov rdi, 1
        lea rsi, [NEWLINE]
        mov rdx, NEWLINE_LEN
        syscall

        pop rsi
        pop rdi

        add rsi, 8              ; next argument
        dec rdi                 ; decrement number of arguments remaining
        jmp .loop

.loop_end:

    mov rax, 60                 ; syscall for exit
    mov rdi, 0                  ; exit code
    syscall

section .data
NEWLINE: db 10
NEWLINE_LEN equ $ - NEWLINE
