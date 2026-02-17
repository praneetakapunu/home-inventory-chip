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
- `timestamp` (from SoC timer) — optional for v1; if omitted, use sample index
- `status` (raw ADC status word) — if available
- `ch[0..7]` signed sample values

### Bit width
- Store raw samples at their native width (likely 24-bit) and sign-extend to 32-bit in firmware.

## Throughput targets (sanity)
We should support at least:
- 8 channels, ≥ 1 kS/s effective per channel (v1), with headroom.

RTL should be able to sustain burst transfers into a small FIFO so Wishbone reads are decoupled from DRDY timing.

## Register/firmware contract (placeholder)
Create/extend regmap to expose:
- FIFO level + overrun flag
- FIFO pop (returns one word / one sample)
- status: last STATUS word + sticky error bits
- control: enable/disable capture, soft reset, CRC enable (if we use it)

> NOTE: We already have `spec/regmap.md`; this doc is meant to inform the next regmap increment.

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
- [ ] Decide exact FIFO word packing (status + channels)
- [ ] Decide if we include CRC in v1 (DV + silicon debug tradeoff)
- [ ] Confirm clocking plan for ADC on the OpenMPW harness/PCB
