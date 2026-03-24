;
;   Printing arguments in UTF-8 on Windows is tricky, because of two reasons:
;   1. We need to decode UTF-16 arguments, as it is the main encoding in WinApi
;   2. We need to encode resulting unicode characters to UTF-8 before printing
;

bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern WriteFile
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree



STD_OUTPUT_HANDLE equ -11


section .bss
stdout resb 8
argW resb 8
argc resb 8


section .text
main:
    ; Alignment + Local variables (char, lpNumberOfBytesWritten) + Arguments (bytes) + Shadow Space
    sub rsp, 0+8+0+32
   
    ; stdout = GetStdHandle(STD_OUTPUT_HANDLE)
    mov rcx, STD_OUTPUT_HANDLE      ; argument 1: nStdHandle, enum of a standard device
    call GetStdHandle
    mov QWORD [stdout], rax
   
    ; rax = GetCommandLineW()
    call GetCommandLineW
   
    ; argW = CommandLineToArgvW(rax, &argc)
    mov  rcx, rax               ; argument 1: lpCmdLine, returned by GetCommandLineW
    lea  rdx, QWORD [argc]      ; argument 2: pNumArgs, pointer to global variable argc
    call CommandLineToArgvW
    mov  QWORD [argW], rax
   
    ; rsi = number of remaining command line arguments to process (preserved by callee)
    mov  rsi, QWORD [argc]
    dec  rsi
    jle  .end_arguments
   
    ; rbx = pointer to the current command line argument (preserved by callee)
    mov  rbx, rax
    add  rbx, 8

.next_argument:
    ; rdi = current argument (preserved by callee)
    mov  rdi, QWORD [rbx]

  .next_character:
    xor  rcx, rcx
    mov  cx,  WORD [rdi]
    cmp  cx,  0
    jle  .end_characters

    cmp  cx, 0xD800
    jl   .decoded

    cmp  cx, 0xDBFF
    jg   .decoded

    ; surrogate
    add  rdi, 2
    sub  cx,  0xD800
    shl  rcx, 10
    mov  cx,  WORD [rdi]
    sub  rcx, 0xDC00
    add  rcx, 0x10000

  .decoded:
    call emit_unicode_char

    add  rdi, 2
    jmp  .next_character

  .end_characters:

    mov  cx, 13
    call emit_char
    mov  cx, 10
    call emit_char

    add  rbx, 8
    dec  rsi
    jg   .next_argument

.end_arguments:
   
    ; LocalFree(argW)
    mov  rcx, QWORD [argW]
    call LocalFree
   
    mov  rcx, 0
    call ExitProcess
    hlt
    ret



emit_char:
; Emits byte cl to stdout

    ; Alignment + Local variables (char, lpNumberOfBytesWritten) + Arguments (bytes) + Shadow Space
    sub  rsp, 0+16+8+32

    mov  BYTE [rsp+32+8+8], cl

    ; rax = WriteFile(stdout, &MSG, 1, [rsp+32], NULL)
    mov  rcx, [stdout]          ; argument 1: file handle returned from GetStdHandle
    lea  rdx, [rsp+32+8+8]      ; argument 2: string
    mov  r8,  1                 ; argument 3: string length
    lea  r9,  QWORD [rsp+40]    ; argument 4: &bytes
    mov  QWORD [rsp+32], 0      ; argument 5: lpOverlapped
    call WriteFile

    ; Restore stack
    add rsp, 0+16+8+32

    ret



emit_unicode_char:
; Emits unicode character ECX to stdout as UTF-8 character.

    cmp rcx, 0x007F
    jg  .check_two_bytes

    jmp emit_char

.check_two_bytes:
    push 0  ; alignment for subsequent calls
    mov r12, rcx
    cmp rcx, 0x07FF
    jg  .check_three_bytes

    shr  rcx, 6
    or   rcx, 0xC0
    call emit_char

    mov rcx, r12
    and rcx, 0x3F
    or  rcx, 0x80
    pop rax
    jmp emit_char

.check_three_bytes:
    cmp rcx, 0xFFFF
    jg  .four_bytes

    shr  rcx, 12
    or   rcx, 0xE0
    call emit_char

    mov  rcx, r12
    shr  rcx, 6
    and  rcx, 0x3F
    or   rcx, 0x80
    call emit_char

    mov rcx, r12
    and rcx, 0x3F
    or  rcx, 0x80
    pop rax
    jmp emit_char

.four_bytes:
    shr  rcx, 18
    or   rcx, 0xF0
    call emit_char

    mov  rcx, r12
    shr  rcx, 12
    and  rcx, 0x3F
    or   rcx, 0x80
    call emit_char

    mov  rcx, r12
    shr  rcx, 6
    and  rcx, 0x3F
    or   rcx, 0x80
    call emit_char

    mov rcx, r12
    and rcx, 0x3F
    or  rcx, 0x80
    pop rax
    jmp emit_char
