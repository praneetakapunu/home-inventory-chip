#!/usr/bin/env bash
set -euo pipefail

# capture_gate_evidence.sh
#
# Purpose:
#   Capture a *reviewable* evidence snippet for a gate/decision without needing
#   CI reruns. Appends to reports/YYYY-MM-DD.md with:
#     - UTC timestamp
#     - repo path + git commit
#     - label
#     - exact command
#     - captured stdout/stderr + exit code
#
# Usage:
#   bash ops/capture_gate_evidence.sh "<label>" -- <command...>
# Example:
#   bash ops/capture_gate_evidence.sh "preflight_low_disk" -- bash ops/preflight_low_disk.sh

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <label> -- <command...>" >&2
  exit 2
fi

LABEL="$1"
shift

if [[ "${1:-}" != "--" ]]; then
  echo "Expected '--' before command." >&2
  echo "Usage: $0 <label> -- <command...>" >&2
  exit 2
fi
shift

if [[ $# -lt 1 ]]; then
  echo "Missing command after '--'." >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORTS_DIR="$ROOT_DIR/reports"
DATE_UTC="$(date -u +%F)"
TS_UTC="$(date -u +%FT%TZ)"
REPORT_PATH="$REPORTS_DIR/$DATE_UTC.md"

mkdir -p "$REPORTS_DIR"

# Best-effort git metadata.
GIT_COMMIT="(unknown)"
GIT_BRANCH="(unknown)"
if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
  GIT_BRANCH="$(git -C "$ROOT_DIR" rev-parse --abbrev-ref HEAD)"
fi

CMD_STR="$(printf "%q " "$@")"

TMP_OUT="$(mktemp)"
set +e
( cd "$ROOT_DIR" && "$@" ) >"$TMP_OUT" 2>&1
RC=$?
set -e

{
  echo
  echo "## Evidence: $LABEL"
  echo "- time_utc: $TS_UTC"
  echo "- repo: $ROOT_DIR"
  echo "- git: $GIT_BRANCH @ $GIT_COMMIT"
  echo "- cmd: $CMD_STR"
  echo "- exit_code: $RC"
  echo
  echo "```"
  # Trim extremely long logs to keep reports human-sized.
  # Keep the *end* of the log since it usually contains PASS/FAIL summary.
  MAX_LINES=240
  LINES="$(wc -l < "$TMP_OUT" | tr -d ' ')"
  if [[ "$LINES" -le "$MAX_LINES" ]]; then
    cat "$TMP_OUT"
  else
    echo "(log truncated: showing last $MAX_LINES of $LINES lines)"
    tail -n "$MAX_LINES" "$TMP_OUT"
  fi
  echo "```"
} >> "$REPORT_PATH"

rm -f "$TMP_OUT"

if [[ $RC -ne 0 ]]; then
  echo "Captured evidence (FAIL) to: $REPORT_PATH" >&2
  exit $RC
fi

echo "Captured evidence (PASS) to: $REPORT_PATH"