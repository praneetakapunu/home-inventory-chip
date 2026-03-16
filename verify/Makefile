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

REAL_ADC_TB  := real_adc_compile_tb.v
REAL_ADC_OUT := real_adc_compile_tb.out

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

INGEST_TB  := adc_streaming_ingest_tb.v
INGEST_OUT := adc_streaming_ingest_tb.out

OVERRUN_TB  := adc_stream_overrun_tb.v
OVERRUN_OUT := adc_stream_overrun_tb.out

UNPACK_TB  := adc_soc_frame_unpack_tb.v
UNPACK_OUT := adc_soc_frame_unpack_tb.out

WB_ADC_OVERRIDE_TB  := wb_adc_fifo_override_tb.v
WB_ADC_OVERRIDE_OUT := wb_adc_fifo_override_tb.out

WB_ADC_SNAPSHOT_FRAME_TB  := wb_adc_snapshot_frame_tb.v
WB_ADC_SNAPSHOT_FRAME_OUT := wb_adc_snapshot_frame_tb.out

WB_REAL_ADC_SMOKE_TB  := wb_real_adc_ingest_smoke_tb.v
WB_REAL_ADC_SMOKE_OUT := wb_real_adc_ingest_smoke_tb.out

WB_EVT_CFG_SELMASK_TB  := wb_evt_cfg_selmask_tb.v
WB_EVT_CFG_SELMASK_OUT := wb_evt_cfg_selmask_tb.out

WB_EVT_INTEGRATION_TB  := wb_evt_integration_tb.v
WB_EVT_INTEGRATION_OUT := wb_evt_integration_tb.out

WB_TIME_NOW_TB  := wb_time_now_tb.v
WB_TIME_NOW_OUT := wb_time_now_tb.out

.PHONY: help all sim top-sim real-adc-sim wb-real-adc-smoke-sim wb-evt-cfg-selmask-sim wb-evt-integration-sim wb-time-now-sim fifo-sim drdy-sim spi-sim evt-sim f2f-sim pipe-sim ingest-sim overrun-sim unpack-sim wb-adc-override-sim wb-adc-snapshot-frame-sim \
	rtl-compile-check regmap-check regmap-gen regmap-gen-check regmap-sv-gen regmap-sv-gen-check \
	regmap-vh-gen regmap-vh-gen-check clean

help:
	@echo "Targets:" \
	 && echo "  make -C verify all                 # full smoke suite (recommended)" \
	 && echo "  make -C verify regmap-check        # YAML ↔ RTL consistency" \
	 && echo "  make -C verify regmap-gen-check    # generated artifacts up-to-date" \
	 && echo "  make -C verify rtl-compile-check   # compile full IP filelist" \
	 && echo "  make -C verify sim                 # wb_tb" \
	 && echo "  make -C verify top-sim             # top_tb" \
	 && echo "  make -C verify real-adc-sim        # compiles with USE_REAL_ADC_INGEST" \
	 && echo "  make -C verify wb-real-adc-smoke-sim # wb + real ADC ingest FIFO pop semantics" \
	 && echo "  make -C verify wb-evt-cfg-selmask-sim # verify EVT_CFG W1P bits are byte-lane masked" \
	 && echo "  make -C verify wb-evt-integration-sim # wb programming + SIM injection for event detector" \
	 && echo "  make -C verify wb-time-now-sim      # verify TIME_NOW free-running counter" \
	 && echo "  make -C verify fifo-sim            # adc_stream_fifo_tb" \
	 && echo "  make -C verify drdy-sim            # adc_drdy_sync_tb" \
	 && echo "  make -C verify spi-sim             # adc_spi_frame_capture_tb" \
	 && echo "  make -C verify evt-sim             # event_detector_tb" \
	 && echo "  make -C verify f2f-sim             # adc_frame_to_fifo_tb" \
	 && echo "  make -C verify pipe-sim            # adc_stream_pipe_tb" \
	 && echo "  make -C verify ingest-sim          # adc_streaming_ingest_tb" \
	 && echo "  make -C verify overrun-sim         # adc_stream_overrun_tb" \
	 && echo "  make -C verify unpack-sim          # adc_soc_frame_unpack_tb" \
	 && echo "  make -C verify wb-adc-override-sim # wb_adc_fifo_override_tb" \
	 && echo "  make -C verify wb-adc-snapshot-frame-sim # SNAPSHOT -> FIFO -> pop (contract/order)" \
	 && echo "  make -C verify clean"

# One command to run the whole smoke suite (what humans should run locally).
all: regmap-check regmap-gen-check rtl-compile-check sim top-sim real-adc-sim wb-real-adc-smoke-sim wb-evt-cfg-selmask-sim wb-evt-integration-sim wb-time-now-sim fifo-sim drdy-sim spi-sim evt-sim f2f-sim pipe-sim ingest-sim overrun-sim unpack-sim wb-adc-override-sim wb-adc-snapshot-frame-sim

# Compile full RTL filelist (no simulation). This is a closer approximation of
# the harness compile-check than the per-testbench compile steps.
rtl-compile-check:
	bash ../ops/rtl_compile_check.sh

sim: $(OUT)
	$(VVP) $(OUT)

top-sim: $(TOP_OUT)
	$(VVP) $(TOP_OUT)

real-adc-sim: $(REAL_ADC_OUT)
	$(VVP) $(REAL_ADC_OUT)

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

ingest-sim: $(INGEST_OUT)
	$(VVP) $(INGEST_OUT)

overrun-sim: $(OVERRUN_OUT)
	$(VVP) $(OVERRUN_OUT)

unpack-sim: $(UNPACK_OUT)
	$(VVP) $(UNPACK_OUT)

wb-adc-override-sim: $(WB_ADC_OVERRIDE_OUT)
	$(VVP) $(WB_ADC_OVERRIDE_OUT)

wb-adc-snapshot-frame-sim: $(WB_ADC_SNAPSHOT_FRAME_OUT)
	$(VVP) $(WB_ADC_SNAPSHOT_FRAME_OUT)

wb-real-adc-smoke-sim: $(WB_REAL_ADC_SMOKE_OUT)
	$(VVP) $(WB_REAL_ADC_SMOKE_OUT)

wb-evt-cfg-selmask-sim: $(WB_EVT_CFG_SELMASK_OUT)
	$(VVP) $(WB_EVT_CFG_SELMASK_OUT)

wb-evt-integration-sim: $(WB_EVT_INTEGRATION_OUT)
	$(VVP) $(WB_EVT_INTEGRATION_OUT)

wb-time-now-sim: $(WB_TIME_NOW_OUT)
	$(VVP) $(WB_TIME_NOW_OUT)

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

$(WB_EVT_CFG_SELMASK_OUT): $(WB_EVT_CFG_SELMASK_TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -o $(WB_EVT_CFG_SELMASK_OUT) \
		-I$(RTL_DIR) -I$(RTL_DIR)/include \
		$(WB_EVT_CFG_SELMASK_TB) \
		$(RTL_DIR)/home_inventory_wb.v \
		$(RTL_DIR)/home_inventory_event_detector.v \
		$(RTL_DIR)/adc/adc_stream_fifo.v \
		$(RTL_DIR)/adc/adc_frame_to_fifo.v

$(WB_EVT_INTEGRATION_OUT): $(WB_EVT_INTEGRATION_TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(WB_TIME_NOW_OUT): $(WB_TIME_NOW_TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(TOP_OUT): $(TOP_TB) \
	$(RTL_DIR)/home_inventory_top.v \
	$(RTL_DIR)/home_inventory_wb.v \
	$(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v \
	$(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(REAL_ADC_OUT): $(REAL_ADC_TB) \
	$(RTL_DIR)/home_inventory_top.v \
	$(RTL_DIR)/home_inventory_wb.v \
	$(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_streaming_ingest.v \
	$(RTL_DIR)/adc/adc_spi_frame_capture.v \
	$(RTL_DIR)/adc/adc_soc_frame_unpack.v \
	$(RTL_DIR)/adc/adc_frame_to_fifo.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -DUSE_REAL_ADC_INGEST -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

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

$(INGEST_OUT): $(INGEST_TB) \
	$(RTL_DIR)/adc/adc_streaming_ingest.v \
	$(RTL_DIR)/adc/adc_spi_frame_capture.v \
	$(RTL_DIR)/adc/adc_frame_to_fifo.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(OVERRUN_OUT): $(OVERRUN_TB) $(RTL_DIR)/adc/adc_frame_to_fifo.v $(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(UNPACK_OUT): $(UNPACK_TB) $(RTL_DIR)/adc/adc_soc_frame_unpack.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(WB_ADC_OVERRIDE_OUT): $(WB_ADC_OVERRIDE_TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(WB_ADC_SNAPSHOT_FRAME_OUT): $(WB_ADC_SNAPSHOT_FRAME_TB) $(RTL_DIR)/home_inventory_wb.v $(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v $(RTL_DIR)/adc/adc_frame_to_fifo.v $(RTL_DIR)/adc/adc_soc_frame_unpack.v
	$(IVERILOG) $(IVERILOG_FLAGS) -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

$(WB_REAL_ADC_SMOKE_OUT): $(WB_REAL_ADC_SMOKE_TB) \
	$(RTL_DIR)/home_inventory_wb.v \
	$(RTL_DIR)/home_inventory_event_detector.v \
	$(RTL_DIR)/adc/adc_streaming_ingest.v \
	$(RTL_DIR)/adc/adc_spi_frame_capture.v \
	$(RTL_DIR)/adc/adc_soc_frame_unpack.v \
	$(RTL_DIR)/adc/adc_frame_to_fifo.v \
	$(RTL_DIR)/adc/adc_stream_fifo.v
	$(IVERILOG) $(IVERILOG_FLAGS) -DUSE_REAL_ADC_INGEST -I$(RTL_DIR) -I$(RTL_DIR)/include -o $@ $^

clean:
	rm -f $(OUT) $(TOP_OUT) $(REAL_ADC_OUT) $(WB_REAL_ADC_SMOKE_OUT) $(FIFO_OUT) $(DRDY_OUT) $(SPI_OUT) $(EVT_OUT) $(F2F_OUT) $(PIPE_OUT) $(INGEST_OUT) $(OVERRUN_OUT) $(UNPACK_OUT) $(WB_ADC_OVERRIDE_OUT) $(WB_ADC_SNAPSHOT_FRAME_OUT)
	rm -f *.vcd *.fst *.log *.dump
