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

3) Run consistency gates

```bash
make -C verify regmap-check
make -C verify regmap-gen-check
```

4) Commit as a single atomic change

```bash
git status
# sanity: only regmap-related files changed

git commit -am "regmap: freeze v1 (addrs/resets) + regen derived headers"
```

(Prefer an explicit `git add` if other files are in-flight.)

## What the gates mean (quick)

- `regmap-check`: schema/semantic checks and/or YAML ↔ expectations consistency.
- `regmap-gen-check`: ensures derived artifacts match the YAML (no “forgot to regen”).

If either gate fails, **do not** patch derived headers by hand; fix the YAML or generator.

## Common pitfalls

- **Hand-editing generated files**: will drift and get overwritten. Treat derived artifacts as read-only.
- **Changing reset values without updating RTL**: make sure RTL reset assignments match the YAML.
- **Byte-lane/Wishbone confusion**: if a register uses W1C/W1P semantics, document lane masking behavior.

## “Frozen” definition

Regmap is considered frozen when:

- Addresses and reset values are stable.
- Both gates are green.
- The freeze commit hash is referenced from `docs/TAPEOUT_CHECKLIST.md`.
