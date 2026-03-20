#!/usr/bin/env bash
set -euo pipefail

# check_adc_pinout_contract.sh
#
# Purpose:
#   Fail-fast check that the canonical ADC pinout contract has been filled in
#   (i.e., no placeholder mappings like io[?], io[*], ???, TBD) before tapeout/cutoff.
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 2
  }
}
need_cmd grep
need_cmd mktemp

# Patterns that indicate the mapping section is not locked.
# Keep this intentionally simple + text-based.
PATTERNS=(
  "io\\[\\?\\]"   # explicit unknown index
  "io\\[\\*\\]"   # wildcard placeholder like io[*]
  "-> \\?\\?\\?" # unknown net/source
  "TBD"           # generic placeholder
  "tbd"           # lowercase variant
)

TMP_HITS=""
cleanup() {
  [[ -n "$TMP_HITS" ]] && rm -f "$TMP_HITS" || true
}
trap cleanup EXIT

hits=0
for pat in "${PATTERNS[@]}"; do
  TMP_HITS=$(mktemp)
  # grep returns 1 when no matches, so don't treat that as failure.
  grep -nE "$pat" "$DOC" >"$TMP_HITS" 2>/dev/null || true

  if [[ -s "$TMP_HITS" ]]; then
    echo
    echo "== Placeholder evidence for pattern: $pat =="
    cat "$TMP_HITS"
    hits=$((hits + 1))
  fi

  rm -f "$TMP_HITS"
  TMP_HITS=""
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
