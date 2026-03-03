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

if [[ "$TBD_COUNT" -gt 0 ]]; then
  echo "Shuttle lock record status: NOT LOCKED (contains $TBD_COUNT 'TBD' placeholders)"
  echo "  File: $RECORD"
  echo "  Tip: Once Praneet chooses a shuttle, fill the record and re-run with --strict."
  if [[ "$STRICT" -eq 1 ]]; then
    exit 1
  fi
else
  echo "Shuttle lock record status: LOCKED (no 'TBD' placeholders found)"
  echo "  File: $RECORD"
fi
