# Register Map (v1)

This is the **v1** register map for the digital block that will live in the OpenMPW (Caravel) harness.

Source-of-truth (machine-readable): `spec/regmap_v1.yaml`

- Bus: **Wishbone slave**, 32-bit data.
- Addressing: Caravel presents a **byte address** on `wbs_adr_i`, but this block decodes registers as **32-bit word-aligned** (i.e. it ignores `wbs_adr_i[1:0]`).
- All registers are 32-bit.
- Byte-enables (`wbs_sel_i`) must be respected on writes.

### Wishbone byte-select semantics (normative)
- Writes are **byte-lane masked** by `wbs_sel_i[3:0]` (little-endian lanes).
- For **W1C (write-1-to-clear)** bits, only bits in selected byte lanes participate in the clear operation.
  - Recommendation for firmware: write full word (`wbs_sel_i = 4'b1111`) when clearing sticky bits.

## Goals
- Provide a stable bring-up surface early (ID/VERSION + basic control/status).
- Leave clean address space for ADC + calibration + event reporting.

## 0x0000_0000 — ID / version

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0000 | `ID` | RO | — | Fixed ASCII tag. Current RTL returns `0x4849_4348` (`"HICH"`). |
| 0x0000_0004 | `VERSION` | RO | — | Register map / RTL interface version. Current RTL returns `0x0000_0001`. |

## 0x0000_0100 — Control / status

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0100 | `CTRL` | RW | 0x0 | Control bits (see below). `START` is write-1-to-pulse. |
| 0x0000_0104 | `IRQ_EN` | RW | 0x0 | Enable bits for `user_irq[2:0]` (future). |
| 0x0000_0108 | `STATUS` | RO | — | Status from core. Current RTL exposes `core_status[7:0]` in bits `[7:0]`. |

### `CTRL` bitfields

| Bit | Name | Meaning |
|---:|---|---|
| 0 | `ENABLE` | 1 = enable core. |
| 1 | `START` | Write 1 to request a start pulse (1 cycle). Reads return 0. |

### `IRQ_EN` bitfields

| Bit | Name | Meaning |
|---:|---|---|
| 2:0 | `IRQ_EN` | Per-interrupt enable (future). |

## 0x0000_0200 — ADC interface

These registers define the firmware-visible ADC interface.
Numeric conventions (raw sample width, sign-extension, etc.) are defined in `spec/fixed_point.md`.

Two usage models exist:
1) **Snapshot (bring-up)**: firmware triggers `ADC_CMD.SNAPSHOT` and then reads `ADC_RAW_CHx`.
2) **Streaming (preferred)**: hardware pushes per-frame words into a small FIFO which firmware drains via `ADC_FIFO_DATA`.

### Streaming FIFO packing (normative)
When streaming is enabled, each captured ADC frame is pushed to the FIFO as:
- Word 0: `ADC_STATUS_WORD` (raw ADC status if available; otherwise 0)
- Word 1..8: `ADC_CH0..ADC_CH7` raw samples

Each channel word is a sign-extended 32-bit value with the **native ADC sample width** right-justified (expected 24-bit).

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0200 | `ADC_CFG` | RW | 0x0 | ADC config. For v1 bring-up, only `NUM_CH` is normative; other fields are reserved and must read as 0. |
| 0x0000_0204 | `ADC_CMD` | RW | 0x0 | ADC command. For v1 bring-up, `SNAPSHOT` is write-1-to-pulse (latch raw regs). Other fields reserved. |
| 0x0000_0208 | `ADC_FIFO_STATUS` | RO/W1C | — | Streaming FIFO status (level + sticky overrun). |
| 0x0000_020C | `ADC_FIFO_DATA` | RO | — | Streaming FIFO data pop. Each read pops one 32-bit word **when `LEVEL_WORDS != 0`**. Reads when empty return 0 and do not change state. |
| 0x0000_0210 | `ADC_RAW_CH0` | RO | — | Latest raw sample CH0. Format per `spec/fixed_point.md` (24-bit right-justified with sign/zero extension). |
| 0x0000_0214 | `ADC_RAW_CH1` | RO | — | Latest raw sample CH1. Format per `spec/fixed_point.md`. |
| 0x0000_0218 | `ADC_RAW_CH2` | RO | — | Latest raw sample CH2. Format per `spec/fixed_point.md`. |
| 0x0000_021C | `ADC_RAW_CH3` | RO | — | Latest raw sample CH3. Format per `spec/fixed_point.md`. |
| 0x0000_0220 | `ADC_RAW_CH4` | RO | — | Latest raw sample CH4. Format per `spec/fixed_point.md`. |
| 0x0000_0224 | `ADC_RAW_CH5` | RO | — | Latest raw sample CH5. Format per `spec/fixed_point.md`. |
| 0x0000_0228 | `ADC_RAW_CH6` | RO | — | Latest raw sample CH6. Format per `spec/fixed_point.md`. |
| 0x0000_022C | `ADC_RAW_CH7` | RO | — | Latest raw sample CH7. Format per `spec/fixed_point.md`. |
| 0x0000_0230 | `ADC_SNAPSHOT_COUNT` | RO | — | Counts the number of accepted `ADC_CMD.SNAPSHOT` pulses (bring-up/debug). |

### `ADC_CFG` bitfields (v1 bring-up)

| Bit(s) | Name | Meaning |
|---:|---|---|
| 3:0 | `NUM_CH` | Number of channels populated (1–8). Firmware uses this to enumerate channels. |
| 31:4 | — | Reserved (must be 0; ignore on write). |

### `ADC_CMD` bitfields (v1 bring-up)

| Bit(s) | Name | Meaning |
|---:|---|---|
| 0 | `SNAPSHOT` | Write 1 to request a snapshot/latch of all `ADC_RAW_CHx` registers. Reads return 0. |
| 31:1 | — | Reserved. |

### `ADC_FIFO_STATUS` bitfields (v1)

| Bit(s) | Name | Meaning |
|---:|---|---|
| 15:0 | `LEVEL_WORDS` | Current FIFO fill level in 32-bit words. |
| 16 | `OVERRUN` | Sticky FIFO overrun. Write 1 to clear (W1C; byte-lane masked via `wbs_sel_i`). |
| 31:17 | — | Reserved (read as 0). |

## 0x0000_0300 — Calibration

Per-channel calibration constants. Formats are **normative** and defined in `spec/fixed_point.md`.

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0300 | `TARE_CH0` | RW | 0x0 | Signed 32-bit tare/offset for CH0 (raw ADC LSBs). |
| 0x0000_0304 | `TARE_CH1` | RW | 0x0 | Signed 32-bit tare/offset for CH1. |
| 0x0000_0308 | `TARE_CH2` | RW | 0x0 | Signed 32-bit tare/offset for CH2. |
| 0x0000_030C | `TARE_CH3` | RW | 0x0 | Signed 32-bit tare/offset for CH3. |
| 0x0000_0310 | `TARE_CH4` | RW | 0x0 | Signed 32-bit tare/offset for CH4. |
| 0x0000_0314 | `TARE_CH5` | RW | 0x0 | Signed 32-bit tare/offset for CH5. |
| 0x0000_0318 | `TARE_CH6` | RW | 0x0 | Signed 32-bit tare/offset for CH6. |
| 0x0000_031C | `TARE_CH7` | RW | 0x0 | Signed 32-bit tare/offset for CH7. |
| 0x0000_0320 | `SCALE_CH0` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH0 (1.0 = `0x0001_0000`). |
| 0x0000_0324 | `SCALE_CH1` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH1. |
| 0x0000_0328 | `SCALE_CH2` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH2. |
| 0x0000_032C | `SCALE_CH3` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH3. |
| 0x0000_0330 | `SCALE_CH4` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH4. |
| 0x0000_0334 | `SCALE_CH5` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH5. |
| 0x0000_0338 | `SCALE_CH6` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH6. |
| 0x0000_033C | `SCALE_CH7` | RW | 0x0001_0000 | Unsigned Q16.16 scale for CH7. |

## 0x0000_0400 — Events

Address space for event/counter reporting. Formats are defined in `spec/fixed_point.md`.

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0400 | `EVT_COUNT_CH0` | RO | — | Unsigned 32-bit saturating event count CH0. |
| 0x0000_0404 | `EVT_COUNT_CH1` | RO | — | Unsigned 32-bit saturating event count CH1. |
| 0x0000_0408 | `EVT_COUNT_CH2` | RO | — | Unsigned 32-bit saturating event count CH2. |
| 0x0000_040C | `EVT_COUNT_CH3` | RO | — | Unsigned 32-bit saturating event count CH3. |
| 0x0000_0410 | `EVT_COUNT_CH4` | RO | — | Unsigned 32-bit saturating event count CH4. |
| 0x0000_0414 | `EVT_COUNT_CH5` | RO | — | Unsigned 32-bit saturating event count CH5. |
| 0x0000_0418 | `EVT_COUNT_CH6` | RO | — | Unsigned 32-bit saturating event count CH6. |
| 0x0000_041C | `EVT_COUNT_CH7` | RO | — | Unsigned 32-bit saturating event count CH7. |
| 0x0000_0420 | `EVT_LAST_DELTA_CH0` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH0. |
| 0x0000_0424 | `EVT_LAST_DELTA_CH1` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH1. |
| 0x0000_0428 | `EVT_LAST_DELTA_CH2` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH2. |
| 0x0000_042C | `EVT_LAST_DELTA_CH3` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH3. |
| 0x0000_0430 | `EVT_LAST_DELTA_CH4` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH4. |
| 0x0000_0434 | `EVT_LAST_DELTA_CH5` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH5. |
| 0x0000_0438 | `EVT_LAST_DELTA_CH6` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH6. |
| 0x0000_043C | `EVT_LAST_DELTA_CH7` | RO | — | Unsigned 32-bit delta (in sample ticks) for CH7. |
| 0x0000_0440 | `EVT_LAST_TS` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event across any channel. |
| 0x0000_0444 | `EVT_CFG` | RW | 0x0 | Event detector config. `EVT_EN[7:0]` enables per channel. |
| 0x0000_0448 | `EVT_LAST_TS_CH0` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH0. |
| 0x0000_044C | `EVT_LAST_TS_CH1` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH1. |
| 0x0000_0450 | `EVT_LAST_TS_CH2` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH2. |
| 0x0000_0454 | `EVT_LAST_TS_CH3` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH3. |
| 0x0000_0458 | `EVT_LAST_TS_CH4` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH4. |
| 0x0000_045C | `EVT_LAST_TS_CH5` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH5. |
| 0x0000_0460 | `EVT_LAST_TS_CH6` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH6. |
| 0x0000_0464 | `EVT_LAST_TS_CH7` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event on CH7. |
| 0x0000_0480 | `EVT_THRESH_CH0` | RW | 0x0 | Signed 32-bit threshold for CH0 in raw ADC LSBs (after sign-extension to 32b). |
| 0x0000_0484 | `EVT_THRESH_CH1` | RW | 0x0 | Signed 32-bit threshold for CH1. |
| 0x0000_0488 | `EVT_THRESH_CH2` | RW | 0x0 | Signed 32-bit threshold for CH2. |
| 0x0000_048C | `EVT_THRESH_CH3` | RW | 0x0 | Signed 32-bit threshold for CH3. |
| 0x0000_0490 | `EVT_THRESH_CH4` | RW | 0x0 | Signed 32-bit threshold for CH4. |
| 0x0000_0494 | `EVT_THRESH_CH5` | RW | 0x0 | Signed 32-bit threshold for CH5. |
| 0x0000_0498 | `EVT_THRESH_CH6` | RW | 0x0 | Signed 32-bit threshold for CH6. |
| 0x0000_049C | `EVT_THRESH_CH7` | RW | 0x0 | Signed 32-bit threshold for CH7. |

### `EVT_CFG` bitfields (planned)

| Bit(s) | Name | Meaning |
|---:|---|---|
| 7:0 | `EVT_EN` | 1 = enable event detection for channel. |
| 31:8 | — | Reserved. |

## Notes
- Event detector thresholds are specified in **raw ADC LSBs** so firmware can start using them immediately; additional modes (hysteresis, debounce, comparator direction) can be added later without changing existing addresses.
- Unknown/unused addresses must read as 0.
