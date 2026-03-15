#!/usr/bin/env bash
set -euo pipefail

# Run all low-disk harness audits from the chip-inventory repo.
#
# Usage:
#   tools/harness/harness_audit_all.sh ../home-inventory-chip-openmpw
#
# This script is intentionally grep-based (no OpenLane / Docker) and should run
# even when disk space is tight.

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <path-to-harness-repo>" >&2
  exit 2
fi

HARNESS_DIR="$1"
if [[ ! -d "$HARNESS_DIR" ]]; then
  echo "ERROR: harness repo dir not found: $HARNESS_DIR" >&2
  exit 2
fi

# Resolve repo root (chip-inventory)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

run_one() {
  local name="$1"; shift
  local cmd=("$@");

  echo ""
  echo "===================="
  echo "AUDIT: ${name}"
  echo "CMD:   ${cmd[*]}"
  echo "===================="

  if "${cmd[@]}"; then
    echo "RESULT: PASS (${name})"
    return 0
  else
    echo "RESULT: FAIL (${name})" >&2
    return 1
  fi
}

fail=0

run_one "harness filelist audit" \
  "${REPO_ROOT}/tools/harness/audit_harness_filelist.sh" --harness-root "${HARNESS_DIR}" || fail=1

run_one "ADC pinout audit" \
  "${REPO_ROOT}/tools/harness_adc_pinout_audit.sh" "${HARNESS_DIR}" || fail=1

run_one "ADC clocking audit" \
  "${REPO_ROOT}/tools/harness_adc_clocking_audit.sh" "${HARNESS_DIR}" || fail=1

run_one "ADC streaming audit" \
  "${REPO_ROOT}/tools/harness_adc_streaming_audit.sh" "${HARNESS_DIR}" || fail=1

run_one "event detector audit" \
  "${REPO_ROOT}/tools/harness_event_detector_audit.sh" "${HARNESS_DIR}" || fail=1

echo ""
echo "===================="
if [[ $fail -eq 0 ]]; then
  echo "ALL HARNESS AUDITS: PASS"
else
  echo "ALL HARNESS AUDITS: FAIL" >&2
fi
echo "===================="

exit $fail
