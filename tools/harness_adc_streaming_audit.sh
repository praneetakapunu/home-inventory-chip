#!/usr/bin/env bash
set -euo pipefail

HARNESS_DIR="${1:-}"
if [[ -z "$HARNESS_DIR" ]]; then
  echo "Usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

if [[ ! -d "$HARNESS_DIR" ]]; then
  echo "ERROR: Not a directory: $HARNESS_DIR" >&2
  exit 2
fi

cd "$HARNESS_DIR"

echo "== ADC streaming / real-ingest harness audit =="
echo "Harness: $(pwd)"
echo

echo "-- 1) Make targets / build flags"
if grep -RIn --exclude-dir=.git -E "^rtl-compile-check-real-adc:" -n Makefile* >/dev/null 2>&1; then
  echo "OK: Found make target: rtl-compile-check-real-adc"
else
  echo "WARN: Did not find make target: rtl-compile-check-real-adc"
  echo "      (Expectation: a compile sanity target that enables -DUSE_REAL_ADC_INGEST)"
fi

# Search for any mention of the define in build scripts/Makefiles (only in paths that exist)
SEARCH_PATHS=()
for p in Makefile Makefile.* verilog scripts .github; do
  compgen -G "$p" >/dev/null 2>&1 || continue
  for m in $p; do SEARCH_PATHS+=("$m"); done
done

if [[ ${#SEARCH_PATHS[@]} -eq 0 ]]; then
  echo "WARN: No standard search paths found (Makefile/verilog/etc)."
elif grep -RIn --exclude-dir=.git -E "USE_REAL_ADC_INGEST" "${SEARCH_PATHS[@]}" >/dev/null 2>&1; then
  echo "OK: Found references to USE_REAL_ADC_INGEST (showing up to 20 lines):"
  grep -RIn --exclude-dir=.git -E "USE_REAL_ADC_INGEST" "${SEARCH_PATHS[@]}" 2>/dev/null | head -n 20 || true
else
  echo "WARN: No references to USE_REAL_ADC_INGEST found in common build locations"
fi

echo

echo "-- 1b) Filelist / source inclusion (real-ingest should pull adc_streaming_ingest)"
# We can't know the exact harness filelist naming, so we just grep common RTL/filelist locations.
FILELIST_PATHS=()
for p in verilog/rtl verilog/dv verilog/includes verilog; do
  [[ -d "$p" ]] && FILELIST_PATHS+=("$p")
done

if [[ ${#FILELIST_PATHS[@]} -eq 0 ]]; then
  echo "WARN: Could not find verilog/* directories to scan for filelists"
else
  if grep -RIn --exclude-dir=.git -E "adc_streaming_ingest\.v" "${FILELIST_PATHS[@]}" >/dev/null 2>&1; then
    echo "OK: Found mention of adc_streaming_ingest.v (showing up to 20 lines):"
    grep -RIn --exclude-dir=.git -E "adc_streaming_ingest\.v" "${FILELIST_PATHS[@]}" 2>/dev/null | head -n 20 || true
  else
    echo "WARN: Did not find adc_streaming_ingest.v referenced in verilog/* locations"
    echo "      (If the harness relies on an IP filelist sync step, this may be OK; otherwise it's a risk.)"
  fi
fi

echo

echo "-- 2) Wrapper port exposure (adc_* pins)"
WRAPPER_FILES=(
  "verilog/rtl/user_project_wrapper.v"
  "verilog/rtl/home_inventory_user_project.v"
)

for f in "${WRAPPER_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    echo "File: $f"
    # Show any ADC pin mentions (limit output)
    grep -nE "\badc_(sclk|cs_n|mosi|miso)\b" "$f" | head -n 50 || true
  else
    echo "WARN: Missing expected wrapper file: $f"
  fi
  echo
done

echo "-- 3) Quick sanity expectations"
cat <<'EOF'
Expectations when compiling with -DUSE_REAL_ADC_INGEST:
- Port lists match between harness wrapper instantiation and IP module home_inventory_wb.
- If no ADC model is present, it's OK for compile sanity to:
  - tie adc_miso low
  - leave adc_sclk/cs_n/mosi as dummy wires
  as long as the define guard is consistent.

If this audit shows missing make targets or missing adc_* mentions, fix harness wiring before OpenLane/precheck.
EOF
