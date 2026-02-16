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
make -C verify sim
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
- Add coverage for all ADC_RAW_CHx + all calibration channels (CH0..CH7).
- Add a tiny CI job (or local script) that runs this smoke test automatically.
- Consider switching to Verilator for faster regression once core RTL grows.
