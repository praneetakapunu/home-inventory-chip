# Shuttle scoring — ChipFoundry CI2612

> Goal: make the shuttle decision explicit (dates + risk) instead of hand-wavy.
> This sheet is a snapshot; always treat `docs/SHUTTLE_LOCK_RECORD.md` as the single source
> once Praneet confirms.

## Candidate shuttle

- Program / foundry / PDK: ChipFoundry / chipIgnite reservations (PDK not stated on schedule page)
- Shuttle name/number: CI2612
- Source-of-truth link: https://chipfoundry.io/#schedule
- Last verified (UTC): 2026-03-18 02:30 UTC
- Source excerpt (from the schedule table):
  - "CI2612 … Commitment Date October 8, 2026 … Tapeout Date December 7, 2026 … Delivery Date May 25, 2027"

### Submission cutoff

- Local date/time/timezone: **2026-10-08** (time + timezone not specified on source)
- UTC: not specified
- Notes on ambiguity (DST, “end of day”, etc.):
  - Treat this as ambiguous because the schedule is **date-only**.
  - Use an internal safe deadline earlier than the published date.

### Precheck deadline (if different)

- Local date/time/timezone: not specified
- UTC: not specified

### Expected silicon delivery window

- Delivery Date (per schedule): 2027-05-25

## Scoring (0–2 each; higher is better)

- Tooling readiness: **1 / 2**
  - Rationale: readiness checks are feasible; full submission flow still needs validation.
- Time runway to cutoff: **2 / 2**
  - Rationale: comfortably > 8 weeks to cutoff.
- Integration risk (harness + pinout + wrapper + signoff): **1 / 2**
  - Rationale: lots of time helps, but pinout/clocking contracts still must be locked and verified.

Total (max 6): **4 / 6**

## Notes / risks

- CI2612 is the latest 2026 shuttle shown on ChipFoundry’s published schedule at time of verification.
- If CI2609 is too aggressive for any reason (process uncertainty, resource constraints), CI2612 is a safe fallback.

## Decision (recommendation)

- Pick for v1? **fallback / low-stress option**
- Rationale:
  - Most runway for de-risking tooling + harness integration.
  - Trades schedule speed for reduced deadline risk.
