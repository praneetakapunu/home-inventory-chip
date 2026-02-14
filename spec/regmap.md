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

## 0x0000_0200 — ADC interface (reserved)

Reserved for:
- `ADC_CFG`, `ADC_CMD`, `ADC_RAW_CH0..CH7`

## 0x0000_0300 — Calibration (reserved)

Reserved for:
- `TARE_CH0..CH7`, `SCALE_CH0..CH7`

## 0x0000_0400 — Events (reserved)

Reserved for:
- `EVT_COUNT_CH0..CH7`, `EVT_LAST_DELTA_CH0..CH7`, `EVT_LAST_TS`

## Notes
- Fixed-point formats will be specified once ADC sampling resolution/rate is locked.
- Unknown/unused addresses must read as 0.
