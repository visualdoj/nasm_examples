default : build ;

-include ../Makefile.node

.PHONY : default ;

ifeq ($(OS),Windows_NT)
  export SRC := win64
else
  export SRC := unix64
endif

export BIN := bin

NASM ?= nasm
LD ?= ld

EXAMPLES_ASM := $(wildcard $(SRC)/*.asm)
EXAMPLES := $(EXAMPLES_ASM:$(SRC)/%.asm=%)

include $(SRC)/Makefile

build : build_examples ;

test : build_examples
	python -m pytest test
