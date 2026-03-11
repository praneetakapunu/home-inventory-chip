#!/usr/bin/env bash
set -euo pipefail

# Harness audit helper: event detector integration readiness
#
# Usage:
#   tools/harness_event_detector_audit.sh ../home-inventory-chip-openmpw
#
# This script is intentionally grep-based (low disk, no heavy toolchain).

HARNESS_ROOT=${1:-}

if [[ -z "${HARNESS_ROOT}" ]]; then
  echo "usage: $0 <path-to-harness-repo>" >&2
  exit 2
fi

if [[ ! -d "${HARNESS_ROOT}" ]]; then
  echo "ERROR: harness repo not found: ${HARNESS_ROOT}" >&2
  exit 2
fi

cd "${HARNESS_ROOT}"

say() { printf '%s\n' "$*"; }
section() {
  say
  say "== $* =="
}

section "Repo"
say "harness: $(pwd)"

section "Find references to home_inventory_wb / event detector"
# These checks are heuristic; absence does not guarantee missing integration.
rg -n "home_inventory_wb" . || true
rg -n "home_inventory_event_detector|u_evt|EVT_CFG|EVT_COUNT|EVT_THRESH" . || true

section "Filelists / includes"
# Look for common filelist patterns.
rg -n "home_inventory_(wb|event_detector)\.v" . || true
rg -n "rtl/home_inventory_(wb|event_detector)\.v" . || true

section "Build targets (best-effort)"
if [[ -f Makefile ]]; then
  # List likely targets without running toolchains.
  say "Makefile present; listing targets containing: rtl, compile, sync"
  make -nqp 2>/dev/null | rg -n "^[a-zA-Z0-9_.-]+:([^=]|$)" | rg -n "(rtl|compile|sync)" | head -n 80 || true
else
  say "No Makefile found at harness root. (This may be expected depending on layout.)"
fi

section "Notes"
cat <<'EOF'
What you want to see before flipping the event-detector sample source to real ADC frames:
- harness includes the IP RTL (home_inventory_wb.v + friends) in its filelist
- EVT_* registers are visible via the same regmap include the harness uses
- RTL compile-check target exists and can run in low disk conditions

If any grep above shows surprising absences, update docs/HARNESS_INTEGRATION.md
and/or the harness repo's filelist rules.
EOF
