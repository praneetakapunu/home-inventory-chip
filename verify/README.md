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
- CTRL.ENABLE sticky bit
- CTRL.START write-1-to-pulse semantics
- IRQ_EN write path

## Next
- Add a small set of directed tests for ADC + calibration register behaviors.
- Consider switching to Verilator for faster regression once core RTL grows.
