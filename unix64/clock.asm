bits 64
default rel

global main

section .text
main:
    ; time(NULL) — returns UTC epoch seconds in rax
    mov  eax, 201               ; syscall: time
    xor  edi, edi
    syscall

    ; total_days = epoch_seconds / 86400, time_of_day = epoch_seconds % 86400
    xor  edx, edx
    mov  rcx, 86400
    div  rcx
    mov  r12, rax               ; r12 = total_days
    mov  eax, edx               ; eax = time_of_day (0..86399)

    ; hour = time_of_day / 3600
    xor  edx, edx
    mov  ecx, 3600
    div  ecx
    mov  r15d, eax              ; r15 = hour

    ; minute = remaining / 60, second = remaining % 60
    mov  eax, edx
    xor  edx, edx
    mov  ecx, 60
    div  ecx
    mov  r14d, eax              ; r14 = minute
    mov  r13d, edx              ; r13 = second

    ; Compute year from total_days
    mov  rax, r12               ; remaining days
    mov  ebx, 1970

.year_loop:
    mov  edx, 365
    call .is_leap               ; r8d = 1 if leap year, 0 if not
    add  edx, r8d
    cmp  rax, rdx
    jb   .year_done
    sub  rax, rdx
    inc  ebx
    jmp  .year_loop

.year_done:
    mov  r12, rax               ; r12 = remaining days in year
    lea  rsi, [month_days]
    xor  ecx, ecx              ; month index (0 = January)

.month_loop:
    movzx edx, byte [rsi + rcx]
    cmp  ecx, 1                 ; February?
    jne  .not_feb
    call .is_leap
    add  edx, r8d               ; add leap day
.not_feb:
    cmp  r12, rdx
    jb   .format
    sub  r12, rdx
    inc  ecx
    jmp  .month_loop

.format:
    ; ebx=year  ecx=month(0-based)  r12=day(0-based)
    ; r15=hour  r14=minute  r13=second

    mov  eax, ebx
    lea  rdi, [buf + 3]
    mov  r8d, 4
    call .write_digits

    lea  eax, [ecx + 1]         ; month (1-based)
    lea  rdi, [buf + 6]
    mov  r8d, 2
    call .write_digits

    lea  eax, [r12 + 1]         ; day (1-based)
    lea  rdi, [buf + 9]
    mov  r8d, 2
    call .write_digits

    mov  eax, r15d
    lea  rdi, [buf + 12]
    mov  r8d, 2
    call .write_digits

    mov  eax, r14d
    lea  rdi, [buf + 15]
    mov  r8d, 2
    call .write_digits

    mov  eax, r13d
    lea  rdi, [buf + 18]
    mov  r8d, 2
    call .write_digits

    ; write(stdout, buf, BUF_LEN)
    mov  eax, 1                 ; syscall: write
    mov  edi, 1                 ; fd: stdout
    lea  rsi, [buf]
    mov  edx, BUF_LEN
    syscall

    ; exit(0)
    mov  eax, 60                ; syscall: exit
    xor  edi, edi
    syscall

; Checks if year in ebx is a leap year. Returns r8d = 1 if leap, 0 if not.
; Preserves all registers except r8.
.is_leap:
    xor  r8d, r8d
    test ebx, 3                 ; year % 4
    jnz  .il_ret
    push rax
    push rcx
    push rdx
    mov  eax, ebx
    xor  edx, edx
    mov  ecx, 100
    div  ecx                    ; eax = year/100, edx = year%100
    test edx, edx
    jnz  .il_yes                ; not divisible by 100 → leap
    test eax, 3                 ; (year/100) % 4 == 0  ⟺  year % 400 == 0
    jnz  .il_no
.il_yes:
    mov  r8d, 1
.il_no:
    pop  rdx
    pop  rcx
    pop  rax
.il_ret:
    ret

; Writes eax as r8d zero-padded decimal digits to [rdi] right-to-left.
; Clobbers: rax, rdx, rdi, r8, r9.
.write_digits:
    mov  r9d, 10
.wd_loop:
    xor  edx, edx
    div  r9d
    add  dl,  '0'
    mov  [rdi], dl
    dec  rdi
    dec  r8d
    jnz  .wd_loop
    ret

section .data
buf: db "0000-00-00T00:00:00Z",10
BUF_LEN equ $ - buf
month_days: db 31,28,31,30,31,30,31,31,30,31,30,31
