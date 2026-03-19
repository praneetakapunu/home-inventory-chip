#!/usr/bin/env bash
set -euo pipefail

# Fail-fast helper: ensure the harness repo uses an unambiguous active-low DRDY
# net name (`adc_drdy_n`) and that it is sourced from the declared pad index.
#
# Why:
# - ADS131M08 DRDY is active-low.
# - If the harness uses a non-suffixed name (adc_drdy), polarity becomes easy
#   to misread during late integration.
# - This script is intentionally lightweight (grep-based) and safe to run in CI.
#
# Usage:
#   tools/harness_adc_drdy_placeholder_check.sh [PATH_TO_HARNESS_REPO]
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

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

echo "== Checking harness ADC DRDY naming/polarity contract =="
echo "Harness: $HARNESS_REPO"
echo "File:    $FILE_REL"

fail=0

need() {
  local pattern="$1" msg="$2"
  if ! rg -n "$pattern" "$FILE" >/dev/null 2>&1; then
    echo "MISSING: $msg" >&2
    fail=1
  fi
}

forbid() {
  local pattern="$1" msg="$2"
  if rg -n "$pattern" "$FILE" >/dev/null 2>&1; then
    echo "FORBIDDEN: $msg" >&2
    rg -n "$pattern" "$FILE" || true
    fail=1
  fi
}

# Require explicit active-low name.
need "\\bwire\\s+adc_drdy_n\\b" "declare 'wire adc_drdy_n'"
need "\\bassign\\s+adc_drdy_n\\s*=\\s*io_in\\[ADC_DRDYN_IO\\]" "drive adc_drdy_n from io_in[ADC_DRDYN_IO] when HOMEINV_ENABLE_ADC_GPIO"

# Forbid ambiguous non-suffixed naming in this wrapper.
forbid "\\bwire\\s+adc_drdy\\b" "do not declare ambiguous 'adc_drdy' net (use adc_drdy_n)"

if [[ "$fail" -ne 0 ]]; then
  cat <<'EOF' >&2

Action required:
- Make DRDY polarity explicit in the harness wrapper by using the active-low
  net name 'adc_drdy_n' (and document any inversion if present).
- Record the final intent in chip-inventory/docs/ADC_PINOUT_CONTRACT.md.

This is a risk-reduction check to prevent late-stage DRDY polarity mistakes.
EOF
  exit 1
fi

echo "OK: harness uses adc_drdy_n with explicit pad sourcing."
