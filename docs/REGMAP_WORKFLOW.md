# Regmap workflow (single source of truth)

This project treats `spec/regmap_v1.yaml` as the **only** authoritative register map.

Everything else (FW headers, SV packages, Verilog `localparam`s, human tables) is generated from it.

## Quick rule
- **Edit:** `spec/regmap_v1.yaml`
- **Validate + regen artifacts:** `bash ops/regmap_update.sh`
- **Check nothing drifted:** `make -C verify regmap-check regmap-gen-check`

## Files involved
**Source-of-truth**
- `spec/regmap_v1.yaml`

**Generated artifacts (must stay in sync)**
- C header (firmware): `fw/include/home_inventory_regmap.h`
- SystemVerilog package (RTL/DV): `rtl/include/home_inventory_regmap_pkg.sv`
- Verilog include (DV/RTL glue): `rtl/include/regmap_params.vh`
- Markdown table view: `spec/regmap_v1_table.md`

## Normal edit loop
1) Edit the YAML:

```bash
$EDITOR spec/regmap_v1.yaml
```

2) Regenerate + validate:

```bash
bash ops/regmap_update.sh
```

3) Run consistency checks:

```bash
make -C verify regmap-check regmap-gen-check
```

4) Commit the YAML + generated outputs together:

```bash
git add spec/regmap_v1.yaml spec/regmap_v1_table.md \
  fw/include/home_inventory_regmap.h \
  rtl/include/home_inventory_regmap_pkg.sv \
  rtl/include/regmap_params.vh
```

## Common integration pitfalls (Caravel/Wishbone)
- **Byte addressing vs word addressing:** Caravel presents a **byte address** on `wbs_adr_i`. Our RTL decodes 32-bit word-aligned registers (ignores `[1:0]`), but the offsets in docs/specs are still **byte addresses**.
- **W1C + byte-lanes:** for sticky status bits (W1C), firmware should use full-word writes (`SEL=0b1111`) so the correct byte lane participates.

## CI / low-disk friendly
This workflow is designed to be fast and avoid heavy EDA installs.

If you only have a minute, run:

```bash
make -C verify regmap-check
```

(That checks YAML ↔ RTL address map consistency without regenerating outputs.)
