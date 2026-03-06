# Chip-in-hand timeline (best-guess)

Baseline start date: **2026-02-25**

This is a *working* schedule. If we drift by >3 days on any milestone, we should either:
- de-scope, or
- add effort, or
- explicitly re-baseline.

## Milestones (v1)

### M-1 — Confirm & lock target shuttle (ChipFoundry)
- Target (proposed): **CI2605** (Commitment Date: 2026-03-18; Tapeout: 2026-05-13; Delivery: 2026-10-28)
- Exit criteria:
  - `docs/SHUTTLE_LOCK_RECORD.md` filled (no TBDs) and includes:
    - **Last verified (UTC)**
    - **source link** + **copy/paste excerpt**
    - commitment/cutoff **date** (and time/timezone if published; otherwise explicitly marked “not specified”)
  - `bash ops/check_shuttle_lock_record.sh --strict` passes
  - `docs/TAPEOUT_CHECKLIST.md` updated for any ChipFoundry-specific constraints (deliverables, checks, submission mechanics)

Locked fields live in: `docs/SHUTTLE_LOCK_RECORD.md` (single source).

Once locked, also fill in the **Derived deadlines** section in the lock record so the rest of this timeline can be planned backwards from the commitment date.

### M0 — v1 freeze tag (spec/regmap/tests stable)
- Target: **2026-03-01** (baseline)
- Exit criteria:
  - regmap frozen for v1
  - `make -C verify all` green
  - tag created: `v1-freeze-YYYYMMDD`

### M1 — Submission/integration repo path confirmed (ChipFoundry)
- Target: **2026-03-10**
- Exit criteria:
  - ChipFoundry submission/integration repo identified (or their required submission mechanism documented)
  - If a wrapper/harness is required: wrapper wired (clock/reset/Wishbone/IO) and compile-check passes
  - Minimal sim sanity passes (at least RTL compile + smoke DV)

### M2 — Commitment deadline met (ChipFoundry reservation)
- Target: **2026-03-18** (internal safe deadline: **2026-03-17 23:59 PT**)
- Exit criteria:
  - Reservation/commitment submitted/confirmed for CI2605 (or documented why not)
  - `docs/PRECHECK_LOG.md` includes *any* ChipFoundry-required checks that were run (or notes that none are required at this stage)
  - `docs/PRECHECK_LOG.md` includes repo commit + summary

### M3 — PD signoff-quality run (OpenLane/OpenROAD) for integrated design
- Target: **2026-04-15**
- Exit criteria:
  - timing closed (per chosen constraints)
  - DRC/LVS clean (per flow expectations)
  - reproducible run documented

### M4 — Tapeout delivery (CI2605)
- Target: **2026-05-13**
- Exit criteria:
  - final tag + release notes
  - deliverables submitted/accepted per ChipFoundry requirements

## Post-tapeout (external lead times)
- ChipFoundry schedule (per CI2605): **Delivery Date 2026-10-28**
- Packaging/shipping details: TBD (depends on ChipFoundry offering: QFN vs bare die, etc.)

