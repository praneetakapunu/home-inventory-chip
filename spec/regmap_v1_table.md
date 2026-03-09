# Register Map Table (generated)

This file is **auto-generated** from `spec/regmap_v1.yaml`. Do not edit by hand.

- Source: `spec/regmap_v1.yaml`
- Version: 1
- Bus: wishbone (32-bit)
- Address unit: byte; word_align: 4

## 0x00000000 — id_version

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00000000 | `ID` | ro | — | Fixed ASCII tag. Current RTL returns 0x4849_4348 ("HICH"). |
| 0x00000004 | `VERSION` | ro | — | Register map / RTL interface version. Current RTL returns 0x0000_0001. |

## 0x00000100 — ctrl_status

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00000100 | `CTRL` | rw | 0x00000000 | Control bits. START is write-1-to-pulse; reads return 0. |
| 0x00000104 | `IRQ_EN` | rw | 0x00000000 | Enable bits for user_irq[2:0] (future). |
| 0x00000108 | `STATUS` | ro | — | Status from core. Current RTL exposes core_status[7:0] in bits [7:0]. |
| 0x0000010C | `TIME_NOW` | ro | — | Free-running 32-bit timebase counter (increments every wb_clk_i). Wraps naturally. |

### `CTRL` fields @ 0x00000100

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 0 | `ENABLE` | rw | 0x00000000 | 1 = enable core. |
| 1 | `START` | w1p | 0x00000000 | Write 1 to request a start pulse (1 cycle). Reads return 0. |

### `IRQ_EN` fields @ 0x00000104

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 2:0 | `IRQ_EN` | rw | 0x00000000 | Per-interrupt enable (future). |

### `STATUS` fields @ 0x00000108

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 7:0 | `CORE_STATUS` | ro | — | Core status bits. |

## 0x00000200 — adc

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00000200 | `ADC_CFG` | rw | 0x00000008 | ADC config. For v1 bring-up, only NUM_CH is normative. |
| 0x00000204 | `ADC_CMD` | rw | 0x00000000 | ADC command. SNAPSHOT is write-1-to-pulse; reads return 0. |
| 0x00000208 | `ADC_FIFO_STATUS` | ro_w1c | — | Streaming FIFO status. LEVEL_WORDS reports fill level; OVERRUN is sticky and clears on write-1 (byte-lane masked by wbs_sel_i). |
| 0x0000020C | `ADC_FIFO_DATA` | ro | — | FIFO data pop. Each read pops one 32-bit word when LEVEL_WORDS != 0; reads when empty return 0 and do not change state. |
| 0x00000210 | `ADC_RAW_CH0` | ro | — | Latest raw sample CH0 (format per spec/fixed_point.md). |
| 0x00000214 | `ADC_RAW_CH1` | ro | — | Latest raw sample CH1 (format per spec/fixed_point.md). |
| 0x00000218 | `ADC_RAW_CH2` | ro | — | Latest raw sample CH2 (format per spec/fixed_point.md). |
| 0x0000021C | `ADC_RAW_CH3` | ro | — | Latest raw sample CH3 (format per spec/fixed_point.md). |
| 0x00000220 | `ADC_RAW_CH4` | ro | — | Latest raw sample CH4 (format per spec/fixed_point.md). |
| 0x00000224 | `ADC_RAW_CH5` | ro | — | Latest raw sample CH5 (format per spec/fixed_point.md). |
| 0x00000228 | `ADC_RAW_CH6` | ro | — | Latest raw sample CH6 (format per spec/fixed_point.md). |
| 0x0000022C | `ADC_RAW_CH7` | ro | — | Latest raw sample CH7 (format per spec/fixed_point.md). |
| 0x00000230 | `ADC_SNAPSHOT_COUNT` | ro | — | Counts the number of accepted SNAPSHOT commands (for bring-up / debug). |

### `ADC_CFG` fields @ 0x00000200

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 3:0 | `NUM_CH` | rw | 0x00000008 | Number of channels populated (1–8). Firmware enumerates channels using this. |

### `ADC_CMD` fields @ 0x00000204

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 0 | `SNAPSHOT` | w1p | 0x00000000 | Write 1 to latch raw regs into ADC_RAW_CHx. |

### `ADC_FIFO_STATUS` fields @ 0x00000208

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 15:0 | `LEVEL_WORDS` | ro | — | Current FIFO fill level in 32-bit words. |
| 16 | `OVERRUN` | w1c | — | Sticky FIFO overrun (FIFO full when a new word arrived). Write 1 to clear. |
| 17 | `CAPTURE_BUSY` | ro | — | 1 when the real ADC ingest block is actively capturing a frame. 0 in stub mode. |

## 0x00000300 — calibration

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00000300 | `TARE_CH0` | rw | 0x00000000 | Signed 32-bit tare/offset for CH0 (raw ADC LSBs). |
| 0x00000304 | `TARE_CH1` | rw | 0x00000000 | Signed 32-bit tare/offset for CH1. |
| 0x00000308 | `TARE_CH2` | rw | 0x00000000 | Signed 32-bit tare/offset for CH2. |
| 0x0000030C | `TARE_CH3` | rw | 0x00000000 | Signed 32-bit tare/offset for CH3. |
| 0x00000310 | `TARE_CH4` | rw | 0x00000000 | Signed 32-bit tare/offset for CH4. |
| 0x00000314 | `TARE_CH5` | rw | 0x00000000 | Signed 32-bit tare/offset for CH5. |
| 0x00000318 | `TARE_CH6` | rw | 0x00000000 | Signed 32-bit tare/offset for CH6. |
| 0x0000031C | `TARE_CH7` | rw | 0x00000000 | Signed 32-bit tare/offset for CH7. |
| 0x00000320 | `SCALE_CH0` | rw | 0x00010000 | Unsigned Q16.16 scale for CH0 (1.0 = 0x0001_0000). |
| 0x00000324 | `SCALE_CH1` | rw | 0x00010000 | Unsigned Q16.16 scale for CH1. |
| 0x00000328 | `SCALE_CH2` | rw | 0x00010000 | Unsigned Q16.16 scale for CH2. |
| 0x0000032C | `SCALE_CH3` | rw | 0x00010000 | Unsigned Q16.16 scale for CH3. |
| 0x00000330 | `SCALE_CH4` | rw | 0x00010000 | Unsigned Q16.16 scale for CH4. |
| 0x00000334 | `SCALE_CH5` | rw | 0x00010000 | Unsigned Q16.16 scale for CH5. |
| 0x00000338 | `SCALE_CH6` | rw | 0x00010000 | Unsigned Q16.16 scale for CH6. |
| 0x0000033C | `SCALE_CH7` | rw | 0x00010000 | Unsigned Q16.16 scale for CH7. |

## 0x00000400 — events

| Address | Name | Access | Reset | Description |
|---:|---|---|---:|---|
| 0x00000400 | `EVT_COUNT_CH0` | ro | — | Unsigned 32-bit saturating event count CH0. |
| 0x00000404 | `EVT_COUNT_CH1` | ro | — | Unsigned 32-bit saturating event count CH1. |
| 0x00000408 | `EVT_COUNT_CH2` | ro | — | Unsigned 32-bit saturating event count CH2. |
| 0x0000040C | `EVT_COUNT_CH3` | ro | — | Unsigned 32-bit saturating event count CH3. |
| 0x00000410 | `EVT_COUNT_CH4` | ro | — | Unsigned 32-bit saturating event count CH4. |
| 0x00000414 | `EVT_COUNT_CH5` | ro | — | Unsigned 32-bit saturating event count CH5. |
| 0x00000418 | `EVT_COUNT_CH6` | ro | — | Unsigned 32-bit saturating event count CH6. |
| 0x0000041C | `EVT_COUNT_CH7` | ro | — | Unsigned 32-bit saturating event count CH7. |
| 0x00000420 | `EVT_LAST_DELTA_CH0` | ro | — | Unsigned 32-bit delta (sample ticks) for CH0. |
| 0x00000424 | `EVT_LAST_DELTA_CH1` | ro | — | Unsigned 32-bit delta (sample ticks) for CH1. |
| 0x00000428 | `EVT_LAST_DELTA_CH2` | ro | — | Unsigned 32-bit delta (sample ticks) for CH2. |
| 0x0000042C | `EVT_LAST_DELTA_CH3` | ro | — | Unsigned 32-bit delta (sample ticks) for CH3. |
| 0x00000430 | `EVT_LAST_DELTA_CH4` | ro | — | Unsigned 32-bit delta (sample ticks) for CH4. |
| 0x00000434 | `EVT_LAST_DELTA_CH5` | ro | — | Unsigned 32-bit delta (sample ticks) for CH5. |
| 0x00000438 | `EVT_LAST_DELTA_CH6` | ro | — | Unsigned 32-bit delta (sample ticks) for CH6. |
| 0x0000043C | `EVT_LAST_DELTA_CH7` | ro | — | Unsigned 32-bit delta (sample ticks) for CH7. |
| 0x00000440 | `EVT_LAST_TS` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event. |
| 0x00000444 | `EVT_CFG` | rw | 0x00000000 | Event detector config (v1). EVT_EN[7:0] enables per channel. 0→1 clears per-channel timestamp history so first event reports LAST_DELTA=0. |
| 0x00000448 | `EVT_LAST_TS_CH0` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH0. |
| 0x0000044C | `EVT_LAST_TS_CH1` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH1. |
| 0x00000450 | `EVT_LAST_TS_CH2` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH2. |
| 0x00000454 | `EVT_LAST_TS_CH3` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH3. |
| 0x00000458 | `EVT_LAST_TS_CH4` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH4. |
| 0x0000045C | `EVT_LAST_TS_CH5` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH5. |
| 0x00000460 | `EVT_LAST_TS_CH6` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH6. |
| 0x00000464 | `EVT_LAST_TS_CH7` | ro | — | Unsigned 32-bit timestamp (sample ticks) of most recent event on CH7. |
| 0x00000480 | `EVT_THRESH_CH0` | rw | 0x00000000 | Signed 32-bit threshold for CH0 in raw ADC LSBs (after sign-extension to 32b). |
| 0x00000484 | `EVT_THRESH_CH1` | rw | 0x00000000 | Signed 32-bit threshold for CH1. |
| 0x00000488 | `EVT_THRESH_CH2` | rw | 0x00000000 | Signed 32-bit threshold for CH2. |
| 0x0000048C | `EVT_THRESH_CH3` | rw | 0x00000000 | Signed 32-bit threshold for CH3. |
| 0x00000490 | `EVT_THRESH_CH4` | rw | 0x00000000 | Signed 32-bit threshold for CH4. |
| 0x00000494 | `EVT_THRESH_CH5` | rw | 0x00000000 | Signed 32-bit threshold for CH5. |
| 0x00000498 | `EVT_THRESH_CH6` | rw | 0x00000000 | Signed 32-bit threshold for CH6. |
| 0x0000049C | `EVT_THRESH_CH7` | rw | 0x00000000 | Signed 32-bit threshold for CH7. |

### `EVT_CFG` fields @ 0x00000444

| Bits | Field | Access | Reset | Description |
|---:|---|---|---:|---|
| 7:0 | `EVT_EN` | rw | 0x00000000 | 1 = enable event detection for channel. |
| 8 | `CLEAR_COUNTS` | w1p | 0x00000000 | Write 1 to clear all EVT_COUNT_CHx counters (timestamps unaffected). |
| 9 | `CLEAR_HISTORY` | w1p | 0x00000000 | Write 1 to clear per-channel timestamp history (LAST_TS_CHx/LAST_DELTA_CHx) and EVT_LAST_TS. |
