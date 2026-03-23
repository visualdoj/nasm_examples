; Useful macros during debugging

%macro push_all_registers 0
    push rax
    push rcx
    push rdx
    push rbx
    push rsi
    push rdi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp
    mov  rbp, rsp
%endmacro

%macro pop_all_registers 0
    mov  rsp, rbp
    pop  rbp
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  r11
    pop  r10
    pop  r9
    pop  r8
    pop  rdi
    pop  rsi
    pop  rbx
    pop  rdx
    pop  rcx
    pop  rax
%endmacro



%macro macro_print_char 1
    push_all_registers

    mov  al, %1

    ; Local variables + Parameters + Shadow Space
    sub  rsp, 1+16+32
    ; Alignment
    and  rsp, ~0xf

    lea  rsi, [rsp + 16 + 32]

    mov  BYTE [rsi], al

    mov  rcx, [stdout]          ; argument 1: file handle returned from GetStdHandle
    mov  rdx, rsi               ; argument 2: string
    mov  r8,  1                 ; argument 3: string length
    lea  r9,  QWORD [rsp+40]    ; argument 4: &bytes
    mov  QWORD [rsp+32], 0      ; argument 5: lpOverlapped
    call WriteFile

    pop_all_registers
%endmacro



%macro macro_print_endl 0
    push_all_registers

    ; Local variables + Parameters + Shadow Space
    sub  rsp, 2+16+32
    ; Alignment
    and  rsp, ~0xf

    lea  rsi, [rsp + 16 + 32]

    mov  BYTE [rsi+0], 13
    mov  BYTE [rsi+1], 10

    mov  rcx, [stdout]          ; argument 1: file handle returned from GetStdHandle
    mov  rdx, rsi               ; argument 2: string
    mov  r8,  2                 ; argument 3: string length
    lea  r9,  QWORD [rsp+40]    ; argument 4: &bytes
    mov  QWORD [rsp+32], 0      ; argument 5: lpOverlapped
    call WriteFile

    pop_all_registers
%endmacro



%macro macro_print_u64 1
    push_all_registers

    mov  rax, %1
    mov  r11, 10
    xor  r8,  r8

    ; Local variables + Parameters + Shadow Space
    sub  rsp, 100+16+32
    ; Alignment
    and  rsp, ~0xf

    lea  rsi, [rsp + 16 + 32 + 99]

    mov  BYTE [rsi], 0
    dec  rsi

%%next_digit:
    dec  rsi
    mov  rdx, 0
    div  r11
    add  dl, 48
    mov  BYTE [rsi], dl
    inc  r8

    cmp  rax, 0
    jne  %%next_digit 

    mov  rcx, [stdout]          ; argument 1: file handle returned from GetStdHandle
    mov  rdx, rsi               ; argument 2: string
    ; r8                        ; argument 3: string length
    lea  r9, QWORD [rsp+40]     ; argument 4: &bytes
    mov  QWORD [rsp+32], 0      ; argument 5: lpOverlapped
    call WriteFile

    pop_all_registers
%endmacro
