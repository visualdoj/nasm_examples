bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetSystemTime
extern WriteFile

STD_OUTPUT_HANDLE equ -11

section .text
main:
    ; Padding(8) + SYSTEMTIME(16) + bytesWritten(8) + 5th arg(8) + Shadow Space(32)
    sub  rsp, 8+16+8+8+32

    ; GetSystemTime(&systemtime) — returns current UTC
    lea  rcx, [rsp+48]
    call GetSystemTime

    ; SYSTEMTIME layout at [rsp+48]:
    ;   +0 wYear  +2 wMonth  +4 wDayOfWeek  +6 wDay
    ;   +8 wHour  +10 wMinute  +12 wSecond

    movzx eax, word [rsp+48]   ; wYear
    lea  r9,  [buf+3]
    mov  r10d, 4
    call .write_digits

    movzx eax, word [rsp+50]   ; wMonth
    lea  r9,  [buf+6]
    mov  r10d, 2
    call .write_digits

    movzx eax, word [rsp+54]   ; wDay
    lea  r9,  [buf+9]
    mov  r10d, 2
    call .write_digits

    movzx eax, word [rsp+56]   ; wHour
    lea  r9,  [buf+12]
    mov  r10d, 2
    call .write_digits

    movzx eax, word [rsp+58]   ; wMinute
    lea  r9,  [buf+15]
    mov  r10d, 2
    call .write_digits

    movzx eax, word [rsp+60]   ; wSecond
    lea  r9,  [buf+18]
    mov  r10d, 2
    call .write_digits

    ; rax = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle

    ; WriteFile(stdout, buf, BUF_LEN, &bytesWritten, NULL)
    mov  rcx, rax           ; argument 1: file handle
    lea  rdx, [buf]         ; argument 2: buffer
    mov  r8,  BUF_LEN       ; argument 3: length
    lea  r9,  [rsp+40]      ; argument 4: &bytesWritten
    mov  QWORD [rsp+32], 0  ; argument 5: lpOverlapped
    call WriteFile

    ; ExitProcess(0)
    mov  rcx, 0
    call ExitProcess
    hlt

; Writes eax as r10d zero-padded decimal digits to [r9] right-to-left.
.write_digits:
    mov  r8d, 10
.wd_loop:
    xor  edx, edx
    div  r8d
    add  dl,  '0'
    mov  [r9], dl
    dec  r9
    dec  r10d
    jnz  .wd_loop
    ret

section .data
buf: db "0000-00-00T00:00:00Z",13,10
BUF_LEN equ $ - buf
