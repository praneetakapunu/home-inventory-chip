# Decision: Open-source timeline / repo visibility

- **Date:** 2026-02-10
- **Owner:** Praneet
- **Status:** Decided

## Decision
Make the project **public + open source now** to unlock low-cost MPW shuttle options (OpenMPW-style programs).

## Rationale
Keeping the repo private conflicts with the requirements of many no-cost/low-cost open MPW shuttles (public/open licensing + reproducibility).

## Implications
- Ensure no secrets/PII are committed (shipping contact stays in `private/` and is gitignored).
- Choose an open-source license and add `LICENSE`.
- Align tapeout path toward OpenMPW (Sky130/GF180) + harness-style integration.
