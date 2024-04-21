export EXEEXT := .exe

EXAMPLES_EXE := $(addprefix $(BIN)/,$(addsuffix .exe,$(EXAMPLES)))

LDFLAGS := -LC:\prog\mingw64\x86_64-w64-mingw32\lib -lkernel32 -luser32 C:\Windows\System32\kernel32.dll C:\Windows\System32\user32.dll C:\Windows\System32\msvcrt.dll C:\Windows\System32\shell32.dll

$(BIN) :
	mkdir $(BIN)

$(BIN)/%.obj : $(SRC)/%.asm $(BIN)
	$(NASM) -w+error -f win64 $< -o $@

$(BIN)/%.exe : $(BIN)/%.obj
	$(LD) $(LDFLAGS) -e main --strip-all $< -o $@

build_examples : $(EXAMPLES_EXE)
	@: # no-op to suppress "make: Nothing to be done ..."
