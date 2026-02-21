# Verification

## Goal
Have a repeatable simulation/regression loop early.

## Smoke test (Wishbone regfile)
A minimal iverilog-based smoke test exists for the Wishbone register block.

Prereq (Ubuntu/Debian):

```sh
sudo apt-get update && sudo apt-get install -y iverilog
```

Run:

```sh
# One command (recommended)
make -C verify all

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
```

This checks:
- ID + VERSION reads
- STATUS passthrough
- CTRL.ENABLE sticky bit + CTRL.START readback=0
- CTRL.START write-1-to-pulse semantics
- IRQ_EN write path + byte strobes
- ADC_CFG reset + NUM_CH RW behavior
- ADC_CMD readback=0 (W1P-style)
- Calibration reset values + byte strobe behavior
- RO regs ignore writes (events block)

## Next
- Add negative tests for bad byte-strobes / reserved-bit masking.
- Add deeper FIFO stress (wraparound) once FIFO depth becomes configurable.
- Consider switching to Verilator for faster regression once core RTL grows.
