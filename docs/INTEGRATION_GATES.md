# Integration Gates (low-disk, repeatable)

This is the **minimum set of checks** we should be able to run repeatedly (even on low disk)
while iterating toward OpenMPW tapeout.

Goals:
- Catch **integration drift** between IP repo and harness repo early.
- Make “are we still tapeout-viable?” a yes/no answer.

## Quickstart (most common)
From `chip-inventory/`:

```bash
# Runs: IP preflight + harness compile-check + placeholder/contract gates.
bash ops/preflight_all_low_disk.sh ../home-inventory-chip-openmpw
```

If you only want IP-side checks:

```bash
bash ops/preflight_low_disk.sh
```

If you only want the strict cutoff + lock gating (process gate):

```bash
bash ops/preflight_cutoff_gate.sh --strict
```

## What each gate covers

### 1) IP repo: “build sanity”
Script: `bash ops/preflight_low_disk.sh`

Includes (see script for authoritative list):
- `bash ops/rtl_compile_check.sh` (RTL compiles under our chosen simulator)
- `make -C verify all` (DV/smoke targets intended to be lightweight)

### 2) Harness repo: “wiring sanity”
Script: `bash ops/preflight_ip_and_harness_low_disk.sh ../home-inventory-chip-openmpw`

Includes:
- Harness-side `make rtl-compile-check` (or equivalent) so the wrapper stays buildable.

### 3) Placeholder / contract gates (fail-fast)
Primary entrypoint:

```bash
bash tools/harness_placeholder_suite.sh ../home-inventory-chip-openmpw
```

This suite is intentionally grep-based (no heavy toolchain) and checks that the harness
wrapper has not silently fallen back to placeholders for:
- ADC pin mapping / signal naming
- ADC clocking (CLKIN source)
- ADC DRDY polarity assumptions
- WB wiring presence
- Event detector wiring presence

### 4) Regmap drift gate (YAML ↔ RTL)
In `chip-inventory/`:

```bash
make -C verify regmap-check
```

And in harness integration windows, also run:

```bash
bash tools/harness_regmap_drift_check.sh ../home-inventory-chip-openmpw
```

This catches the common failure mode where the IP-side regmap evolves but the harness
wrapper (or SW assumptions) lag behind.

### 5) Shuttle lock + cutoff gate (process gate)
Script: `bash ops/preflight_cutoff_gate.sh [--strict]`

Checks:
- Shuttle lock record exists, is complete, and (in strict mode) explicitly **LOCKED**.
- Record is not stale (defaults to `STALE_DAYS=7`).

## When to run which
- During active RTL work: run **(1) + (4)** frequently.
- Before opening a harness PR: run **(2) + (3) + (4)**.
- Within ~2 weeks of the chosen cutoff: treat **(5)** as mandatory before merge.

## If anything fails
- Prefer to fix immediately.
- If blocked (missing external info, disk issues, toolchain breakage): record it in
  `docs/EXECUTION_PLAN.md` under **## Blockers** with the exact command + error summary.
