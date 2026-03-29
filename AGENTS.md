# AGENTS.md

This repository is a collection of testable, minimalistic, human-readable NASM assembly programs. Each example demonstrates a specific aspect of assembly programming or low-level OS interaction (system calls, calling conventions, Win32 API, exit codes, I/O, etc.) with as little noise as possible.

## Project layout

```
win64/      x86-64 Windows examples (Win32 API via link.exe)
unix64/     x86-64 Linux examples (raw syscalls via ld)
mac64/      x86-64 macOS examples (syscalls via ld)
macros/     Reusable NASM macros (e.g. macro_strlen)
test/       pytest test suite
bin/        Build output (generated)
Makefile    Top-level build, auto-detects platform
```

All `Makefile.local` configure building on local machine, it is not part of the repository.

## Examples

| Program  | Description                                                    |
|----------|----------------------------------------------------------------|
| exit77   | Returns exit code 77 — the simplest possible complete program  |
| hello    | Prints "Hello world!" to stdout                                |
| args     | Prints command-line arguments one per line in UTF-8 encoding   |

## Building

```
make build
```

The Makefile auto-detects the OS and selects the correct platform subdirectory (`win64`, `unix64`, or `mac64`).

### Windows prerequisites

- [NASM](https://www.nasm.us/) — assembler
- GNU `make`
- Microsoft `link.exe` and `dumpbin.exe` from [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/?q=build+tools) ("C++ Build Tools" workload)
- `LIB` environment variable must include the Windows Kit `um/x64` path

If any of the above are not on `PATH`, copy `win64/Makefile.local` and uncomment/set the relevant variables (`NASM`, `VSLINK`, `VSDUMPBIN`, `VSKIT`).

### Linux / macOS prerequisites

- NASM
- GNU `make`
- `ld` (system linker)

## Testing

```
make test
```

This builds all examples then runs `pytest test/`. Tests verify exit codes and stdout for each program. The test suite skips a test automatically if the corresponding `.asm` file does not exist for the current platform.

CI runs the full matrix (Windows, Ubuntu, macOS) on every push and pull request via GitHub Actions.

## Adding a new example

1. Create `<platform>/yourprogram.asm` (and equivalents for other platforms if applicable).
2. The Makefile picks up all `*.asm` files in the platform directory automatically — no Makefile edits needed.
3. Add a test function in `test/test_examples.py` that checks the program's exit code and output.
4. Keep the source minimal and self-explanatory — the goal is readability, not production robustness.

## Assembly style guide

- **Indent instructions with 4 spaces.**

- **Pad the mnemonic to 4 characters** by adding trailing spaces before the operands, so all operands start in the same column regardless of mnemonic length:
  ```
  jb   .label       ; 2-char mnemonic + 3 spaces
  mov  rax, 1       ; 3-char mnemonic + 2 spaces
  call foo          ; 4-char mnemonic + 1 space
  ```

- **Align the second operand** when the first operand is a register: add trailing spaces after the comma to compensate for registers shorter than 3 characters, so the second operand always starts at the same column as it would for a 3-character register:
  ```
  mov  rcx, foo     ; 3-char register — 1 space after comma
  mov  r8,  foo     ; 2-char register — 2 spaces after comma
  mov  cl,  foo     ; 2-char register — 2 spaces after comma
  ```

- **Never use `[symbol + register]` memory operands.** In x86-64, `default rel` makes plain `[symbol]` references RIP-relative, but adding a register (e.g. `[buf + rcx]`) forces NASM to emit a 32-bit absolute address — there is no `[RIP + disp + reg]` encoding. This generates relocations (`IMAGE_REL_AMD64_ADDR32`, `R_X86_64_32S`) that fail on modern linkers (ASLR, PIE, Mach-O 64-bit). Instead, load the symbol address into a register first, then index from it:
  ```nasm
  ; WRONG — generates a 32-bit absolute relocation:
  movzx eax, byte [buf + rcx]

  ; RIGHT — RIP-relative lea, then register+register:
  lea  rsi, [buf]
  movzx eax, byte [rsi + rcx]
  ```

## Conventions

- Each `.asm` file should be self-contained and demonstrate one concept.
- Prefer inline comments that explain *why* (calling convention requirements, alignment constraints, syscall numbers) rather than restating what the instruction does.
- Platform differences (Win32 API vs. Linux syscalls vs. macOS syscalls) are intentional and illustrative — do not abstract them away.
- Macros live in `macros/` and may include `%ifdef UNIT_TESTS` blocks for inline unit testing.
