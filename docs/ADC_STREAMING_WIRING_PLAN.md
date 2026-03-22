# ADC Streaming Wiring Plan (v1)

Goal: wire the **real** ADS131M08 ingest path into the user project (IP repo + harness) in a way that is:
- low-risk for integration (build-flagged)
- firmware-visible via the existing regmap (`ADC_FIFO_*`, `ADC_RAW_CH*`)
- compatible with bring-up stubs until the harness pinout/clocking are finalized

This doc is intentionally implementation-oriented (a checklist).

## Definitions

- **Stub path**: `ADC_CMD.SNAPSHOT` latches `ADC_RAW_CHx` and (optionally) pushes a single synthetic frame into the FIFO.
- **Real ingest path**: SPI/DRDY-driven capture from ADS131M08 that pushes frames into the FIFO.
- **Build flag**: `USE_REAL_ADC_INGEST` (or similar) selects stub vs real ingest.

## Contract summary (what must not change silently)

### Firmware contract
- FIFO packing is normative (see `spec/regmap.md`):
  - Word 0: status word (0 if unavailable)
  - Word 1..8: CH0..CH7 sign-extended to 32-bit, right-justified native width
- `ADC_FIFO_STATUS.LEVEL_WORDS` counts 32-bit words (not frames).
- `ADC_FIFO_STATUS.OVERRUN` is sticky W1C.
- `ADC_FIFO_STATUS.CAPTURE_BUSY` is 1 only in the real ingest build.

### Harness contract (must be locked before tapeout)
- ADC pin mapping: `docs/ADC_PINOUT_CONTRACT.md`
- ADC CLKIN source/frequency: `decisions/011-adc-clkin-source-and-frequency.md`

## RTL wiring plan (chip-inventory repo)

### 1) Top-level integration (`rtl/home_inventory_top.v`)
- Instantiate real ingest block only when `USE_REAL_ADC_INGEST` is defined.
- Inputs (expected names; adapt to actual module):
  - `adc_sclk`, `adc_csn`, `adc_mosi`, `adc_miso`
  - `adc_drdy_n` (or `adc_drdy` + explicit polarity handling)
  - `adc_rst_n`
  - `wb_clk_i` / `wb_rst_i` domain for FIFO + regbank
- Outputs to the Wishbone/regbank domain:
  - FIFO write: `fifo_wr_en`, `fifo_wr_data[31:0]`
  - FIFO status: `capture_busy`, `overrun_sticky`
  - Optionally: latest raw channels for `ADC_RAW_CHx` mirror

**CDC rule (v1):** avoid multi-domain complexity.
- Preferred: run the ingest capture state machine in the **wb clock domain** and treat ADC SPI as synchronous to `wb_clk_i` (for bring-up).
- If the ADC capture uses another clock, make CDC explicit:
  - synchronize DRDY edge into wb domain (2FF + edge detect)
  - perform SPI sampling with a derived/controlled clock, or implement a clean async FIFO boundary

### 2) FIFO module (`rtl/adc/adc_stream_fifo.v`)
- Confirm interface is exactly what regbank expects:
  - `level_words` exposed
  - `pop` on `ADC_FIFO_DATA` read when non-empty
  - sticky overrun asserted on write when full

### 3) Regbank wiring (`rtl/home_inventory_wb.v`)
- Ensure these registers are sourced correctly in **both** builds:
  - `ADC_FIFO_STATUS.LEVEL_WORDS`
  - `ADC_FIFO_STATUS.OVERRUN` (W1C)
  - `ADC_FIFO_STATUS.CAPTURE_BUSY` (0 in stub build)
- Ensure `ADC_CMD.SNAPSHOT` still works for bring-up (stub build).

## Harness wiring plan (home-inventory-chip-openmpw repo)

### 1) Wrapper constants and overrides
- Ensure placeholder ADC IO indices are either:
  - overridden by make/defines for the chosen harness mapping, or
  - replaced by the real mapping once confirmed.

### 2) Sanity checks (must be runnable on low disk)
- Run from `chip-inventory`:
  - `bash ops/preflight_all_low_disk.sh`
  - `bash tools/harness_placeholder_suite.sh ../home-inventory-chip-openmpw`
  - `bash tools/harness_adc_pinout_placeholder_check.sh ../home-inventory-chip-openmpw`
  - `bash tools/harness_adc_clocking_placeholder_check.sh ../home-inventory-chip-openmpw`

## Bring-up checklist (acceptance for this wiring)

This wiring step is “done” when:
1) RTL compile-check passes in both repos (low-disk path).
2) Stub build:
   - `ADC_CMD.SNAPSHOT` increments `ADC_SNAPSHOT_COUNT`.
   - `ADC_RAW_CHx` are readable (even if synthetic).
   - FIFO pop path works (LEVEL decreases; empty reads return 0).
3) Real ingest build:
   - `CAPTURE_BUSY` asserts during capture.
   - FIFO receives 9 words per frame (status + 8 channels).
   - Overrun sticky asserts when firmware intentionally stops draining.

## Open questions (track explicitly)
- What is the authoritative `wb_clk_i` frequency in the harness? (Needed for timestamp scaling + FIFO service budget.)
- ADS131M08 CPOL/CPHA and exact frame alignment assumptions (see `spec/ads131m08_interface.md`).
- Do we want a frame counter in the FIFO stream (optional future word 0 encoding)?
