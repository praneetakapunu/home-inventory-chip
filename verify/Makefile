# Minimal smoke-test harness for the Wishbone register block
#
# Requires: iverilog (recommended) or another Verilog simulator.
#
# Usage:
#   make -C verify sim
#

IVERILOG ?= iverilog
VVP     ?= vvp

# Build flags for simulation.
#
# -DSIM enables DV-only hooks in RTL (e.g., event-detector sample overrides)
# without changing the regmap.
IVERILOG_FLAGS ?= -g2012 -Wall -DSIM

RTL_DIR := ../rtl

TB      := wb_tb.v
OUT     := wb_tb.out

TOP_TB  := top_tb.v
TOP_OUT := top_tb.out

FIFO_TB  := adc_stream_fifo_tb.v
FIFO_OUT := adc_stream_fifo_tb.out

DRDY_TB  := adc_drdy_sync_tb.v
DRDY_OUT := adc_drdy_sync_tb.out

SPI_TB   := adc_spi_frame_capture_tb.v
SPI_OUT  := adc_spi_frame_capture_tb.out

EVT_TB   := event_detector_tb.v
EVT_OUT  := event_detector_tb.out

F2F_TB   := adc_frame_to_fifo_tb.v
F2F_OUT  := adc_frame_to_fifo_tb.out

PIPE_TB  := adc_stream_pipe_tb.v
PIPE_OUT := adc_stream_pipe_tb.out

.PHONY: all sim top-sim fifo-sim drdy-sim spi-sim evt-sim f2f-sim pipe-sim regmap-check regmap-gen regmap-gen-check regmap-sv-gen regmap-sv-gen-check \
	regmap-vh-gen regmap-vh-gen-check clean

# One command to run the whole smoke suite (what humans should run locally).
all: regmap-check regmap-gen-check sim top-sim fifo-sim drdy-sim spi-sim evt-sim f2f-sim pipe-sim

sim: $(OUT)
	$(VVP) $(OUT)

top-sim: $(TOP_OUT)
	$(VVP) $(TOP_OUT)

fifo-sim: $(FIFO_OUT)
	$(VVP) $(FIFO_OUT)

drdy-sim: $(DRDY_OUT)
	$(VVP) $(DRDY_OUT)

spi-sim: $(SPI_OUT)
	$(VVP) $(SPI_OUT)

evt-sim: $(EVT_OUT)
	$(VVP) $(EVT_OUT)

f2f-sim: $(F2F_OUT)
	$(VVP) $(F2F_OUT)

pipe-sim: $(PIPE_OUT)
	$(VVP) $(PIPE_OUT)

# Pure-Python consistency check (no Verilog simulator required).
regmap-check:
	python3 ../tools/regmap/check_regmap.py --yaml ../spec/regmap_v1.yaml --rtl ../rtl/home_inventory_wb.v

# Validate YAML + (re)generate derived artifacts from YAML.
regmap-gen:
	python3 ../ops/regmap_validate.py --yaml ../spec/regmap_v1.yaml
	python3 ../ops/gen_regmap_header.py --yaml ../spec/regmap_v1.yaml --out ../fw/include/home_inventory_regmap.h
	python3 ../ops/gen_regmap_sv_pkg.py --yaml ../spec/regmap_v1.yaml --out ../rtl/include/home_inventory_regmap_pkg.sv
	python3 ../tools/regmap/gen_verilog_params.py --yaml ../spec/regmap_v1.yaml --out ../rtl/include/regmap_params.vh

# Assert that the committed generated artifacts are up-to-date.
#
# This target is what CI should run to ensure contributors didn't forget to
# re-run generation after editing spec/regmap_v1.yaml.
regmap-gen-check:
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../ops/gen_regmap_header.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../fw/include/home_inventory_regmap.h; \
	rm -f $$TMP; \
	echo "OK: generated C header matches spec/regmap_v1.yaml"'
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../ops/gen_regmap_sv_pkg.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../rtl/include/home_inventory_regmap_pkg.sv; \
	rm -f $$TMP; \
	echo "OK: generated SV package matches spec/regmap_v1.yaml"'
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../tools/regmap/gen_verilog_params.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../rtl/include/regmap_params.vh; \
	rm -f $$TMP; \
	echo "OK: generated Verilog include matches spec/regmap_v1.yaml"'

# (Re)generate the SV package (RTL/DV constants) from YAML.
regmap-sv-gen:
	python3 ../ops/gen_regmap_sv_pkg.py --yaml ../spec/regmap_v1.yaml --out ../rtl/include/home_inventory_regmap_pkg.sv

# Assert that the committed generated SV package is up-to-date.
regmap-sv-gen-check:
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../ops/gen_regmap_sv_pkg.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../rtl/include/home_inventory_regmap_pkg.sv; \
	rm -f $$TMP; \
	echo "OK: generated SV package matches spec/regmap_v1.yaml"'

# (Re)generate the Verilog include with ADR_* localparams from YAML.
regmap-vh-gen:
	python3 ../tools/regmap/gen_verilog_params.py --yaml ../spec/regmap_v1.yaml --out ../rtl/include/regmap_params.vh

# Assert that the committed generated Verilog include is up-to-date.
regmap-vh-gen-check:
	@bash -c 'set -euo pipefail; \
	TMP=$$(mktemp); \
	python3 ../tools/regmap/gen_verilog_params.py --yaml ../spec/regmap_v1.yaml --out $$TMP; \
	diff -u $$TMP ../rtl/include/regmap_params.vh; \
	rm -f $$TMP; \
	echo "OK: generated Verilog params include matches spec/regmap_v1.yaml"'

$(OUT): $(TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(TOP_OUT): $(TOP_TB) $(RTL_DIR)/home_inventory_top.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(FIFO_OUT): $(FIFO_TB) $(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(DRDY_OUT): $(DRDY_TB) $(RTL_DIR)/adc/adc_drdy_sync.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(SPI_OUT): $(SPI_TB) $(RTL_DIR)/adc/adc_spi_frame_capture.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(EVT_OUT): $(EVT_TB) $(RTL_DIR)/home_inventory_event_detector.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(F2F_OUT): $(F2F_TB) $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(PIPE_OUT): $(PIPE_TB) $(RTL_DIR)/adc/adc_frame_to_fifo.v $(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

clean:
	rm -f $(OUT) $(TOP_OUT) $(FIFO_OUT) $(DRDY_OUT) $(SPI_OUT) $(EVT_OUT) $(F2F_OUT) $(PIPE_OUT)
