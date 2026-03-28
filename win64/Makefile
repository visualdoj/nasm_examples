-include $(SRC)/Makefile.local

export EXEEXT := .exe

EXAMPLES_EXE := $(addprefix $(BIN)/,$(addsuffix .exe,$(EXAMPLES)))

$(BIN) :
	mkdir $(BIN)

build_examples : $(EXAMPLES_EXE)
	@: # no-op to suppress "make: Nothing to be done ..."

# MSVC's link.exe and lld-link.exe read the LINK env var as extra command-line
# arguments, so we must not export it to child processes.
unexport LINK

ifeq ($(LINK),)	 # default linker
  LINK := ld
endif

ifeq ($(LINK),ld)  # MinGW linker
  LINKOPTO := -o #
  LINKOPTS := -e main --strip-all
  LINKOPTS += C:\Windows\System32\kernel32.dll
  LINKOPTS += C:\Windows\System32\user32.dll
  LINKOPTS += C:\Windows\System32\msvcrt.dll
  LINKOPTS += C:\Windows\System32\shell32.dll
endif

ifeq ($(LINK),link.exe)  # MSVC linker
  # Auto-detect MSVC link.exe via vswhere so we don't rely on PATH order
  # (GitHub runners have /usr/bin/link.exe which is the POSIX link command).
  VSWHERE := C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe
  _MSVC_LINK := $(shell "$(VSWHERE)" -latest -products "*" -find VC\\Tools\\MSVC\\*\\bin\\Hostx64\\x64\\link.exe 2>/dev/null)
  ifneq ($(_MSVC_LINK),)
    override LINK := $(_MSVC_LINK)
  endif
  export LIB:=$(VSKIT);$(LIB)
  LINKOPTO := /OUT:
  LINKOPTS := /ENTRY:main /SUBSYSTEM:console kernel32.lib user32.lib shell32.lib
endif

ifeq ($(LINK),lld-link.exe)  # LLVM linker
  export LIB:=$(VSKIT);$(LIB)
  LINKOPTO := /out:
  LINKOPTS := /entry:main /subsystem:console kernel32.lib user32.lib shell32.lib
endif

$(BIN)/%.o : $(SRC)/%.asm $(BIN)
	$(NASM) -w+error -f win64 $< -o $@

$(BIN)/%.exe : $(BIN)/%.o
	"$(LINK)" $(LINKOPTS) $(LINKOPTO)$@ $<
