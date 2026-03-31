bits 64
default rel

global _main


SYS_exit          equ 0x02000001
SYS_write         equ 0x02000004
SYS_ioctl         equ 0x02000036
SYS_gettimeofday  equ 0x02000074

STDOUT_FD         equ 1
STDERR_FD         equ 2
TIOCGWINSZ        equ 0x40087468
BAR_WIDTH         equ 50
MAX_BARS          equ 16
BAR_SIZE          equ 32

; Bar struct field offsets (32 bytes each)
bDurUs            equ 0        ; qword: seconds * 1000000
bStartUs          equ 8        ; qword: flat microseconds at start
bLastPct          equ 16       ; dword: last rendered percent (-1 = never)
bDone             equ 20       ; dword: 0=running, 1=just done, 2=msg printed
bDurSecs          equ 24       ; dword: original seconds value


; ---- Macro: write decimal of eax (0..99) at [rdi], advance rdi ----
; Clobbers eax, ecx, edx.
%macro write_dec 0
    xor  edx, edx
    mov  ecx, 10
    div  ecx                   ; eax=tens, edx=ones
    test eax, eax
    jz   %%ones
    add  al, '0'
    mov  [rdi], al
    inc  rdi
%%ones:
    add  dl, '0'
    mov  [rdi], dl
    inc  rdi
%endmacro

; ---- Macro: append ESC[<eax>A (cursor up) to [rdi], advance rdi ----
%macro append_cuu 0
    mov  byte [rdi], 0x1B
    mov  byte [rdi+1], '['
    add  rdi, 2
    write_dec
    mov  byte [rdi], 'A'
    inc  rdi
%endmacro

; ---- Macro: append ESC[<eax>B (cursor down) to [rdi], advance rdi ----
%macro append_cud 0
    mov  byte [rdi], 0x1B
    mov  byte [rdi+1], '['
    add  rdi, 2
    write_dec
    mov  byte [rdi], 'B'
    inc  rdi
%endmacro


section .data
stderr_is_tty   dq 0
num_bars        dd 0
done_count      dd 0
msg_count       dd 0

msg_pre         db "Progress bar for "
MSG_PRE_LEN     equ $ - msg_pre
msg_suf         db " seconds is completed", 10
MSG_SUF_LEN     equ $ - msg_suf


section .bss
bars            resb BAR_SIZE * MAX_BARS
render_buf      resb 1024
msgbuf          resb 80
winsizeBuf      resb 8
nowTv           resq 2          ; { tv_sec (qword), tv_usec (dword padded) }


section .text

; ============================================================================
; _main
;
; Usage: multibars <sec1> <sec2> ... (up to 16 durations)
;
; Renders one progress bar per duration on stderr using ANSI cursor escapes.
; Prints "Progress bar for N seconds is completed\n" to stdout as each finishes.
; If stderr is not a TTY, bar rendering is skipped; stdout messages still print.
; ============================================================================
_main:
    push rbx
    push rbp
    push r12
    push r13
    push r14
    push r15
    ; 6 pushes = 48 bytes; entry rsp mod 16 = 8; after pushes: (8-48) mod 16 = 8
    sub  rsp, 8                ; align: (8-8) mod 16 = 0

    ; Save argc and argv into callee-saved registers before any syscall
    mov  r12d, edi             ; r12d = argc
    mov  r13, rsi              ; r13  = argv

    ; ---------- TTY detection ----------

    mov  eax, SYS_ioctl
    mov  edi, STDERR_FD
    mov  esi, TIOCGWINSZ
    lea  rdx, [winsizeBuf]
    syscall

    jc   .stderr_not_tty       ; carry flag set = error = not a TTY
    mov  qword [stderr_is_tty], 1

.stderr_not_tty:
    ; ---------- Validate and count bars ----------

    dec  r12d                  ; r12d = argc - 1 = num_bars
    jle  .exit_err
    cmp  r12d, MAX_BARS
    jg   .exit_err
    mov  [num_bars], r12d

    ; ---------- Init bar structs ----------

    xor  ebx, ebx              ; bar index

.init:
    cmp  ebx, r12d
    jge  .init_done

    ; Parse argv[ebx+1]: UTF-8 decimal string -> seconds in ebp
    mov  r15, [r13 + rbx*8 + 8]
    xor  ebp, ebp
.prs:
    movzx ecx, byte [r15]
    test  cl, cl
    jz    .prs_end
    imul  ebp, 10
    sub   ecx, '0'
    add   ebp, ecx
    inc   r15
    jmp   .prs

.prs_end:
    ; Compute bar struct pointer: r14 = &bars[ebx]
    mov  eax, ebx
    imul eax, BAR_SIZE
    lea  r14, [bars + rax]

    ; bar.durationUs = ebp * 1000000
    mov  rax, 1000000
    imul rax, rbp
    mov  [r14 + bDurUs], rax

    ; bar.startUs = gettimeofday() as flat microseconds
    mov  eax, SYS_gettimeofday
    lea  rdi, [nowTv]
    xor  esi, esi
    xor  edx, edx
    syscall
    mov  rax, [nowTv]
    imul rax, 1000000
    mov  ecx, DWORD [nowTv + 8]    ; tv_usec is 32-bit on macOS
    add  rax, rcx
    mov  [r14 + bStartUs], rax

    mov  dword [r14 + bLastPct], -1
    mov  dword [r14 + bDone], 0
    mov  [r14 + bDurSecs], ebp

    inc  ebx
    jmp  .init

.init_done:
    ; ---------- Reserve lines + position cursor (TTY only) ----------

    cmp  qword [stderr_is_tty], 0
    je   .main_loop

    ; Write num_bars LFs to reserve vertical space
    cld
    lea  rdi, [render_buf]
    xor  ecx, ecx
.rsv:
    cmp  ecx, r12d
    jge  .rsv_end
    mov  byte [rdi], 10
    inc  rdi
    inc  ecx
    jmp  .rsv
.rsv_end:
    ; Append ESC[<num_bars>A to move cursor back to first bar row
    mov  eax, r12d
    append_cuu

    lea  rsi, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  edx, edi
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    syscall

    ; ======================================================================
    ; MAIN LOOP
    ; ======================================================================

.main_loop:
    mov  eax, [done_count]
    cmp  eax, r12d
    jge  .all_done

    ; Sample current time as flat microseconds into r15
    mov  eax, SYS_gettimeofday
    lea  rdi, [nowTv]
    xor  esi, esi
    xor  edx, edx
    syscall
    mov  r15, [nowTv]
    imul r15, 1000000
    mov  ecx, DWORD [nowTv + 8]    ; tv_usec is 32-bit on macOS
    add  r15, rcx                  ; r15 = nowUs

    ; ------ Phase 1: scan bars, update state ------

    xor  ebx, ebx              ; bar index
    xor  ebp, ebp              ; changed flag
    xor  r13d, r13d            ; new-completions flag

.scan:
    cmp  ebx, r12d
    jge  .scan_end

    mov  eax, ebx
    imul eax, BAR_SIZE
    lea  r14, [bars + rax]

    cmp  dword [r14 + bDone], 0
    jne  .scan_next

    ; elapsed = nowUs - startUs
    mov  rax, r15
    sub  rax, [r14 + bStartUs]

    cmp  rax, [r14 + bDurUs]
    jb   .scan_run

    ; Bar just completed
    mov  dword [r14 + bDone], 1
    mov  dword [r14 + bLastPct], 100
    mov  ebp, 1
    mov  r13d, 1
    jmp  .scan_next

.scan_run:
    ; pct = elapsed * 100 / durationUs
    xor  edx, edx
    imul rax, 100
    div  qword [r14 + bDurUs]

    cmp  eax, [r14 + bLastPct]
    je   .scan_next
    mov  [r14 + bLastPct], eax
    mov  ebp, 1

.scan_next:
    inc  ebx
    jmp  .scan

.scan_end:

    ; ------ Phase 2: render all bars (TTY + changed only) ------

    test ebp, ebp
    jz   .phase3
    cmp  qword [stderr_is_tty], 0
    je   .phase3

    ; Build all bar lines into render_buf
    cld
    lea  rdi, [render_buf]
    xor  ebx, ebx

.rbar:
    cmp  ebx, r12d
    jge  .rbar_end

    mov  eax, ebx
    imul eax, BAR_SIZE
    lea  r14, [bars + rax]

    cmp  dword [r14 + bDone], 0
    jne  .rbar_full

    ; Running bar: compute percent and filled width from elapsed
    mov  rax, r15
    sub  rax, [r14 + bStartUs]
    mov  rcx, rax              ; rcx = elapsed

    xor  edx, edx
    imul rax, 100
    div  qword [r14 + bDurUs]
    mov  r10d, eax             ; r10d = percent

    mov  rax, rcx
    xor  edx, edx
    imul rax, BAR_WIDTH
    div  qword [r14 + bDurUs]
    mov  r11d, eax             ; r11d = filled
    jmp  .rbar_draw

.rbar_full:
    mov  r10d, 100
    mov  r11d, BAR_WIDTH

.rbar_draw:
    ; Format: [####-----] xxx%\n

    mov  byte [rdi], '['
    inc  rdi

    mov  ecx, r11d
    mov  al, '#'
    rep  stosb

    mov  ecx, BAR_WIDTH
    sub  ecx, r11d
    mov  al, '-'
    rep  stosb

    mov  byte [rdi], ']'
    mov  byte [rdi+1], ' '

    cmp  r10d, 100
    jne  .rbar_lt100

    mov  byte [rdi+2], '1'
    mov  byte [rdi+3], '0'
    mov  byte [rdi+4], '0'
    jmp  .rbar_pct

.rbar_lt100:
    mov  byte [rdi+2], ' '
    mov  byte [rdi+3], ' '

    mov  eax, r10d
    xor  edx, edx
    mov  ecx, 10
    div  ecx               ; eax=tens, edx=ones

    test eax, eax
    jz   .rbar_ones
    add  al, '0'
    mov  [rdi+3], al

.rbar_ones:
    add  dl, '0'
    mov  [rdi+4], dl

.rbar_pct:
    mov  byte [rdi+5], '%'
    mov  byte [rdi+6], 10  ; LF
    add  rdi, 7

    inc  ebx
    jmp  .rbar

.rbar_end:
    ; Append ESC[<num_bars>A to return cursor to first bar row
    mov  eax, r12d
    append_cuu

    ; write(stderr, render_buf, len)
    lea  rsi, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  edx, edi
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    syscall

    ; ------ Phase 3: print completion messages ------

.phase3:
    test r13d, r13d
    jz   .main_loop

    xor  ebx, ebx

.cmsg:
    cmp  ebx, r12d
    jge  .main_loop

    mov  eax, ebx
    imul eax, BAR_SIZE
    lea  r14, [bars + rax]

    cmp  dword [r14 + bDone], 1
    jne  .cmsg_next

    mov  dword [r14 + bDone], 2

    ; TTY: move cursor down to message row, then back up after writing
    cmp  qword [stderr_is_tty], 0
    je   .cmsg_build

    ; Emit ESC[<num_bars+msg_count>B on stderr
    lea  rdi, [render_buf]
    mov  eax, [num_bars]
    add  eax, [msg_count]
    append_cud
    lea  rsi, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  edx, edi
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    syscall

.cmsg_build:
    ; Build "Progress bar for <N> seconds is completed\n" in msgbuf
    cld
    lea  rdi, [msgbuf]

    lea  rsi, [msg_pre]
    mov  ecx, MSG_PRE_LEN
    rep  movsb

    ; Integer-to-string: right-to-left into temp area, then copy forward
    mov  eax, [r14 + bDurSecs]
    lea  r8, [msgbuf + 70]
    mov  r9, r8
    mov  ecx, 10
.i2s:
    xor  edx, edx
    div  ecx
    add  dl, '0'
    dec  r8
    mov  [r8], dl
    test eax, eax
    jnz  .i2s

    mov  rcx, r9
    sub  rcx, r8
    mov  rsi, r8
    rep  movsb

    lea  rsi, [msg_suf]
    mov  ecx, MSG_SUF_LEN
    rep  movsb

    ; write(stdout, msgbuf, len)
    lea  rax, [msgbuf]
    mov  rdx, rdi
    sub  rdx, rax
    mov  eax, SYS_write
    mov  edi, STDOUT_FD
    lea  rsi, [msgbuf]
    syscall

    inc  dword [done_count]

    ; TTY: move cursor back up to first bar row
    cmp  qword [stderr_is_tty], 0
    je   .cmsg_skip_up

    lea  rdi, [render_buf]
    mov  eax, [num_bars]
    add  eax, [msg_count]
    inc  eax               ; +1 for the message's own newline
    append_cuu
    lea  rsi, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  edx, edi
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    syscall

.cmsg_skip_up:
    inc  dword [msg_count]

.cmsg_next:
    inc  ebx
    jmp  .cmsg

    ; ======================================================================
    ; EXIT
    ; ======================================================================

.all_done:
    ; TTY: move cursor past bars + all messages so prompt lands correctly
    cmp  qword [stderr_is_tty], 0
    je   .exit_ok

    lea  rdi, [render_buf]
    mov  eax, [num_bars]
    add  eax, [msg_count]
    append_cud
    lea  rsi, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  edx, edi
    mov  eax, SYS_write
    mov  edi, STDERR_FD
    syscall

.exit_ok:
    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbp
    pop  rbx
    mov  eax, SYS_exit
    xor  edi, edi
    syscall
    hlt

.exit_err:
    add  rsp, 8
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    pop  rbp
    pop  rbx
    mov  eax, SYS_exit
    mov  edi, 1
    syscall
    hlt
