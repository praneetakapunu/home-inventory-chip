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

## 0x0000_0200 — ADC interface (reserved placeholders)

These registers are **placeholders** to lock down address space for the ADC datapath.
Until the ADC part/protocol is chosen, reads should return 0 and writes may be ignored.

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0200 | `ADC_CFG` | RW | 0x0 | ADC configuration (format TBD: protocol, rate, gains). |
| 0x0000_0204 | `ADC_CMD` | RW | 0x0 | ADC command (format TBD: start conversion, sync, etc.). |
| 0x0000_0210 | `ADC_RAW_CH0` | RO | — | Raw sample channel 0 (format TBD). |
| 0x0000_0214 | `ADC_RAW_CH1` | RO | — | Raw sample channel 1 (format TBD). |
| 0x0000_0218 | `ADC_RAW_CH2` | RO | — | Raw sample channel 2 (format TBD). |
| 0x0000_021C | `ADC_RAW_CH3` | RO | — | Raw sample channel 3 (format TBD). |
| 0x0000_0220 | `ADC_RAW_CH4` | RO | — | Raw sample channel 4 (format TBD). |
| 0x0000_0224 | `ADC_RAW_CH5` | RO | — | Raw sample channel 5 (format TBD). |
| 0x0000_0228 | `ADC_RAW_CH6` | RO | — | Raw sample channel 6 (format TBD). |
| 0x0000_022C | `ADC_RAW_CH7` | RO | — | Raw sample channel 7 (format TBD). |

## 0x0000_0300 — Calibration (reserved placeholders)

Address space for per-channel calibration constants.

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0300 | `TARE_CH0` | RW | 0x0 | Tare/offset for channel 0 (format TBD). |
| 0x0000_0304 | `TARE_CH1` | RW | 0x0 | Tare/offset for channel 1 (format TBD). |
| 0x0000_0308 | `TARE_CH2` | RW | 0x0 | Tare/offset for channel 2 (format TBD). |
| 0x0000_030C | `TARE_CH3` | RW | 0x0 | Tare/offset for channel 3 (format TBD). |
| 0x0000_0310 | `TARE_CH4` | RW | 0x0 | Tare/offset for channel 4 (format TBD). |
| 0x0000_0314 | `TARE_CH5` | RW | 0x0 | Tare/offset for channel 5 (format TBD). |
| 0x0000_0318 | `TARE_CH6` | RW | 0x0 | Tare/offset for channel 6 (format TBD). |
| 0x0000_031C | `TARE_CH7` | RW | 0x0 | Tare/offset for channel 7 (format TBD). |
| 0x0000_0320 | `SCALE_CH0` | RW | 0x0 | Scale for channel 0 (format TBD). |
| 0x0000_0324 | `SCALE_CH1` | RW | 0x0 | Scale for channel 1 (format TBD). |
| 0x0000_0328 | `SCALE_CH2` | RW | 0x0 | Scale for channel 2 (format TBD). |
| 0x0000_032C | `SCALE_CH3` | RW | 0x0 | Scale for channel 3 (format TBD). |
| 0x0000_0330 | `SCALE_CH4` | RW | 0x0 | Scale for channel 4 (format TBD). |
| 0x0000_0334 | `SCALE_CH5` | RW | 0x0 | Scale for channel 5 (format TBD). |
| 0x0000_0338 | `SCALE_CH6` | RW | 0x0 | Scale for channel 6 (format TBD). |
| 0x0000_033C | `SCALE_CH7` | RW | 0x0 | Scale for channel 7 (format TBD). |

## 0x0000_0400 — Events (reserved placeholders)

Address space for event/counter reporting.

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x0000_0400 | `EVT_COUNT_CH0` | RO | — | Event count channel 0 (format TBD). |
| 0x0000_0404 | `EVT_COUNT_CH1` | RO | — | Event count channel 1 (format TBD). |
| 0x0000_0408 | `EVT_COUNT_CH2` | RO | — | Event count channel 2 (format TBD). |
| 0x0000_040C | `EVT_COUNT_CH3` | RO | — | Event count channel 3 (format TBD). |
| 0x0000_0410 | `EVT_COUNT_CH4` | RO | — | Event count channel 4 (format TBD). |
| 0x0000_0414 | `EVT_COUNT_CH5` | RO | — | Event count channel 5 (format TBD). |
| 0x0000_0418 | `EVT_COUNT_CH6` | RO | — | Event count channel 6 (format TBD). |
| 0x0000_041C | `EVT_COUNT_CH7` | RO | — | Event count channel 7 (format TBD). |
| 0x0000_0420 | `EVT_LAST_DELTA_CH0` | RO | — | Last event delta channel 0 (format TBD). |
| 0x0000_0424 | `EVT_LAST_DELTA_CH1` | RO | — | Last event delta channel 1 (format TBD). |
| 0x0000_0428 | `EVT_LAST_DELTA_CH2` | RO | — | Last event delta channel 2 (format TBD). |
| 0x0000_042C | `EVT_LAST_DELTA_CH3` | RO | — | Last event delta channel 3 (format TBD). |
| 0x0000_0430 | `EVT_LAST_DELTA_CH4` | RO | — | Last event delta channel 4 (format TBD). |
| 0x0000_0434 | `EVT_LAST_DELTA_CH5` | RO | — | Last event delta channel 5 (format TBD). |
| 0x0000_0438 | `EVT_LAST_DELTA_CH6` | RO | — | Last event delta channel 6 (format TBD). |
| 0x0000_043C | `EVT_LAST_DELTA_CH7` | RO | — | Last event delta channel 7 (format TBD). |
| 0x0000_0440 | `EVT_LAST_TS` | RO | — | Timestamp of last event (format TBD). |

## Notes
- Fixed-point formats will be specified once ADC sampling resolution/rate is locked.
- Unknown/unused addresses must read as 0.
