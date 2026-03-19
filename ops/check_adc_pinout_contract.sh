#!/usr/bin/env bash
set -euo pipefail

# check_adc_pinout_contract.sh
#
# Purpose:
#   Fail-fast check that the canonical ADC pinout contract has been filled in
#   (i.e., no placeholder mappings like io[?], ???, TBD) before tapeout/cutoff.
#
# Why:
#   The harness wrapper historically used placeholder io indices.
#   This script makes that risk visible in CI / preflight.
#
# Usage:
#   bash ops/check_adc_pinout_contract.sh            # non-strict: warn-only
#   bash ops/check_adc_pinout_contract.sh --strict   # strict: fail on placeholders

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOC="$ROOT_DIR/docs/ADC_PINOUT_CONTRACT.md"

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

if [[ ! -f "$DOC" ]]; then
  echo "ERROR: missing doc: $DOC" >&2
  exit 2
fi

# Patterns that indicate the mapping section is not locked.
# Keep this intentionally simple + text-based.
PATTERNS=(
  "io\\[\\?\\]"
  "-> \\?\\?\\?"
  "TBD"
)

hits=0
for pat in "${PATTERNS[@]}"; do
  if grep -nE "$pat" "$DOC" >/tmp/adc_pinout_contract_hits.txt 2>/dev/null; then
    true
  fi
  if [[ -s /tmp/adc_pinout_contract_hits.txt ]]; then
    echo
    echo "== Placeholder evidence for pattern: $pat =="
    cat /tmp/adc_pinout_contract_hits.txt
    hits=$((hits + 1))
  fi
  rm -f /tmp/adc_pinout_contract_hits.txt
done

if [[ $hits -eq 0 ]]; then
  echo "OK: ADC pinout contract appears filled (no placeholders detected): $DOC"
  exit 0
fi

msg="ADC pinout contract still contains placeholders; fill docs/ADC_PINOUT_CONTRACT.md before tapeout."

if [[ $STRICT -eq 1 ]]; then
  echo
  echo "ERROR: $msg" >&2
  exit 1
fi

echo
echo "WARN: $msg"
exit 0
