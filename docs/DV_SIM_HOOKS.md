# DV / Simulation Hooks (SIM-only)

This repo intentionally exposes a couple of **SIM-only** override signals inside
`rtl/home_inventory_wb.v` to make directed tests deterministic.

These hooks are:
- **Only compiled when `SIM` is defined**
- Marked `(* keep *)` so they survive common optimizations
- Intended to be driven via **hierarchical `force`/`release`** from the testbench

They are *not* part of the tapeout interface and should remain internal.

## 1) ADC FIFO push override (inject FIFO stream)

Purpose: allow DV to inject ADC FIFO words directly (corner cases, overrun,
long streams) without modifying the regmap or adding top-level ports.

Defined in: `rtl/home_inventory_wb.v` under `SIM`.

Signals (hierarchical under the DUT):
- `sim_adc_fifo_override_en` (1 = select sim push path)
- `sim_adc_fifo_push_valid` (1-cycle push strobe)
- `sim_adc_fifo_push_data[31:0]` (word to push)

Effect:
- When `sim_adc_fifo_override_en==1`, the internal `adc_fifo_push_*` wires are
  driven from the sim signals instead of the SNAPSHOT stub generator.

Example (from a testbench):

```verilog
// Enable the override
force dut.sim_adc_fifo_override_en = 1'b1;

// Push one word
force dut.sim_adc_fifo_push_data  = 32'hDEADBEEF;
force dut.sim_adc_fifo_push_valid = 1'b1;
@(posedge wb_clk);
force dut.sim_adc_fifo_push_valid = 1'b0;

// Done
release dut.sim_adc_fifo_push_valid;
release dut.sim_adc_fifo_push_data;
release dut.sim_adc_fifo_override_en;
```

## 2) Event detector sample override (inject sample vector)

Purpose: allow DV to drive the event detector sample vector deterministically
without needing real ADC ingest wiring.

Defined in: `rtl/home_inventory_wb.v` under `SIM`.

Signals:
- `sim_evt_override_en` (1 = select sim sample path)
- `sim_evt_sample_valid` (1-cycle strobe)
- `sim_evt_sample_ch0..ch7[31:0]` (per-channel sample words)

Effect:
- When `sim_evt_override_en==1`, the event detector sees `sim_evt_sample_*`
  instead of the current stub sample source.

Example:

```verilog
force dut.sim_evt_override_en  = 1'b1;
force dut.sim_evt_sample_ch0   = 32'd123;
force dut.sim_evt_sample_valid = 1'b1;
@(posedge wb_clk);
force dut.sim_evt_sample_valid = 1'b0;
release dut.sim_evt_sample_valid;
release dut.sim_evt_sample_ch0;
release dut.sim_evt_override_en;
```

## References
- Concrete examples:
  - `verify/wb_adc_fifo_override_tb.v`
  - `verify/wb_evt_integration_tb.v`
- Preflight entrypoint:
  - `bash ops/preflight_low_disk.sh`
