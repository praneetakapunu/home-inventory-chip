#!/usr/bin/env bash
set -euo pipefail

RESULT=""
HARNESS_PATH=""
LOG_REF=""
DATE_UTC="$(date -u +%Y-%m-%d)"

usage() {
  cat <<'EOF'
Usage:
  bash ops/record_precheck_run.sh --result PASS|FAIL --harness <path-to-harness-repo> [--log <path-or-link>] [--date <YYYY-MM-DD>]

Appends a row to docs/BASELINES.md under "Precheck runs" capturing:
- Date (UTC)
- Result (PASS/FAIL)
- Harness commit
- IP commit (this repo)
- Log reference (path/link)

Example:
  bash ops/record_precheck_run.sh \
    --result PASS \
    --harness ../home-inventory-chip-openmpw \
    --log docs/PRECHECK_LOG.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --result)
      RESULT="${2:-}"; shift 2 ;;
    --harness)
      HARNESS_PATH="${2:-}"; shift 2 ;;
    --log)
      LOG_REF="${2:-}"; shift 2 ;;
    --date)
      DATE_UTC="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage; exit 2 ;;
  esac
done

if [[ -z "$RESULT" || -z "$HARNESS_PATH" ]]; then
  echo "ERROR: --result and --harness are required." >&2
  usage
  exit 2
fi

if [[ "$RESULT" != "PASS" && "$RESULT" != "FAIL" ]]; then
  echo "ERROR: --result must be PASS or FAIL (got: $RESULT)" >&2
  exit 2
fi

if [[ ! -d "$HARNESS_PATH/.git" ]]; then
  echo "ERROR: harness path is not a git repo: $HARNESS_PATH" >&2
  exit 2
fi

IP_COMMIT="$(git rev-parse HEAD)"
HARNESS_COMMIT="$(git -C "$HARNESS_PATH" rev-parse HEAD)"

if [[ -z "$LOG_REF" ]]; then
  LOG_REF="(add log reference)"
fi

BASELINES_MD="docs/BASELINES.md"
if [[ ! -f "$BASELINES_MD" ]]; then
  echo "ERROR: expected $BASELINES_MD in repo root" >&2
  exit 2
fi

ENTRY="- ${DATE_UTC} | ${RESULT} | ${HARNESS_COMMIT} | ${IP_COMMIT} | ${LOG_REF}"

# Append under the "Entries:" line.
TMP="$(mktemp)"
awk -v entry="$ENTRY" '
  {print}
  /^Entries:/{
    getline nextline
    if (nextline ~ /^- \(none yet\)/) {
      print entry
    } else {
      print nextline
      print entry
    }
    next
  }
' "$BASELINES_MD" > "$TMP"

mv "$TMP" "$BASELINES_MD"

echo "Recorded precheck run:" >&2
echo "  $ENTRY" >&2
