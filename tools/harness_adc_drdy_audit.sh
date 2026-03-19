#!/usr/bin/env bash
set -euo pipefail

# Quick, low-disk helper to audit the harness repo for ADC DRDY naming/polarity.
#
# Why:
# - The ADS131M08 DRDY is *active-low*.
# - Our chip-inventory docs standardize on `adc_drdy_n` for clarity.
# - The harness may expose either `adc_drdy` or `adc_drdy_n`, and may (or may not)
#   invert the signal in wrapper wiring.
#
# This script does not enforce a single style; it prints the evidence you need
# to lock the polarity contract in chip-inventory/docs/ADC_PINOUT_CONTRACT.md.
#
# Usage:
#   tools/harness_adc_drdy_audit.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_drdy_audit.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Harness repo: $(pwd)"

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

SEARCH_DIRS=(docs verilog)
RG_EXCLUDES=(
  "--glob" "!**/*.spice"
  "--glob" "!**/lvs/**"
)

TERMS=(
  "adc_drdy"
  "adc_drdy_n"
  "ADC_DRDYN_IO"
  "DRDY"
  "drdy"
  "USE_REAL_ADC_INGEST"
)

for t in "${TERMS[@]}"; do
  echo
  echo "--- rg -n \"$t\" (${SEARCH_DIRS[*]}) ---"
  rg -n "${RG_EXCLUDES[@]}" "$t" "${SEARCH_DIRS[@]}" 2>/dev/null || true
done

echo
echo "== Heuristic: look for inversion (~ / !) on adc_drdy-like nets in verilog =="
rg -n "${RG_EXCLUDES[@]}" "(~|!)[[:space:]]*adc_drdy(_n)?" verilog 2>/dev/null || true

cat <<'EOF'

What to record after running this:

1) Which net name is used in the harness wrapper?
   - If `adc_drdy_n` appears: assume active-low (preferred).
   - If only `adc_drdy` appears: you MUST record whether it is active-low or
     active-high in chip-inventory/docs/ADC_PINOUT_CONTRACT.md.

2) Is there an explicit inversion in the wrapper wiring?
   - If the harness exposes `adc_drdy` but connects `~adc_drdy` into the IP as
     `adc_drdy_n`, that's fine (document it).
   - If there is no inversion and the name is ambiguous, treat it as unresolved.

3) Update the canonical pinout doc once confirmed:
   - chip-inventory/docs/ADC_PINOUT_CONTRACT.md

EOF
