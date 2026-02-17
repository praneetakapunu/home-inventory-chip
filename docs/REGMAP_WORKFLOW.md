# Regmap workflow (v1)

Goal: keep **spec**, **RTL**, **DV**, and **firmware** aligned as the design evolves.

## Source of truth
- Machine-readable: `spec/regmap_v1.yaml`
- Human-readable: `spec/regmap.md`

When changing the regmap, update **both** in the same PR.

## Validation
Run:

```bash
python3 ops/regmap_validate.py --yaml spec/regmap_v1.yaml
```

This checks:
- unique addresses
- word alignment
- sane/ non-overlapping bitfields

## Firmware header generation
The C header used by bring-up software is generated from the YAML.

Run:

```bash
python3 ops/gen_regmap_header.py \
  --yaml spec/regmap_v1.yaml \
  --out  fw/include/home_inventory_regmap.h
```

### Policy
- **Do not** hand-edit `fw/include/home_inventory_regmap.h`.
- If you need a new constant/macro, add it to the YAML (preferred) or add a small post-generation section in the generator.

## SystemVerilog package generation
For RTL/DV, we also generate a small SV package with addresses + bitfield masks.

Run:

```bash
python3 ops/gen_regmap_sv_pkg.py \
  --yaml spec/regmap_v1.yaml \
  --out  rtl/include/home_inventory_regmap_pkg.sv
```

### Policy
- **Do not** hand-edit `rtl/include/home_inventory_regmap_pkg.sv`.
- Prefer importing this package in RTL/DV instead of duplicating address constants.

## DV expectations
In the harness repo, the Wishbone regblock smoke tests should enumerate expected addresses / resets from `spec/regmap_v1.yaml`.

This keeps DV and firmware using the same definitions.
