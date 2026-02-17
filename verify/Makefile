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

.PHONY: sim regmap-check regmap-gen regmap-gen-check clean

sim: $(OUT)
	$(VVP) $(OUT)

# Pure-Python consistency check (no Verilog simulator required).
regmap-check:
	python3 ../tools/regmap/check_regmap.py --yaml ../spec/regmap_v1.yaml --rtl ../rtl/home_inventory_wb.v

# Validate YAML + (re)generate FW header from YAML.
regmap-gen:
	python3 ../ops/regmap_validate.py --yaml ../spec/regmap_v1.yaml
	python3 ../ops/gen_regmap_header.py --yaml ../spec/regmap_v1.yaml --out ../fw/include/home_inventory_regmap.h

# Assert that the committed generated header is up-to-date.
regmap-gen-check:
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../ops/gen_regmap_header.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../fw/include/home_inventory_regmap.h; \
	rm -f $$TMP; \
	echo "OK: generated header matches spec/regmap_v1.yaml"'

$(OUT): $(TB) $(RTL_DIR)/home_inventory_wb.v
	$(IVERILOG) -g2012 -Wall -o $@ $^

clean:
	rm -f $(OUT)
