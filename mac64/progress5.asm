bits 64
default rel

global _main


SYS_exit           equ 0x02000001
SYS_write          equ 0x02000004
SYS_ioctl          equ 0x02000036
SYS_gettimeofday   equ 0x02000074

STDERR_FD         equ 2
TIOCGWINSZ        equ 0x40087468
BAR_WIDTH         equ 50


section .data
stderr_is_tty   dq 0
startTv         dq 0, 0              ; { tv_sec, tv_usec }
nowTv           dq 0, 0              ; { tv_sec, tv_usec }
elapsedUs       dq 0
durationUs      dq 5000000
lastPct         dd -1


section .bss
winsizeBuf      resb 8
buf             resb 64


section .text
_main:
    ; TIOCGWINSZ is enough to distinguish terminal from pipe/file
    mov  eax, SYS_ioctl
    mov  edi, STDERR_FD
    mov  esi, TIOCGWINSZ
    lea  rdx, [winsizeBuf]
    syscall

    jc   .stderr_not_tty
    mov  QWORD [stderr_is_tty], 1

.stderr_not_tty:
    ; gettimeofday is the straightforward raw BSD time syscall in XNU
    mov  eax, SYS_gettimeofday
    lea  rdi, [startTv]
    xor  esi, esi
    xor  edx, edx
    syscall

.main_loop:
    mov  eax, SYS_gettimeofday
    lea  rdi, [nowTv]
    xor  esi, esi
    xor  edx, edx
    syscall

    ; elapsedUs = now - start
    mov  rax, QWORD [nowTv + 0]
    imul rax, 1000000
    mov  ecx, DWORD [nowTv + 8]
    add  rax, rcx

    mov  rdx, QWORD [startTv + 0]
    imul rdx, 1000000
    mov  ecx, DWORD [startTv + 8]
    add  rdx, rcx

    sub  rax, rdx
    mov  QWORD [elapsedUs], rax

    cmp  rax, QWORD [durationUs]
    jae  .done

    ; r10d = elapsed * 100 / duration
    xor  edx, edx
    mov  rax, QWORD [elapsedUs]
    imul rax, 100
    div  QWORD [durationUs]
    mov  r10d, eax

    ; redraw only when percent changes
    cmp  r10d, DWORD [lastPct]
    je   .main_loop
    mov  DWORD [lastPct], r10d

    ; r11d = elapsed * BAR_WIDTH / duration
    xor  edx, edx
    mov  rax, QWORD [elapsedUs]
    imul rax, BAR_WIDTH
    div  QWORD [durationUs]
    mov  r11d, eax

    ; skip redraw if stderr is not TTY
    mov  rdi, QWORD [stderr_is_tty]
    test rdi, rdi
    jz   .main_loop

    xor  r8d, r8d               ; final = 0
    call render_and_write
    jmp  .main_loop

.done:
    mov  r10d, 100
    mov  r11d, BAR_WIDTH
    mov  r8d,  1                ; final = 1
    call render_and_write

    mov  eax, SYS_exit
    xor  edi, edi
    syscall


; -----------------------------------------------------------------------------
; render_and_write
;   in:
;     r10d = percent   (0..100)
;     r11d = filled    (0..BAR_WIDTH)
;     r8d  = final     (0/1)  -> add '\n' on final frame
; -----------------------------------------------------------------------------
render_and_write:
    cld

    lea  rdi, [buf]

    ; '\r['
    mov  BYTE [rdi + 0], 13
    mov  BYTE [rdi + 1], '['
    lea  rdi, [rdi + 2]

    ; memset([rdi], '#', r11d); rdi += r11d
    mov  ecx, r11d
    mov  al,  '#'
    rep  stosb

    ; memset([rdi], '-', BAR_WIDTH - r11d); rdi += BAR_WIDTH - r11d
    mov  ecx, BAR_WIDTH
    sub  ecx, r11d
    mov  al,  '-'
    rep  stosb

    ; "] xxx%"
    mov  BYTE [rdi + 0], ']'
    mov  BYTE [rdi + 1], ' '

    cmp  r10d, 100
    jne  .not100

    mov  BYTE [rdi + 2], '1'
    mov  BYTE [rdi + 3], '0'
    mov  BYTE [rdi + 4], '0'
    jmp  .digits_done

.not100:
    ; default: "  x" or " xx"
    mov  BYTE [rdi + 2], ' '
    mov  BYTE [rdi + 3], ' '

    ; eax = r10d / 10; edx = r10d % 10
    mov  eax, r10d
    xor  edx, edx
    mov  ecx, 10
    div  ecx

    test eax, eax
    jz   .add_ones
    add  al,  '0'
    mov  BYTE [rdi + 3], al     ; tens

.add_ones:
    add  dl,  '0'
    mov  BYTE [rdi + 4], dl     ; ones

.digits_done:
    mov  BYTE [rdi + 5], '%'

    mov  edx, 58                ; len without '\n'

    test r8d, r8d
    jz   .write
    mov  BYTE [rdi + 6], 10     ; '\n'
    mov  edx, 59

.write:
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    lea  rsi, [buf]
    syscall
    ret
