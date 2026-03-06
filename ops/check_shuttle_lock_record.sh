#!/usr/bin/env bash
set -euo pipefail

# check_shuttle_lock_record.sh
#
# Purpose:
#   Lightweight sanity check for the shuttle lock record.
#   Designed to be runnable even in low-disk environments.
#
# Behavior:
#   - Default mode is non-strict: prints status and exits 0.
#   - Strict mode (--strict) exits non-zero if the record is not fully locked.
#
# Usage:
#   bash ops/check_shuttle_lock_record.sh
#   bash ops/check_shuttle_lock_record.sh --strict

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
elif [[ -n "${1:-}" ]]; then
  echo "Unknown arg: $1" >&2
  echo "Usage: $0 [--strict]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RECORD="$ROOT_DIR/docs/SHUTTLE_LOCK_RECORD.md"

if [[ ! -f "$RECORD" ]]; then
  echo "ERROR: missing $RECORD" >&2
  exit 1
fi

# Count any remaining TBD placeholders.
TBD_COUNT=$( (grep -n "\bTBD\b" "$RECORD" || true) | wc -l | tr -d ' ')

# Read lock status (LOCKED vs PROPOSED) from the top of the file.
# Expected line:
#   **Lock status:** LOCKED
LOCK_STATUS=$(grep -m1 -E "^\*\*Lock status:\*\*" "$RECORD" | sed -E 's/^\*\*Lock status:\*\* *//')
LOCK_STATUS=${LOCK_STATUS:-"(missing)"}

# Ensure the record includes a 'Last verified (UTC)' field.
if ! grep -q "Last verified (UTC)" "$RECORD"; then
  echo "ERROR: shuttle lock record is missing 'Last verified (UTC)' field" >&2
  exit 1
fi

field_line() {
  # Print the first matching markdown bullet line for a field label.
  # Example: field_line "Source link"
  # Matches labels that may include a trailing colon inside the bold text.
  local label="$1"
  grep -m1 -n "^[-*] \*\*${label}[^*]*\*\*" "$RECORD" || true
}

if [[ "$TBD_COUNT" -gt 0 ]]; then
  echo "Shuttle lock record status: NOT LOCKED (contains $TBD_COUNT 'TBD' placeholders)"
  echo "  Lock status line: $LOCK_STATUS"
  echo "  File: $RECORD"
  echo "  Tip: Once Praneet chooses a shuttle, fill the record and re-run with --strict."
  if [[ "$STRICT" -eq 1 ]]; then
    echo "\nStrict-mode requirements not met (TBD placeholders remain)." >&2
    exit 1
  fi
else
  # In strict mode, require an explicit LOCKED status (not merely 'no TBDs').
  if [[ "$STRICT" -eq 1 && "$LOCK_STATUS" != "LOCKED" ]]; then
    echo "ERROR: record has no TBDs, but is not explicitly LOCKED (Lock status: $LOCK_STATUS)" >&2
    echo "  If this shuttle is confirmed, edit docs/SHUTTLE_LOCK_RECORD.md and set: **Lock status:** LOCKED" >&2
    exit 1
  fi

  # In strict mode, do a couple of additional lightweight sanity checks.
  if [[ "$STRICT" -eq 1 ]]; then
    LV_LINE=$(field_line "Last verified (UTC)")
    SL_LINE=$(field_line "Source link")
    SX_LINE=$(field_line "Source excerpt")

    if [[ -z "$LV_LINE" ]]; then
      echo "ERROR: missing 'Last verified (UTC)' line" >&2
      exit 1
    fi

    if [[ -z "$SL_LINE" ]]; then
      echo "ERROR: missing 'Source link' line" >&2
      exit 1
    fi

    # Require an http(s) URL somewhere on the source link line.
    if ! echo "$SL_LINE" | grep -Eq "https?://"; then
      echo "ERROR: source link does not look like a URL (expected http(s)://...)" >&2
      echo "  Line: $SL_LINE" >&2
      exit 1
    fi

    if [[ -z "$SX_LINE" ]]; then
      echo "ERROR: missing 'Source excerpt' line" >&2
      exit 1
    fi

    # Ensure the canonical formatting block has explicit date/time/timezone values.
    # This prevents ambiguous cutoffs like "Mar 12" without a timezone.
    require_nonempty() {
      local key="$1"
      local val
      val=$(awk -F': ' -v k="$key" '
        $0 ~ "^  "k":" {sub(/^  "k": */, "", $0); print $0; exit}
      ' "$RECORD" || true)

      if [[ -z "$val" ]]; then
        echo "ERROR: '$key' is missing or empty in canonical cutoff block" >&2
        echo "  Expected a line like:  $key: <value>" >&2
        exit 1
      fi
    }

    require_nonempty "date"
    require_nonempty "time"
    require_nonempty "timezone"
  fi

  echo "Shuttle lock record status: OK (no 'TBD' placeholders found; Lock status: $LOCK_STATUS)"
  echo "  File: $RECORD"
fi
