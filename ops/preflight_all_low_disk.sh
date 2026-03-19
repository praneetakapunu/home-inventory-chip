#!/usr/bin/env bash
set -euo pipefail

# Cross-repo low-disk preflight.
#
# This is the "one command" sanity suite for the v1 OpenMPW path:
# - Runs the IP repo low-disk preflight (RTL compile, regmap drift, smoke sims)
# - Optionally runs the harness repo lightweight compile checks (if present)
#
# It intentionally avoids heavy OpenLane/hardening flows.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

banner() { echo "==> $*"; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

banner "IP repo: low-disk preflight"
bash ops/preflight_low_disk.sh

HARNESS_DIR_DEFAULT="$ROOT_DIR/../home-inventory-chip-openmpw"
HARNESS_DIR="${1:-$HARNESS_DIR_DEFAULT}"

if [[ ! -d "$HARNESS_DIR" ]]; then
  banner "Harness repo: SKIP (not found)"
  echo "Looked for harness at: $HARNESS_DIR" >&2
  echo "Tip: run: bash ops/preflight_all_low_disk.sh /path/to/home-inventory-chip-openmpw" >&2
  exit 0
fi

banner "Harness repo: sync IP filelist + RTL compile-check(s)"
(
  cd "$HARNESS_DIR" || die "failed to cd to harness dir: $HARNESS_DIR"
  make sync-ip-filelist
  make rtl-compile-check

  # Optional, but strongly preferred: compile-check the real ADC ingest build.
  # Not all harness branches may have the target yet.
  if make -q rtl-compile-check-real-adc >/dev/null 2>&1 || make -n rtl-compile-check-real-adc >/dev/null 2>&1; then
    make rtl-compile-check-real-adc
  else
    banner "Harness repo: WARN (no make target rtl-compile-check-real-adc)"
  fi
)

banner "Harness repo: lightweight grep-based audits (no toolchain)"
# These are intentionally grep-based so they still work on low-disk / minimal setups.
# They help catch integration drift early (pin names, clocking assumptions, wiring stubs).
bash tools/harness_adc_clocking_audit.sh "$HARNESS_DIR"
# Placeholder clocking markers are a tapeout-risk item.
# Keep this as a WARN by default so we can still run integration checks while the clock source/freq is pending.
# To make it a hard failure, set: REQUIRE_NO_ADC_CLOCKING_PLACEHOLDERS=1
if ! bash tools/harness_adc_clocking_placeholder_check.sh "$HARNESS_DIR"; then
  if [[ "${REQUIRE_NO_ADC_CLOCKING_PLACEHOLDERS:-0}" == "1" ]]; then
    die "ADC clocking placeholders still present in harness"
  fi
  banner "Harness repo: WARN (ADC clocking placeholders detected; see output above)"
fi

bash tools/harness_adc_pinout_audit.sh "$HARNESS_DIR"
# Placeholder io[*] indices are a tapeout-risk item.
# Keep this as a WARN by default so we can still run integration checks while the mapping is pending.
# To make it a hard failure, set: REQUIRE_NO_ADC_PINOUT_PLACEHOLDERS=1
if ! bash tools/harness_adc_pinout_placeholder_check.sh "$HARNESS_DIR"; then
  if [[ "${REQUIRE_NO_ADC_PINOUT_PLACEHOLDERS:-0}" == "1" ]]; then
    die "ADC pinout placeholder io[*] indices still present in harness"
  fi
  banner "Harness repo: WARN (ADC pinout placeholders detected; see output above)"
fi

bash tools/harness_adc_streaming_audit.sh "$HARNESS_DIR"
# Placeholder streaming markers are a tapeout-risk item.
# Keep this as a WARN by default so the suite still runs before wiring is finalized.
# To make it a hard failure, set: REQUIRE_NO_ADC_STREAMING_PLACEHOLDERS=1
if ! bash tools/harness_adc_streaming_placeholder_check.sh "$HARNESS_DIR"; then
  if [[ "${REQUIRE_NO_ADC_STREAMING_PLACEHOLDERS:-0}" == "1" ]]; then
    die "ADC streaming placeholders still present in harness"
  fi
  banner "Harness repo: WARN (ADC streaming placeholders detected; see output above)"
fi

bash tools/harness_event_detector_audit.sh "$HARNESS_DIR"
bash tools/harness_wb_wiring_audit.sh "$HARNESS_DIR"

banner "Harness repo: placeholder suite (fail-fast placeholders)"
# This suite is a concentrated signal on tapeout-critical unknowns.
# By default it is a WARN so we can keep running integration checks while
# pinout/clocking are still being finalized. To make it a hard failure:
#   REQUIRE_NO_HARNESS_PLACEHOLDERS=1
if ! bash tools/harness_placeholder_suite.sh "$HARNESS_DIR"; then
  if [[ "${REQUIRE_NO_HARNESS_PLACEHOLDERS:-0}" == "1" ]]; then
    die "Harness placeholders still present (see output above)"
  fi
  banner "Harness repo: WARN (placeholders detected; see output above)"
fi

banner "DONE: cross-repo low-disk preflight checks passed"
