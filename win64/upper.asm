bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern ReadFile
extern WriteFile

STD_INPUT_HANDLE  equ -10
STD_OUTPUT_HANDLE equ -11

section .bss
stdin    resb 8
stdout   resb 8
char     resb 1
nread    resb 4
nwritten resb 4

section .text
main:
    ; Alignment + Local variables + 5th arg + Shadow Space
    sub  rsp, 0+0+8+32

    ; stdin = GetStdHandle(STD_INPUT_HANDLE)
    mov  rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov  QWORD [stdin], rax

    ; stdout = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  QWORD [stdout], rax

.read:
    ; ReadFile(stdin, &char, 1, &nread, NULL)
    mov  rcx, QWORD [stdin]
    lea  rdx, [char]
    mov  r8,  1
    lea  r9,  [nread]
    mov  QWORD [rsp+32], 0
    call ReadFile

    ; if nread == 0, we're done (EOF)
    cmp  DWORD [nread], 0
    je   .done

    ; convert 'a'-'z' to 'A'-'Z'
    mov  cl,  BYTE [char]
    cmp  cl,  'a'
    jb   .write
    cmp  cl,  'z'
    ja   .write
    sub  cl,  32
    mov  BYTE [char], cl

.write:
    ; WriteFile(stdout, &char, 1, &nwritten, NULL)
    mov  rcx, QWORD [stdout]
    lea  rdx, [char]
    mov  r8,  1
    lea  r9,  [nwritten]
    mov  QWORD [rsp+32], 0
    call WriteFile

    jmp  .read

.done:
    mov  rcx, 0
    call ExitProcess
    hlt
