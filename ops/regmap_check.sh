#!/usr/bin/env bash
# Verify that all derived regmap artifacts are in sync with the YAML source-of-truth.
#
# This is CI-friendly and low-disk: it re-runs generation and then fails if git
# shows any diffs.
#
# Usage:
#   bash ops/regmap_check.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
need_cmd git
need_cmd python3

banner "Regmap: validate + regenerate derived artifacts"
bash ops/regmap_update.sh >/dev/null

banner "Regmap: check for generation drift (git diff)"
# Limit the diff check to derived artifacts to avoid false failures when other
# files are dirty.
PATHS=(
  spec/regmap_v1_table.md
  fw/include/home_inventory_regmap.h
  rtl/include/home_inventory_regmap_pkg.sv
  rtl/include/regmap_params.vh
)

# If any of these files are missing, that's also a failure.
for p in "${PATHS[@]}"; do
  [[ -f "$p" ]] || die "expected regmap artifact missing: $p"
done

if ! git diff --exit-code -- "${PATHS[@]}" >/dev/null; then
  echo ""
  echo "Regmap artifacts are OUT OF DATE relative to spec/regmap_v1.yaml."
  echo "Run: bash ops/regmap_update.sh" 
  echo "Then commit the updated artifacts."
  echo ""
  echo "Changed files:"
  git diff --name-only -- "${PATHS[@]}" || true
  echo ""
  echo "Diff (first 200 lines):"
  git diff -- "${PATHS[@]}" | sed -n '1,200p' || true
  exit 2
fi

banner "Regmap: OK (no drift)"
