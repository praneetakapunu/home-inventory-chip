#!/usr/bin/env bash
set -euo pipefail

# Fail-fast helper: detect if the harness repo still has placeholder ADC io[*]
# indices (0..5) in home_inventory_user_project.v.
#
# Why: the harness currently defines ADC_*_IO parameters with default values.
# Those defaults are *not* a real pinout and must be replaced/overridden before
# tapeout.
#
# Usage:
#   tools/harness_adc_pinout_placeholder_check.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"
FILE_REL="verilog/rtl/home_inventory_user_project.v"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  exit 2
fi

FILE="$HARNESS_REPO/$FILE_REL"
if [[ ! -f "$FILE" ]]; then
  echo "ERROR: expected harness file not found: $FILE" >&2
  exit 2
fi

echo "== Checking harness ADC pinout placeholders =="
echo "Harness: $HARNESS_REPO"
echo "File:    $FILE_REL"

a=0
check() {
  local name="$1" expected="$2"
  if rg -n "parameter[[:space:]]+integer[[:space:]]+${name}[[:space:]]*=[[:space:]]*${expected}[[:space:]]*;" "$FILE" >/dev/null; then
    echo "PLACEHOLDER: ${name} is still set to ${expected}" >&2
    a=1
  fi
}

check ADC_SCLK_IO 0
check ADC_CSN_IO  1
check ADC_MOSI_IO 2
check ADC_MISO_IO 3
check ADC_DRDYN_IO 4
check ADC_RSTN_IO 5

if [[ "$a" -ne 0 ]]; then
  cat <<'EOF' >&2

Action required:
- Lock real io[*] indices (or named pads) for adc_* signals.
- Update the harness wrapper (or override parameters centrally).
- Record the final mapping in chip-inventory/docs/ADC_PINOUT_CONTRACT.md.

This is a tapeout blocker until resolved.
EOF
  exit 1
fi

echo "OK: no default placeholder ADC io[*] indices detected."
