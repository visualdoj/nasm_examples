bits 64
default rel

global _main

section .text
_main:
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
    test r15d, r15d
    jz   .no_i
    lea  r12, [buf]
    mov  byte [r12 + rax], 'i'
    inc  rax
.no_i:
    mov  byte [r12 + rax], 10  ; newline
    inc  rax

    ; write(stdout, buf, len)
    mov  rdx, rax
    mov  rax, 0x02000004       ; syscall: write
    mov  rdi, 1                ; fd: stdout
    lea  rsi, [buf]
    syscall

    mov  rax, 0x02000001       ; syscall: exit
    xor  edi, edi
    syscall

.exit_error:
    mov  rax, 0x02000001
    mov  rdi, 1
    syscall

; ---------------------------------------------------------------------------
; atof: parse ASCII string at [rdi] to double in xmm0
; ---------------------------------------------------------------------------
.atof:
    pxor xmm0, xmm0
    xor  r8d, r8d

    cmp  byte [rdi], '-'
    jne  .atof_int
    inc  r8d
    inc  rdi

.atof_int:
    movzx eax, byte [rdi]
    sub  al,  '0'
    cmp  al,  9
    ja   .atof_dot
    mulsd xmm0, [TEN]
    cvtsi2sd xmm1, eax
    addsd xmm0, xmm1
    inc  rdi
    jmp  .atof_int

.atof_dot:
    cmp  byte [rdi], '.'
    jne  .atof_sign
    inc  rdi
    movsd xmm2, [TEN]

.atof_frac:
    movzx eax, byte [rdi]
    sub  al,  '0'
    cmp  al,  9
    ja   .atof_sign
    cvtsi2sd xmm1, eax
    divsd xmm1, xmm2
    addsd xmm0, xmm1
    mulsd xmm2, [TEN]
    inc  rdi
    jmp  .atof_frac

.atof_sign:
    test r8d, r8d
    jz   .atof_ret
    pxor xmm1, xmm1
    subsd xmm1, xmm0
    movsd xmm0, xmm1
.atof_ret:
    ret

; ---------------------------------------------------------------------------
; dtoa: non-negative xmm0 → decimal string at [rdi], length in rax
; ---------------------------------------------------------------------------
.dtoa:
    mov  rsi, rdi

    cvttsd2si r8, xmm0
    cvtsi2sd xmm1, r8
    subsd xmm0, xmm1
    mulsd xmm0, [MILLION]
    addsd xmm0, [HALF]
    cvttsd2si r9, xmm0

    cmp  r9,  1000000
    jl   .dtoa_int
    inc  r8
    xor  r9d, r9d

.dtoa_int:
    test r8,  r8
    jnz  .dtoa_int_push
    mov  byte [rdi], '0'
    inc  rdi
    jmp  .dtoa_frac

.dtoa_int_push:
    xor  ecx, ecx
    mov  rax, r8
.dtoa_int_div:
    test rax, rax
    jz   .dtoa_int_pop
    xor  edx, edx
    mov  r10, 10
    div  r10
    add  dl,  '0'
    push rdx
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

.dtoa_frac:
    test r9,  r9
    jz   .dtoa_done

    mov  byte [rdi], '.'
    inc  rdi

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

    add  rdi, 6
.dtoa_trim:
    dec  rdi
    cmp  byte [rdi], '0'
    je   .dtoa_trim
    inc  rdi

.dtoa_done:
    mov  rax, rdi
    sub  rax, rsi
    ret

section .data
TEN:     dq 10.0
MILLION: dq 1000000.0
HALF:    dq 0.5

section .bss
buf: resb 64
