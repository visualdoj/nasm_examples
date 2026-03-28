bits 64
default rel

global _main

SYS_READ   equ 0x02000003
SYS_WRITE  equ 0x02000004
SYS_MMAP   equ 0x020000C5
SYS_MUNMAP equ 0x02000049
SYS_EXIT   equ 0x02000001

PROT_RW          equ 3       ; PROT_READ | PROT_WRITE
MAP_PRIVATE_ANON equ 0x1002  ; MAP_PRIVATE | MAP_ANON
INITIAL_CAP      equ 4096

section .text
_main:
    ; r12 = buf, r13 = len, r14 = cap

    ; buf = mmap(NULL, INITIAL_CAP, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
    mov  rax, SYS_MMAP
    mov  rdi, 0
    mov  rsi, INITIAL_CAP
    mov  rdx, PROT_RW
    mov  r10, MAP_PRIVATE_ANON
    mov  r8,  -1
    mov  r9,  0
    syscall

    mov  r12, rax               ; buf
    xor  r13, r13               ; len = 0
    mov  r14, INITIAL_CAP       ; cap

.read:
    ; remaining = cap - len
    mov  rdx, r14
    sub  rdx, r13
    jz   .grow

    ; read(stdin, buf + len, remaining)
    mov  rax, SYS_READ
    mov  rdi, 0                 ; fd: stdin
    mov  rsi, r12
    add  rsi, r13               ; buf + len
    syscall

    ; if rax <= 0, we're done (EOF or error)
    cmp  rax, 0
    jle  .reverse

    add  r13, rax               ; len += bytes_read
    jmp  .read

.grow:
    ; new_cap = cap * 2
    mov  r15, r14
    shl  r15, 1

    ; new_buf = mmap(NULL, new_cap, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANON, -1, 0)
    mov  rax, SYS_MMAP
    mov  rdi, 0
    mov  rsi, r15
    mov  rdx, PROT_RW
    mov  r10, MAP_PRIVATE_ANON
    mov  r8,  -1
    mov  r9,  0
    syscall

    mov  rbx, rax               ; save new_buf

    ; memcpy(new_buf, old_buf, len)
    cld
    mov  rdi, rax               ; dest = new_buf
    mov  rsi, r12               ; src = old_buf
    mov  rcx, r13               ; count = len
    rep  movsb

    ; munmap(old_buf, old_cap)
    mov  rax, SYS_MUNMAP
    mov  rdi, r12
    mov  rsi, r14
    syscall

    mov  r12, rbx               ; buf = new_buf
    mov  r14, r15               ; cap = new_cap
    jmp  .read

.reverse:
    ; reverse buf[0..len-1] in place
    mov  rsi, r12               ; left = buf
    mov  rdi, r12
    add  rdi, r13
    dec  rdi                    ; right = buf + len - 1

.rev_loop:
    cmp  rsi, rdi
    jge  .write

    mov  al,  BYTE [rsi]
    mov  cl,  BYTE [rdi]
    mov  BYTE [rsi], cl
    mov  BYTE [rdi], al
    inc  rsi
    dec  rdi
    jmp  .rev_loop

.write:
    ; write(stdout, buf, len)
    mov  rax, SYS_WRITE
    mov  rdi, 1                 ; fd: stdout
    mov  rsi, r12
    mov  rdx, r13
    syscall

    ; munmap(buf, cap)
    mov  rax, SYS_MUNMAP
    mov  rdi, r12
    mov  rsi, r14
    syscall

    ; exit(0)
    mov  rax, SYS_EXIT
    mov  rdi, 0
    syscall
