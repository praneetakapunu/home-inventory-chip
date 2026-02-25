# Firmware examples (bring-up)

These examples are **standalone snippets** meant to be copy/pasted into the
Caravel management firmware environment.

They are intentionally minimal and avoid depending on a particular SDK.

## Files
- `homeinv_adc_fifo_dump.c`: demonstrates how to:
  - clear FIFO overrun (W1C)
  - trigger a `SNAPSHOT`
  - drain the ADC FIFO as 32-bit words

- `homeinv_event_detector_smoke.c`: demonstrates how to:
  - enable event detection on CH0 (`EVT_CFG`)
  - program a threshold (`EVT_THRESH_CH0`)
  - trigger `ADC_CMD.SNAPSHOT` (current RTL stub sample_valid)
  - read `EVT_COUNT_CH0`, `EVT_LAST_DELTA_CH0`, `EVT_LAST_TS`

## Notes
- These snippets use the generated register map header:
  - `../include/home_inventory_regmap.h`
- You must provide the correct peripheral base address for your platform.
  In Caravel this is typically the user project Wishbone base, e.g.
  `0x3000_0000`, but confirm in the harness/SoC documentation.
