# Decision: Effective resolution target (v1)

- **Date:** 2026-02-15
- **Owner:** Praneet
- **Status:** Decided

## Decision
Relax v1 effective resolution target to **20 g**.

## Rationale
This de-risks the first tapeout by reducing sensitivity to mechanical noise/drift and simplifies calibration/filtering.

## Implications
- Update acceptance metrics and spec language from 5 g → 20 g.
- ADC selection can prioritize robustness and simpler integration.
- Verification and bench procedures should use 20 g step tests.
