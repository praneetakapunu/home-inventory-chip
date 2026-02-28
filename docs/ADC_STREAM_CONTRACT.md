# ADC streaming contract (RTL ↔ regbank) — v1

This doc freezes the **minimal, tapeout-friendly wiring contract** for the ADC streaming path:

`adc_spi_frame_capture` → (word-unpacker) → `adc_stream_fifo` → Wishbone regbank (`ADC_FIFO_STATUS`/`ADC_FIFO_DATA`).

It is meant to be concrete enough that:
- RTL wiring can be implemented without re-litigating semantics.
- DV + firmware can write deterministic “drain one frame” tests.

Source-of-truth for firmware-visible behavior:
- `spec/regmap_v1.yaml`
- Human-readable summary: `spec/regmap.md`

## Clocks and domains

v1 assumes a **single clock domain** for the streaming path:
- `wb_clk_i` (Wishbone clock) is also the clock that drives:
  - `adc_spi_frame_capture.clk`
  - `adc_stream_fifo.clk`
  - the event detector timestamp counter (`TIME_NOW`)

If a future rev adds an ADC-specific clock, this contract must be revisited (CDC + timestamp alignment).

## Frame model (normative)

There are two related "frames" in v1:

1) **Wire frame** (ADS131M08 DOUT): **10 words** per conversion
   - word0 = STATUS/RESPONSE
   - word1..8 = CH0..CH7
   - word9 = OUTPUT_CRC (always present on the wire; ignored in v1)

2) **SoC frame** (what we push to the firmware-visible FIFO / event detector): **9 words**
   - STATUS + CH0..CH7 (CRC dropped)

A *SoC frame* is the fixed-length sequence of **9 words** (32-bit each) produced per ADC conversion event:

- Word 0: `ADC_STATUS_WORD`
- Word 1..8: `ADC_CH0 .. ADC_CH7`

All words are pushed into the FIFO in-order.

### Sample formatting

Each channel word is a **sign-extended 32-bit** value with the native ADC width right-justified.
For ADS131M08 bring-up we assume 24-bit samples.

(Formatting details: `spec/fixed_point.md`.)

## Capture block interface (`adc_spi_frame_capture`)

Module: `rtl/adc/adc_spi_frame_capture.v`

For ADS131M08 bring-up, instantiate this block with:
- `BITS_PER_WORD = 32` (MODE.WLENGTH=32b sign-extend)
- `WORDS_PER_FRAME = 10` (STATUS + 8 channels + output CRC)

The integration layer then **drops the final CRC word** and only pushes 9 words to the firmware FIFO/event detector.

### Inputs
- `start` (pulse): request capture of exactly one frame.
- `adc_miso`: ADC serial data.

### Outputs
- `busy`: high while capture is in progress.
- `frame_valid` (pulse): asserted for 1 cycle when the frame is complete.
- `frame_words_packed`: `32*WORDS_PER_FRAME` bits, packed as:
  - word0 in bits `[31:0]`, word1 in `[63:32]`, etc.

### Required behavior
- `frame_valid` must only assert when `frame_words_packed` is stable.
- A new `start` request while `busy==1` is ignored (v1 behavior).

## Unpack + FIFO push contract

FIFO module: `rtl/adc/adc_stream_fifo.v`

### FIFO push rule (normative)
On `frame_valid==1`, the top-level integration must attempt to push **exactly 9 FIFO words** in the following order:

1) `frame_words_packed[ 31:  0]` → STATUS
2) `frame_words_packed[ 63: 32]` → CH0
3) `frame_words_packed[ 95: 64]` → CH1
4) `frame_words_packed[127: 96]` → CH2
5) `frame_words_packed[159:128]` → CH3
6) `frame_words_packed[191:160]` → CH4
7) `frame_words_packed[223:192]` → CH5
8) `frame_words_packed[255:224]` → CH6
9) `frame_words_packed[287:256]` → CH7

If the FIFO cannot accept all words (near/full), the FIFO’s sticky `overrun` must assert.

### Overrun policy (v1)
- FIFO depth for the **firmware-visible FIFO** is v1-defined as **16 words**.
- When full:
  - pushes are **dropped**
  - `overrun_sticky` becomes 1 and stays 1 until cleared via `ADC_FIFO_STATUS.OVERRUN` W1C.

This matches the current stub semantics in `rtl/home_inventory_wb.v` and the DV expectations in `verify/wb_tb.v`.

## Register interface mapping

Registers:
- `ADC_FIFO_STATUS` @ `0x0000_0208`
  - `LEVEL_WORDS[15:0]`: current FIFO fill level (words)
  - `OVERRUN[16]`: sticky overflow indicator (W1C)
- `ADC_FIFO_DATA` @ `0x0000_020C`
  - reading pops one word iff `LEVEL_WORDS != 0`
  - empty reads return 0 and do not change state

Normative behavior: see `spec/regmap.md`.

## Minimal acceptance tests (done-when)

### DV (directed)
1) Trigger one capture (`start`), wait for `frame_valid`.
2) Read `ADC_FIFO_STATUS.LEVEL_WORDS` and expect `== 9`.
3) Drain `ADC_FIFO_DATA` 9 times and confirm ordering: STATUS then CH0..CH7.
4) Confirm `LEVEL_WORDS == 0` and empty-read returns 0.

### Overrun behavior
1) Trigger 2 frames without draining (18 pushes attempted into 16-depth FIFO).
2) Expect `LEVEL_WORDS == 16` and `OVERRUN == 1`.
3) Drain 16 words and confirm the retained word ordering is consistent with a drop-on-full policy.
4) Clear `OVERRUN` with W1C and confirm it reads 0.

## Integration in `home_inventory_wb.v` (implementation sketch)

This section exists to prevent “wiring drift”: the regbank contract is fixed, but there are several reasonable internal implementations.

### FIFO implementation choice

Use the shared RTL FIFO:
- `rtl/adc/adc_stream_fifo.v`
- Instantiate with `DEPTH_WORDS = 16` to match the firmware-visible depth defined above.

Expose the following internal signals in the Wishbone block:
- `adc_fifo_push_valid`, `adc_fifo_push_data[31:0]`, `adc_fifo_push_ready`
- `adc_fifo_pop_valid`,  `adc_fifo_pop_data[31:0]`,  `adc_fifo_pop_ready`
- `adc_fifo_level_words` (0..16)
- `adc_fifo_overrun_sticky` + `adc_fifo_overrun_clear` (W1C pulse from `ADC_FIFO_STATUS.OVERRUN`)

### Push sequencing rule (important)

A single `frame_valid` pulse represents **9 logical words** that must enter the FIFO in-order.

Because the FIFO push interface is 1 word/beat, the integration must include a tiny “push sequencer”.

Two equivalent options are acceptable in v1:

1) Inline the sequencer inside the top/wb block.
2) Instantiate the shared helper `rtl/adc/adc_frame_to_fifo.v`.

Sequencer behavior (normative):

- Latch the packed frame (`frame_words_packed`) on `frame_valid`.
- Set `push_idx = 0`.
- While `push_idx < 9`:
  - drive `adc_fifo_push_valid=1` with the next word
  - if `adc_fifo_push_ready==1`, the FIFO accepts the word
  - if `adc_fifo_push_ready==0` (full), the word is **dropped** (drop-on-full)
  - increment `push_idx` every cycle (regardless of `push_ready`)

**Back-to-back frames:** for v1 robustness, the shared helper `adc_frame_to_fifo.v` includes a **1-frame skid buffer** (it can accept one additional `frame_valid` while busy). If more frames arrive before it finishes pushing, it will assert `frame_dropped`.

Normative behavior when FIFO becomes full mid-frame:
- subsequent words are dropped by the FIFO’s drop-on-full policy
- `overrun_sticky` must assert and stay set until W1C cleared

### Register mapping (exact)

- `ADC_FIFO_STATUS.LEVEL_WORDS` returns `adc_fifo_level_words` (zero-extended into [15:0]).
- `ADC_FIFO_STATUS.OVERRUN` returns `adc_fifo_overrun_sticky`.
- `ADC_FIFO_DATA` read:
  - returns `adc_fifo_pop_data` when `adc_fifo_pop_valid==1`, else 0
  - asserts `adc_fifo_pop_ready` for 1 cycle only on the Wishbone **accepted read** beat

### Acceptance timing note

Tests should not assume the FIFO level becomes 9 in the same cycle as `frame_valid`.
Instead, DV/FW should poll `LEVEL_WORDS` until it reaches 9 (or a bounded timeout), then drain.

## Notes
- The existing Wishbone block (`rtl/home_inventory_wb.v`) currently implements a **deterministic stub** for streaming FIFO population on `ADC_CMD.SNAPSHOT`.
  - That stub is the reference behavior until `adc_spi_frame_capture` is wired in.
- When real ADC wiring lands, keep `spec/regmap_v1.yaml` stable; change internal implementation only.
