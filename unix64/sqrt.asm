bits 64
default rel

global main

section .text
main:
    ; argc is in rdi, argv is in rsi

    cmp  rdi, 2
    jne  .exit_error

    ; Parse argv[1] to double -> xmm0
    mov  rdi, [rsi + 8]
    call .atof

    ; If negative, negate and remember for the trailing "i"
    xor  r15d, r15d            ; negative flag
    pxor xmm1, xmm1
    ucomisd xmm0, xmm1
    jae  .do_sqrt
    inc  r15d
    subsd xmm1, xmm0
    movsd xmm0, xmm1

.do_sqrt:
    sqrtsd xmm0, xmm0

    ; Convert result to string
    lea  rdi, [buf]
    call .dtoa                 ; rax = length

    ; Append "i" for imaginary results
    lea  r12, [buf]
    test r15d, r15d
    jz   .no_i
    mov  byte [r12 + rax], 'i'
    inc  rax
.no_i:
    mov  byte [r12 + rax], 10  ; newline
    inc  rax

    ; write(stdout, buf, len)
    mov  rdx, rax
    mov  rax, 1                ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [buf]
    syscall

    mov  rax, 60               ; syscall: exit
    xor  edi, edi
    syscall

.exit_error:
    mov  rax, 60
    mov  rdi, 1
    syscall

; ---------------------------------------------------------------------------
; atof: parse ASCII string at [rdi] to double in xmm0
; Handles optional leading '-', integer part, optional '.fraction'.
; ---------------------------------------------------------------------------
.atof:
    pxor xmm0, xmm0           ; result = 0.0
    xor  r8d, r8d              ; sign flag (0 = positive)

    cmp  byte [rdi], '-'
    jne  .atof_int
    inc  r8d
    inc  rdi

.atof_int:
    movzx eax, byte [rdi]
    sub  al,  '0'
    cmp  al,  9
    ja   .atof_dot
    mulsd xmm0, [TEN]         ; result *= 10
    cvtsi2sd xmm1, eax
    addsd xmm0, xmm1          ; result += digit
    inc  rdi
    jmp  .atof_int

.atof_dot:
    cmp  byte [rdi], '.'
    jne  .atof_sign
    inc  rdi
    movsd xmm2, [TEN]         ; divisor = 10

.atof_frac:
    movzx eax, byte [rdi]
    sub  al,  '0'
    cmp  al,  9
    ja   .atof_sign
    cvtsi2sd xmm1, eax
    divsd xmm1, xmm2          ; digit / divisor
    addsd xmm0, xmm1
    mulsd xmm2, [TEN]         ; divisor *= 10
    inc  rdi
    jmp  .atof_frac

.atof_sign:
    test r8d, r8d
    jz   .atof_ret
    pxor xmm1, xmm1
    subsd xmm1, xmm0          ; negate
    movsd xmm0, xmm1
.atof_ret:
    ret

; ---------------------------------------------------------------------------
; dtoa: convert non-negative double in xmm0 to decimal string at [rdi]
; Returns string length in rax.  Up to 6 fractional digits, trailing zeros
; trimmed.
; ---------------------------------------------------------------------------
.dtoa:
    mov  rsi, rdi              ; save buffer start

    ; Split value into integer part (r8) and 6-digit rounded fraction (r9)
    cvttsd2si r8, xmm0        ; r8 = integer part
    cvtsi2sd xmm1, r8
    subsd xmm0, xmm1          ; xmm0 = fractional part
    mulsd xmm0, [MILLION]     ; shift 6 decimal places
    addsd xmm0, [HALF]        ; round half-up
    cvttsd2si r9, xmm0        ; r9 = rounded fractional digits

    ; Handle carry from rounding (e.g. 0.9999999 → 1.000000)
    cmp  r9,  1000000
    jl   .dtoa_int
    inc  r8
    xor  r9d, r9d

    ; --- Write integer part ---
.dtoa_int:
    test r8,  r8
    jnz  .dtoa_int_push
    mov  byte [rdi], '0'
    inc  rdi
    jmp  .dtoa_frac

.dtoa_int_push:
    xor  ecx, ecx             ; digit count
    mov  rax, r8
.dtoa_int_div:
    test rax, rax
    jz   .dtoa_int_pop
    xor  edx, edx
    mov  r10, 10
    div  r10
    add  dl,  '0'
    push rdx                   ; push digit (right-to-left)
    inc  ecx
    jmp  .dtoa_int_div

.dtoa_int_pop:
    test ecx, ecx
    jz   .dtoa_frac
    pop  rax
    mov  [rdi], al
    inc  rdi
    dec  ecx
    jmp  .dtoa_int_pop

    ; --- Write fractional part (6 digits with leading zeros, trim trailing) ---
.dtoa_frac:
    test r9,  r9
    jz   .dtoa_done

    mov  byte [rdi], '.'
    inc  rdi

    ; Write 6 digits right-to-left into [rdi..rdi+5]
    lea  r10, [rdi + 5]
    mov  rax, r9
    mov  ecx, 6
.dtoa_frac_div:
    xor  edx, edx
    mov  r11, 10
    div  r11
    add  dl,  '0'
    mov  [r10], dl
    dec  r10
    dec  ecx
    jnz  .dtoa_frac_div

    ; Trim trailing zeros
    add  rdi, 6
.dtoa_trim:
    dec  rdi
    cmp  byte [rdi], '0'
    je   .dtoa_trim
    inc  rdi                   ; keep last non-zero digit

.dtoa_done:
    mov  rax, rdi
    sub  rax, rsi              ; length
    ret

section .data
TEN:     dq 10.0
MILLION: dq 1000000.0
HALF:    dq 0.5

section .bss
buf: resb 64
