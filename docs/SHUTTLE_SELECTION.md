# OpenMPW shuttle selection (how to pick + what we need)

This doc exists so we stop treating the shuttle choice as a vague TODO.

## What we need to lock

Record these **exact fields** once Praneet chooses a target shuttle:

- **Program / foundry / PDK:** (e.g. OpenMPW / Sky130A)
- **Shuttle name/number:** (e.g. OpenMPW-??)
- **Submission cutoff (date + time + timezone):**
- **Precheck deadline (if different):**
- **Expected silicon delivery window:**
- **Link to the official schedule page / announcement:**

Once chosen, copy the values into:
- `docs/DASHBOARD.md` (top-level status)
- `docs/TIMELINE.md` (milestone dates)
- `docs/TAPEOUT_CHECKLIST.md` (gates keyed off the cutoff)

## Where to find the schedule (source of truth)

Use *at least one* of these sources and paste the link when we lock the shuttle:

1) **Efabless platform shuttles page**
   - Look for a shuttles/program page on `https://platform.efabless.com/`.
   - Capture a permalink to the specific shuttle entry.

2) **Official announcements (mailing list / blog / portal)**
   - Examples (historical): SkyWater PDK announce list, Efabless announcements.

3) **Caravel / user-project docs**
   - Not usually the schedule, but useful to confirm submission mechanics.

## How to choose (practical rubric)

Pick the earliest shuttle that is realistic **without** heroics.

Evaluate these constraints:

- **Time:** how many weeks until cutoff?
- **Disk/tooling:** can we run full OpenLane + mpw-precheck in our current environment?
  - If disk is a blocker, we can still do “continuous readiness” (RTL + DV + wrapper compile),
    but we should not pretend we’re ready to harden.
- **Scope:** does v1 really need analog / special IO beyond Caravel defaults?
- **Risk:** schedule slip risk if we pick something too aggressive.

Decision rule (v1):
- If we cannot reliably run mpw-precheck end-to-end today, pick a shuttle far enough out
  that we can first eliminate the tooling/disk blockers.

## Action items (to close this TBD)

- [ ] Praneet: choose target shuttle + cutoff.
- [ ] Madhuri: paste the locked fields into `docs/DASHBOARD.md` + `docs/TIMELINE.md`.
- [ ] Madhuri: update `docs/TAPEOUT_CHECKLIST.md` so the checklist is keyed to that cutoff.

