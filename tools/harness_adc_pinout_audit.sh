#!/usr/bin/env bash
set -euo pipefail

# Quick, low-disk helper to audit whether the harness repo:
#  - exposes the optional ADC interface pins under USE_REAL_ADC_INGEST
#    (SPI: adc_sclk/cs_n/mosi/miso, plus drdy/reset/optional clkin)
#  - maps those pins to specific Caravel io[*] indices (or at least names the nets)
#  - has a compile-time path that defines USE_REAL_ADC_INGEST (Makefile target, etc.)
#
# Usage:
#   tools/harness_adc_pinout_audit.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_pinout_audit.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Harness repo: $(pwd)"

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

# Directories that are likely to contain wrapper wiring + docs.
SEARCH_DIRS=(
  docs
  verilog
)

# Keep the script fast/readable by skipping huge LVS spice trees.
RG_EXCLUDES=(
  "--glob" "!**/*.spice"
  "--glob" "!**/lvs/**"
)

TERMS=(
  "USE_REAL_ADC_INGEST"
  "adc_sclk"
  "adc_cs_n"
  "adc_mosi"
  "adc_miso"
  "adc_drdy"
  "adc_drdy_n"
  "adc_rst_n"
  "adc_clkin"
  # Common Caravel wrapper naming.
  "user_project_wrapper"
  "user_project"
  "io_in"
  "io_out"
  "io_oeb"
)

for t in "${TERMS[@]}"; do
  echo
  echo "--- rg -n \"$t\" (${SEARCH_DIRS[*]}) ---"
  rg -n "${RG_EXCLUDES[@]}" "$t" "${SEARCH_DIRS[@]}" 2>/dev/null || true
done

echo
cat <<'EOF'

What to conclude from the output:

1) If you see adc_* nets in verilog wrappers (home_inventory_user_project/user_project_wrapper):
   - Great: port-list drift is unlikely.

2) If you also see explicit io[*] indices (or named pads) connected to adc_* (including drdy/reset/clkin):
   - Record the exact mapping in chip-inventory/docs/ADC_PINOUT_CONTRACT.md.
   - If drdy appears as adc_drdy_n vs adc_drdy, also record the polarity assumption explicitly.

3) If adc_* is ONLY mentioned in docs (not in verilog):
   - Expect harness compile to fail under -DUSE_REAL_ADC_INGEST.
   - Fix by adding conditional ports/wiring in the wrapper modules.

4) If USE_REAL_ADC_INGEST never appears:
   - The harness probably lacks a dedicated compile target.
   - Add/verify a make target analogous to "rtl-compile-check-real-adc".
EOF
