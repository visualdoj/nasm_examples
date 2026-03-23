bits 64
default rel

global main

extern ExitProcess
extern GetStdHandle
extern GetConsoleMode
extern SetConsoleMode
extern WriteFile

STD_OUTPUT_HANDLE equ -11
ENABLE_VIRTUAL_TERMINAL_PROCESSING equ 0x0004

section .text
main:
    ; Alignment + Local variables (bytes) + Arguments + Shadow Space
    sub  rsp, 12+4+8+32
 
    ; stdout = GetStdHandle(STD_OUTPUT_HANDLE)
    mov  rcx, STD_OUTPUT_HANDLE ; argument 1: identifier of a standard device
    call GetStdHandle
    mov  QWORD [stdout], rax

    ; rax = GetConsoleMode(rax, &terminalMode)
    mov  rcx, rax               ; argument 1: stdout handle
    lea  rdx, [terminalMode]    ; argument 2: pointer to the resulting terminal mode
    call GetConsoleMode

    ; rax = SetConsoleMode(stdout, terminalMode | ENABLE_VIRTUAL_TERMINAL_PROCESSING)
    mov  rcx, QWORD [stdout]                      ; argument 1: stdout handle
    mov  edx, DWORD [terminalMode]
    or   edx, ENABLE_VIRTUAL_TERMINAL_PROCESSING  ; argument 2: pointer to the terminal mode to set
    call SetConsoleMode
 
    ; rax = WriteFile(rax, &MSG, MSG_LEN, &bytes, NULL)
    mov  rcx, QWORD [stdout]    ; argument 1: file handle returned from GetStdHandle
    lea  rdx, [MSG]             ; argument 2: string
    mov  r8, MSG_LEN            ; argument 3: string length
    lea  r9, DWORD [rsp+32]     ; argument 4: &bytes
    mov  QWORD [rsp], 0         ; argument 5: lpOverlapped
    call WriteFile
 
    ; ExitProcess(0)
    mov  rcx, 0
    call ExitProcess
    hlt


section .bss
stdout resb 8
terminalMode resb 4


section .data
MSG: db \
        0x1b,"[97mWhite ",0x1b,"[91mRed ",0x1b,"[92mGreen ",0x1b,"[93mYellow ",0x1b,"[94mBlue ",0x1b,"[95mMagenta ",0x1b,"[96mCyan ",0x1b,"[0m",13,10,\
        0x1b,"[37mWhite ",0x1b,"[31mRed ",0x1b,"[32mGreen ",0x1b,"[33mYellow ",0x1b,"[34mBlue ",0x1b,"[35mMagenta ",0x1b,"[36mCyan ",0x1b,"[0m",13,10
MSG_LEN equ $ - MSG
