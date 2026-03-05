# Shuttle lock record (single source)

Fill this in **once** when Praneet chooses the target OpenMPW shuttle.

Why this file exists:
- We kept copying the shuttle cutoff into multiple docs.
- This is the **single** record; other docs should **link here** (and optionally mirror dates).

## Locked fields (copy/paste from official source)

- **Last verified (UTC):** TBD
- **Program / foundry / PDK:** OpenMPW / Sky130A
- **Shuttle name/number:** TBD
- **Submission cutoff:** TBD
- **Precheck deadline (if different):** TBD
- **Expected silicon delivery window:** TBD
- **Source link (official schedule / announcement):** TBD
- **Source excerpt (copy/paste):** TBD

### Canonical formatting (use this structure when locking)

Keep this structure even after locking so the cutoff is unambiguous.

```text
Submission cutoff:
  date:
  time:
  timezone:

Precheck deadline (if different):
  date:
  time:
  timezone:
```

## Derived deadlines (internal; compute from the cutoff)

Once the shuttle is locked, derive these “internal” dates so we can plan backwards.
(These do not have to match any official program deadline.)

- **Internal freeze tag (v1-freeze):** TBD
- **Internal precheck-clean target:** TBD
- **Internal final-integration target:** TBD

## Change log

If the official schedule changes, append a line here.

- TBD — initial record created.

## Notes
- If the official schedule changes, update this file and then re-baseline `docs/TIMELINE.md`.
- Always include the timezone; do *not* assume UTC.
