#!/usr/bin/env bash
set -euo pipefail

# Cross-repo low-disk preflight.
#
# This is the "one command" sanity suite for the v1 OpenMPW path:
# - Runs the IP repo low-disk preflight (RTL compile, regmap drift, smoke sims)
# - Optionally runs the harness repo lightweight compile checks (if present)
#
# It intentionally avoids heavy OpenLane/hardening flows.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

banner() { echo "==> $*"; }

die() {
  echo "ERROR: $*" >&2
  exit 1
}

banner "IP repo: low-disk preflight"
bash ops/preflight_low_disk.sh

HARNESS_DIR_DEFAULT="$ROOT_DIR/../home-inventory-chip-openmpw"
HARNESS_DIR="${1:-$HARNESS_DIR_DEFAULT}"

if [[ ! -d "$HARNESS_DIR" ]]; then
  banner "Harness repo: SKIP (not found)"
  echo "Looked for harness at: $HARNESS_DIR" >&2
  echo "Tip: run: bash ops/preflight_all_low_disk.sh /path/to/home-inventory-chip-openmpw" >&2
  exit 0
fi

banner "Harness repo: sync IP filelist + RTL compile-check"
(
  cd "$HARNESS_DIR" || die "failed to cd to harness dir: $HARNESS_DIR"
  make sync-ip-filelist
  make rtl-compile-check
)

banner "DONE: cross-repo low-disk preflight checks passed"
