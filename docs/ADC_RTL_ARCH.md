# ADC RTL Architecture (v1)

This document breaks the ADC interface into concrete RTL modules so we can implement + verify incrementally.

Target ADC: **TI ADS131M08** (see `decisions/008-adc-part-selection.md`).

## Design goals (v1)
- Provide a *stable* firmware-visible surface early (regmap + FIFO contract).
- Keep the SPI/framing layer generic enough that small datasheet corrections (STATUS/CRC presence, word size) do not force a rewrite.
- Make DV easy: cocotb can emulate DRDY + SPI MISO frames without a full analog model.

## Top-level data path

`ADS131M08` → (SPI framed capture) → (frame unpack + pack) → (stream FIFO) → (Wishbone drain)

Firmware-visible models:
1) **Snapshot** (bring-up): latch latest samples into `ADC_RAW_CHx` via `ADC_CMD.SNAPSHOT`.
2) **Streaming** (preferred): push one frame → FIFO; firmware drains via `ADC_FIFO_DATA`.

## Normative FIFO contract
Source of truth: `spec/regmap.md` + `spec/ads131m08_interface.md`.

Per conversion, push **9 x 32-bit words** into the streaming FIFO:
- Word 0: STATUS/RESPONSE word (raw from ADC; response to NULL command)
- Word 1..8: CH0..CH7 (native width right-justified, sign-extended to 32b)

Note: on the SPI wire the ADS131M08 outputs an additional **CRC word** at the end of each frame (10th word). v1 capture should **drop** this CRC word and only push the 9-word payload above.

## Proposed module split

### 1) `adc_drdy_sync`
- Inputs: `adc_drdy_n` (async), `clk`, `rst`
- Output: `drdy_pulse` (1-cycle pulse when a new frame is ready)

Notes:
- Treat DRDY as asynchronous; 2FF sync + edge detect.

### 2) `adc_spi_frame_capture`
Role: capture a complete "frame" worth of words from the ADC serial stream.

**Key point:** this module should not *assume* the exact ADS131M08 layout beyond "N words of W bits".

- Inputs:
  - `clk`, `rst`
  - `start` (pulse, typically from `drdy_pulse`)
  - `adc_sclk`, `adc_cs_n`, `adc_mosi` (driven elsewhere)
  - `adc_miso` (from ADC)
- Params:
  - `BITS_PER_WORD` (default 32, preferred for v1 so samples arrive sign-extended)
  - `WORDS_PER_FRAME_WIRE` (default 10: RESPONSE/STATUS + 8 channels + CRC)
  - `DROP_OUTPUT_CRC` (default 1 for v1)
  - `HAS_STATUS_WORD` (default 1)
- Outputs:
  - `frame_valid` (pulse when a full wire frame has been captured)
  - `frame_words_wire[0:WORDS_PER_FRAME_WIRE-1]` (packed to 32b, right-justified)
  - `busy`, `err` (optional)

Implementation strategy (v1):
- Generate SCLK and CS in a simple deterministic way (or accept them from a shared SPI master).
- Sample MISO on the correct edge (CPOL=0/CPHA=1 per `spec/ads131m08_interface.md`) — keep this selectable with parameters.

### 3) `adc_frame_unpack_pack`
- Input: `frame_words[]`
- Output:
  - `status_word` (32b)
  - `ch0..ch7` (32b each, sign-extended)

This is where ADS131M08-specific assumptions live, but keep them minimal.

### 4) `adc_stream_fifo`
- Interface: simple push/pop FIFO in **32-bit words**.
- Push side: 9 words per frame.
- Pop side: Wishbone `ADC_FIFO_DATA` reads.

Must provide:
- `level_words` for `ADC_FIFO_STATUS.LEVEL_WORDS`
- Sticky `overrun` for `ADC_FIFO_STATUS.OVERRUN` (W1C)

### 5) `home_inventory_wb` integration
- Map `ADC_CFG.NUM_CH`, `ADC_CMD.SNAPSHOT`, `ADC_RAW_CHx`, FIFO status/data.
- Clear reserved bits on reads and ignore reserved bits on writes.

## Verification plan linkage
- Spec-level: `docs/VERIFICATION_PLAN.md`
- Existing Wishbone TB: `verify/wb_tb.v`
- Next DV milestone (harness repo): cocotb smoke tests for regblock + FIFO drain.

## Open items (must close before tapeout)
- Confirm SPI mode, word width, STATUS/CRC placement from datasheet.
- Decide whether CRC is enabled in v1.
- Decide clocking for ADC on the harness/PCB and how we expose/drive it.
