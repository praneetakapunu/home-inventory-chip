# Simulation / DV Toolchain Notes (v1)

This repo keeps DV intentionally lightweight so it can run in CI and on a fresh VM.

## What we run today
- **Fast, no-sim check:** `make -C verify regmap-check`
  - Pure Python, checks `spec/regmap_v1.yaml` vs `rtl/home_inventory_wb.v` ADR_* constants.
- **Minimal RTL smoke sim:** `make -C verify sim`
  - Builds and runs `verify/wb_tb.v` against `rtl/home_inventory_wb.v`.
  - Default simulator: **iverilog + vvp**.

## Local setup (Ubuntu/Debian)
```bash
sudo apt-get update
sudo apt-get install -y iverilog

# quick sanity:
make -C verify regmap-check
make -C verify sim
```

## CI
GitHub Actions workflow: `.github/workflows/verify-sim.yml`
- Installs iverilog via apt.
- Runs `make -C verify sim`.

## If iverilog is not available
Use the regmap check as the minimum guardrail:
```bash
make -C verify regmap-check
```

If we later move to **verilator** or cocotb, add it as a parallel workflow rather than replacing the simple smoke tests.
