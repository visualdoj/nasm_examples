-include $(SRC)/Makefile.local

export EXEEXT := .exe

EXAMPLES_EXE := $(addprefix $(BIN)/,$(addsuffix .exe,$(EXAMPLES)))

$(BIN) :
	mkdir $(BIN)

build_examples : $(EXAMPLES_EXE)
	@: # no-op to suppress "make: Nothing to be done ..."

# MSVC's link.exe and lld-link.exe read the LINK env var as extra command-line
# arguments, so callers should use NASM_LINKER instead of LINK whenever possible.
# Keep LINK as a backward-compatible fallback for local usage.
ifeq ($(NASM_LINKER),)
  ifeq ($(LINK),)  # default linker
    LINKER := ld
  else
    LINKER := $(LINK)
  endif
else
  LINKER := $(NASM_LINKER)
endif
unexport LINK

LINKER_CMD := $(LINKER)

ifeq ($(LINKER),ld)  # MinGW linker
  LINKOPTO := -o #
  LINKOPTS := -e main --strip-all
  LINKOPTS += C:/Windows/System32/kernel32.dll
  LINKOPTS += C:/Windows/System32/user32.dll
  LINKOPTS += C:/Windows/System32/msvcrt.dll
  LINKOPTS += C:/Windows/System32/shell32.dll
endif

ifeq ($(LINKER),link.exe)  # MSVC linker
  export LIB:=$(VSKIT);$(LIB)
  LINKER_CMD := $(if $(VSLINK),$(VSLINK),$(LINKER))
  LINKOPTO := /OUT:
  LINKOPTS := /ENTRY:main /SUBSYSTEM:console kernel32.lib user32.lib shell32.lib
endif

ifeq ($(LINKER),lld-link.exe)  # LLVM linker
  export LIB:=$(VSKIT);$(LIB)
  LINKOPTO := /out:
  LINKOPTS := /entry:main /subsystem:console kernel32.lib user32.lib shell32.lib
endif

$(BIN)/%.o : $(SRC)/%.asm $(BIN)
	$(NASM) -w+error -f win64 $< -o $@

$(BIN)/%.exe : $(BIN)/%.o
	$(LINKER_CMD) $(LINKOPTS) $(LINKOPTO)$@ $<
