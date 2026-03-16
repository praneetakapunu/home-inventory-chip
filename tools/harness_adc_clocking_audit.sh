#!/usr/bin/env bash
set -euo pipefail

# Quick, low-disk helper to locate ADC clocking references in the harness repo.
#
# Usage:
#   tools/harness_adc_clocking_audit.sh [PATH_TO_HARNESS_REPO]
#
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_clocking_audit.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "ERROR: ripgrep (rg) not found" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Harness repo: $(pwd)"
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "== Harness git HEAD: $(git rev-parse --short HEAD)"
  echo "== Harness git status: $(git status -sb | head -n 1)"
fi

# NOTE: Searching for the bare string "CLKIN" across the harness repo is extremely noisy
# (it matches many internal cell/net names, especially in LVS spice). Instead, we:
#   - prefer explicit signal names (adc_clkin, ADC_CLKIN)
#   - search for ADS131 references
#   - search for the word-boundary "CLKIN" only in doc/rtl-ish sources

# Candidate directories that are likely to contain pinout/clocking intent.
# We keep this limited on purpose (avoid large dumps like LVS/SPICE).
CANDIDATE_DIRS=(
  docs
  verilog
  rtl
  src
  openlane
)

SEARCH_DIRS=()
for d in "${CANDIDATE_DIRS[@]}"; do
  [[ -d "$d" ]] && SEARCH_DIRS+=("$d")
done

if [[ "${#SEARCH_DIRS[@]}" -eq 0 ]]; then
  echo "WARN: none of the expected source dirs exist (docs/verilog/rtl/src/openlane)." >&2
  echo "      Falling back to searching from repo root (still excluding spice/lvs)." >&2
  SEARCH_DIRS=(.)
fi

echo "== Search dirs: ${SEARCH_DIRS[*]}"

# Broad terms that are still high-signal.
TERMS=(
  # Explicit signal names / part identifiers
  "adc_clkin"
  "ADC_CLKIN"
  "adc-clkin"
  "ADS131"
  "ads131"
  "ADS131M08"
  "ads131m08"

  # Likely clock-source breadcrumbs (even before a pinout is finalized)
  "oscillator"
  "OSC"
  "xtal"
  "crystal"
  "CLKOUT"
  "clkout"
  "clock out"
  "clock_out"
)

# File globs we explicitly exclude to keep this script fast and readable.
# (The harness repo often contains large LVS spice dumps where CLK* substrings are common.)
RG_EXCLUDES=(
  "--glob" "!**/*.spice"
  "--glob" "!**/*.mag"
  "--glob" "!**/*.gds"
  "--glob" "!**/*.lef"
  "--glob" "!**/lvs/**"
)

any_hit=0

for t in "${TERMS[@]}"; do
  echo
  echo "--- rg -n \"$t\" (${SEARCH_DIRS[*]}) ---"
  if rg -n "${RG_EXCLUDES[@]}" -S "$t" "${SEARCH_DIRS[@]}" 2>/dev/null; then
    any_hit=1
  fi

done

echo
echo "--- Files with any hits (quick index) ---"
if rg "${RG_EXCLUDES[@]}" -l -S "(adc_clkin|ADC_CLKIN|ADS131|ads131|ADS131M08|ads131m08|\\bCLKIN\\b|oscillator|xtal|crystal|CLKOUT|clkout)" "${SEARCH_DIRS[@]}" 2>/dev/null; then
  any_hit=1
fi

echo
echo "--- rg -n \"\\bCLKIN\\b\" (docs/verilog/rtl/src/openlane, word-boundary) ---"
if rg -n "${RG_EXCLUDES[@]}" -S "\\bCLKIN\\b" "${SEARCH_DIRS[@]}" 2>/dev/null; then
  any_hit=1
fi

echo
echo "--- rg -n likely io[*] mapping near adc_clkin/CLKIN (tries to find explicit io[17] style evidence) ---"
# We want hard evidence like: io[17] -> adc_clkin OR adc_clkin: io[17]
# This is heuristic, but often catches pinout tables.
if rg -n "${RG_EXCLUDES[@]}" -S -i "(adc[_-]?clkin|ADC_CLKIN|\\bCLKIN\\b)[^\n]{0,160}io\\[[0-9]+\\]" "${SEARCH_DIRS[@]}" 2>/dev/null; then
  any_hit=1
fi
if rg -n "${RG_EXCLUDES[@]}" -S -i "io\\[[0-9]+\\][^\n]{0,160}(adc[_-]?clkin|ADC_CLKIN|\\bCLKIN\\b)" "${SEARCH_DIRS[@]}" 2>/dev/null; then
  any_hit=1
fi

echo
echo "--- rg -n frequency clues near CLKIN/adc_clkin (tries to find explicit MHz/kHz/Hz) ---"
# This is intentionally heuristic: we're looking for any doc/RTL notes that mention a
# clock net alongside an explicit frequency. This helps turn the 'CLKIN unknown' blocker
# into concrete evidence quickly.
if rg -n "${RG_EXCLUDES[@]}" -S -i "(adc[_-]?clkin|\\bCLKIN\\b)[^\n]{0,120}([0-9]+\\s*(mhz|khz|hz))" "${SEARCH_DIRS[@]}" 2>/dev/null; then
  any_hit=1
fi

echo
if [[ "$any_hit" -eq 0 ]]; then
  echo "== Summary: no obvious CLKIN/ADS131 clocking hits found in ${SEARCH_DIRS[*]} (excluding spice/lvs)."
  echo "           That may mean: clocking is not documented yet OR uses different naming."
else
  echo "== Summary: hits found. Review the matches above and extract the concrete pad/net mapping + clock source." 
fi

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
