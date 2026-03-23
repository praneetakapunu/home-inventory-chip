#!/usr/bin/env bash
set -euo pipefail

# check_adc_contracts.sh
#
# Purpose:
#   One-stop checker for all ADC tapeout-critical contracts:
#     - pinout mapping contract
#     - CLKIN source/frequency contract
#     - streaming FIFO/ingest contract
#
# Why:
#   These checks are intentionally simple + text-based so they run on low-disk
#   setups and can be embedded in CI / preflight scripts.
#
# Usage:
#   bash ops/check_adc_contracts.sh
#   bash ops/check_adc_contracts.sh --strict
#   bash ops/check_adc_contracts.sh --harness ../home-inventory-chip-openmpw
#   bash ops/check_adc_contracts.sh --strict --harness ../home-inventory-chip-openmpw

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
      sed -n '1,120p' "$0"
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

strict_flag=""
if [[ $STRICT -eq 1 ]]; then
  strict_flag="--strict"
fi

banner() { echo "==> $*"; }

banner "ADC pinout contract ${STRICT:+(STRICT)}"
if [[ -n "$HARNESS_REPO" ]]; then
  bash ops/check_adc_pinout_contract.sh $strict_flag --harness "$HARNESS_REPO"
else
  bash ops/check_adc_pinout_contract.sh $strict_flag
fi

banner "ADC CLKIN contract ${STRICT:+(STRICT)}"
if [[ -n "$HARNESS_REPO" ]]; then
  bash ops/check_adc_clkin_contract.sh $strict_flag --harness "$HARNESS_REPO"
else
  bash ops/check_adc_clkin_contract.sh $strict_flag
fi

banner "ADC streaming contract ${STRICT:+(STRICT)}"
if [[ -n "$HARNESS_REPO" ]]; then
  bash ops/check_adc_streaming_contract.sh $strict_flag --harness "$HARNESS_REPO"
else
  bash ops/check_adc_streaming_contract.sh $strict_flag
fi

banner "ADC DRDY naming/polarity contract ${STRICT:+(STRICT)}"
if [[ -n "$HARNESS_REPO" ]]; then
  bash ops/check_adc_drdy_contract.sh $strict_flag --harness "$HARNESS_REPO"
else
  bash ops/check_adc_drdy_contract.sh $strict_flag
fi

banner "DONE: ADC contract checks passed"