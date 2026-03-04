#!/usr/bin/env bash
set -euo pipefail

# check_shuttle_lock_record.sh
#
# Purpose:
#   Lightweight sanity check for the OpenMPW shuttle lock record.
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
TBD_COUNT=$(grep -n "\bTBD\b" "$RECORD" | wc -l | tr -d ' ')

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
  echo "  File: $RECORD"
  echo "  Tip: Once Praneet chooses a shuttle, fill the record and re-run with --strict."
  if [[ "$STRICT" -eq 1 ]]; then
    echo "\nStrict-mode requirements not met (TBD placeholders remain)." >&2
    exit 1
  fi
else
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
  fi

  echo "Shuttle lock record status: LOCKED (no 'TBD' placeholders found)"
  echo "  File: $RECORD"
fi
