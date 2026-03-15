# ChipFoundry submission notes (CI2605-style shuttles)

This doc captures **what we still need to confirm** to submit successfully via a ChipFoundry / chipIgnite-style shuttle.

Why this exists:
- Our repo has a lot of **OpenMPW/Caravel/OpenLane** muscle memory.
- The current proposed shuttle target in `docs/SHUTTLE_LOCK_RECORD.md` is **ChipFoundry CI2605**, which may **not** use the exact OpenMPW “mpw-precheck” flow.
- We need a crisp checklist of unknowns so we don’t waste time setting up the wrong toolchain.

## Current assumption
- We will still keep the harness repo (`home-inventory-chip-openmpw`) in a **Caravel-style shape** because it’s a useful, well-known wrapper.
- But we should treat **ChipFoundry submission requirements as source-of-truth** and adjust quickly once we have the official checklist.

## Inputs we must obtain (hard blockers for final submission)
Request/confirm these items from ChipFoundry docs/portal (or a program email) and paste links + excerpts here.

To reduce thrash, use the email draft in:
- `docs/CHIPFOUNDRY_INTAKE_EMAIL.md`

### Intake record (fill this in as we learn facts)
```yaml
shuttle:
  name: null
  program: null            # chipIgnite / ChipFoundry / etc.
  cutoff:
    datetime: null         # ISO8601
    tz: null
    source_url: null
pdk:
  name: null               # sky130A/sky130B/...
  version: null
  source_url: null
flow:
  requires_openlane: null
  openlane_version: null
  openroad_version: null
  docker_image: null
  precheck:
    required: null
    instructions_url: null
    pass_fail_gates: []
deliverables:
  artifact_format: null    # repo/tag/tarball/portal upload
  required_views: []       # gds/lef/def/lib/spef/netlist/...
  required_reports: []
notes: []
```

### 1) Required repository/layout
- Do they require a specific top-level repo structure?
- Do they accept a Caravel user project wrapper repo as-is?
- Do they require a specific Git tag / tarball / manifest?

### 2) Toolchain requirements
- OpenLane version / OpenROAD version constraints (if any)
- PDK name/version (sky130A? sky130B? something else?)
- Docker image requirements (if submission uses containers)

### 3) What must be provided
- GDS + LEF + Liberty + SPEF? (and for which blocks)
- Full chip vs macro submission?
- Required reports (DRC/LVS, antenna, IR drop, etc.)

### 4) Pinout / padframe requirements
- Allowed IO voltages / ESD / pullups
- Clocking constraints
- Whether the padframe is provided (harness-style) or custom

### 5) Precheck / signoff
- Is there a ChipFoundry “precheck” equivalent?
- Are there hard pass/fail gates we can run locally?

## What we can keep doing *now* (low-disk, always useful)
These tasks reduce risk regardless of final submission flow:

1) Keep IP repo green:
   - `bash ops/preflight_low_disk.sh`
2) Keep harness integration green:
   - `bash ops/preflight_ip_and_harness_low_disk.sh`
3) Keep regmap + bring-up docs consistent:
   - `spec/regmap.md`
   - `docs/BRINGUP_SEQUENCE.md`
4) Keep "top-level wiring" changes small and compile-checked:
   - `docs/HARNESS_INTEGRATION.md`
   - `docs/ADC_PINOUT_CONTRACT.md`

## Decision point
Once we have the official ChipFoundry submission checklist, we will:
1) Update `docs/SHUTTLE_LOCK_RECORD.md` → set **Lock status: LOCKED**
2) Update `docs/TAPEOUT_CHECKLIST.md` to match ChipFoundry gates
3) Update `docs/OPENMPW_SUBMISSION.md` to clearly mark what is "OpenMPW-only"

## References
- Shuttle record (proposed): `docs/SHUTTLE_LOCK_RECORD.md`
