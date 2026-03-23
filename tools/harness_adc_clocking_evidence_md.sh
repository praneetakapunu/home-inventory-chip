#!/usr/bin/env bash
set -euo pipefail

# harness_adc_clocking_evidence_md.sh
#
# Purpose:
#   Generate a paste-ready Markdown evidence snippet about ADS131M08 CLKIN
#   from the harness repo, suitable for pasting into:
#     decisions/011-adc-clkin-source-and-frequency.md
#
# Why:
#   During tapeout crunch, we want a *repeatable* way to capture “what do the
#   committed harness sources currently say about CLKIN?” with file:line refs.
#
# Usage:
#   tools/harness_adc_clocking_evidence_md.sh [PATH_TO_HARNESS_REPO]
#
# Output:
#   Markdown to stdout.

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

HARNESS_REPO="${1:-../home-inventory-chip-openmpw}"

if [[ ! -d "$HARNESS_REPO" ]]; then
  echo "ERROR: harness repo not found at: $HARNESS_REPO" >&2
  echo "Pass the path explicitly, e.g.:" >&2
  echo "  tools/harness_adc_clocking_evidence_md.sh /abs/path/to/home-inventory-chip-openmpw" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found" >&2
  exit 2
fi

if [[ ! -f tools/harness_evidence_snip.py ]]; then
  echo "ERROR: missing tools/harness_evidence_snip.py (expected in chip-inventory)" >&2
  exit 2
fi

TS_UTC=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

cat <<EOF
# Harness CLKIN evidence snapshot

Generated: **$TS_UTC**

Command:
\`\`\`bash
tools/harness_adc_clocking_audit.sh $HARNESS_REPO
python3 tools/harness_evidence_snip.py $HARNESS_REPO \\
  --terms adc_clkin,ADC_CLKIN,CLKIN,oscillator,xtal,crystal,frequency,MHz,kHz,Hz,io\[\?\?\] \\
  --markdown
\`\`\`

## grep/evidence excerpts (file:line)

EOF

python3 tools/harness_evidence_snip.py "$HARNESS_REPO" \
  --terms adc_clkin,ADC_CLKIN,CLKIN,oscillator,xtal,crystal,frequency,MHz,kHz,Hz,io\[\?\?\] \
  --markdown || true
