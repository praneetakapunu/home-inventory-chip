#!/usr/bin/env bash
set -euo pipefail

# gate_status_summary.sh
#
# Purpose:
#   One-page human-readable summary of tapeout-critical “gates” for this repo.
#   Intended for low-disk environments; relies on lightweight grep-based checks.
#
# Usage:
#   bash ops/gate_status_summary.sh
#   bash ops/gate_status_summary.sh --strict
#   HARNESS_DIR=../home-inventory-chip-openmpw bash ops/gate_status_summary.sh
#
# Behavior:
#   - Default: prints a summary and exits 0 (even if some gates are failing).
#   - Strict: exits non-zero if any gate check fails.

STRICT=0
if [[ "${1:-}" == "--strict" ]]; then
  STRICT=1
elif [[ -n "${1:-}" ]]; then
  echo "Unknown arg: $1" >&2
  echo "Usage: $0 [--strict]" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS_DIR="${HARNESS_DIR:-$ROOT_DIR/../home-inventory-chip-openmpw}"

ok()   { printf "%-38s %s\n" "$1" "OK"; }
warn() { printf "%-38s %s\n" "$1" "WARN"; }
fail() { printf "%-38s %s\n" "$1" "FAIL"; }

run_gate() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    ok "$name"
    return 0
  else
    if [[ "$STRICT" -eq 1 ]]; then
      fail "$name"
      return 1
    fi
    warn "$name"
    return 0
  fi
}

printf "Tapeout gate summary (chip-inventory)\n"
printf "  repo:    %s\n" "$ROOT_DIR"
printf "  harness: %s\n\n" "$HARNESS_DIR"

# Shuttle / schedule
run_gate "Shuttle lock record (strict)" bash "$ROOT_DIR/ops/check_shuttle_lock_record.sh" --strict || exit 1

# Decisions that must exist/avoid placeholders.
run_gate "Required decisions present" bash "$ROOT_DIR/ops/check_required_decisions.sh" || exit 1

# ADC contracts (these are process gates; strict mode should fail if placeholders exist).
run_gate "ADC pinout contract (strict)" bash "$ROOT_DIR/ops/check_adc_pinout_contract.sh" --strict || exit 1
run_gate "ADC CLKIN contract (strict)" bash "$ROOT_DIR/ops/check_adc_clkin_contract.sh" --strict || exit 1
run_gate "ADC DRDY contract (strict)" bash "$ROOT_DIR/ops/check_adc_drdy_contract.sh" --strict || exit 1
run_gate "ADC streaming contract (strict)" bash "$ROOT_DIR/ops/check_adc_streaming_contract.sh" --strict || exit 1

# Harness placeholder sweep (grep-based; quick signal for integration readiness)
if [[ -d "$HARNESS_DIR" ]]; then
  run_gate "Harness placeholder suite" bash "$ROOT_DIR/tools/harness_placeholder_suite.sh" "$HARNESS_DIR" || exit 1
else
  if [[ "$STRICT" -eq 1 ]]; then
    echo "ERROR: HARNESS_DIR not found: $HARNESS_DIR" >&2
    exit 1
  fi
  warn "Harness placeholder suite (missing harness dir)"
fi

printf "\nTip: default mode prints WARN without failing; use --strict for CI/gating.\n"
