# Register Map workflow (v1)

This project treats the register map as **spec-first**.

- **Source-of-truth:** `spec/regmap_v1.yaml`
- **Derived artifacts (must stay in sync):**
  - `spec/regmap_v1_table.md` (human-readable table)
  - `fw/include/home_inventory_regmap.h` (firmware C header)
  - `rtl/include/home_inventory_regmap_pkg.sv` (SystemVerilog package)
  - `rtl/include/regmap_params.vh` (Verilog `localparam` include)

## Quick start

### Update / regenerate artifacts (normal development)

```bash
bash ops/regmap_update.sh
```

This will:
1) validate `spec/regmap_v1.yaml`
2) regenerate all derived artifacts listed above
3) print a `git status` summary so you can see what changed

### Verify artifacts are in sync (CI / pre-push)

```bash
bash ops/regmap_check.sh
```

This script regenerates artifacts and then **fails** if `git diff` shows drift.

## Making changes safely

1. Edit **only** `spec/regmap_v1.yaml` for functional changes.
   - Do **not** hand-edit the generated `.h`, `.sv`, `.vh`, or the markdown table.
2. Run `bash ops/regmap_update.sh`.
3. Review diffs:

```bash
git diff -- spec/regmap_v1.yaml spec/regmap_v1_table.md \
  fw/include/home_inventory_regmap.h \
  rtl/include/home_inventory_regmap_pkg.sv \
  rtl/include/regmap_params.vh
```

4. Commit **both** the YAML and the derived artifacts.
   - Rationale: downstream users (firmware/RTL) shouldn’t need Python tooling to build.

## YAML conventions (what the generator expects)

The YAML schema is validated by `ops/regmap_validate.py`. In general:
- Addresses are **byte offsets** (Wishbone byte addressing).
- Registers are 32-bit.
- Bitfields should explicitly specify:
  - access type (RO/RW/W1C/W1P)
  - reset value (where applicable)
  - a short description suitable for both RTL and firmware docs

If validation fails, fix the YAML until `ops/regmap_update.sh` succeeds.

## Common footguns

- **Byte vs word addressing:** Caravel presents a byte address on `wbs_adr_i`.
  - In firmware you almost always want to use the byte offsets shown in the docs.
- **W1C + byte-select interaction:** If you clear sticky bits with partial `wbs_sel_i`, only those byte lanes participate.
  - Firmware recommendation: clear W1C bits with full-word writes (`SEL=0b1111`).

## Troubleshooting

- If generation fails due to Python environment issues, capture the exact error and add it under `## Blockers` in `docs/EXECUTION_PLAN.md` (chip-inventory repo) so it doesn’t get forgotten.
