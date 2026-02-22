# Decision 003 — Event threshold hysteresis for add/remove

- **Date:** 2026-02-22
- **Status:** Accepted
- **Owner:** Praneet

## Decision
Use **hysteresis** for event detection:
- Trigger **ADD** on approximately **+25 g** step.
- Trigger **REMOVE** on approximately **−25 g** step.

(Effective resolution target remains 20 g; hysteresis is chosen to reduce false events under noise/drift.)

## Rationale
Hysteresis improves stability for an event-centric UX by reducing oscillation and false positives around the threshold.

## Notes
Exact implementation details (filter window, debounce time, and drift compensation) will be specified in `spec/v1.md` and verified with directed sims.
