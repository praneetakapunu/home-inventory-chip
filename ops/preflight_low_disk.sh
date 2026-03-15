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

banner "Disk space (informational)"
# This suite is meant to be low-disk, but we still want an explicit log line
# for CI/debugging. Fail only when the workspace is critically low.
#
# Threshold chosen to avoid false negatives while still catching "everything is
# about to fail" situations.
DF_LINE=$(df -Pk . | tail -n 1)
# shellcheck disable=SC2086
set -- $DF_LINE
AVAIL_KB=${4:-0}
echo "df -h ."; df -h . | sed -n '1,2p'
if [[ "$AVAIL_KB" -lt $((2*1024*1024)) ]]; then
  echo "WARNING: low free space: ${AVAIL_KB} KB available (< 2 GiB). Some flows may fail." >&2
fi

# Print versions for reproducibility/debugging in CI logs.
(iverilog -V 2>/dev/null || iverilog -v 2>/dev/null || true) | sed -n '1,2p' || true
(python3 --version 2>/dev/null || true)
(make --version 2>/dev/null | sed -n '1p' || true)

banner "RTL compile/elaboration (iverilog)"
bash ops/rtl_compile_check.sh

banner "Shuttle lock record (informational)"
# This is intentionally non-strict: it should not block preflight before the
# shuttle is chosen, but it provides a clear log line in CI and local runs.
bash ops/check_shuttle_lock_record.sh

banner "Shuttle runway metrics (informational)"
# Print runway numbers derived from docs/SHUTTLE_LOCK_RECORD.md.
# Non-strict by default so it won't block work before the shuttle is confirmed.
python3 ops/shuttle_runway.py || true

banner "Regmap generation drift check"
# Ensure committed derived artifacts match spec/regmap_v1.yaml.
bash ops/regmap_check.sh

banner "Regmap + smoke sims (make -C verify all)"
make -C verify all

banner "DONE: low-disk preflight checks passed"