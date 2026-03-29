bits 64
default rel

global main

TCGETS       equ 0x5401
TCSETS       equ 0x5402
ICANON       equ 0x02
ECHO         equ 0x08
LFLAG_OFF    equ 12
CC_OFF       equ 17
VMIN         equ 6
VTIME        equ 5
TERMIOS_SIZE equ 36

section .text
main:
    ; Save current terminal settings
    ; ioctl(stdin, TCGETS, &old_termios)
    mov  eax, 16               ; SYS_ioctl
    xor  edi, edi              ; fd: stdin
    mov  esi, TCGETS
    lea  rdx, [old_termios]
    syscall

    ; Copy old_termios to new_termios
    cld
    lea  rsi, [old_termios]
    lea  rdi, [new_termios]
    mov  ecx, TERMIOS_SIZE
    rep  movsb

    ; Clear ICANON and ECHO in c_lflag, set VMIN=1 VTIME=0
    and  DWORD [new_termios + LFLAG_OFF], ~(ICANON | ECHO)
    mov  byte [new_termios + CC_OFF + VMIN], 1
    mov  byte [new_termios + CC_OFF + VTIME], 0

    ; Apply new settings
    ; ioctl(stdin, TCSETS, &new_termios)
    mov  eax, 16
    xor  edi, edi
    mov  esi, TCSETS
    lea  rdx, [new_termios]
    syscall

.loop:
    ; read(stdin, &keybyte, 1)
    mov  eax, 0
    xor  edi, edi
    lea  rsi, [keybyte]
    mov  edx, 1
    syscall
    test rax, rax
    jle  .restore

    ; Convert byte to decimal string
    movzx eax, byte [keybyte]
    lea  rdi, [numbuf + 3]
    mov  byte [rdi], 10        ; newline
    mov  ecx, 10
.to_str:
    xor  edx, edx
    div  ecx
    dec  rdi
    add  dl, '0'
    mov  [rdi], dl
    test eax, eax
    jnz  .to_str

    ; write(stdout, rdi, len)
    mov  rsi, rdi
    lea  rdx, [numbuf + 4]
    sub  rdx, rsi
    mov  eax, 1
    mov  edi, 1
    syscall

    ; Exit on ESC (27)
    cmp  byte [keybyte], 27
    jne  .loop

.restore:
    ; Restore terminal settings
    ; ioctl(stdin, TCSETS, &old_termios)
    mov  eax, 16
    xor  edi, edi
    mov  esi, TCSETS
    lea  rdx, [old_termios]
    syscall

    ; exit(0)
    mov  eax, 60
    xor  edi, edi
    syscall

section .bss
old_termios: resb TERMIOS_SIZE
new_termios: resb TERMIOS_SIZE
keybyte:     resb 1
numbuf:      resb 4
