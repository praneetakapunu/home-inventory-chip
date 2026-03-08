# Verification

## Goal
Have a repeatable simulation/regression loop early.

## Smoke test (Wishbone regfile + top)
A minimal iverilog-based smoke suite exists for:
- the Wishbone register block,
- the SoC top wrapper (`rtl/home_inventory_top.v`), and
- the ADC streaming submodules.

Prereq (Ubuntu/Debian):

```sh
sudo apt-get update && sudo apt-get install -y iverilog
```

Run:

```sh
# See available targets
make -C verify help

# One command (recommended)
make -C verify all

# Low-disk / fast preflight (good for frequent local checks)
# - regmap consistency
# - wb + top compile/run
make -C verify regmap-check regmap-gen-check sim top-sim

# Or run step-by-step:
# 1) Regmap drift checks (no simulator needed)
make -C verify regmap-check

# 2) Assert generated FW header matches the YAML
make -C verify regmap-gen-check

# 3) Wishbone smoke test (requires iverilog)
make -C verify sim

# 4) ADC stream FIFO directed test (requires iverilog)
make -C verify fifo-sim

# 5) DRDY synchronizer falling-edge pulse test (requires iverilog)
make -C verify drdy-sim

# 6) SPI frame-capture directed test (requires iverilog)
make -C verify spi-sim

# 7) Event detector directed test (requires iverilog)
make -C verify evt-sim
```

Notes:
- Most targets produce a local `verify/*.out` executable and run it via `vvp`.
- Use `make -C verify clean` to remove generated `*.out` and `*.vcd` artifacts.

This checks:
- ID + VERSION reads
- STATUS passthrough
- CTRL.ENABLE sticky bit + CTRL.START readback=0
- CTRL.START write-1-to-pulse semantics
- IRQ_EN write path + byte strobes
- ADC_CFG reset + NUM_CH RW behavior
- ADC_CMD readback=0 (W1P-style)
- ADC FIFO: snapshot push behavior (9 words per frame), ordering, level decrement, sticky OVERRUN + W1C clear, and empty-read returns 0
- Calibration reset values + byte strobe behavior
- RO regs ignore writes (events block)
- Event detector: threshold compare, per-channel enable edge semantics (first delta=0), multi-channel last_ts, and saturating counters

## Next
- Add negative tests for bad byte-strobes / reserved-bit masking.
- Add deeper FIFO stress (wraparound) once FIFO depth becomes configurable.
- Consider switching to Verilator for faster regression once core RTL grows.
