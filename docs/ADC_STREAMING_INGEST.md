# `adc_streaming_ingest` integration note (v1)

This doc explains how to use the RTL glue module:
- `rtl/adc/adc_streaming_ingest.v`

It is the intended **single integration point** for the v1 ADC streaming path:

`adc_spi_frame_capture` → `adc_frame_to_fifo` → `adc_stream_fifo` → (Wishbone regbank FIFO registers)

Normative behavior for the firmware-visible FIFO is defined in:
- `docs/ADC_STREAM_CONTRACT.md`

## What this module does (and does not)

**Does:**
- Generates SPI signals (`adc_sclk`, `adc_cs_n`, `adc_mosi`) and captures framed ADC words from `adc_miso`.
- Sequences a multi-word frame into a 1-word/beat FIFO push interface.
- Exposes a pop interface (`pop_valid/pop_data/pop_ready`) plus FIFO level and sticky overrun.
- Supports dropping trailing words (e.g. ADS131M08 output CRC) via `WORDS_OUT`.

**Does not:**
- Interpret ADC words (no channel mapping, no sign extension rules).
- Provide any register interface.
- Provide CDC; v1 assumes a single clock domain.

## Port summary

Clocks/resets:
- `clk`: v1 uses `wb_clk_i`.
- `rst`: synchronous reset in this clock domain.

Capture control:
- `start` (pulse): begin capture of exactly one frame. If asserted while `capture_busy==1`, request is ignored (v1).

SPI pins (SoC perspective):
- Outputs: `adc_sclk`, `adc_cs_n`, `adc_mosi`
- Input:  `adc_miso`

FIFO pop (consumer side, e.g. Wishbone):
- Output `pop_valid`, `pop_data[31:0]`
- Input  `pop_ready`

Status:
- `capture_busy`
- `fifo_level_words`
- `fifo_overrun_sticky` + `fifo_overrun_clear` (W1C pulse from regbank)

## Parameterization for ADS131M08 bring-up (recommended v1)

ADS131M08 wire frame is 10x 32-bit words:
- STATUS/RESPONSE + CH0..CH7 + OUTPUT_CRC

For v1 we expose a **SoC frame** of 9 words (CRC dropped).

Recommended instantiation:

- `BITS_PER_WORD   = 32`
- `WORDS_PER_FRAME = 10`
- `WORDS_OUT       = 9`  (drops OUTPUT_CRC)
- `CPOL/CPHA` per the chosen SPI mode (current default in RTL: `CPOL=0`, `CPHA=1`)
- `SCLK_DIV` tuned to meet ADC timing while staying friendly to digital closure
- `FIFO_DEPTH_WORDS = 16` for the **firmware-visible** FIFO (matches `docs/ADC_STREAM_CONTRACT.md`)

Note: `adc_streaming_ingest` itself can be used with deeper FIFOs in DV, but the regbank-visible FIFO depth should remain 16 unless the reg contract is updated.

## Suggested wiring in `home_inventory_wb.v`

Inside the Wishbone block (single-clock v1), the regbank should:

1) Instantiate `adc_streaming_ingest`.
2) Drive `.start` from the existing `ADC_CMD.SNAPSHOT` pulse (until continuous streaming is added).
3) Connect `.pop_*` to the existing `ADC_FIFO_DATA` pop-on-read semantics.
4) Connect `.fifo_level_words` and `.fifo_overrun_*` to `ADC_FIFO_STATUS`.

If/when the event detector is switched from the current stub to real ADC data:
- Tap the unpacked channel words from the packed frame **before** the FIFO (or reconstruct them from the first 9 popped words).
- Prefer tapping directly from the capture/unpack path to preserve “all 8 channels at once” semantics.

## Back-to-back frames and overflow

Internally, `adc_streaming_ingest` uses `adc_frame_to_fifo`, which provides:
- a 1-frame skid buffer for back-to-back `frame_valid` pulses
- a `frame_dropped` indicator (currently unused at the top level)

The FIFO implements drop-on-full and sets `fifo_overrun_sticky` whenever a push is attempted while full.

For v1, it is acceptable to:
- treat `fifo_overrun_sticky` as the only overflow indicator exposed to firmware
- optionally OR in the internal `frame_dropped` as “overrun” in a later change (but keep the reg semantics stable)

## Done-when (for the wiring commit)

When `adc_streaming_ingest` is integrated into the Wishbone block, the streaming path is “done” when:
- `make -C verify all` passes in the IP repo
- `bash ops/rtl_compile_check.sh` passes
- A directed test drains one frame and observes 9 FIFO words in STATUS, CH0..CH7 order (see `docs/ADC_STREAM_CONTRACT.md`)
