# Chip-in-hand timeline (best-guess)

Baseline start date: **2026-02-25**

This is a *working* schedule. If we drift by >3 days on any milestone, we should either:
- de-scope, or
- add effort, or
- explicitly re-baseline.

## Milestones (v1)

### M-1 — Pick target OpenMPW shuttle
- Target: **TBD (Praneet)**
- Exit criteria:
  - shuttle name + submission cutoff date recorded in `docs/DASHBOARD.md`
  - `docs/TAPEOUT_CHECKLIST.md` updated if any shuttle-specific constraints exist

### M0 — v1 freeze tag (spec/regmap/tests stable)
- Target: **2026-03-01** (baseline)
- Exit criteria:
  - regmap frozen for v1
  - `make -C verify all` green
  - tag created: `v1-freeze-YYYYMMDD`

### M1 — OpenMPW/Caravel harness integration complete
- Target: **2026-03-11**
- Exit criteria:
  - builds in the submission repo
  - wrapper wired (clock/reset/Wishbone/IO)
  - harness-level sim sanity passes

### M2 — OpenMPW precheck clean + artifacts logged
- Target: **2026-03-18**
- Exit criteria:
  - precheck passes (or documented waivers)
  - `docs/PRECHECK_LOG.md` includes command + commit + summary

### M3 — PD signoff-quality run (OpenLane/OpenROAD) for integrated design
- Target: **2026-04-15**
- Exit criteria:
  - timing closed (per chosen constraints)
  - DRC/LVS clean (per flow expectations)
  - reproducible run documented

### M4 — Submit to MPW shuttle
- Target: **2026-04-20**
- Exit criteria:
  - final tag + release notes
  - submission accepted

## Post-submission (external lead times)
- Fab (MPW): **8–16 weeks** typical
- Packaging + shipping: **2–6 weeks**

