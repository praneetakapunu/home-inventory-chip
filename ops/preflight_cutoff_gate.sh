#!/usr/bin/env bash
set -euo pipefail

# preflight_cutoff_gate.sh
#
# Purpose:
#   A strict "are we ready to commit to a shuttle cutoff" gate.
#
# Why this exists:
#   - We run low-disk preflight often during development.
#   - But once we pick a shuttle cutoff, we need strict checks that:
#       (1) the lock record is truly LOCKED (not just "no TBD"), and
#       (2) the lock record was verified recently (staleness gate), and
#       (3) the internal safe deadline has not already passed.
#
# What it runs:
#   - ops/preflight_low_disk.sh (RTL compile + regmap + smoke sims)
#   - ops/check_shuttle_lock_record.sh --strict
#   - ops/shuttle_runway.py --strict
#
# Usage:
#   bash ops/preflight_cutoff_gate.sh
#
# Tuning:
#   STALE_DAYS=7 bash ops/preflight_cutoff_gate.sh

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

banner() { echo "==> $*"; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

need_cmd bash
need_cmd python3

banner "Low-disk preflight (baseline)"
bash ops/preflight_low_disk.sh

banner "ADC framing params (strict sanity)"
# Extra redundancy: this gate is cheap and catches accidental RTL contract drift.
bash ops/check_adc_framing_params.sh

banner "Shuttle lock record (STRICT)"
bash ops/check_shuttle_lock_record.sh --strict

banner "Required decisions are locked (STRICT)"
# Ensure tapeout-critical decision docs are not still Proposed/TBD.
bash ops/check_required_decisions.sh --strict

banner "Shuttle runway (STRICT)"
# Fail if the deadline is in the past OR if the record is stale (see --stale-days).
python3 ops/shuttle_runway.py --strict --stale-days "${STALE_DAYS:-7}"

HARNESS_REPO_DEFAULT="../home-inventory-chip-openmpw"
HARNESS_REPO_PATH="${HARNESS_REPO:-$HARNESS_REPO_DEFAULT}"

banner "ADC pinout contract (STRICT)"
# Also validate the harness repo isn't still using placeholder io[*] mappings.
bash ops/check_adc_pinout_contract.sh --strict --harness "$HARNESS_REPO_PATH"

banner "ADC CLKIN contract (STRICT)"
# Also validate the harness repo has concrete CLKIN evidence (io[*] mapping or oscillator+freq).
bash ops/check_adc_clkin_contract.sh --strict --harness "$HARNESS_REPO_PATH"

banner "ADC streaming contract (STRICT)"
# Validate the streaming contract doc has no placeholders and the harness isn't using stub wiring.
bash ops/check_adc_streaming_contract.sh --strict --harness "$HARNESS_REPO_PATH"

banner "DONE: cutoff gate passed"
