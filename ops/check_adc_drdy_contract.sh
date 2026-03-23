#!/usr/bin/env bash
set -euo pipefail

# check_adc_drdy_contract.sh
#
# Purpose:
#   Enforce a *polarity-explicit* DRDY naming contract in the submission harness.
#
# Background:
#   ADS131M08 DRDY is active-low. We standardize on the net name `adc_drdy_n`
#   in the harness wrapper to prevent late-stage polarity mistakes.
#
# What this checks:
#   - In harness wrapper verilog, require:
#       wire adc_drdy_n;
#       assign adc_drdy_n = io_in[ADC_DRDYN_IO];
#   - Forbid ambiguous `adc_drdy` net naming.
#
# Why text-only:
#   This is intended to run on low-disk environments and in CI without
#   requiring a full toolchain.
#
# Usage:
#   bash ops/check_adc_drdy_contract.sh
#   bash ops/check_adc_drdy_contract.sh --strict
#   bash ops/check_adc_drdy_contract.sh --harness ../home-inventory-chip-openmpw
#   bash ops/check_adc_drdy_contract.sh --strict --harness ../home-inventory-chip-openmpw

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

STRICT=0
HARNESS_REPO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    --harness)
      HARNESS_REPO="${2:-}"
      [[ -z "$HARNESS_REPO" ]] && { echo "ERROR: --harness requires a path" >&2; exit 2; }
      shift 2
      ;;
    -h|--help)
      sed -n '1,200p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

HARNESS_REPO_DEFAULT="../home-inventory-chip-openmpw"
if [[ -z "$HARNESS_REPO" && -d "$HARNESS_REPO_DEFAULT" ]]; then
  HARNESS_REPO="$HARNESS_REPO_DEFAULT"
fi

if [[ -z "$HARNESS_REPO" ]]; then
  if [[ $STRICT -eq 1 ]]; then
    cat <<'EOF' >&2
ERROR: --strict requires a harness repo path.

Provide the harness checkout path, e.g.:
  bash ops/check_adc_drdy_contract.sh --strict --harness ../home-inventory-chip-openmpw
EOF
    exit 2
  fi

  echo "WARN: no harness repo found/passed; skipping DRDY harness contract check."
  echo "      (pass --harness PATH to enable)"
  exit 0
fi

# Delegate to the grep-based harness check.
bash tools/harness_adc_drdy_placeholder_check.sh "$HARNESS_REPO"
