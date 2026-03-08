#!/usr/bin/env bash
set -euo pipefail

# Quick, low-disk helper to locate ADC clocking references in the harness repo.
# Usage:
#   tools/harness_adc_clocking_audit.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_clocking_audit.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Harness repo: $(pwd)"

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

# These terms are intentionally broad: we want to find *any* hint of how CLKIN is sourced or routed.
TERMS=(
  "adc_clkin"
  "ADC_CLKIN"
  "CLKIN"
  "ads131"
  "ADS131"
)

for t in "${TERMS[@]}"; do
  echo
  echo "--- rg -n \"$t\" (docs/verilog/caravel/spi) ---"
  rg -n "$t" docs verilog caravel spi 2>/dev/null || true
done

echo
cat <<'EOF'

Next steps (manual, but fast):
1) If you see an explicit net/pad mapping for adc_clkin/CLKIN:
   - record the exact io[*] index (or net name) in chip-inventory/docs/ADC_CLOCKING_PLAN.md
   - lock the expected frequency source (oscillator part# or SoC clock output)
2) If you see *no* CLKIN routing:
   - assume the board must provide an oscillator into CLKIN (Option A)
   - add that as a tapeout requirement + blocker if not guaranteed
EOF
