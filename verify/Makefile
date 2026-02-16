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

.PHONY: sim regmap-check clean

sim: $(OUT)
	$(VVP) $(OUT)

# Pure-Python consistency check (no Verilog simulator required).
regmap-check:
	python3 ../tools/regmap/check_regmap.py --yaml ../spec/regmap_v1.yaml --rtl ../rtl/home_inventory_wb.v

$(OUT): $(TB) $(RTL_DIR)/home_inventory_wb.v
	$(IVERILOG) -g2012 -Wall -o $@ $^

clean:
	rm -f $(OUT)
