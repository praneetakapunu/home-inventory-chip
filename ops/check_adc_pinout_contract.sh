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

# In strict mode, only enforce the dedicated "Tapeout-ready mapping (LOCKED)" block.
# This lets the doc keep historical placeholder context without breaking the gate once
# the real mapping is recorded.
LOCKED_START_STR='### Tapeout-ready mapping (LOCKED)'

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
need_cmd awk

# Patterns that indicate the mapping is not locked.
# Keep this intentionally simple + text-based.
PATTERNS=(
  "io\\[\\?\\]"     # explicit unknown index
  "io\\[\\*\\]"     # wildcard placeholder like io[*]
  "io\\[\\?\\?\\]"  # e.g. io[??]
  "-> \\?\\?\\?"   # unknown net/source
  "TBD"             # generic placeholder
  "tbd"             # lowercase variant
)

SCAN_FILE="$DOC"
TMP_SCAN=""
TMP_HITS=""

cleanup() {
  [[ -n "$TMP_SCAN" ]] && rm -f "$TMP_SCAN" || true
  [[ -n "$TMP_HITS" ]] && rm -f "$TMP_HITS" || true
}
trap cleanup EXIT

if [[ $STRICT -eq 1 ]]; then
  TMP_SCAN=$(mktemp)

  # Extract only the locked mapping section into TMP_SCAN.
  # We start at the heading line and stop before the next markdown heading.
  # If the section is missing/empty, strict mode should fail.
  awk -v start_str="$LOCKED_START_STR" '
    BEGIN {in_section=0}
    index($0, start_str) > 0 {in_section=1; print; next}
    in_section==1 {
      if ($0 ~ /^## / || $0 ~ /^### /) { exit }
      print
    }
  ' "$DOC" >"$TMP_SCAN"

  if ! grep -qF "$LOCKED_START_STR" "$TMP_SCAN"; then
    echo "ERROR: missing required section in $DOC: '### Tapeout-ready mapping (LOCKED)'" >&2
    exit 1
  fi

  # If the section exists but contains no mapping lines, treat as failure.
  if [[ $(wc -l <"$TMP_SCAN") -lt 3 ]]; then
    echo "ERROR: locked mapping section in $DOC appears empty; fill it before tapeout." >&2
    exit 1
  fi

  SCAN_FILE="$TMP_SCAN"
fi

hits=0
for pat in "${PATTERNS[@]}"; do
  TMP_HITS=$(mktemp)
  # grep returns 1 when no matches, so don't treat that as failure.
  grep -nE "$pat" "$SCAN_FILE" >"$TMP_HITS" 2>/dev/null || true

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
  if [[ $STRICT -eq 1 ]]; then
    echo "OK: ADC pinout LOCKED mapping section appears filled (no placeholders detected): $DOC"
  else
    echo "OK: ADC pinout contract appears filled (no placeholders detected): $DOC"
  fi
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
