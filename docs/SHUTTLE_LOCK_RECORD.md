# Shuttle lock record (single source)

**Lock status:** PROPOSED (awaiting Praneet confirmation)

Fill this in **once** when Praneet chooses the target shuttle.

Why this file exists:
- We kept copying the shuttle cutoff into multiple docs.
- This is the **single** record; other docs should **link here** (and optionally mirror dates).

## Locked fields (copy/paste from official source)

- **Last verified (UTC):** 2026-03-06 18:18 UTC
- **Program / foundry / PDK:** ChipFoundry / chipIgnite reservations (PDK not stated on schedule page)
- **Shuttle name/number:** CI2605 (May MPW Shuttle)
- **Submission cutoff:** Commitment Date: 2026-03-18 (date-only on source; internal safe deadline is earlier)
- **Precheck deadline (if different):** Not specified (ChipFoundry flow; see notes)
- **Expected silicon delivery window:** Delivery Date: 2026-10-28 (per schedule)
- **Source link (official schedule / announcement):** https://chipfoundry.io/#schedule
- **Source excerpt (copy/paste):**
  "CI2605 … Commitment Date March 18, 2026 … Tapeout Date May 13, 2026 … Delivery Date October 28, 2026"

### Canonical formatting (use this structure when locking)

Keep this structure even after locking so the cutoff is unambiguous.

```text
Submission cutoff (ChipFoundry commitment date):
  official date: 2026-03-18
  official time: not specified (date-only on source)
  official timezone: not specified (source does not state TZ)
  official utc: not specified

Internal safe deadline (assume safest):
  date: 2026-03-17
  time: 23:59
  timezone: PT
  utc: 2026-03-18 06:59Z

Precheck deadline (if different):
  date: not specified
  time: not specified
  timezone: not specified
  utc: not specified
```

## Derived deadlines (internal; compute from the cutoff)

Once the shuttle is locked, derive these “internal” dates so we can plan backwards.
(These do not have to match any official program deadline.)

Preferred workflow:
- Update the **Internal safe deadline ... utc:** line above.
- Run: `python3 ops/shuttle_runway.py`
- Copy the “Suggested internal milestones” dates into this section.

- **Internal freeze tag (v1-freeze):** 2026-03-08 (tag: `v1-freeze-20260308`) *(derived)*
- **Internal precheck-clean target:** not applicable (ChipFoundry requirements not yet provided; no OpenMPW mpw-precheck assumed)
- **Internal final-integration target:** 2026-03-13 *(derived; keep margin before internal safe deadline)*

## Change log

If the official schedule changes, append a line here.

- 2026-03-06 — proposed shuttle target: ChipFoundry CI2605 (date-only commitment deadline from schedule page).

## Notes
- If the official schedule changes, update this file and then re-baseline `docs/TIMELINE.md`.
- Always include the timezone; do *not* assume UTC.
