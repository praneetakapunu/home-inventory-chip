# ADC Firmware Init & Bring-up Sequence (v1)

This document is the **firmware-side** bring-up sequence for the v1 ADC path.
It is intentionally pragmatic: it tells you what to do first to see sane samples.

Related specs:
- ADC chip interface assumptions: `spec/ads131m08_interface.md`
- Register map: `spec/regmap.md` (source-of-truth: `spec/regmap_v1.yaml`)

## Goals (v1)
1) Prove we can talk to the Wishbone register block (ID/VERSION).
2) Prove the ADC streaming FIFO path works end-to-end (capture → FIFO → drain).
3) Provide a repeatable sequence that avoids common ADS131M08 “first data after pause” gotchas.

## Terminology
- **SoC**: Caravel user project / our RTL block
- **ADC**: TI ADS131M08 on the board
- **Frame**: one ADC conversion packet captured by RTL
  - In v1 we push **9 words** into FIFO per frame: `STATUS_WORD` + `CH0..CH7`.

## Preconditions (hardware)
- ADC has power.
- The board provides the ADC clocking expected by the design (see TODO in `spec/ads131m08_interface.md`).
- `adc_rst_n` is controllable (preferred) or at least well-behaved at power-up.

## Firmware sequence (recommended)

### 0) Basic sanity: ID/VERSION
1) Read `ID` @ `0x0000_0000` → expect ASCII tag (currently `"HICH"`).
2) Read `VERSION` @ `0x0000_0004` → expect `0x1` for regmap v1.

If either read is wrong, stop and debug bus/harness before touching ADC.

### 1) Configure channel count (enumeration only)
Write `ADC_CFG.NUM_CH` @ `0x0000_0200`.
- Set to the number of physically populated channels (1–8).
- This value is used for firmware-side loops and reporting.

### 2) Enable the core
Write `CTRL.ENABLE=1` @ `0x0000_0100`.

### 3) Clear any stale FIFO/overrun state
The FIFO status is visible in `ADC_FIFO_STATUS` @ `0x0000_0208`:
- `LEVEL_WORDS[15:0]`: number of 32-bit words currently in FIFO
- `OVERRUN[16]`: sticky; W1C

Do:
1) If `OVERRUN=1`, clear it by writing `1` to bit 16.
2) Drain any existing FIFO words by reading `ADC_FIFO_DATA` until `LEVEL_WORDS==0`.

Notes:
- Draining is safe even during early bring-up. It makes later checks unambiguous.
- For v1, the FIFO depth and exact watermark behavior are RTL-defined; firmware must handle non-zero level at any time.

### 4) ADS131M08 first-data precaution (important)
The ADS131M08 can retain two samples/channel internally if data weren’t read for a while.
Result: DRDY/STATUS behavior can be confusing on the first read.

Recommended v1 approach:
- After reset / any long pause, **discard the first two captured frames** before trusting steady-state.

(See `spec/ads131m08_interface.md` for rationale.)

### 5) Start capture (v1 generic)
The v1 register map includes `CTRL.START` (write-1-to-pulse) @ `0x0000_0100`.

Write `CTRL.START=1` once.
- This is a *pulse* request; reads return 0.

Expectation:
- If the ADC SPI capture path is active, frames begin appearing in the FIFO.

### 6) Drain frames + validate packing
Each captured frame contributes **9 FIFO words**, in order:
1) `STATUS_WORD`
2) `CH0`
3) `CH1`
4) `CH2`
5) `CH3`
6) `CH4`
7) `CH5`
8) `CH6`
9) `CH7`

Suggested smoke test:
1) Wait until `LEVEL_WORDS >= 18` (at least two frames buffered).
2) Read 18 words.
3) Discard the first 18 words (two frames) per the “first-data precaution”.
4) For subsequent frames:
   - Check that `STATUS_WORD` changes at the expected rate.
   - Check that channel words look like signed values (not all 0 / not stuck at a single code).

### 7) Snapshot path (optional bring-up)
The regmap also provides a snapshot mechanism:
- Write `ADC_CMD.SNAPSHOT=1` @ `0x0000_0204`
- Then read `ADC_RAW_CH0..CH7` @ `0x0000_0210..0x0000_022C`

Use this when you want a quick “single capture” sanity check without FIFO draining loops.

## Error handling / debug checklist
- `ADC_FIFO_STATUS.OVERRUN=1`:
  - Drain faster; increase poll rate; reduce ADC output rate; consider enlarging FIFO (RTL change).
- FIFO `LEVEL_WORDS` never increases after `CTRL.START`:
  - Check `CTRL.ENABLE`.
  - Confirm ADC clocking and DRDY toggling on the board.
  - Confirm SPI mode/word length expectations match `spec/ads131m08_interface.md`.
- Channel samples look byte-swapped or misaligned:
  - Likely word-length/packing mismatch (24 vs 32-bit mode); confirm WLENGTH choice.

## Open items (must be resolved before tapeout)
- Choose the exact ADS131M08 WLENGTH setting we will run in v1 and reflect it in:
  - firmware init code, and
  - `spec/ads131m08_interface.md` TODO list.
