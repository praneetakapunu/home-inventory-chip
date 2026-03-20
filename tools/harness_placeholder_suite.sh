#!/usr/bin/env bash
set -euo pipefail

# Harness placeholder suite: run all fail-fast placeholder checks against the
# harness repo.
#
# Purpose:
# - Keep tapeout-critical unknowns from silently lingering in the harness.
# - Provide a single command that can be run locally or in low-disk CI.
#
# This suite intentionally uses grep/ripgrep-only checks (no OpenLane / precheck).
#
# Usage:
#   tools/harness_placeholder_suite.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw
#
# Exit codes:
#   0  all checks pass
#   1  at least one placeholder detected
#   2  harness path/file missing (propagated)

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

checks=(
  "${here}/harness_adc_pinout_placeholder_check.sh"
  "${here}/harness_adc_clocking_placeholder_check.sh"
  "${here}/harness_adc_drdy_placeholder_check.sh"
  "${here}/harness_adc_streaming_placeholder_check.sh"
  "${here}/harness_event_detector_placeholder_check.sh"
  "${here}/harness_wb_wiring_placeholder_check.sh"
)

fail=0

echo "== Harness placeholder suite =="
echo "Harness: ${HARNESS_REPO}"
echo

for c in "${checks[@]}"; do
  echo "-- Running: $(basename "$c")"
  if ! bash "$c" "$HARNESS_REPO"; then
    rc=$?
    # If a check reports missing harness, stop immediately (signal caller misconfig)
    if [[ "$rc" -eq 2 ]]; then
      exit 2
    fi
    fail=1
  fi
  echo
done

if [[ "$fail" -ne 0 ]]; then
  echo "FAIL: one or more placeholders remain in the harness."
  exit 1
fi

echo "OK: placeholder suite passed."
