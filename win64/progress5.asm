bits 64
default rel

global main

extern GetStdHandle
extern GetConsoleMode
extern WriteFile
extern QueryPerformanceFrequency
extern QueryPerformanceCounter
extern ExitProcess


; STD_OUTPUT_HANDLE equ -11
STD_ERROR_HANDLE  equ -12
BAR_WIDTH         equ 50


section .data
stderr          dq 0
stderr_mode     dd 0
stderr_is_tty   dq 0
freq            dq 0    ; Ticks per second
startTick       dq 0
nowTick         dq 0
durationTicks   dq 0
bytesWritten    dq 0
lastPct         dd -1


section .bss
buf             resb 64


section .text
main:
    ; Alignment + Shadow Space
    sub  rsp, 8+32

    ; stderr = GetStdHandle(STD_ERROR_HANDLE)
    mov  rcx, STD_ERROR_HANDLE
    call GetStdHandle
    mov  [stderr], rax

    ; stderr_is_tty = GetConsoleMode(stderr, &stderr_mode)
    mov  rcx, rax
    lea  rdx, [stderr_mode]
    call GetConsoleMode
    mov  QWORD [stderr_is_tty], rax

    ; QueryPerformanceFrequency(&freq)
    lea  rcx, [freq]
    call QueryPerformanceFrequency

    ; QueryPerformanceCounter(&startTick)
    lea  rcx, [startTick]
    call QueryPerformanceCounter

    ; durationTicks = freq * 5
    mov  rax, QWORD [freq]
    imul rax, 5
    mov  QWORD [durationTicks], rax

.main_loop:
    ; QueryPerformanceCounter(&nowTick)
    lea  rcx, [nowTick]
    call QueryPerformanceCounter

    ; nowTick - startTick >= durationTicks ?
    mov  rax, [nowTick]
    sub  rax, [startTick]
    cmp  rax, [durationTicks]
    jae  .done

    ; rcx = elapsed ticks
    mov  rcx, rax

    ; r10d = progress percantage
    xor  edx, edx
    mov  rax, rcx
    imul rax, 100
    div  QWORD [durationTicks]
    mov  r10d, eax

    ; redraw only when percent changes
    cmp  r10d, DWORD [lastPct]
    je   .main_loop
    mov  DWORD [lastPct], r10d

    ; r11d = elapsed * BAR_WIDTH / durationTicks
    mov  rax, rcx
    xor  edx, edx
    imul rax, BAR_WIDTH
    div  QWORD [durationTicks]
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
    mov  r8d, 1                 ; final = 1
    call render_and_write

    xor  ecx, ecx
    call ExitProcess


; -----------------------------------------------------------------------------
; render_and_write
;   in:
;     r10d = percent   (0..100)
;     r11d = filled    (0..BAR_WIDTH)
;     r8d  = final     (0/1)  -> add '\n' on final frame
; -----------------------------------------------------------------------------
render_and_write:
    sub  rsp, 40

    cld

    lea  rdi, [buf]

    ; '\r['
    mov  BYTE [rdi + 0], 13
    mov  BYTE [rdi + 1], '['
    lea  rdi, [rdi+2]

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
    mov  BYTE [rdi+0], ']'
    mov  BYTE [rdi+1], ' '

    cmp  r10d, 100
    jne  .not100

    mov  BYTE [rdi+2], '1'
    mov  BYTE [rdi+3], '0'
    mov  BYTE [rdi+4], '0'
    jmp  .digits_done

.not100:
    ; default: "  x" or " xx"
    mov  BYTE [rdi+2], ' '
    mov  BYTE [rdi+3], ' '

    ; eax = r10d / 10; edx = r10d % 10
    mov  eax, r10d
    xor  edx, edx
    mov  ecx, 10
    div  ecx

    test eax, eax
    jz   .add_ones
    add  al,  '0'
    mov  [rdi + 3], al          ; tens

.add_ones:
    add  dl,  '0'
    mov  [rdi + 4], dl          ; ones

.digits_done:
    mov  BYTE [rdi + 5], '%'

    mov  rax, 58                ; len without '\n'

    test r8d, r8d
    jz   .write
    mov  BYTE [rdi + 6], 10     ; '\n'
    mov  rax, 59

.write:
    ; rax = WriteFile(stderr, &buf, rax, &bytesWritten, NULL)
    mov  rcx, [stderr]          ; argument 1: file handle
    lea  rdx, [buf]             ; argument 2: the buffer
    mov  r8,  rax               ; argument 3: string length
    lea  r9,  [bytesWritten]    ; argument 4: &bytesWritten
    mov  QWORD [rsp + 32], 0    ; argument 5: lpOverlapped = NULL
    call WriteFile

    add  rsp, 40
    ret
