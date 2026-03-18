#!/usr/bin/env bash
set -euo pipefail

# Fail-fast helper: detect if the harness repo *still lacks* any explicit
# wiring/compile surface for the real ADC ingest path (USE_REAL_ADC_INGEST).
#
# Why: we keep a bring-up SNAPSHOT/stub path around, but tapeout prep needs an
# intentional, testable knob that compiles the "real ingest" wiring.
#
# Usage:
#   tools/harness_adc_streaming_placeholder_check.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Checking harness ADC streaming compile surface =="
echo "Harness: $(pwd)"

# Heuristic expectations (keep light: grep only).
# 1) A make target that enables the real-ingest define.
if rg -n "^rtl-compile-check-real-adc:" Makefile* >/dev/null 2>&1; then
  echo "OK: Found make target: rtl-compile-check-real-adc"
else
  echo "MISSING: Make target rtl-compile-check-real-adc" >&2
  echo "  Expected a target that enables -DUSE_REAL_ADC_INGEST and runs a compile sanity check." >&2
  exit 1
fi

# 2) Some mention of the define in build scripts / makefiles.
#    (If this is missing, it likely means the target doesn't actually plumb the define.)
if rg -n "USE_REAL_ADC_INGEST" Makefile* verilog scripts .github 2>/dev/null | head -n 5 | rg -q .; then
  echo "OK: Found references to USE_REAL_ADC_INGEST"
else
  echo "MISSING: No references to USE_REAL_ADC_INGEST found in common harness locations" >&2
  echo "  Expected build scripts to pass -DUSE_REAL_ADC_INGEST under rtl-compile-check-real-adc." >&2
  exit 1
fi

echo "OK: harness appears to have a real-ingest compile surface (non-placeholder)."
