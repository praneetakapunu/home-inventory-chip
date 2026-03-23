#!/usr/bin/env bash
set -euo pipefail

# harness_contract_summary.sh
#
# Purpose:
#   One-command, low-disk summary of harness integration contracts that tend to
#   drift (ADC pinout/clocking/streaming + WB wiring).
#
# Why:
#   We have several focused audit scripts. This wrapper runs them in a stable
#   order and prints a short, grep-friendly transcript that can be pasted into
#   issues/PRs.
#
# Usage:
#   tools/harness_contract_summary.sh ../home-inventory-chip-openmpw
#
# Notes:
#   - This does NOT require toolchains (no iverilog, no OpenLane).
#   - It is safe to run in low-disk environments.

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-harness-repo>" >&2
  exit 2
fi

HARNESS_DIR="$1"
if [[ ! -d "$HARNESS_DIR" ]]; then
  echo "ERROR: harness dir not found: $HARNESS_DIR" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

banner() {
  local title="$1"
  echo ""
  echo "================================================================================"
  echo "$title"
  echo "================================================================================"
}

banner "Harness contract summary"
echo "IP repo:      $ROOT_DIR"
echo "Harness repo: $(cd "$HARNESS_DIR" && pwd)"

echo ""
echo "Tip: for strict fail-fast placeholder checks, run the *_placeholder_check.sh scripts."

banner "ADC pinout (io[*] mapping evidence)"
bash "$ROOT_DIR/tools/harness_adc_pinout_audit.sh" "$HARNESS_DIR" || true

banner "ADC DRDY naming/polarity evidence"
bash "$ROOT_DIR/tools/harness_adc_drdy_audit.sh" "$HARNESS_DIR" || true

banner "ADC clocking (CLKIN source/frequency evidence)"
bash "$ROOT_DIR/tools/harness_adc_clocking_audit.sh" "$HARNESS_DIR" || true

banner "ADC streaming/real-ingest wiring surfaces"
bash "$ROOT_DIR/tools/harness_adc_streaming_audit.sh" "$HARNESS_DIR" || true

banner "Event detector wiring surfaces"
bash "$ROOT_DIR/tools/harness_event_detector_audit.sh" "$HARNESS_DIR" || true

banner "Wishbone wiring surfaces"
bash "$ROOT_DIR/tools/harness_wb_wiring_audit.sh" "$HARNESS_DIR" || true

banner "Done"
