#!/usr/bin/env bash
set -euo pipefail

# check_adc_framing_params.sh
#
# Purpose:
#   Fail fast if our RTL instantiation of the real ADS131M08 ingest path drifts
#   from the v1 framing assumptions documented in:
#     - spec/ads131m08_interface.md
#     - rtl/home_inventory_wb.v (USE_REAL_ADC_INGEST block)
#
# v1 framing assumptions (normative for first silicon):
#   - 24-bit words on the wire
#   - 10 words per conversion frame (STATUS + CH0..CH7 + OUTPUT_CRC)
#   - drop OUTPUT_CRC in v1 FIFO output => WORDS_OUT = 9
#
# This is intentionally a *grep-style* gate (no heavy parsing / no toolchain).

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 2
  }
}

need_cmd rg

FILE="rtl/home_inventory_wb.v"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: missing $FILE" >&2
  exit 2
fi

# Only enforce when the USE_REAL_ADC_INGEST instantiation exists in the file.
if ! rg -q '`ifdef USE_REAL_ADC_INGEST' "$FILE"; then
  echo "ERROR: expected USE_REAL_ADC_INGEST block not found in $FILE" >&2
  exit 2
fi

need() {
  local pat="$1"
  local msg="$2"
  if ! rg -n "$pat" "$FILE" >/dev/null; then
    echo "ERROR: $msg" >&2
    echo "  missing pattern: $pat" >&2
    exit 1
  fi
}

need "adc_streaming_ingest" "expected adc_streaming_ingest instantiation in $FILE"
need "\\.BITS_PER_WORD\\(24\\)" "v1 expects BITS_PER_WORD=24 (ADS131M08 default word length on-wire)"
need "\\.WORDS_PER_FRAME\\(10\\)" "v1 expects WORDS_PER_FRAME=10 (STATUS+8ch+CRC)"
need "\\.WORDS_OUT\\(9\\)" "v1 expects WORDS_OUT=9 (CRC dropped before FIFO/regmap)"

echo "PASS: ADC framing params match v1 assumptions (24-bit, 10 words/frame, 9 words out)"