#!/usr/bin/env bash
# Preflight gate: regmap consistency (low-disk).
#
# Runs chip-inventory's internal regmap checks and (optionally) verifies that the
# harness repo's IP submodule copy matches this repo.
#
# Usage:
#   bash ops/preflight_regmap_gate.sh
#   bash ops/preflight_regmap_gate.sh --harness ../home-inventory-chip-openmpw
#
# Exit codes:
#   0 = OK
#   2 = bad usage / missing deps
#   3 = regmap drift vs harness detected
#   4 = internal regmap check failed

set -euo pipefail

HARNESS_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness)
      HARNESS_ROOT="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "usage: $0 [--harness <path-to-home-inventory-chip-openmpw>]" >&2
      exit 0
      ;;
    *)
      echo "ERROR: unknown arg: $1" >&2
      echo "usage: $0 [--harness <path-to-home-inventory-chip-openmpw>]" >&2
      exit 2
      ;;
  esac
done

echo "[regmap] running internal consistency checks..."
if ! bash ops/regmap_check.sh >/dev/null; then
  echo "FAIL: ops/regmap_check.sh failed" >&2
  exit 4
fi

# Keep this gate tool-light: these verify targets should not pull in OpenLane.
if [[ -f verify/Makefile ]]; then
  echo "[regmap] running generator drift checks (verify/regmap-*)..."
  make -C verify regmap-check >/dev/null
  make -C verify regmap-gen-check >/dev/null
fi

echo "[regmap] OK: chip-inventory regmap is self-consistent."

if [[ -n "${HARNESS_ROOT}" ]]; then
  echo "[regmap] checking drift vs harness submodule copy..."
  tools/harness_regmap_drift_check.sh "${HARNESS_ROOT}" >/dev/null
  echo "[regmap] OK: no drift vs harness." 
fi

echo "OK: regmap gate passed." 
