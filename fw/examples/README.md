# Firmware examples (bring-up)

These examples are **standalone snippets** meant to be copy/pasted into the
Caravel management firmware environment.

They are intentionally minimal and avoid depending on a particular SDK.

## Files
- `homeinv_reg_smoke.c`: minimal reg-block smoke test:
  - reads `ID`/`VERSION`
  - writes `CTRL.ENABLE`
  - reads `TIME_NOW` (sanity check for a live counter)
  - pulses `CTRL.START` (W1P)

- `homeinv_adc_fifo_dump.c`: demonstrates how to:
  - clear FIFO overrun (W1C)
  - trigger a `SNAPSHOT`
  - drain the ADC FIFO as 32-bit words

- `homeinv_event_detector_smoke.c`: demonstrates how to:
  - enable event detection on CH0 (`EVT_CFG`)
  - program a threshold (`EVT_THRESH_CH0`)
  - trigger `ADC_CMD.SNAPSHOT` (current RTL stub sample_valid)
  - read `EVT_COUNT_CH0`, `EVT_LAST_DELTA_CH0`, `EVT_LAST_TS`

## Integration notes (Caravel/Wishbone pitfalls)

1) **Offsets are byte addresses**
- The register offsets in `home_inventory_regmap.h` are **byte offsets**.
- Caravel presents a byte address on `wbs_adr_i`. Do not treat offsets as
  word indices unless you explicitly shift (`byte_off = word_index << 2`).

2) **Byte-enables / partial writes**
- The RTL is required to honor `wbs_sel_i[3:0]` for writes.
- For sticky/W1C bits (e.g. `ADC_FIFO_STATUS.OVERRUN`), prefer full-word writes
  so you don't accidentally miss the byte lane containing the sticky bit.

3) **Base address is harness-specific**
- You must provide the correct peripheral base address for your platform.
  In Caravel this is often the user project Wishbone base (commonly shown as
  `0x3000_0000` in examples), but confirm in the specific harness/SoC docs.

## Notes
- These snippets use the generated register map header:
  - `../include/home_inventory_regmap.h`
- For full regmap semantics (W1P/W1C details, FIFO packing), see:
  - `../../spec/regmap.md`
