# Firmware (v1)

This folder contains firmware-facing artifacts for the **home-inventory** OpenMPW user project.

Goal: keep the RTL/spec **register map** usable from C early, even before full firmware exists.

## What lives here
- `include/home_inventory_regmap.h`: C header with Wishbone register offsets + bitfields.

## Conventions
- Base address is platform-specific (Caravel / management SoC map). Use offsets from `HOMEINV_*`.
- All registers are 32-bit.
- Addresses in the spec are **byte addresses**.

## Source of truth
- Human-readable spec: `../spec/regmap.md`
- Machine-readable: `../spec/regmap_v1.yaml`
