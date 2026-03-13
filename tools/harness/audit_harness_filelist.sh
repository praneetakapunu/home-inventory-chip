#!/usr/bin/env bash
set -euo pipefail

# Audit the harness-side RTL filelist for common integration errors.
#
# Intended usage (run from harness repo root):
#   ip/home-inventory-chip/tools/harness/audit_harness_filelist.sh
#
# Or pass --harness-root <path>.
#
# Checks:
#   - verilog/rtl/ip_home_inventory.f exists
#   - every non-comment line points to an existing file
#   - no absolute paths
#   - no parent traversal (..)
#   - (soft) all entries are under ip/home-inventory-chip/rtl/

usage() {
  cat <<'EOF'
Usage:
  audit_harness_filelist.sh [--harness-root <path>]

Run from the OpenMPW harness repo root, OR pass --harness-root.

Audits:
  <harness-root>/verilog/rtl/ip_home_inventory.f
EOF
}

HARNESS_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness-root)
      HARNESS_ROOT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${HARNESS_ROOT}" ]]; then
  HARNESS_ROOT="$(pwd)"
fi

FILELIST="${HARNESS_ROOT}/verilog/rtl/ip_home_inventory.f"

if [[ ! -f "${FILELIST}" ]]; then
  echo "ERROR: harness filelist not found: ${FILELIST}" >&2
  echo "Hint: run gen_harness_filelist.sh first." >&2
  exit 1
fi

missing=0
badpath=0
warn=0
entries=0

echo "Audit: ${FILELIST}"

while IFS='' read -r line; do
  # Strip leading/trailing whitespace
  line="${line#${line%%[![:space:]]*}}"
  line="${line%${line##*[![:space:]]}}"

  if [[ -z "${line}" ]] || [[ "${line}" =~ ^# ]]; then
    continue
  fi

  entries=$((entries+1))

  if [[ "${line}" == /* ]]; then
    echo "ERROR: absolute path in filelist: ${line}" >&2
    badpath=$((badpath+1))
    continue
  fi

  if [[ "${line}" == *".."* ]]; then
    echo "ERROR: parent traversal (..) in filelist entry: ${line}" >&2
    badpath=$((badpath+1))
    continue
  fi

  if [[ "${line}" != ip/home-inventory-chip/rtl/* ]]; then
    echo "WARN: entry not under ip/home-inventory-chip/rtl/: ${line}" >&2
    warn=$((warn+1))
  fi

  if [[ ! -f "${HARNESS_ROOT}/${line}" ]]; then
    echo "ERROR: missing file referenced by filelist: ${line}" >&2
    missing=$((missing+1))
  fi

done < "${FILELIST}"

echo ""
echo "Summary: entries=${entries} missing=${missing} badpath=${badpath} warnings=${warn}"

if [[ ${missing} -ne 0 || ${badpath} -ne 0 ]]; then
  echo "FAIL: harness filelist audit failed" >&2
  exit 1
fi

echo "OK: harness filelist audit passed"
