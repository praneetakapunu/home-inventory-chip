#!/usr/bin/env bash
# Update all derived regmap artifacts from the YAML source-of-truth.
#
# Usage:
#   bash ops/regmap_update.sh
#
# This script is intentionally lightweight so it can run in CI and on dev boxes.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

YAML="spec/regmap_v1.yaml"
HDR_OUT="fw/include/home_inventory_regmap.h"
SVPKG_OUT="rtl/include/home_inventory_regmap_pkg.sv"

python3 ops/regmap_validate.py --yaml "$YAML"

python3 ops/gen_regmap_header.py \
  --yaml "$YAML" \
  --out  "$HDR_OUT"

python3 ops/gen_regmap_sv_pkg.py \
  --yaml "$YAML" \
  --out  "$SVPKG_OUT"

echo ""
echo "Regmap artifacts updated from: $YAML"
echo " - $HDR_OUT"
echo " - $SVPKG_OUT"
echo ""
echo "Git status (if anything changed):"
git status --porcelain=v1 || true
