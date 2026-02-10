# Decision: Pad weight-change resolution target

- **Date:** 2026-02-09
- **Owner:** Praneet
- **Status:** Decided

## Decision
Target **5 g** weight-change resolution for pads.

## Rationale
Higher sensitivity improves usefulness for small additions/removals; we will manage noise/drift via calibration + filtering and adjust if tapeout constraints force a relaxation.

## Implications
- Sensor/ADC/noise budgeting must support ~5 g effective resolution.
- Mechanical design + temperature drift handling become important.
