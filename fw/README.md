# Firmware (v1)

This folder contains firmware-facing artifacts for the **home-inventory** OpenMPW user project.

Goal: keep the RTL/spec **register map** usable from C early, even before full firmware exists.

## What lives here
- `include/home_inventory_regmap.h`: **generated** C header with Wishbone register offsets + bitfields.
- `tools/decode_adc_fifo.py`: bring-up helper to decode raw FIFO dumps into 9-word frames.
- `examples/`: copy/paste-ready bring-up snippets (SDK-agnostic).

## Conventions
- Base address is platform-specific (Caravel / management SoC map). Use offsets from `HOMEINV_*`.
- All registers are 32-bit.
- Addresses in the spec are **byte addresses**.

## Source of truth
- Human-readable spec: `../spec/regmap.md`
- Machine-readable: `../spec/regmap_v1.yaml`

## How to regenerate the regmap artifacts

`spec/regmap_v1.yaml` is the single source of truth.

To regenerate *all* derived artifacts (C header, SV package, markdown table, etc.):

```bash
cd ..
bash ops/regmap_update.sh
```

To verify nothing drifted (what CI runs):

```bash
cd ..
bash ops/regmap_check.sh
```
