#!/usr/bin/env bash
# Compare regmap source + generated artifacts between:
#   - chip-inventory (source-of-truth)
#   - home-inventory-chip-openmpw/ip/home-inventory-chip (harness submodule copy)
#
# This is a *low-disk, tool-light* drift check. It does not run OpenLane.
#
# Usage:
#   tools/harness_regmap_drift_check.sh ../home-inventory-chip-openmpw
#
# Exit codes:
#   0 = no drift detected
#   2 = missing expected files
#   3 = diff detected
#   4 = regmap_check failed in chip-inventory

set -euo pipefail

HARNESS_ROOT="${1:-}"
if [[ -z "${HARNESS_ROOT}" ]]; then
  echo "usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

# Resolve paths (best-effort) while keeping behavior portable.
if command -v realpath >/dev/null 2>&1; then
  HARNESS_ROOT="$(realpath "${HARNESS_ROOT}")"
fi

IP_SUBMODULE="${HARNESS_ROOT}/ip/home-inventory-chip"

if [[ ! -d "${IP_SUBMODULE}" ]]; then
  echo "ERROR: expected IP submodule directory not found: ${IP_SUBMODULE}" >&2
  echo "Hint: are you pointing at the harness repo root?" >&2
  exit 2
fi

# Run chip-inventory's own internal regmap drift check first.
# This ensures our generated artifacts are consistent before we compare repos.
if ! bash ops/regmap_check.sh >/dev/null; then
  echo "ERROR: ops/regmap_check.sh failed in chip-inventory; fix this repo first." >&2
  exit 4
fi

# Canonical files in chip-inventory
declare -a FILES=(
  "spec/regmap_v1.yaml"
  "spec/regmap_v1_table.md"
  "fw/include/home_inventory_regmap.h"
  "rtl/include/home_inventory_regmap_pkg.sv"
  "rtl/include/regmap_params.vh"
)

missing=0
for f in "${FILES[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "ERROR: missing in chip-inventory: ${f}" >&2
    missing=1
  fi

  # Missing/empty in harness submodule is treated as drift (it means the
  # submodule pointer is behind or artifacts weren't committed).
  if [[ ! -f "${IP_SUBMODULE}/${f}" ]]; then
    echo "DRIFT: missing in harness submodule: ${IP_SUBMODULE}/${f}" >&2
    missing=1
    continue
  fi
  if [[ ! -s "${IP_SUBMODULE}/${f}" ]]; then
    echo "DRIFT: empty file in harness submodule: ${IP_SUBMODULE}/${f}" >&2
    missing=1
  fi

done

if [[ ${missing} -ne 0 ]]; then
  echo "FAIL: required regmap files are missing in one repo; treating as drift." >&2
  exit 3
fi

drift=0
for f in "${FILES[@]}"; do
  if ! diff -u "${f}" "${IP_SUBMODULE}/${f}" >/dev/null; then
    echo "--- DRIFT DETECTED: ${f}"
    diff -u "${f}" "${IP_SUBMODULE}/${f}" || true
    echo
    drift=1
  fi

done

if [[ ${drift} -ne 0 ]]; then
  echo "FAIL: regmap drift detected between chip-inventory and harness submodule." >&2
  echo "Fix by updating the harness submodule pointer and syncing any derived artifacts." >&2
  echo "In the harness repo (home-inventory-chip-openmpw):" >&2
  echo "  git submodule update --init --recursive" >&2
  echo "  (then commit the updated submodule SHA)" >&2
  exit 3
fi

echo "OK: regmap source + generated artifacts match harness submodule."
