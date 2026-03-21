#!/usr/bin/env bash
# preflight_ip_and_harness_low_disk.sh
#
# Runs the "low disk" readiness checks across BOTH repos:
#  - IP repo: chip-inventory
#  - Harness repo: home-inventory-chip-openmpw
#
# This is intentionally lightweight: it avoids OpenLane hardening and focuses on
# RTL/DV + integration wiring staying green.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Allow override for non-standard layouts.
HARNESS_REPO="${HARNESS_REPO:-${ROOT_DIR%/chip-inventory}/home-inventory-chip-openmpw}"

STRICT=0

usage() {
  cat <<'EOF'
Usage: bash ops/preflight_ip_and_harness_low_disk.sh [--strict]

Runs low-disk preflight checks across BOTH repos:
  - chip-inventory (IP)
  - home-inventory-chip-openmpw (harness)

Options:
  --strict   Also run fail-fast placeholder checks against the harness repo
             (e.g., ADC pinout/clocking placeholders).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

say() { printf "%s\n" "$*"; }

say "[preflight] IP repo:      ${ROOT_DIR}"
say "[preflight] Harness repo:  ${HARNESS_REPO}"
say "[preflight] Strict mode:   ${STRICT}" 

if [[ ! -d "${HARNESS_REPO}" ]]; then
  say "ERROR: harness repo not found at: ${HARNESS_REPO}"
  say "Set HARNESS_REPO=/abs/path/to/home-inventory-chip-openmpw and retry."
  exit 2
fi

# 1) IP repo checks
say "[preflight] (1/2) chip-inventory: ops/preflight_low_disk.sh"
(
  cd "${ROOT_DIR}"
  bash ops/preflight_low_disk.sh
)

# Helpers
have_make_target() {
  # Best-effort: checks whether a Makefile defines a given target.
  # Avoids failing the whole preflight when optional targets aren't present.
  local target="$1"
  if [[ ! -f Makefile ]]; then
    return 1
  fi
  make -nqp 2>/dev/null | grep -Eq "^${target}:([^=]|$)"
}

# 2) Harness repo checks
say "[preflight] (2/2) home-inventory-chip-openmpw: sync filelist + verify drift + rtl compile checks"
(
  cd "${HARNESS_REPO}"

  # Keep the harness-consumed filelist in sync with the IP repo, then verify it
  # matches the canonical source-of-truth.
  if have_make_target "sync-ip-filelist"; then
    make sync-ip-filelist
  else
    say "[preflight] WARNING: harness Makefile has no 'sync-ip-filelist' target; skipping. (Check harness repo layout.)"
  fi

  bash "${ROOT_DIR}/tools/harness/check_harness_filelist.sh" --harness-root .

  # Fast sanity compile (default + real-ADC wiring) to catch wrapper/port drift
  # without running any DV or OpenLane.
  if have_make_target "rtl-compile-check"; then
    make rtl-compile-check
  else
    say "[preflight] WARNING: harness Makefile has no 'rtl-compile-check' target; skipping."
  fi

  # Optional: some harness repos may not yet have the REAL-ADC wrapper wiring target.
  if have_make_target "rtl-compile-check-real-adc"; then
    make rtl-compile-check-real-adc
  else
    say "[preflight] NOTE: no 'rtl-compile-check-real-adc' target in harness; skipping (OK for early integration)."
  fi

  # Grep-based audits (no toolchain): catch integration drift early even on low-disk setups.
  say "[preflight] Harness repo: grep-based audits (no toolchain)"
  bash "${ROOT_DIR}/tools/harness_adc_clocking_audit.sh" .
  bash "${ROOT_DIR}/tools/harness_adc_pinout_audit.sh" .
  bash "${ROOT_DIR}/tools/harness_adc_streaming_audit.sh" .
  bash "${ROOT_DIR}/tools/harness_event_detector_audit.sh" .

  if [[ "${STRICT}" -eq 1 ]]; then
    say "[preflight] Harness repo: strict placeholder checks (fail-fast)"
    bash "${ROOT_DIR}/tools/harness_adc_clocking_placeholder_check.sh" .
    bash "${ROOT_DIR}/tools/harness_adc_pinout_placeholder_check.sh" .
    bash "${ROOT_DIR}/tools/harness_adc_streaming_placeholder_check.sh" .
    bash "${ROOT_DIR}/tools/harness_event_detector_placeholder_check.sh" .
    bash "${ROOT_DIR}/tools/harness_wb_wiring_placeholder_check.sh" .
  fi
)

say "[preflight] OK: IP + harness low-disk readiness checks passed."
