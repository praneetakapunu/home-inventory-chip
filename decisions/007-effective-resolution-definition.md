# Decision: Define “5 g effective resolution” as an acceptance metric

- **Date:** 2026-02-15
- **Owner:** Madhuri
- **Status:** Proposed (needs Praneet sign-off)

## Decision
Convert the ambiguous requirement **“5 g effective resolution”** into **testable acceptance metrics** for the v1 demo.

The working draft lives at:
- `spec/acceptance_metrics.md`

## Rationale
Without a concrete definition, different parts of the stack will optimize different things:
- Hardware might target ADC LSBs.
- Firmware might over-filter (good drift, bad latency).
- Verification can’t be strict.

A measurable definition lets us:
- pick an ADC part + sampling plan with margin,
- design firmware filters and thresholds intentionally,
- write regression tests that prevent regressions.

## Implications
- This creates explicit requirements for latency, false event rate, drift envelope, and crosstalk.
- If the metrics prove unrealistic for the mechanical setup, we can revise them early (before RTL/PD lock-in).

## Follow-ups
1) Praneet to review and either:
   - approve the draft, or
   - choose an easier target (e.g., 20 g event detectability) for v1.
2) Once approved:
   - update `docs/TAPEOUT_CHECKLIST.md` to mark “success metrics precisely defined” as done,
   - add verification items into `docs/VERIFICATION_PLAN.md` (post-ADC selection).
