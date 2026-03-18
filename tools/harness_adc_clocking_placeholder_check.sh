#!/usr/bin/env bash
set -euo pipefail

# Fail-fast check: ensure the harness repo has *concrete* ADC CLKIN evidence,
# not just a placeholder "io[??]" plan.
#
# This is intentionally grep-based (low disk, no toolchain required).
#
# Usage:
#   tools/harness_adc_clocking_placeholder_check.sh [PATH_TO_HARNESS_REPO]
#
# Pass criteria (any ONE of these is acceptable):
#   A) We find an explicit io[*] mapping for adc_clkin/CLKIN (evidence of routing), OR
#   B) We find explicit documentation that the board provides an oscillator into CLKIN
#      (and the oscillator frequency is stated).
#
# If neither is found, exit non-zero and explain what to fix.

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_clocking_placeholder_check.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

cd "$HARNESS_REPO"

# Keep the search small and readable.
SEARCH_DIRS=(docs verilog rtl src openlane)
ACTIVE_DIRS=()
for d in "${SEARCH_DIRS[@]}"; do
  [[ -d "$d" ]] && ACTIVE_DIRS+=("$d")
done
[[ "${#ACTIVE_DIRS[@]}" -eq 0 ]] && ACTIVE_DIRS=(.)

RG_EXCLUDES=(
  "--glob" "!**/*.spice"
  "--glob" "!**/*.mag"
  "--glob" "!**/*.gds"
  "--glob" "!**/*.lef"
  "--glob" "!**/lvs/**"
)

have_io_mapping=0
have_board_oscillator=0
have_frequency=0

# (A) Look for hard io[*] mapping evidence near adc_clkin/CLKIN.
if rg -n "${RG_EXCLUDES[@]}" -S -i "(adc[_-]?clkin|ADC_CLKIN|\\bCLKIN\\b)[^\n]{0,160}io\\[[0-9]+\\]" "${ACTIVE_DIRS[@]}" >/dev/null 2>&1; then
  have_io_mapping=1
fi
if rg -n "${RG_EXCLUDES[@]}" -S -i "io\\[[0-9]+\\][^\n]{0,160}(adc[_-]?clkin|ADC_CLKIN|\\bCLKIN\\b)" "${ACTIVE_DIRS[@]}" >/dev/null 2>&1; then
  have_io_mapping=1
fi

# (B) Look for explicit statement that the board provides an oscillator into CLKIN.
# We accept various phrasings; the key is that CLKIN is sourced externally.
if rg -n "${RG_EXCLUDES[@]}" -S -i "(board|pcb|harness).{0,40}(oscillator|xtal|crystal).{0,80}\\bCLKIN\\b" "${ACTIVE_DIRS[@]}" >/dev/null 2>&1; then
  have_board_oscillator=1
fi
if rg -n "${RG_EXCLUDES[@]}" -S -i "(oscillator|xtal|crystal).{0,80}\\bCLKIN\\b" "${ACTIVE_DIRS[@]}" >/dev/null 2>&1; then
  have_board_oscillator=1
fi

# Frequency must be stated somewhere near CLKIN/adc_clkin (MHz/kHz/Hz).
if rg -n "${RG_EXCLUDES[@]}" -S -i "(adc[_-]?clkin|\\bCLKIN\\b)[^\n]{0,120}([0-9]+\\s*(mhz|khz|hz))" "${ACTIVE_DIRS[@]}" >/dev/null 2>&1; then
  have_frequency=1
fi

if [[ "$have_io_mapping" -eq 1 ]]; then
  echo "PASS: Found explicit io[*] mapping evidence for adc_clkin/CLKIN in harness repo."
  exit 0
fi

if [[ "$have_board_oscillator" -eq 1 && "$have_frequency" -eq 1 ]]; then
  echo "PASS: Found board-oscillator-into-CLKIN statement AND explicit frequency evidence in harness repo."
  exit 0
fi

cat <<EOF >&2
FAIL: ADC CLKIN is still effectively a placeholder in the harness repo.

What this check expects (any one is OK):
  A) Explicit io[*] mapping evidence for adc_clkin/CLKIN (routing locked), OR
  B) Explicit statement that the board/harness provides an oscillator into CLKIN
     AND the oscillator frequency is written down (e.g. "2.048 MHz").

What to do next:
  1) Decide: Option A (board oscillator into CLKIN) vs Option B (SoC drives adc_clkin).
  2) Record the evidence + frequency in the harness docs (recommended: docs/source/adc_clocking_plan.md).
  3) If Option B: also lock the exact io[*] index for adc_clkin routing.

Helpful command:
  tools/harness_adc_clocking_audit.sh "$HARNESS_REPO"
EOF
exit 1
