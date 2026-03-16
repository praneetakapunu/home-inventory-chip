# Shuttle lock PR template (copy/paste)

Use this template when opening the PR that **locks** the target shuttle.

> Goal: make the shuttle choice + cutoff **unambiguous** and future-verifiable.

---

## Summary
Lock target shuttle for OpenMPW submission.

## What changed
- Updated `docs/SHUTTLE_LOCK_RECORD.md` with the confirmed shuttle + cutoff.
- Re-keyed timeline/checklist to match the cutoff.

## Lock record (canonical)
Paste the filled canonical block from `docs/SHUTTLE_LOCK_RECORD.md` here:

```
shuttle: <name>
date: <YYYY-MM-DD>
time: <HH:MM>
timezone: <TZ>
utc: <YYYY-MM-DD HH:MMZ>
```

## Evidence (copy/paste excerpt)
**Source link:** <https://...>

**Source excerpt (verbatim, includes timezone):**
```
<paste>
```

**Last verified (UTC):** <YYYY-MM-DD HH:MMZ>

## Checklist
- [ ] `docs/SHUTTLE_LOCK_RECORD.md` has **Lock status: LOCKED**
- [ ] No `TBD` placeholders remain in the lock record
- [ ] `bash ops/check_shuttle_lock_record.sh --strict` passes
- [ ] `docs/DASHBOARD.md` updated (target shuttle + cutoff)
- [ ] `docs/TIMELINE.md` updated (milestones re-keyed)
- [ ] `docs/TAPEOUT_CHECKLIST.md` updated (shuttle-specific gates)

## Notes / assumptions
- If the official source only provided a date (no time), we treated cutoff as **23:59** in the source timezone and wrote that explicitly in Notes.
