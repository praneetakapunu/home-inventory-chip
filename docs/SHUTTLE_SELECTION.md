# Shuttle selection (how to pick + what we need)

This doc exists so we stop treating the shuttle choice as a vague TODO.

Current target (proposed): **ChipFoundry CI2605** (see `docs/SHUTTLE_LOCK_RECORD.md`).

## What we need to lock

Record these **exact fields** once Praneet chooses a target shuttle:

- **Program / foundry / PDK:** (e.g. ChipFoundry / chipIgnite)
- **Shuttle name/number:** (e.g. CI2605)
- **Commitment/cutoff (date + time + timezone):** (if time/tz aren’t published, mark as “not specified”)
- **Any required checks / precheck equivalent (if applicable):**
- **Expected silicon delivery window (or listed delivery date):**
- **Link to the official schedule page / announcement:**

Once chosen, copy the values into:
- `docs/SHUTTLE_LOCK_RECORD.md` (**single source**) — include **Last verified (UTC)** + a short **source excerpt**
- `docs/DASHBOARD.md` (top-level status)
- `docs/TIMELINE.md` (milestone dates)
- `docs/TAPEOUT_CHECKLIST.md` (gates keyed off the cutoff)

### Copy/paste lock record (fill this in)

Keep this block in the PR description when we lock the shuttle, then copy it into the
docs listed above.

```text
Program / foundry / PDK:
Shuttle name/number:
Source-of-truth link:
Last verified (UTC):
Source excerpt (1–3 lines; paste from the schedule page):

Submission cutoff:
  local date:
  local time:
  local timezone:
  utc:

Precheck deadline (if different):
  local date:
  local time:
  local timezone:
  utc:

Expected silicon delivery window:
Notes:
```

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

### Quick scoring heuristic (simple, not scientific)

Score each candidate shuttle 0–2 in each category (higher is better).
Also record the cutoff **both in local timezone and UTC** so we can’t misread the deadline.

- **Tooling readiness**
  - 0: cannot run `mpw-precheck` end-to-end in a reproducible way
  - 1: can run precheck sometimes / with manual steps / with known flakiness
  - 2: can run precheck reliably (CI or one-liner) with current disk + environment
- **Time runway to cutoff**
  - 0: < 4 weeks
  - 1: 4–8 weeks
  - 2: > 8 weeks
- **Integration risk** (harness + pinout + wrapper + signoff)
  - 0: lots of unknowns (pin plan, clocking, hard IP assumptions, etc.)
  - 1: some unknowns, but bounded
  - 2: mostly known / already integrated + tested

Prefer the earliest shuttle that scores **≥ 5** total *without* requiring new hardware,
heroics, or “we'll fix disk later” optimism.

Decision rule (v1):
- If we cannot reliably run mpw-precheck end-to-end today, pick a shuttle far enough out
  that we can first eliminate the tooling/disk blockers.

### Minimum “we can commit to a cutoff” checklist

Before we say “yes” to a specific cutoff, we should be able to do these in a clean clone:

- IP repo (`chip-inventory`):
  - `bash ops/preflight_low_disk.sh` (or equivalent) passes
- Harness repo (`home-inventory-chip-openmpw`):
  - `make sync-ip-filelist`
  - `make rtl-compile-check`

If any item above is blocked (disk, missing dependency, broken script), record it in
`docs/EXECUTION_PLAN.md` → **Blockers** with the exact failing command + error.

## Template (to make comparisons fast)

- Copy/paste checklist + scoring sheet: `docs/shuttle_scoring_template.md`
  - Goal: when we talk about “OpenMPW-XX”, we can point to a filled-in sheet with UTC dates.

### Filled-in scoring sheets (examples)

Put one file per candidate shuttle under `docs/shuttle_scores/`.

- ChipFoundry CI2605 (May MPW Shuttle): `docs/shuttle_scores/CI2605_chipfoundry.md`

## Action items (to close this TBD)

- [ ] Praneet: choose target shuttle + cutoff.
- [ ] Madhuri: paste the locked fields into `docs/DASHBOARD.md` + `docs/TIMELINE.md`.
- [ ] Madhuri: update `docs/TAPEOUT_CHECKLIST.md` so the checklist is keyed to that cutoff.
