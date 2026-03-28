bits 64
default rel

global _main

section .text
_main:
    ; argc in rdi, argv in rsi
    cmp  rdi, 2
    jne  .exit_error

    ; fd = open(argv[1], O_RDONLY)
    mov  rdi, [rsi + 8]
    xor  esi, esi              ; O_RDONLY = 0
    mov  rax, 0x02000005       ; syscall: open
    syscall
    test rax, rax
    js   .exit_error
    mov  r12, rax              ; r12 = fd
    xor  r13d, r13d            ; r13 = file offset
    lea  rbx, [HEX]

.line:
    ; n = read(fd, rbuf, 16)
    mov  rax, 0x02000003       ; syscall: read
    mov  rdi, r12
    lea  rsi, [rbuf]
    mov  edx, 16
    syscall
    test rax, rax
    jle  .final
    mov  r14, rax              ; r14 = bytes read

    ; --- Format line into lbuf ---
    lea  rdi, [lbuf]
    mov  rax, r13
    call .write_hex8
    mov  word [rdi], 0x2020    ; two spaces
    add  rdi, 2

    ; Hex bytes (16 columns, extra space after column 8)
    xor  ecx, ecx
.hex:
    cmp  ecx, 16
    je   .asc
    cmp  ecx, 8
    jne  .no_gap
    mov  byte [rdi], ' '
    inc  rdi
.no_gap:
    cmp  ecx, r14d
    jge  .pad
    movzx eax, byte [rbuf + rcx]
    mov  edx, eax
    shr  edx, 4
    mov  dl, [rbx + rdx]
    mov  [rdi], dl
    and  eax, 0xf
    mov  al, [rbx + rax]
    mov  [rdi + 1], al
    mov  byte [rdi + 2], ' '
    add  rdi, 3
    jmp  .hex_next
.pad:
    mov  byte [rdi], ' '
    mov  byte [rdi + 1], ' '
    mov  byte [rdi + 2], ' '
    add  rdi, 3
.hex_next:
    inc  ecx
    jmp  .hex

    ; ASCII column
.asc:
    mov  byte [rdi], ' '
    mov  byte [rdi + 1], '|'
    add  rdi, 2
    xor  ecx, ecx
.asc_loop:
    cmp  ecx, r14d
    je   .asc_end
    movzx eax, byte [rbuf + rcx]
    cmp  al, 0x20
    jb   .dot
    cmp  al, 0x7e
    ja   .dot
    mov  [rdi], al
    jmp  .asc_next
.dot:
    mov  byte [rdi], '.'
.asc_next:
    inc  rdi
    inc  ecx
    jmp  .asc_loop
.asc_end:
    mov  byte [rdi], '|'
    mov  byte [rdi + 1], 10
    add  rdi, 2

    ; write(stdout, lbuf, len)
    mov  rdx, rdi
    lea  rsi, [lbuf]
    sub  rdx, rsi
    mov  rax, 0x02000004       ; syscall: write
    mov  edi, 1
    syscall

    add  r13, r14
    cmp  r14, 16
    je   .line

.final:
    ; Final offset line
    lea  rdi, [lbuf]
    mov  rax, r13
    call .write_hex8
    mov  byte [rdi], 10
    inc  rdi

    mov  rdx, rdi
    lea  rsi, [lbuf]
    sub  rdx, rsi
    mov  rax, 0x02000004
    mov  edi, 1
    syscall

    ; close(fd)
    mov  rax, 0x02000006       ; syscall: close
    mov  rdi, r12
    syscall

    ; exit(0)
    mov  rax, 0x02000001
    xor  edi, edi
    syscall

.exit_error:
    mov  rax, 0x02000001
    mov  edi, 1
    syscall

; ---------------------------------------------------------------------------
; write_hex8: write rax as 8 hex digits at [rdi], advance rdi by 8
; Requires rbx = HEX base. Clobbers rax, ecx, edx.
; ---------------------------------------------------------------------------
.write_hex8:
    mov  ecx, 28
.wh8:
    mov  edx, eax
    shr  edx, cl
    and  edx, 0xf
    mov  dl, [rbx + rdx]
    mov  [rdi], dl
    inc  rdi
    sub  ecx, 4
    jge  .wh8
    ret

section .data
HEX: db "0123456789abcdef"

section .bss
rbuf: resb 16
lbuf: resb 80
