# Shuttle scoring — ChipFoundry CI2605 (May MPW Shuttle)

> Goal: make the shuttle decision explicit (dates + risk) instead of hand-wavy.
> This sheet is a snapshot; always treat `docs/SHUTTLE_LOCK_RECORD.md` as the single source
> once Praneet confirms.

## Candidate shuttle

- Program / foundry / PDK: ChipFoundry / chipIgnite reservations (PDK not stated on schedule page)
- Shuttle name/number: CI2605 (May MPW Shuttle)
- Source-of-truth link: https://chipfoundry.io/#schedule
- Last verified (UTC): 2026-03-06 18:18 UTC
- Source excerpt (1–3 lines; paste from the schedule page):
  "CI2605 … Commitment Date March 18, 2026 … Tapeout Date May 13, 2026 … Delivery Date October 28, 2026"
- Weeks until cutoff (approx): ~1.5 weeks (as of 2026-03-07)

### Submission cutoff

- Local date/time/timezone: **2026-03-18** (time + timezone not specified on source)
- UTC: not specified
- Notes on ambiguity (DST, “end of day”, etc.):
  - Treat this as **high ambiguity** because the schedule is date-only.
  - Use an **internal safe deadline earlier than the published date** to avoid missing cutoff.

### Precheck deadline (if different)

- Local date/time/timezone: not specified
- UTC: not specified

### Expected silicon delivery window

- Delivery Date (per schedule): 2026-10-28

## Scoring (0–2 each; higher is better)

- Tooling readiness: **1 / 2**
  - Rationale: we can keep RTL + DV + wrapper compile green, but we do **not** have an end-to-end
    ChipFoundry-specific “submission precheck” procedure validated in CI yet.
- Time runway to cutoff: **0 / 2**
  - Rationale: < 4 weeks to a date-only cutoff.
- Integration risk (harness + pinout + wrapper + signoff): **1 / 2**
  - Rationale: bounded (digital-only), but there are still unknowns around submission mechanics
    and any ChipFoundry-specific deliverable requirements.

Total (max 6): **2 / 6**

## Notes / risks

- Disk/tooling blockers:
  - Not a blocker for RTL/DV work, but full signoff flows may be disk-heavy (environment-dependent).
- External dependencies (harness updates, pinout decisions):
  - Confirm final harness wrapper expectations and any required checklists.
- Confidence level: **medium** on dates (source is clear but date-only); **low** on process requirements.

## Decision (recommendation)

- Pick for v1? **no (unless already reserved and Praneet wants to push for it)**
- Rationale:
  - The cutoff runway is too short to treat as a primary plan unless the submission mechanics are
    already known and the project is already near signoff.
  - Use this as a forcing function to keep continuous readiness green, but consider a later shuttle
    for a realistic tapeout plan.
