# Regmap Freeze Playbook (v1)

Goal: freeze the **address map + reset values** once, and make it hard to drift.

This is the *mechanical* sequence to run when we decide “regmap v1 is frozen”.

## Source of truth

- Source of truth is **`spec/regmap_v1.yaml`**.
- Human-readable reference is **`spec/regmap.md`**.
- Derived artifacts (must be regenerated and committed together):
  - `fw/include/home_inventory_regmap.h`
  - `rtl/include/home_inventory_regmap_pkg.sv`
  - `rtl/include/regmap_params.vh`
  - `rtl/regmap_v1.h`

Rule: any change to YAML requires regenerating derived artifacts in the *same commit*.

## One-shot freeze sequence

From repo root (`chip-inventory/`):

1) Edit the YAML (and update the markdown doc)

- Update `spec/regmap_v1.yaml`
- Update `spec/regmap.md`

2) Regenerate derived artifacts

```bash
bash ops/regmap_update.sh
```

3) Run consistency gates (single entrypoint)

```bash
bash ops/preflight_regmap_gate.sh
```

(Equivalent to running `ops/regmap_check.sh` + the `verify` regmap targets.)

4) Commit as a single atomic change

```bash
git status
# sanity: only regmap-related files changed

git add \
  spec/regmap_v1.yaml \
  spec/regmap.md \
  fw/include/home_inventory_regmap.h \
  rtl/include/home_inventory_regmap_pkg.sv \
  rtl/include/regmap_params.vh \
  rtl/regmap_v1.h

git commit -m "regmap: freeze v1 (addrs/resets) + regen derived headers"
```

Notes:
- Avoid `git commit -am ...` here: it can silently omit newly-generated files.
- If you touched RTL reset logic, stage those RTL changes in the same commit (or split into a clearly-related follow-up).

## What the gates mean (quick)

- `regmap-check`: schema/semantic checks and/or YAML ↔ expectations consistency.
- `regmap-gen-check`: ensures derived artifacts match the YAML (no “forgot to regen”).

If either gate fails, **do not** patch derived headers by hand; fix the YAML or generator.

## Common pitfalls

- **Hand-editing generated files**: will drift and get overwritten. Treat derived artifacts as read-only.
- **Changing reset values without updating RTL**: make sure RTL reset assignments match the YAML.
- **Byte-lane/Wishbone confusion**: if a register uses W1C/W1P semantics, document lane masking behavior.

## Cross-repo sync (harness)

Once the freeze commit is on `main`, ensure the harness repo is pointing at the
same IP commit SHA and that all derived artifacts match.

Low-disk drift check:

```bash
bash ops/preflight_regmap_gate.sh --harness ../home-inventory-chip-openmpw
```

If it reports drift, update/commit the harness submodule pointer (in the harness
repo) rather than trying to patch generated files by hand.

## “Frozen” definition

Regmap is considered frozen when:

- Addresses and reset values are stable.
- The regmap gate is green (`bash ops/preflight_regmap_gate.sh`).
- Harness drift check is green (if using the OpenMPW harness repo).
- The freeze commit hash is recorded in `docs/BASELINES.md` (**Regmap v1 freeze**).
- The tapeout checklist points at the same baseline.
