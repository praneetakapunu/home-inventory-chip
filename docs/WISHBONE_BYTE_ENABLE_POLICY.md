# Wishbone byte-enable (`wbs_sel_i`) policy (v1)

This document locks the expected semantics of `wbs_sel_i[3:0]` for the **home_inventory** Wishbone register block (`rtl/home_inventory_wb.v`).

It exists to prevent firmware/harness ambiguity late in the tapeout cycle.

## Summary

- Addressing is **byte-addressed**, but the regblock decodes on **32-bit word boundaries**.
  - Decode uses: `wb_adr_aligned = {wbs_adr_i[31:2], 2'b00}`.
  - `wbs_adr_i[1:0]` is ignored for register selection.

- Reads ignore `wbs_sel_i`.
  - A read returns the full 32-bit register value.

- Writes honor `wbs_sel_i` **per-byte** for standard R/W registers.
  - Implementation uses `apply_wstrb(oldv, newv, sel)`.

- **Write-1-to-pulse** (W1P) and **write-1-to-clear** (W1C) bits have *explicit* lane requirements.
  - If the relevant byte lane is not selected, the pulse/clear does not fire.

## Byte lanes

`wbs_sel_i[n]` selects byte lane `n`:

- `wbs_sel_i[0]` → bits `[7:0]`
- `wbs_sel_i[1]` → bits `[15:8]`
- `wbs_sel_i[2]` → bits `[23:16]`
- `wbs_sel_i[3]` → bits `[31:24]`

## Standard R/W registers

Registers that are updated with `apply_wstrb(...)` support partial writes.

Examples (non-exhaustive):
- `IRQ_EN`
- `TARE_CHx`, `SCALE_CHx`
- `EVT_THRESH_CHx`

Reserved bits are still masked after applying strobes where required (e.g. `IRQ_EN` keeps only `[2:0]`).

## W1P (write-1-to-pulse) bits

These are not sticky; writing a `1` causes a **1-cycle** internal pulse (delayed by one cycle in RTL so downstream logic sees a clean full-cycle pulse).

### `CTRL.START` (bit 1)
- Fires when:
  - `wb_fire && wbs_we_i && (ADR == ADR_CTRL)`
  - **and** `wbs_sel_i[0] == 1` (byte lane 0 selected)
  - **and** `wbs_dat_i[1] == 1`

Implication: firmware must set `sel[0]` when writing `CTRL.START`.

### `ADC_CMD.SNAPSHOT` (bit 0)
- Fires when:
  - `wb_fire && wbs_we_i && (ADR == ADR_ADC_CMD)`
  - **and** `wbs_sel_i[0] == 1`
  - **and** `wbs_dat_i[0] == 1`

## Event detector W1P controls (`EVT_CFG`)

These pulses live in **byte lane 1**.

### `EVT_CFG.CLEAR_COUNTS` (bit 8)
- Requires `wbs_sel_i[1] == 1` and `wbs_dat_i[8] == 1`.

### `EVT_CFG.CLEAR_HISTORY` (bit 9)
- Requires `wbs_sel_i[1] == 1` and `wbs_dat_i[9] == 1`.

## ADC FIFO W1C bit (`ADC_FIFO_STATUS.OVERRUN`)

`ADC_FIFO_STATUS.OVERRUN` is a sticky flag that clears on a write-1.

- Bit: `16`
- Lane: **2** (bits `[23:16]`)
- Clear fires when:
  - `wb_fire && wbs_we_i && (ADR == ADR_ADC_FIFO_STATUS)`
  - **and** `wbs_sel_i[2] == 1`
  - **and** `wbs_dat_i[16] == 1`

This is intentionally lane-specific so a byte write to lane 2 can clear it without disturbing lane 0 (FIFO level field).

## Why this matters

Caravel firmware stacks sometimes default to `sel=4'b1111` (full word writes), but some lightweight drivers use byte writes.

If a W1P/W1C write is performed with the wrong byte lane selected, it will be silently ignored.

## References

- RTL source of truth: `rtl/home_inventory_wb.v`
- Regmap source of truth: `spec/regmap_v1.yaml` (generated human view: `spec/regmap.md`)
