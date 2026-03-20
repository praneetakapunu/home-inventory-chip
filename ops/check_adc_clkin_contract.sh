#!/usr/bin/env bash
set -euo pipefail

# check_adc_clkin_contract.sh
#
# Purpose:
#   Fail-fast check that the ADC CLKIN source/frequency decision is actually locked
#   (i.e., no placeholders like io[??], ???, TBD) before tapeout/cutoff.
#
# Context:
#   ADS131M08 needs a known CLKIN source + frequency. Historically, the harness repo
#   carried draft notes with unknown io indices, which is a real bring-up/tapeout risk.
#
# Usage:
#   bash ops/check_adc_clkin_contract.sh            # non-strict: warn-only
#   bash ops/check_adc_clkin_contract.sh --strict   # strict: fail on placeholders

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

DOCS=(
  "$ROOT_DIR/docs/ADC_CLOCKING_PLAN.md"
  "$ROOT_DIR/decisions/011-adc-clkin-source-and-frequency.md"
)

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 2
  }
}
need_cmd grep
need_cmd mktemp

# Patterns that indicate the clocking decision is not yet locked.
# Keep it intentionally simple and text-based.
PATTERNS=(
  "io\\[\\?\\?\\]" # explicit unknown index like io[??]
  "io\\[\\?\\]"   # io[?]
  "\\?\\?\\?"      # ???
  "TBD"            # placeholder
  "tbd"            # placeholder
  "UNKNOWN"        # placeholder (shouty)
  "unknown"        # placeholder
)

missing=0
for f in "${DOCS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing required clocking doc: $f" >&2
    missing=1
  fi
done
if [[ $missing -ne 0 ]]; then
  exit 2
fi

TMP_HITS=""
cleanup() { [[ -n "$TMP_HITS" ]] && rm -f "$TMP_HITS" || true; }
trap cleanup EXIT

hits=0
for f in "${DOCS[@]}"; do
  for pat in "${PATTERNS[@]}"; do
    TMP_HITS=$(mktemp)
    grep -nE "$pat" "$f" >"$TMP_HITS" 2>/dev/null || true
    if [[ -s "$TMP_HITS" ]]; then
      echo
      echo "== Placeholder evidence in: $f (pattern: $pat) =="
      cat "$TMP_HITS"
      hits=$((hits + 1))
    fi
    rm -f "$TMP_HITS"
    TMP_HITS=""
  done
done

if [[ $hits -eq 0 ]]; then
  echo "OK: ADC CLKIN contract appears locked (no placeholders detected)."
  exit 0
fi

msg="ADC CLKIN contract still contains placeholders; lock source + frequency before tapeout/cutoff."

if [[ $STRICT -eq 1 ]]; then
  echo
  echo "ERROR: $msg" >&2
  exit 1
fi

echo
echo "WARN: $msg"
exit 0
