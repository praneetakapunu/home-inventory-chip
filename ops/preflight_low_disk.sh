#!/usr/bin/env bash
set -euo pipefail

# Low-disk friendly preflight checks for the IP repo.
#
# Goal: provide a single command humans/CI can run to assert the repo is in a
# "safe" state without pulling in heavy OpenLane flows.
#
# What it runs:
# - RTL compile/elaboration using the repo filelist (iverilog)
# - Regmap consistency + generation drift checks
# - Minimal iverilog/vvp smoke sims (Wishbone + ADC helpers + event detector)

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

banner() { echo "==> $*"; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

banner "Toolchain sanity"
need_cmd bash
need_cmd make
need_cmd python3
need_cmd iverilog
need_cmd vvp

# Print versions for reproducibility/debugging in CI logs.
(iverilog -V 2>/dev/null || iverilog -v 2>/dev/null || true) | sed -n '1,2p' || true
(python3 --version 2>/dev/null || true)
(make --version 2>/dev/null | sed -n '1p' || true)

banner "RTL compile/elaboration (iverilog)"
bash ops/rtl_compile_check.sh

banner "Regmap + smoke sims (make -C verify all)"
make -C verify all

banner "DONE: low-disk preflight checks passed"