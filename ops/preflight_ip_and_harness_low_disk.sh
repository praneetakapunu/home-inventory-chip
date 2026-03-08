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

say() { printf "%s\n" "$*"; }

say "[preflight] IP repo:      ${ROOT_DIR}"
say "[preflight] Harness repo:  ${HARNESS_REPO}"

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

# 2) Harness repo checks
say "[preflight] (2/2) home-inventory-chip-openmpw: make sync-ip-filelist + rtl-compile-check"
(
  cd "${HARNESS_REPO}"
  make sync-ip-filelist
  make rtl-compile-check
)

say "[preflight] OK: IP + harness low-disk readiness checks passed."
