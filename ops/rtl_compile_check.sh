#!/usr/bin/env bash
set -euo pipefail

# Fast, tool-light sanity check: ensure the RTL filelist compiles and elaborates.
# This is intended to be runnable in CI and locally without OpenLane.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

if ! command -v iverilog >/dev/null 2>&1; then
  echo "ERROR: iverilog not found. Install iverilog to run this check." >&2
  exit 2
fi

OUT=${OUT:-/tmp/home_inventory_rtl.out}

# Compile/elaborate the default (stub ADC) configuration.
iverilog -g2012 -Wall -Irtl -o "${OUT}" \
  -s home_inventory_top \
  -f rtl/ip_home_inventory.f

echo "OK: RTL compiles + elaborates (stub ADC). Output: ${OUT}"

# Compile/elaborate the real ADC ingest configuration (still tool-light).
# This catches accidental breakage in the optional ADC wiring early.
OUT_REAL="${OUT%.out}.real_adc.out"
iverilog -g2012 -Wall -Irtl -DUSE_REAL_ADC_INGEST -o "${OUT_REAL}" \
  -s home_inventory_top \
  -f rtl/ip_home_inventory.f

echo "OK: RTL compiles + elaborates (USE_REAL_ADC_INGEST). Output: ${OUT_REAL}"
