#!/usr/bin/env bash
set -euo pipefail

# check_required_decisions.sh
#
# Purpose:
#   Fail-fast gate that the tapeout-critical decisions are actually *locked*
#   (i.e., not still Proposed/TBD).
#
# Why:
#   We have a habit of capturing key constraints as "Decision" docs, but the
#   status can silently remain Proposed even while RTL proceeds. This gate makes
#   the "are we really locked?" question explicit before we commit to a shuttle
#   cutoff.
#
# Usage:
#   bash ops/check_required_decisions.sh
#   bash ops/check_required_decisions.sh --strict
#
# Notes:
#   - This is a text-only check; it does not validate the correctness of the
#     decision, only that the doc is marked as locked.
#   - Acceptable locked statuses are intentionally permissive to match existing
#     decision templates used in this repo.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Tapeout-critical decisions (extend this list as we add new must-lock items).
#
# Keep this list intentionally small and focused on decisions that, if left ambiguous,
# will cause last-minute tapeout churn (interface contracts, timing/clocking, and
# acceptance targets).
DECISIONS=(
  "decisions/007-effective-resolution-definition.md"
  "decisions/008-adc-part-selection.md"
  "decisions/009-ads131m08-word-length-and-crc.md"
  "decisions/010-adc-fifo-depth-and-overrun-policy.md"
  "decisions/011-adc-clkin-source-and-frequency.md"
)

# Status values we consider "locked".
# (We use a set because different decision docs use different templates.)
LOCKED_STATUSES=(
  "accepted"
  "decided"
  "locked"
  "final"
)

is_locked_status() {
  local s="$1"
  s="${s,,}"  # lowercase

  # Many decision docs include clarifiers like "Accepted (v1 baseline)".
  # Treat any status that *starts with* a known locked keyword as locked.
  for ok in "${LOCKED_STATUSES[@]}"; do
    if [[ "$s" == "$ok" || "$s" == "$ok"* ]]; then
      return 0
    fi
  done
  return 1
}

extract_status() {
  local f="$1"

  # Supported templates:
  # 1) "## Status" section with a bold line below (e.g., "**Proposed**")
  # 2) Top bullet metadata: "- **Status:** Decided"
  # 3) Inline metadata: "**Status:** Decided"

  # First try the "- **Status:**" pattern.
  local line
  line=$(grep -nE "\*\*Status:\*\*" "$f" | head -n 1 || true)
  if [[ -n "$line" ]]; then
    # Extract after "Status:"; trim leading/trailing spaces and punctuation.
    echo "$line" | sed -E 's/^.*\*\*Status:\*\*\s*//; s/[[:space:]]+$//; s/[[:space:]]*\*\*.*$//'
    return 0
  fi

  # Then try the "## Status" section.
  # Find the first line after "## Status" that contains bold text "**...**".
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

fail=0

for f in "${DECISIONS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: missing decision file: $f" >&2
    fail=1
    continue
  fi

  status=$(extract_status "$f" || true)
  if [[ -z "${status:-}" ]]; then
    echo "ERROR: could not extract Status from: $f" >&2
    fail=1
    continue
  fi

  if is_locked_status "$status"; then
    echo "OK: $f status is locked: $status"
  else
    msg="$f is not locked (Status: $status). Mark it Accepted/Decided/Locked before cutoff."
    if [[ $STRICT -eq 1 ]]; then
      echo "ERROR: $msg" >&2
      fail=1
    else
      echo "WARN: $msg" >&2
    fi
  fi

done

if [[ $fail -ne 0 ]]; then
  exit 1
fi

exit 0
