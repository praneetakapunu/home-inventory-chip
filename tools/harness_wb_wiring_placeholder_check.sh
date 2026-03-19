#!/usr/bin/env bash
set -euo pipefail

# Fail-fast helper: sanity-check that the harness repo wires Wishbone clock/reset
# in the expected, non-placeholder way.
#
# Why:
# - Tapeout risk if wb_clk_i / wb_rst_i are accidentally tied off, renamed, or
#   cross-wired.
# - This is a grep-only check intended for low-disk CI.
#
# Usage:
#   tools/harness_wb_wiring_placeholder_check.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"
UPW_REL="verilog/rtl/user_project_wrapper.v"
HIP_REL="verilog/rtl/home_inventory_user_project.v"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  exit 2
fi

UPW="$HARNESS_REPO/$UPW_REL"
HIP="$HARNESS_REPO/$HIP_REL"

if [[ ! -f "$UPW" ]]; then
  echo "ERROR: expected harness file not found: $UPW" >&2
  exit 2
fi
if [[ ! -f "$HIP" ]]; then
  echo "ERROR: expected harness file not found: $HIP" >&2
  exit 2
fi

echo "== Checking harness Wishbone wiring placeholders =="
echo "Harness: $HARNESS_REPO"
echo "Files:   $UPW_REL, $HIP_REL"

fail=0

# 1) Ensure the wrapper instantiates our project and wires wb_clk_i/wb_rst_i by name.
if ! rg -n "home_inventory_user_project[[:space:]]+mprj" "$UPW" >/dev/null; then
  echo "PLACEHOLDER: user_project_wrapper does not instantiate home_inventory_user_project mprj" >&2
  fail=1
fi

# Expected wiring: .wb_clk_i(wb_clk_i) and .wb_rst_i(wb_rst_i)
if ! rg -n "\\.wb_clk_i\\(wb_clk_i\\)" "$UPW" >/dev/null; then
  echo "PLACEHOLDER: missing expected .wb_clk_i(wb_clk_i) wiring in user_project_wrapper" >&2
  fail=1
fi
if ! rg -n "\\.wb_rst_i\\(wb_rst_i\\)" "$UPW" >/dev/null; then
  echo "PLACEHOLDER: missing expected .wb_rst_i(wb_rst_i) wiring in user_project_wrapper" >&2
  fail=1
fi

# Guardrail: reject accidental wiring to user_clock2 (seen in some templates).
if rg -n "\\.wb_clk_i\\(user_clock2\\)" "$UPW" >/dev/null; then
  echo "PLACEHOLDER: wb_clk_i is incorrectly wired to user_clock2 in user_project_wrapper" >&2
  fail=1
fi

# 2) Ensure home_inventory_user_project exposes the wb_clk_i/wb_rst_i ports.
if ! rg -n "input[[:space:]]+wire[[:space:]]+wb_clk_i" "$HIP" >/dev/null; then
  echo "PLACEHOLDER: home_inventory_user_project is missing port: wb_clk_i" >&2
  fail=1
fi
if ! rg -n "input[[:space:]]+wire[[:space:]]+wb_rst_i" "$HIP" >/dev/null; then
  echo "PLACEHOLDER: home_inventory_user_project is missing port: wb_rst_i" >&2
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  cat <<'EOF' >&2

Action required:
- Fix the harness wrapper Wishbone wiring so that wb_clk_i and wb_rst_i are
  connected through the Caravel user_project_wrapper Wishbone slave interface.
- Re-run:
    tools/harness_wb_wiring_audit.sh ../home-inventory-chip-openmpw

This is a tapeout risk until resolved.
EOF
  exit 1
fi

echo "OK: Wishbone wiring sanity checks passed."
