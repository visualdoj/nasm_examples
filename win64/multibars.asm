bits 64
default rel

global main

extern GetStdHandle
extern GetConsoleMode
extern GetConsoleScreenBufferInfo
extern SetConsoleCursorPosition
extern WriteFile
extern QueryPerformanceFrequency
extern QueryPerformanceCounter
extern GetCommandLineW
extern CommandLineToArgvW
extern LocalFree
extern ExitProcess


STD_OUTPUT_HANDLE equ -11
STD_ERROR_HANDLE  equ -12
BAR_WIDTH         equ 50
MAX_BARS          equ 16
BAR_SIZE          equ 32

; Bar struct field offsets (32 bytes each)
bDurTicks         equ 0        ; qword: freq * seconds
bStartTick        equ 8        ; qword: QPC value at start
bLastPct          equ 16       ; dword: last rendered percent (-1 = never)
bDone             equ 20       ; dword: 0=running, 1=just done, 2=msg printed
bDurSecs          equ 24       ; dword: original seconds value


section .data
stdout          dq 0
stderr          dq 0
stderr_mode     dd 0
stderr_is_tty   dq 0
freq            dq 0
nowTick         dq 0
bw              dq 0
num_bars        dd 0
done_count      dd 0
base_row        dd 0
msg_count       dd 0
argW            dq 0

msg_pre         db "Progress bar for "
MSG_PRE_LEN     equ $ - msg_pre
msg_suf         db " seconds is completed", 13, 10
MSG_SUF_LEN     equ $ - msg_suf


section .bss
bars            resb BAR_SIZE * MAX_BARS
render_buf      resb 1024
csbi            resb 24
msgbuf          resb 80


section .text

; ============================================================================
; main
;
; Usage: multibars <sec1> <sec2> ... (up to 16 durations)
;
; Renders one progress bar per duration on stderr (using cursor positioning).
; Prints "Progress bar for N seconds is completed" to stdout as each finishes.
; If stderr is not a TTY, progress bars are skipped; stdout messages still print.
; ============================================================================
main:
    push rbx
    push rsi
    push rdi
    push rbp
    push r12
    push r13
    push r14
    push r15
    ; 8 pushes (64 bytes) + return address: RSP mod 16 = 8
    sub  rsp, 40               ; alignment(8) + shadow(32)

    ; ---------- Handles ----------

    mov  rcx, STD_OUTPUT_HANDLE
    call GetStdHandle
    mov  [stdout], rax

    mov  rcx, STD_ERROR_HANDLE
    call GetStdHandle
    mov  [stderr], rax

    ; stderr_is_tty = GetConsoleMode(stderr, &stderr_mode)
    mov  rcx, rax
    lea  rdx, [stderr_mode]
    call GetConsoleMode
    mov  [stderr_is_tty], rax

    ; ---------- Performance frequency ----------

    lea  rcx, [freq]
    call QueryPerformanceFrequency

    ; ---------- Parse command line ----------

    call GetCommandLineW
    mov  rcx, rax
    lea  rdx, [num_bars]
    call CommandLineToArgvW
    mov  [argW], rax
    mov  r15, rax              ; r15 = argv[]

    movsxd r12, dword [num_bars]
    dec  r12                   ; skip argv[0]
    jle  .exit_err
    cmp  r12, MAX_BARS
    jg   .exit_err
    mov  [num_bars], r12d

    ; ---------- Init bar structs ----------

    xor  ebx, ebx

.init:
    cmp  ebx, r12d
    jge  .init_done

    ; Parse argv[ebx+1] (UTF-16 digits -> integer seconds)
    mov  rsi, [r15 + rbx*8 + 8]
    xor  r13d, r13d
.prs:
    movzx ecx, word [rsi]
    test  cx, cx
    jz    .prs_end
    imul  r13d, 10
    sub   ecx, '0'
    add   r13d, ecx
    add   rsi, 2
    jmp   .prs

.prs_end:
    ; r13d = duration in seconds
    mov   eax, ebx
    imul  eax, BAR_SIZE
    lea   r14, [bars + rax]

    ; bar.durationTicks = freq * seconds
    mov   rax, [freq]
    mov   ecx, r13d
    imul  rax, rcx
    mov   [r14 + bDurTicks], rax

    ; bar.startTick = QueryPerformanceCounter()
    lea   rcx, [r14 + bStartTick]
    call  QueryPerformanceCounter

    mov   dword [r14 + bLastPct], -1
    mov   dword [r14 + bDone], 0
    mov   [r14 + bDurSecs], r13d

    inc   ebx
    jmp   .init

.init_done:
    ; ---------- Get base cursor row (TTY only) ----------

    cmp  qword [stderr_is_tty], 0
    je   .main_loop

    mov  rcx, [stderr]
    lea  rdx, [csbi]
    call GetConsoleScreenBufferInfo
    ; csbi layout: dwSize(4), dwCursorPosition(4) -> Y at offset 6
    movzx eax, word [csbi + 6]
    mov  [base_row], eax

    ; Reserve num_bars blank lines so the bars have room
    lea  rdi, [render_buf]
    xor  ecx, ecx
.rsv:
    cmp  ecx, r12d
    jge  .rsv_end
    mov  byte [rdi], 13
    mov  byte [rdi+1], 10
    add  rdi, 2
    inc  ecx
    jmp  .rsv
.rsv_end:
    mov  rcx, [stderr]
    lea  rdx, [render_buf]
    mov  eax, r12d
    shl  eax, 1               ; 2 bytes (CR+LF) per line
    mov  r8d, eax
    lea  r9, [bw]
    mov  qword [rsp+32], 0
    call WriteFile

    ; Re-query cursor position: reserve CRLFs may have scrolled the buffer,
    ; making the earlier base_row stale. base_row = cursorY - num_bars.
    mov  rcx, [stderr]
    lea  rdx, [csbi]
    call GetConsoleScreenBufferInfo
    movzx eax, word [csbi + 6]   ; cursor Y after reserve
    sub  eax, r12d                ; base_row = cursorY - num_bars
    mov  [base_row], eax

    ; ======================================================================
    ; MAIN LOOP
    ; ======================================================================

.main_loop:
    mov  eax, [done_count]
    cmp  eax, r12d
    jge  .all_done

    lea  rcx, [nowTick]
    call QueryPerformanceCounter

    ; ------ Phase 1: scan bars, update state ------

    xor  ebx, ebx             ; bar index
    xor  ebp, ebp             ; changed flag
    xor  r13d, r13d           ; new-completions flag

.scan:
    cmp  ebx, r12d
    jge  .scan_end

    mov  eax, ebx
    imul eax, BAR_SIZE
    lea  r14, [bars + rax]

    cmp  dword [r14 + bDone], 0
    jne  .scan_next

    ; elapsed = nowTick - startTick
    mov  rax, [nowTick]
    sub  rax, [r14 + bStartTick]

    cmp  rax, [r14 + bDurTicks]
    jb   .scan_run

    ; Bar just completed
    mov  dword [r14 + bDone], 1
    mov  dword [r14 + bLastPct], 100
    mov  ebp, 1
    mov  r13d, 1
    jmp  .scan_next

.scan_run:
    ; pct = elapsed * 100 / durationTicks
    xor  edx, edx
    imul rax, 100
    div  qword [r14 + bDurTicks]

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

    ; SetConsoleCursorPosition(stderr, COORD(X=0, Y=base_row))
    mov  rcx, [stderr]
    mov  edx, [base_row]
    shl  edx, 16              ; Y in high word, X=0 in low word
    call SetConsoleCursorPosition

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

    ; --- Running bar: compute filled & percent from elapsed ---
    mov  rax, [nowTick]
    sub  rax, [r14 + bStartTick]
    mov  rcx, rax             ; rcx = elapsed

    xor  edx, edx
    imul rax, 100
    div  qword [r14 + bDurTicks]
    mov  r10d, eax            ; r10d = percent

    mov  rax, rcx
    xor  edx, edx
    imul rax, BAR_WIDTH
    div  qword [r14 + bDurTicks]
    mov  r11d, eax            ; r11d = filled
    jmp  .rbar_draw

.rbar_full:
    mov  r10d, 100
    mov  r11d, BAR_WIDTH

.rbar_draw:
    ; Format: [####-----] xxx%\r\n

    mov  byte [rdi], '['
    inc  rdi

    ; '#' * filled
    mov  ecx, r11d
    mov  al, '#'
    rep  stosb

    ; '-' * (BAR_WIDTH - filled)
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
    div  ecx                  ; eax = tens, edx = ones

    test eax, eax
    jz   .rbar_ones
    add  al, '0'
    mov  [rdi+3], al

.rbar_ones:
    add  dl, '0'
    mov  [rdi+4], dl

.rbar_pct:
    mov  byte [rdi+5], '%'
    mov  byte [rdi+6], 13     ; CR
    mov  byte [rdi+7], 10     ; LF
    add  rdi, 8

    inc  ebx
    jmp  .rbar

.rbar_end:
    ; WriteFile(stderr, render_buf, len, &bw, NULL)
    mov  rcx, [stderr]
    lea  rdx, [render_buf]
    lea  rax, [render_buf]
    sub  rdi, rax
    mov  r8, rdi
    lea  r9, [bw]
    mov  qword [rsp+32], 0
    call WriteFile

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

    ; Mark message as printed
    mov  dword [r14 + bDone], 2

    ; Position cursor below bars + previous messages (TTY only)
    cmp  qword [stderr_is_tty], 0
    je   .cmsg_build

    mov  rcx, [stderr]
    mov  edx, [base_row]
    add  edx, r12d
    add  edx, [msg_count]
    shl  edx, 16
    call SetConsoleCursorPosition

.cmsg_build:
    ; Build: "Progress bar for <N> seconds is completed\r\n"
    cld
    lea  rdi, [msgbuf]

    ; Copy prefix
    lea  rsi, [msg_pre]
    mov  ecx, MSG_PRE_LEN
    rep  movsb

    ; Integer-to-string (right-to-left in temp area at end of msgbuf)
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

    ; Copy digit string forward
    mov  rcx, r9
    sub  rcx, r8
    mov  rsi, r8
    rep  movsb

    ; Copy suffix
    lea  rsi, [msg_suf]
    mov  ecx, MSG_SUF_LEN
    rep  movsb

    ; WriteFile(stdout, msgbuf, len, &bw, NULL)
    lea  rax, [msgbuf]
    mov  r8, rdi
    sub  r8, rax
    mov  rcx, [stdout]
    lea  rdx, [msgbuf]
    lea  r9, [bw]
    mov  qword [rsp+32], 0
    call WriteFile

    inc  dword [done_count]

    ; Re-query cursor: the message CRLF may have scrolled the buffer.
    ; Recompute base_row while msg_count still reflects rows already printed.
    cmp  qword [stderr_is_tty], 0
    je   .skip_adj
    mov  rcx, [stderr]
    lea  rdx, [csbi]
    call GetConsoleScreenBufferInfo
    movzx eax, word [csbi + 6]   ; cursor Y after message
    sub  eax, r12d
    sub  eax, [msg_count]         ; msg_count not yet incremented
    mov  [base_row], eax
.skip_adj:
    inc  dword [msg_count]

.cmsg_next:
    inc  ebx
    jmp  .cmsg

    ; ======================================================================
    ; EXIT
    ; ======================================================================

.all_done:
    ; Position cursor after all output (TTY only)
    cmp  qword [stderr_is_tty], 0
    je   .cleanup

    mov  rcx, [stderr]
    mov  edx, [base_row]
    add  edx, r12d
    add  edx, [msg_count]
    shl  edx, 16
    call SetConsoleCursorPosition

.cleanup:
    mov  rcx, [argW]
    call LocalFree

    xor  ecx, ecx
    call ExitProcess
    hlt

.exit_err:
    cmp  qword [argW], 0
    je   .exit1
    mov  rcx, [argW]
    call LocalFree
.exit1:
    mov  ecx, 1
    call ExitProcess
    hlt
