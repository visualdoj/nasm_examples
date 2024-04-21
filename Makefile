default : build ;

-include ../Makefile.node

.PHONY : default ;

ifeq ($(OS),Windows_NT)
  UNAME := Windows
  export SRC := win64
else
  UNAME := $(shell uname)
  ifeq ($(UNAME),Darwin)
    export SRC := mac64
  else
    export SRC := unix64
  endif
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
