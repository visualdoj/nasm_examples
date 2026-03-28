bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern VirtualAlloc
extern VirtualFree
extern ReadFile
extern WriteFile

STD_INPUT_HANDLE   equ -10
STD_OUTPUT_HANDLE  equ -11
MEM_COMMIT_RESERVE equ 0x3000  ; MEM_COMMIT | MEM_RESERVE
MEM_RELEASE        equ 0x8000
PAGE_READWRITE     equ 0x04
INITIAL_CAP        equ 4096

section .bss
nread    resb 4
nwritten resb 4

section .text
main:
    ; Alignment + Local variables + 5th arg + Shadow Space
    sub  rsp, 0+0+8+32

    ; rbx = GetStdHandle(STD_INPUT_HANDLE)
    mov  rcx, STD_INPUT_HANDLE
    call GetStdHandle
    mov  rbx, rax

    ; rbp = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  rbp, rax

    ; r12 = VirtualAlloc(NULL, INITIAL_CAP, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE)
    mov  rcx, 0
    mov  rdx, INITIAL_CAP
    mov  r8,  MEM_COMMIT_RESERVE
    mov  r9,  PAGE_READWRITE
    call VirtualAlloc
    mov  r12, rax               ; buf
    xor  r13, r13               ; len = 0
    mov  r14, INITIAL_CAP       ; cap

.read:
    ; remaining = cap - len
    mov  rax, r14
    sub  rax, r13
    jz   .grow

    ; ReadFile(stdin, buf + len, remaining, &nread, NULL)
    mov  rcx, rbx
    lea  rdx, [r12 + r13]
    mov  r8,  rax
    lea  r9,  [nread]
    mov  QWORD [rsp+32], 0
    call ReadFile

    ; if nread == 0, we're done (EOF)
    cmp  DWORD [nread], 0
    je   .reverse

    ; len += nread
    mov  eax, DWORD [nread]
    add  r13, rax
    jmp  .read

.grow:
    ; cap *= 2
    shl  r14, 1

    ; r15 = VirtualAlloc(NULL, cap, MEM_COMMIT|MEM_RESERVE, PAGE_READWRITE)
    mov  rcx, 0
    mov  rdx, r14
    mov  r8,  MEM_COMMIT_RESERVE
    mov  r9,  PAGE_READWRITE
    call VirtualAlloc
    mov  r15, rax

    ; memcpy(new_buf, old_buf, len)
    cld
    mov  rdi, r15               ; dest = new_buf
    mov  rsi, r12               ; src = old_buf
    mov  rcx, r13               ; count = len
    rep  movsb

    ; VirtualFree(old_buf, 0, MEM_RELEASE)
    mov  rcx, r12
    mov  rdx, 0
    mov  r8,  MEM_RELEASE
    call VirtualFree

    mov  r12, r15               ; buf = new_buf
    jmp  .read

.reverse:
    ; reverse buf[0..len-1] in place
    mov  rdi, r12               ; left = buf
    lea  rsi, [r12 + r13 - 1]  ; right = buf + len - 1

.rev_loop:
    cmp  rdi, rsi
    jge  .write

    mov  al,  BYTE [rdi]
    mov  cl,  BYTE [rsi]
    mov  BYTE [rdi], cl
    mov  BYTE [rsi], al
    inc  rdi
    dec  rsi
    jmp  .rev_loop

.write:
    ; WriteFile(stdout, buf, len, &nwritten, NULL)
    mov  rcx, rbp
    mov  rdx, r12
    mov  r8,  r13
    lea  r9,  [nwritten]
    mov  QWORD [rsp+32], 0
    call WriteFile

    ; VirtualFree(buf, 0, MEM_RELEASE)
    mov  rcx, r12
    mov  rdx, 0
    mov  r8,  MEM_RELEASE
    call VirtualFree

    mov  rcx, 0
    call ExitProcess
    hlt
