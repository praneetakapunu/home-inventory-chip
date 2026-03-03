# Shuttle lock playbook (do this once, do it right)

This is the *mechanics* of locking the target OpenMPW shuttle so we don’t lose time to ambiguity.

## Goal
End this process with:
- a single source-of-truth record (`docs/SHUTTLE_LOCK_RECORD.md`) that includes **Last verified (UTC)** + a **copy/paste excerpt** from the official source
- the project timeline and checklist re-keyed to the cutoff

## Step-by-step

### 1) Find an official source
Pick the most official thing you can.

Acceptable sources (in descending preference):
1) Efabless platform shuttle schedule page/entry (permalink)
2) Official OpenMPW announcement post / mailing list / portal entry
3) A GitHub issue/discussion in the official OpenMPW repo *that links back to the schedule*

### 2) Capture the evidence (so future-us can verify)
In `docs/SHUTTLE_LOCK_RECORD.md` fill:
- **Last verified (UTC)**
- **Source link**
- **Source excerpt (copy/paste)**

Rules:
- include the **timezone** exactly as stated (don’t convert unless you *also* keep the original)
- if the source uses a date-only cutoff, write "23:59" with the source timezone and say so in Notes

### 3) Mirror the cutoff where it drives work
Update:
- `docs/DASHBOARD.md` → “Target OpenMPW shuttle” section
- `docs/TIMELINE.md` → update M-1 and M4 targets (and re-baseline intermediate milestones if needed)
- `docs/TAPEOUT_CHECKLIST.md` → ensure shuttle-specific constraints are explicitly listed (precheck deadline, submission mechanics)

### 4) Re-baseline (only if needed)
If the chosen cutoff conflicts with the current milestones, re-baseline targets rather than pretending.

Suggested policy:
- keep M4 (submission) fixed to the cutoff
- shift M1–M3 to preserve realistic runway

### 5) Sanity check (read-only)
Confirm these docs are consistent:
- `docs/DASHBOARD.md`
- `docs/TIMELINE.md`
- `docs/TAPEOUT_CHECKLIST.md`
- `docs/SHUTTLE_LOCK_RECORD.md`

Optional helper (non-strict until we actually lock a shuttle):
- `bash ops/check_shuttle_lock_record.sh`
- After locking (no TBDs), you can enforce it with: `bash ops/check_shuttle_lock_record.sh --strict`

## Done when
- shuttle lock record is filled (no TBDs) and includes last-verified + excerpt
- timeline/checklist updated to match
- commit is merged to `main`
