# RTL

This folder will hold the RTL for the home-inventory chip *logic* (source of truth).

Note: OpenMPW submission requires a Caravel `user_project_wrapper` harness. That harness lives in:
- https://github.com/praneetakapunu/home-inventory-chip-openmpw

Our RTL will be integrated into the harness repo as either:
- a submodule import (current), or
- a vendored snapshot when preparing the final submission bundle.

## Register map constants

Wishbone register byte addresses are defined in `spec/regmap_v1.yaml`.

To keep RTL decode constants in sync, we generate an include file:

- Source-of-truth: `spec/regmap_v1.yaml`
- Generated include: `rtl/include/regmap_params.vh`
- Generator: `python3 tools/regmap/gen_verilog_params.py --yaml spec/regmap_v1.yaml --out rtl/include/regmap_params.vh`
- Consistency check: `python3 tools/regmap/check_regmap.py --yaml spec/regmap_v1.yaml --rtl rtl/home_inventory_wb.v`
