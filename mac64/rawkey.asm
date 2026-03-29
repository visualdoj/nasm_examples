bits 64
default rel

global _main

TIOCGETA     equ 0x40487413
TIOCSETA     equ 0x80487414
ICANON       equ 0x100
ECHO         equ 0x08
LFLAG_OFF    equ 24
CC_OFF       equ 32
VMIN         equ 16
VTIME        equ 17
TERMIOS_SIZE equ 72

section .text
_main:
    ; Save current terminal settings
    ; ioctl(stdin, TIOCGETA, &old_termios)
    mov  rax, 0x02000036       ; syscall: ioctl
    xor  edi, edi              ; fd: stdin
    mov  esi, TIOCGETA
    lea  rdx, [old_termios]
    syscall

    ; Copy old_termios to new_termios
    cld
    lea  rsi, [old_termios]
    lea  rdi, [new_termios]
    mov  ecx, TERMIOS_SIZE
    rep  movsb

    ; Clear ICANON and ECHO in c_lflag, set VMIN=1 VTIME=0
    and  QWORD [new_termios + LFLAG_OFF], ~(ICANON | ECHO)
    mov  byte [new_termios + CC_OFF + VMIN], 1
    mov  byte [new_termios + CC_OFF + VTIME], 0

    ; Apply new settings
    ; ioctl(stdin, TIOCSETA, &new_termios)
    mov  rax, 0x02000036
    xor  edi, edi
    mov  esi, TIOCSETA
    lea  rdx, [new_termios]
    syscall

.loop:
    ; read(stdin, &keybyte, 1)
    mov  rax, 0x02000003       ; syscall: read
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
    mov  rax, 0x02000004       ; syscall: write
    mov  edi, 1
    syscall

    ; Exit on ESC (27)
    cmp  byte [keybyte], 27
    jne  .loop

.restore:
    ; Restore terminal settings
    ; ioctl(stdin, TIOCSETA, &old_termios)
    mov  rax, 0x02000036
    xor  edi, edi
    mov  esi, TIOCSETA
    lea  rdx, [old_termios]
    syscall

    ; exit(0)
    mov  rax, 0x02000001
    xor  edi, edi
    syscall

section .bss
old_termios: resb TERMIOS_SIZE
new_termios: resb TERMIOS_SIZE
keybyte:     resb 1
numbuf:      resb 4
