#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

HARNESS_DIR="$1"
UPW="$HARNESS_DIR/verilog/rtl/user_project_wrapper.v"
HIP="$HARNESS_DIR/verilog/rtl/home_inventory_user_project.v"

if [[ ! -f "$UPW" ]]; then
  echo "ERROR: missing: $UPW" >&2
  exit 1
fi

echo "# Wishbone wiring evidence (path:line)"
echo "# harness: $HARNESS_DIR"
echo

show_grep() {
  local pattern="$1"
  local file="$2"
  echo "## $file :: /$pattern/"
  # -n: line numbers; -H: show filename; keep output stable
  grep -nH -E "$pattern" "$file" || true
  echo
}

show_grep "\\.wb_clk_i\\(" "$UPW"
show_grep "\\.wb_rst_i\\(" "$UPW"
show_grep "user_clock2" "$UPW"

if [[ -f "$HIP" ]]; then
  echo "# home_inventory_user_project ports (sanity)"
  show_grep "wb_clk_i" "$HIP"
  show_grep "wb_rst_i" "$HIP"
  show_grep "user_clock2" "$HIP"
else
  echo "WARN: missing (optional): $HIP" >&2
fi
