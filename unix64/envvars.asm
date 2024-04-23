bits 64
default rel

global main

section .text
main:
    ; envp is in rdx (third argument)

    mov rdi, rdx

.loop:
        mov rsi, [rdi]
        cmp rsi, 0
        je .loop_end

        push rdi
        push rsi

        mov rax, 1              ; syscall for write
        mov rdi, 1              ; argument 1: file handle 1 which is stdout
        ; mov rsi, [rdi]        ; argument 2: pointer to data to output, already loaded

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

        add rdi, 8              ; next environment variable
        jmp .loop

.loop_end:

    mov rax, 60                 ; syscall for exit
    mov rdi, 0                  ; exit code
    syscall

section .data
NEWLINE: db 10
NEWLINE_LEN equ $ - NEWLINE
