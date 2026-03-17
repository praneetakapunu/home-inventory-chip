#!/usr/bin/env bash
set -euo pipefail

HARNESS_DIR=${1:-}
if [[ -z "$HARNESS_DIR" ]]; then
  echo "Usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

if [[ ! -d "$HARNESS_DIR" ]]; then
  echo "ERROR: harness dir not found: $HARNESS_DIR" >&2
  exit 2
fi

MAKEFILE="${HARNESS_DIR%/}/Makefile"
if [[ ! -f "$MAKEFILE" ]]; then
  echo "ERROR: Makefile not found at: $MAKEFILE" >&2
  exit 2
fi

# Targets we expect to exist (or to be intentionally absent, in which case we
# want it to be explicit when we audit integration readiness).
EXPECTED_TARGETS=(
  "sync-ip-filelist"
  "rtl-compile-check"
  "rtl-compile-check-real-adc"
)

missing=()

# Very lightweight/low-disk audit: grep for 'target:' at beginning of line.
# This is not a full Make parser; it's a quick readiness check.
for t in "${EXPECTED_TARGETS[@]}"; do
  # Accept either an empty prerequisite list ("target:") or a normal one
  # ("target: prereq"). Avoid matching make variable assignments like "foo:=...".
  if ! grep -Eq "^${t}:[[:space:]]*($|#|[^=])" "$MAKEFILE"; then
    missing+=("$t")
  fi
done

echo "Harness make targets audit: ${HARNESS_DIR}"
echo "Makefile: ${MAKEFILE}"

if (( ${#missing[@]} == 0 )); then
  echo "OK: all expected targets present: ${EXPECTED_TARGETS[*]}"
  exit 0
fi

echo "MISSING targets (${#missing[@]}): ${missing[*]}" >&2

echo "\nNotes:" >&2
echo "- If a target is intentionally not provided, update the integration docs/checklists" >&2
echo "  to reflect the harness's actual entrypoints." >&2

echo "\nQuick context (matching lines):" >&2
# Print a small snippet of related target lines for debugging.
grep -En "^(sync-ip-filelist|rtl-compile-check|rtl-compile-check-real-adc):" "$MAKEFILE" || true

exit 1
