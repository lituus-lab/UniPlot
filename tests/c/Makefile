# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Shell-free: `pwd` and `rm` are unavailable under mingw32-make on Windows.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniPlot.a

ifeq ($(OS),Windows_NT)
  BIN  := test_uniplot.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := test_uniplot
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): test_uniplot.c $(ROOT)/include/UniPlot.h $(LIB)
	$(CC) $(CFLAGS) -DTEST_FONT=\"$(CURDIR)/../DejaVuSans.ttf\" -o $(BIN) test_uniplot.c $(LIB) -lz
# File target, not phony: `nimble ctest` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
