#!/usr/bin/env bash
set -euo pipefail

# check_adc_clkin_decision_evidence.sh
#
# Purpose:
#   Once Decision 011 (ADC CLKIN source + frequency) is marked *locked*, ensure it
#   actually contains the minimum required evidence fields (not TBD).
#
# Why:
#   It's easy to flip a decision doc from Proposed -> Accepted without recording
#   the concrete harness evidence we need for tapeout. This script makes the
#   acceptance criteria mechanically checkable.
#
# Usage:
#   bash ops/check_adc_clkin_decision_evidence.sh
#
# Exit codes:
#   0 = OK
#   1 = locked but missing evidence / still TBD
#   2 = missing file / cannot parse status

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

DECISION_FILE="decisions/011-adc-clkin-source-and-frequency.md"

if [[ ! -f "$DECISION_FILE" ]]; then
  echo "ERROR: missing decision file: $DECISION_FILE" >&2
  exit 2
fi

extract_status() {
  local f="$1"

  local line
  line=$(grep -nE "\*\*Status:\*\*" "$f" | head -n 1 || true)
  if [[ -n "$line" ]]; then
    echo "$line" | sed -E 's/^.*\*\*Status:\*\*\s*//; s/[[:space:]]+$//; s/[[:space:]]*\*\*.*$//'
    return 0
  fi

  local block
  block=$(awk '
    BEGIN{in_status=0}
    /^##[[:space:]]+Status[[:space:]]*$/ {in_status=1; next}
    in_status==1 {
      if ($0 ~ /^##[[:space:]]+/) {exit}
      print
    }
  ' "$f" | grep -E "\*\*[^*]+\*\*" | head -n 1 || true)

  if [[ -n "$block" ]]; then
    echo "$block" | sed -E 's/^.*\*\*([^*]+)\*\*.*$/\1/'
    return 0
  fi

  return 1
}

is_locked_status() {
  local s="$1"
  s="${s,,}"
  case "$s" in
    accepted*|decided*|locked*|final*) return 0 ;;
    *) return 1 ;;
  esac
}

status=$(extract_status "$DECISION_FILE" || true)
if [[ -z "${status:-}" ]]; then
  echo "ERROR: could not extract Status from: $DECISION_FILE" >&2
  exit 2
fi

if ! is_locked_status "$status"; then
  # Not locked yet; evidence fields are expected to be TBD.
  echo "OK: $DECISION_FILE is not locked yet (Status: $status); evidence check skipped"
  exit 0
fi

fail=0

# 1) At least one explicit Source: pointer.
if ! grep -qE '^[- ]+Source:\s*.+$' "$DECISION_FILE"; then
  echo "ERROR: Decision 011 is locked but contains no 'Source: <path>:<line>' evidence line" >&2
  fail=1
fi

# 2) Frequency must not be TBD.
if grep -qE '^[- ]+Expected CLKIN frequency:\s*(TBD|\?\?\?|unknown)\b' "$DECISION_FILE"; then
  echo "ERROR: Decision 011 is locked but 'Expected CLKIN frequency' is still TBD" >&2
  fail=1
fi

# 3) Route must not be empty/TBD.
if grep -qE '^[- ]+CLKIN route:\s*(TBD|\?\?\?|unknown)?\s*$' "$DECISION_FILE"; then
  echo "ERROR: Decision 011 is locked but 'CLKIN route' is missing/TBD" >&2
  fail=1
fi

# 4) Optional sanity: if the decision claims a numeric frequency, ensure it has digits.
if grep -qE '^[- ]+Expected CLKIN frequency:\s*[^0-9\n]*$' "$DECISION_FILE"; then
  echo "ERROR: Decision 011 'Expected CLKIN frequency' does not appear numeric (missing Hz value)" >&2
  fail=1
fi

if [[ $fail -ne 0 ]]; then
  exit 1
fi

echo "OK: Decision 011 locked and includes minimum evidence fields"
exit 0
