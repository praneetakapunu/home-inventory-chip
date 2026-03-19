#!/usr/bin/env bash
set -euo pipefail

# Fail-fast helper: detect if the harness repo *still lacks* inclusion of the
# event-detector RTL (and its regbank) in the harness build/filelists.
#
# Why: the event detector is part of the v1 bring-up surface, and we want a
# cheap, grep-only check that the harness repo is actually pulling the RTL.
#
# Usage:
#   tools/harness_event_detector_placeholder_check.sh [PATH_TO_HARNESS_REPO]
# Default:
#   ../home-inventory-chip-openmpw

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  exit 2
fi

cd "$HARNESS_REPO"

echo "== Checking harness event-detector inclusion (grep-only) =="
echo "Harness: $(pwd)"

need_hit() {
  local pattern="$1"
  local desc="$2"
  if rg -n "$pattern" . >/dev/null 2>&1; then
    echo "OK: found $desc"
  else
    echo "MISSING: $desc" >&2
    echo "  Searched for pattern: $pattern" >&2
    return 1
  fi
}

# We treat these as the minimum sanity signals that the harness is pulling the
# relevant IP files. (Exact paths may vary; we just look for filenames/names.)
need_hit "home_inventory_wb\\.v" "reference to home_inventory_wb.v (Wishbone regbank)" 
need_hit "home_inventory_event_detector\\.v|home_inventory_event_detector" "reference to home_inventory_event_detector.v (event-detector RTL)" 

echo "OK: harness appears to reference event-detector RTL (non-placeholder)."
