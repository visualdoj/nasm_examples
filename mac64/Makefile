export EXEEXT :=

EXAMPLES_EXE := $(addprefix $(BIN)/,$(EXAMPLES))

LDFLAGS :=

$(BIN) :
	mkdir $(BIN)

$(BIN)/%.o : $(SRC)/%.asm $(BIN)
	$(NASM) -w+error -f macho64 $< -o $@

$(BIN)/%.exe : $(BIN)/%.o
	$(LD) $(LDFLAGS) --strip-all $< -o $@

build_examples : $(EXAMPLES_EXE)
	@: # no-op to suppress "make: Nothing to be done ..."

clean :
	rm -rf bin
