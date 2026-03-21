#!/usr/bin/env bash
set -euo pipefail

# Create a timestamped markdown snapshot of harness audit output.
# Intended to be low-disk and toolchain-free: grep-style audits only.
#
# Usage:
#   tools/harness_audit_snapshot.sh ../home-inventory-chip-openmpw
#   HARNESS_REPO=../home-inventory-chip-openmpw tools/harness_audit_snapshot.sh
#
# Output:
#   reports/harness-audit/harness_audit_<UTC-TS>.md

HARNESS_REPO="${1:-${HARNESS_REPO:-}}"
if [[ -z "${HARNESS_REPO}" ]]; then
  echo "ERROR: harness repo path required" >&2
  echo "Usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

if [[ ! -d "${HARNESS_REPO}/.git" ]]; then
  echo "ERROR: not a git repo: ${HARNESS_REPO}" >&2
  exit 2
fi

TS_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="reports/harness-audit"
mkdir -p "${OUT_DIR}"
OUT_MD="${OUT_DIR}/harness_audit_${TS_UTC}.md"

HARNESS_HEAD="$(git -C "${HARNESS_REPO}" rev-parse --short HEAD)"
HARNESS_BRANCH="$(git -C "${HARNESS_REPO}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

run_section() {
  local title="$1"
  shift
  echo "## ${title}"
  echo
  echo "\`\`\`text"
  "$@" || true
  echo "\`\`\`"
  echo
}

{
  echo "# Harness audit snapshot"
  echo
  echo "- Timestamp (UTC): ${TS_UTC}"
  echo "- Harness repo: ${HARNESS_REPO}"
  echo "- Harness HEAD: ${HARNESS_HEAD} (${HARNESS_BRANCH})"
  echo

  run_section "harness_adc_pinout_audit.sh" tools/harness_adc_pinout_audit.sh "${HARNESS_REPO}"
  run_section "harness_adc_clocking_audit.sh" tools/harness_adc_clocking_audit.sh "${HARNESS_REPO}"
  run_section "harness_adc_drdy_audit.sh" tools/harness_adc_drdy_audit.sh "${HARNESS_REPO}"
  run_section "harness_adc_streaming_audit.sh" tools/harness_adc_streaming_audit.sh "${HARNESS_REPO}"
  run_section "harness_wb_wiring_audit.sh" tools/harness_wb_wiring_audit.sh "${HARNESS_REPO}"
  run_section "harness_event_detector_audit.sh" tools/harness_event_detector_audit.sh "${HARNESS_REPO}"

  echo "## Evidence snips (high-signal terms)"
  echo
  echo "\`\`\`text"
  python3 tools/harness_evidence_snip.py "${HARNESS_REPO}" \
    --terms ADS131,ADS131M08,adc_,ADC_,CLKIN,DRDY,oscillator,frequency,io\[\?\?\],user_project_wrapper || true
  echo "\`\`\`"
} > "${OUT_MD}"

echo "Wrote: ${OUT_MD}"