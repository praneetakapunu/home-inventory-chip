# Register Map (v1)

This is the **v1** register map for the digital block that will live in the OpenMPW (Caravel) harness.

- Bus: **Wishbone slave**, 32-bit data.
- Addressing: Caravel presents a **byte address** on `wbs_adr_i`, but this block decodes registers as **32-bit word-aligned** (i.e. it ignores `wbs_adr_i[1:0]`).
- All registers are 32-bit.
- Byte-enables (`wbs_sel_i`) must be respected on writes.

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

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0200 | `ADC_CFG` | RW | 0x0 | ADC config. For v1 bring-up, only `NUM_CH` is normative; other fields are reserved and must read as 0. |
| 0x0000_0204 | `ADC_CMD` | RW | 0x0 | ADC command. For v1 bring-up, `SNAPSHOT` is write-1-to-pulse (latch raw regs). Other fields reserved. |
| 0x0000_0210 | `ADC_RAW_CH0` | RO | — | Latest raw sample CH0. Format per `spec/fixed_point.md` (24-bit right-justified with sign/zero extension). |
| 0x0000_0214 | `ADC_RAW_CH1` | RO | — | Latest raw sample CH1. Format per `spec/fixed_point.md`. |
| 0x0000_0218 | `ADC_RAW_CH2` | RO | — | Latest raw sample CH2. Format per `spec/fixed_point.md`. |
| 0x0000_021C | `ADC_RAW_CH3` | RO | — | Latest raw sample CH3. Format per `spec/fixed_point.md`. |
| 0x0000_0220 | `ADC_RAW_CH4` | RO | — | Latest raw sample CH4. Format per `spec/fixed_point.md`. |
| 0x0000_0224 | `ADC_RAW_CH5` | RO | — | Latest raw sample CH5. Format per `spec/fixed_point.md`. |
| 0x0000_0228 | `ADC_RAW_CH6` | RO | — | Latest raw sample CH6. Format per `spec/fixed_point.md`. |
| 0x0000_022C | `ADC_RAW_CH7` | RO | — | Latest raw sample CH7. Format per `spec/fixed_point.md`. |

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
| 0x0000_0440 | `EVT_LAST_TS` | RO | — | Unsigned 32-bit timestamp (in sample ticks) of most recent event. |

## Notes
- Fixed-point formats will be specified once ADC sampling resolution/rate is locked.
- Unknown/unused addresses must read as 0.
