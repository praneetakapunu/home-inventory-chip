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

# Staleness check: the schedule source can change; in strict mode we fail if the
# lock record hasn't been re-verified recently.
#
# The record line is expected to look like:
#   - **Last verified (UTC):** 2026-03-06 18:18Z
#
# NOTE: This is a *process* gate, not a technical one. Keep it lightweight.
STALE_DAYS=${STALE_DAYS:-7}
LAST_VERIFIED_LINE=$(grep -m1 -E "\*\*Last verified \(UTC\):\*\*" "$RECORD" || true)
LAST_VERIFIED_TS=$(echo "$LAST_VERIFIED_LINE" | sed -E 's/.*\*\*Last verified \(UTC\):\*\* *//')

last_verified_is_stale() {
  local ts="$1"
  if [[ -z "$ts" ]]; then
    return 2
  fi

  # Convert to epoch seconds. Prefer GNU date; if unavailable, skip staleness.
  if ! command -v date >/dev/null 2>&1; then
    return 3
  fi

  local lv_epoch now_epoch age_days
  lv_epoch=$(date -u -d "$ts" +%s 2>/dev/null || true)
  if [[ -z "$lv_epoch" ]]; then
    return 4
  fi
  now_epoch=$(date -u +%s)
  age_days=$(( (now_epoch - lv_epoch) / 86400 ))

  if [[ "$age_days" -gt "$STALE_DAYS" ]]; then
    return 0
  fi
  return 1
}

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

    # Fail strict mode if the record is stale.
    if last_verified_is_stale "$LAST_VERIFIED_TS"; then
      echo "ERROR: shuttle lock record appears stale (Last verified (UTC): $LAST_VERIFIED_TS; stale threshold: ${STALE_DAYS}d)" >&2
      echo "  Re-verify the official schedule link and update docs/SHUTTLE_LOCK_RECORD.md" >&2
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
      val=$(awk -v k="$key" '
        $0 ~ "^  " k ":" {
          sub("^  " k ": *", "", $0)
          print $0
          exit
        }
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
    require_nonempty "utc"
  fi

  if last_verified_is_stale "$LAST_VERIFIED_TS"; then
    echo "WARNING: shuttle lock record may be stale (Last verified (UTC): $LAST_VERIFIED_TS; stale threshold: ${STALE_DAYS}d)"
    echo "  Re-verify the official schedule link and refresh docs/SHUTTLE_LOCK_RECORD.md"
  fi

  if [[ "$LOCK_STATUS" == "LOCKED" ]]; then
    echo "Shuttle lock record status: OK (LOCKED; no 'TBD' placeholders found)"
  else
    echo "Shuttle lock record status: INCOMPLETE (no 'TBD' placeholders, but Lock status is '$LOCK_STATUS')"
    echo "  Tip: When Praneet confirms the shuttle, set: **Lock status:** LOCKED"
  fi
  echo "  File: $RECORD"
fi
