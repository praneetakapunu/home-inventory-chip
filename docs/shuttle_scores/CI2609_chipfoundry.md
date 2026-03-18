# Shuttle scoring — ChipFoundry CI2609

> Goal: make the shuttle decision explicit (dates + risk) instead of hand-wavy.
> This sheet is a snapshot; always treat `docs/SHUTTLE_LOCK_RECORD.md` as the single source
> once Praneet confirms.

## Candidate shuttle

- Program / foundry / PDK: ChipFoundry / chipIgnite reservations (PDK not stated on schedule page)
- Shuttle name/number: CI2609
- Source-of-truth link: https://chipfoundry.io/#schedule
- Last verified (UTC): 2026-03-18 02:30 UTC
- Source excerpt (from the schedule table):
  - "CI2609 … Commitment Date July 18, 2026 … Tapeout Date September 16, 2026 … Delivery Date March 3, 2027"

### Submission cutoff

- Local date/time/timezone: **2026-07-18** (time + timezone not specified on source)
- UTC: not specified
- Notes on ambiguity (DST, “end of day”, etc.):
  - Treat this as ambiguous because the schedule is **date-only**.
  - Use an internal safe deadline earlier than the published date.

### Precheck deadline (if different)

- Local date/time/timezone: not specified
- UTC: not specified

### Expected silicon delivery window

- Delivery Date (per schedule): 2027-03-03

## Scoring (0–2 each; higher is better)

- Tooling readiness: **1 / 2**
  - Rationale: continuous RTL/DV + harness compile checks are feasible; end-to-end submission flow is not yet validated.
- Time runway to cutoff: **2 / 2**
  - Rationale: > 8 weeks to a date-only cutoff (as of 2026-03-18).
- Integration risk (harness + pinout + wrapper + signoff): **1 / 2**
  - Rationale: digital-only scope is bounded, but ADC pinout + CLKIN details still need explicit locking.

Total (max 6): **4 / 6**

## Notes / risks

- This is the first “later” ChipFoundry shuttle on the published 2026 schedule after CI2605.
- If we’re missing any ChipFoundry-specific deliverables, this schedule gives room to discover/fix them without gambling the cutoff.

## Decision (recommendation)

- Pick for v1? **strong candidate**
- Rationale:
  - Significantly more runway than CI2605 while staying within 2026 tapeout.
  - Leaves time to lock ADC pinout/clocking and still run a clean readiness checklist.
