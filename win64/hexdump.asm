bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree
extern WriteFile
extern CreateFileW
extern ReadFile
extern CloseHandle

STD_OUTPUT_HANDLE equ -11
GENERIC_READ      equ 0x80000000
FILE_SHARE_READ   equ 1
OPEN_EXISTING     equ 3

section .text
main:
    ; Shadow space (32) + 3 extra params for CreateFileW (24) = 56
    sub  rsp, 56

    ; r15 = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  r15, rax

    ; rax = GetCommandLineW()
    call GetCommandLineW

    ; argW = CommandLineToArgvW(rax, &argc)
    mov  rcx, rax
    lea  rdx, [argc]
    call CommandLineToArgvW
    mov  [argW], rax

    cmp  QWORD [argc], 2
    jne  .exit_error

    ; r12 = CreateFileW(argv[1], GENERIC_READ, FILE_SHARE_READ, NULL,
    ;                   OPEN_EXISTING, 0, NULL)
    mov  rcx, [rax + 8]
    mov  edx, GENERIC_READ
    mov  r8,  FILE_SHARE_READ
    xor  r9,  r9
    mov  QWORD [rsp+32], OPEN_EXISTING
    mov  QWORD [rsp+40], 0
    mov  QWORD [rsp+48], 0
    call CreateFileW
    cmp  rax, -1
    je   .exit_error
    mov  r12, rax

    ; Free argv (no longer needed)
    mov  rcx, [argW]
    call LocalFree

    xor  r13d, r13d            ; r13 = file offset
    lea  rbx, [HEX]

.line:
    ; ReadFile(r12, rbuf, 16, &nread, NULL)
    mov  rcx, r12
    lea  rdx, [rbuf]
    mov  r8,  16
    lea  r9,  [rsp+40]
    mov  QWORD [rsp+32], 0
    call ReadFile
    mov  eax, DWORD [rsp+40]
    test eax, eax
    jz   .final
    mov  r14d, eax             ; r14 = bytes read

    ; --- Format line into lbuf ---
    lea  rdi, [lbuf]
    mov  rax, r13
    call .write_hex8
    mov  word [rdi], 0x2020    ; two spaces
    add  rdi, 2

    ; Hex bytes (16 columns, extra space after column 8)
    xor  ecx, ecx
.hex:
    cmp  ecx, 16
    je   .asc
    cmp  ecx, 8
    jne  .no_gap
    mov  byte [rdi], ' '
    inc  rdi
.no_gap:
    cmp  ecx, r14d
    jge  .pad
    movzx eax, byte [rbuf + rcx]
    mov  edx, eax
    shr  edx, 4
    mov  dl, [rbx + rdx]
    mov  [rdi], dl
    and  eax, 0xf
    mov  al, [rbx + rax]
    mov  [rdi + 1], al
    mov  byte [rdi + 2], ' '
    add  rdi, 3
    jmp  .hex_next
.pad:
    mov  byte [rdi], ' '
    mov  byte [rdi + 1], ' '
    mov  byte [rdi + 2], ' '
    add  rdi, 3
.hex_next:
    inc  ecx
    jmp  .hex

    ; ASCII column
.asc:
    mov  byte [rdi], ' '
    mov  byte [rdi + 1], '|'
    add  rdi, 2
    xor  ecx, ecx
.asc_loop:
    cmp  ecx, r14d
    je   .asc_end
    movzx eax, byte [rbuf + rcx]
    cmp  al, 0x20
    jb   .dot
    cmp  al, 0x7e
    ja   .dot
    mov  [rdi], al
    jmp  .asc_next
.dot:
    mov  byte [rdi], '.'
.asc_next:
    inc  rdi
    inc  ecx
    jmp  .asc_loop
.asc_end:
    mov  byte [rdi], '|'
    mov  byte [rdi + 1], 13
    mov  byte [rdi + 2], 10
    add  rdi, 3

    ; WriteFile(stdout, lbuf, len, &nwritten, NULL)
    mov  rcx, r15
    lea  rdx, [lbuf]
    mov  r8, rdi
    sub  r8, rdx
    lea  r9, [rsp+40]
    mov  QWORD [rsp+32], 0
    call WriteFile

    add  r13, r14
    cmp  r14, 16
    je   .line

.final:
    ; Final offset line
    lea  rdi, [lbuf]
    mov  rax, r13
    call .write_hex8
    mov  byte [rdi], 13
    mov  byte [rdi + 1], 10
    add  rdi, 2

    mov  rcx, r15
    lea  rdx, [lbuf]
    mov  r8, rdi
    sub  r8, rdx
    lea  r9, [rsp+40]
    mov  QWORD [rsp+32], 0
    call WriteFile

    ; CloseHandle(file)
    mov  rcx, r12
    call CloseHandle

    mov  rcx, 0
    call ExitProcess
    hlt

.exit_error:
    mov  rcx, [argW]
    call LocalFree

    mov  rcx, 1
    call ExitProcess
    hlt

; ---------------------------------------------------------------------------
; write_hex8: write rax as 8 hex digits at [rdi], advance rdi by 8
; Requires rbx = HEX base. Clobbers rax, ecx, edx.
; ---------------------------------------------------------------------------
.write_hex8:
    mov  ecx, 28
.wh8:
    mov  edx, eax
    shr  edx, cl
    and  edx, 0xf
    mov  dl, [rbx + rdx]
    mov  [rdi], dl
    inc  rdi
    sub  ecx, 4
    jge  .wh8
    ret

section .data
HEX: db "0123456789abcdef"

section .bss
argW: resq 1
argc: resq 1
rbuf: resb 16
lbuf: resb 80
