#!/usr/bin/env bash
set -euo pipefail

# Low-disk friendly preflight checks for the IP repo.
#
# Goal: give a single command humans/CI can run to assert the repo is in a
# "safe" state without pulling in heavy OpenLane flows.
#
# What it runs:
# - RTL compile/elaboration using the repo filelist
# - Regmap consistency + generation drift checks
# - Minimal iverilog/vvp smoke sims (wishbone + ADC helpers + event detector)

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

banner() { echo "==> $*"; }

banner "RTL compile/elaboration (iverilog)"
bash ops/rtl_compile_check.sh

grep -q "^all:" verify/Makefile >/dev/null 2>&1 || true

banner "Regmap + smoke sims (make -C verify all)"
make -C verify all

banner "DONE: low-disk preflight checks passed"