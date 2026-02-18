# ADS131M08 Interface Notes (v1 draft)

> Source of truth: TI ADS131M08 datasheet. This doc captures the *chip-level* assumptions we want for v1.
> If anything here conflicts with the datasheet, the datasheet wins.

## Goal
Define the minimum interface contract between:
- the **ADC** (ADS131M08),
- our **RTL** (SPI/serial capture + buffering), and
- our **firmware** (registers + packet format),

so we can implement a testable baseline without re-litigating basics.

## Top-level signals (proposed)
- `adc_sclk`  : SPI clock from SoC → ADC
- `adc_cs_n`  : chip select (active-low) from SoC → ADC
- `adc_mosi`  : serial data from SoC → ADC
- `adc_miso`  : serial data from ADC → SoC
- `adc_drdy_n`: data-ready (active-low) from ADC → SoC (preferred interrupt-style pacing)
- `adc_rst_n` : reset (active-low) from SoC → ADC (optional but recommended)

Optional / board-dependent:
- `adc_clk` or crystal input depending on board (defer to PCB);
- `adc_pwdn_n` if we want explicit powerdown control.

## SPI mode + framing (TO VERIFY)
Open items that must be verified against the datasheet before tapeout:
- SPI mode (CPOL/CPHA)
- Exact word length and alignment
- Whether the device always emits a STATUS word before channel data
- CRC enable/disable behavior and polynomial

### Working assumption for RTL baseline
Implement a **generic framed-SPI capture** block that can handle:
- a fixed number of 16/24/32-bit words per frame, parameterized;
- optional leading STATUS word;
- optional trailing CRC word;
- framing driven by `adc_drdy_n` (capture one frame per DRDY edge while `cs_n` asserted).

This keeps RTL useful even if a later datasheet check changes exact framing.

## Data model (what we want in firmware)
### Sample payload
Define a "sample" as:
- `status` (raw ADC status word) — if available
- `ch[0..7]` signed sample values

(Adding a timestamp is optional for v1; firmware can annotate samples with a SoC timer or a sample index.)

### Bit width
- Store raw samples at their native width (expected 24-bit) and **sign-extend to 32-bit** for the Wishbone register interface.

## Streaming FIFO contract (normative for v1)
When streaming is enabled, the hardware pushes one ADC "frame" into a FIFO which firmware drains via Wishbone.

### FIFO word packing
Per captured frame, push **9 words** in this exact order:
1) `STATUS_WORD` (32-bit; raw ADC STATUS if present, else 0)
2) `CH0`
3) `CH1`
4) `CH2`
5) `CH3`
6) `CH4`
7) `CH5`
8) `CH6`
9) `CH7`

Each channel word is:
- right-justified native sample bits (expected 24)
- sign-extended to 32-bit

### Register interface
See `spec/regmap.md` / `spec/regmap_v1.yaml` for the firmware-visible interface:
- `ADC_FIFO_STATUS.LEVEL_WORDS`
- `ADC_FIFO_STATUS.OVERRUN` (sticky, W1C)
- `ADC_FIFO_DATA` (RO pop)

## Throughput targets (sanity)
We should support at least:
- 8 channels, ≥ 1 kS/s effective per channel (v1), with headroom.

RTL should be able to sustain burst transfers into a small FIFO so Wishbone reads are decoupled from DRDY timing.

## Verification hooks
- A synthesizable "ADC model" for DV is *not* required for baseline.
- Cocotb can drive the SPI bus and DRDY to emulate frames.

Minimum tests:
1) DRDY-triggered capture of N frames into FIFO
2) FIFO overrun sticky flag
3) Software drain via Wishbone, verifying ordering
4) Reset/disable behavior

## TODOs (must close before tapeout)
- [ ] Verify SPI mode, word ordering, presence of STATUS and CRC with datasheet
- [ ] Decide whether CRC is included in v1 (DV + silicon debug tradeoff)
- [ ] Confirm clocking plan for ADC on the OpenMPW harness/PCB
