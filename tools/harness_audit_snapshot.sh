#!/usr/bin/env bash
set -euo pipefail

# Create a timestamped markdown snapshot of harness audit output.
# Intended to be low-disk and toolchain-free: grep-style audits only.
#
# Usage:
#   tools/harness_audit_snapshot.sh ../home-inventory-chip-openmpw
#   HARNESS_REPO=../home-inventory-chip-openmpw tools/harness_audit_snapshot.sh

HARNESS_REPO="${1:-${HARNESS_REPO:-}}"
if [[ -z "${HARNESS_REPO}" ]]; then
  echo "ERROR: harness repo path required" >&2
  echo "Usage: $0 <path-to-home-inventory-chip-openmpw>" >&2
  exit 2
fi

if [[ ! -d "${HARNESS_REPO}/.git" ]]; then
  echo "ERROR: not a git repo: ${HARNESS_REPO}" >&2
  exit 2
fi

TS_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUT_DIR="reports/harness-audit"
mkdir -p "${OUT_DIR}"
OUT_MD="${OUT_DIR}/adc_clocking_${TS_UTC}.md"

HARNESS_HEAD="$(git -C "${HARNESS_REPO}" rev-parse --short HEAD)"
HARNESS_BRANCH="$(git -C "${HARNESS_REPO}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"

{
  echo "# Harness audit snapshot — ADC clocking"
  echo
  echo "- Timestamp (UTC): ${TS_UTC}"
  echo "- Harness repo: ${HARNESS_REPO}"
  echo "- Harness HEAD: ${HARNESS_HEAD} (${HARNESS_BRANCH})"
  echo
  echo "## harness_adc_clocking_audit.sh"
  echo
  echo "\`\`\`text"
  tools/harness_adc_clocking_audit.sh "${HARNESS_REPO}" || true
  echo "\`\`\`"
  echo
  echo "## Evidence snips (terms: adc_clkin, CLKIN, frequency, oscillator, io[??])"
  echo
  echo "\`\`\`text"
  python3 tools/harness_evidence_snip.py "${HARNESS_REPO}" \
    --terms adc_clkin,CLKIN,frequency,oscillator,io\[\?\?\] || true
  echo "\`\`\`"
} > "${OUT_MD}"

echo "Wrote: ${OUT_MD}"