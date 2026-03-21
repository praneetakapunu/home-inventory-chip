#!/usr/bin/env bash
set -euo pipefail

# check_adc_streaming_contract.sh
#
# Purpose:
#   Fail-fast check that the ADC streaming contract is concrete enough for tapeout
#   (no TBD/??? placeholders) and (optionally) that the harness repo isn't still
#   using placeholder wiring for the ADC streaming path.
#
# Why:
#   Streaming is easy to "half-wire" (stubs, TODOs, placeholder module names).
#   This script makes streaming readiness explicit in CI / preflight.
#
# Usage:
#   bash ops/check_adc_streaming_contract.sh                       # non-strict: warn-only
#   bash ops/check_adc_streaming_contract.sh --strict              # strict: fail on placeholders
#   bash ops/check_adc_streaming_contract.sh --harness ../home-inventory-chip-openmpw
#   bash ops/check_adc_streaming_contract.sh --strict --harness ../home-inventory-chip-openmpw

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOC="$ROOT_DIR/docs/ADC_STREAM_CONTRACT.md"

STRICT=0
HARNESS_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --harness)
      HARNESS_REPO="${2:-}"
      [[ -z "$HARNESS_REPO" ]] && { echo "ERROR: --harness requires a path" >&2; exit 2; }
      shift 2
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

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

# Optional: enforce the harness repo isn't still using placeholder streaming wiring.
HARNESS_CHECK_SCRIPT="$ROOT_DIR/tools/harness_adc_streaming_placeholder_check.sh"
if [[ -n "$HARNESS_REPO" ]]; then
  if [[ ! -x "$HARNESS_CHECK_SCRIPT" ]]; then
    echo "ERROR: missing harness check script: $HARNESS_CHECK_SCRIPT" >&2
    exit 2
  fi
fi

# Patterns that indicate the streaming contract isn't locked.
# Keep simple and text-based.
PATTERNS=(
  "\\?\\?\\?"            # generic unknown marker
  "TBD"                 # placeholder
  "tbd"                 # lowercase variant
  "TODO"                # TODO marker
  "todo"                # lowercase variant
  "FIXME"               # fixme marker
  "fixme"               # lowercase variant
)

hits=0
for pat in "${PATTERNS[@]}"; do
  tmp=$(mktemp)
  grep -nE "$pat" "$DOC" >"$tmp" 2>/dev/null || true
  if [[ -s "$tmp" ]]; then
    echo
    echo "== Placeholder evidence for pattern: $pat =="
    cat "$tmp"
    hits=$((hits + 1))
  fi
  rm -f "$tmp"
done

if [[ $hits -eq 0 ]]; then
  if [[ $STRICT -eq 1 ]]; then
    echo "OK: ADC streaming contract appears concrete (no placeholders detected): $DOC"
  else
    echo "OK: ADC streaming contract appears concrete (no placeholders detected): $DOC"
  fi

  if [[ -n "$HARNESS_REPO" ]]; then
    if "$HARNESS_CHECK_SCRIPT" "$HARNESS_REPO" >/dev/null; then
      echo "OK: Harness ADC streaming wiring appears non-placeholder: $HARNESS_REPO"
    else
      if [[ $STRICT -eq 1 ]]; then
        echo "ERROR: Harness ADC streaming wiring still appears placeholder: $HARNESS_REPO" >&2
        echo "Run: $HARNESS_CHECK_SCRIPT '$HARNESS_REPO'" >&2
        exit 1
      fi
      echo "WARN: Harness ADC streaming wiring still appears placeholder: $HARNESS_REPO" >&2
      echo "Run: $HARNESS_CHECK_SCRIPT '$HARNESS_REPO'" >&2
    fi
  fi

  exit 0
fi

msg="ADC streaming contract still contains placeholders; tighten docs/ADC_STREAM_CONTRACT.md before tapeout."

if [[ $STRICT -eq 1 ]]; then
  echo
  echo "ERROR: $msg" >&2
  exit 1
fi

echo

echo "WARN: $msg"
exit 0
