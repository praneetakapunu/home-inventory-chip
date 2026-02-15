# Minimal smoke-test harness for the Wishbone register block
#
# Requires: iverilog (recommended) or another Verilog simulator.
#
# Usage:
#   make -C verify sim
#

IVERILOG ?= iverilog
VVP     ?= vvp

RTL_DIR := ../rtl

TB      := wb_tb.v
OUT     := wb_tb.out

.PHONY: sim clean

sim: $(OUT)
	$(VVP) $(OUT)

$(OUT): $(TB) $(RTL_DIR)/home_inventory_wb.v
	$(IVERILOG) -g2012 -Wall -o $@ $^

clean:
	rm -f $(OUT)
