# ADS131M08 Interface Notes (v1)

> Source of truth: TI ADS131M08 datasheet (SBAS950B – Feb 2021). This doc captures the **chip-level** assumptions we want for v1.
> If anything here conflicts with the datasheet, the datasheet wins.

## Goal
Define the minimum interface contract between:
- the **ADC** (ADS131M08),
- our **RTL** (SPI capture + buffering), and
- our **firmware** (registers + packet format),

so we can implement + verify a baseline without re-litigating fundamentals.

## Top-level signals (board ↔ SoC)
- `adc_sclk`  : serial clock from SoC → ADC
- `adc_cs_n`  : chip select (active-low) from SoC → ADC
- `adc_mosi`  : serial data from SoC → ADC (DIN)
- `adc_miso`  : serial data from ADC → SoC (DOUT)
- `adc_drdy` / `adc_drdy_n`: data-ready from ADC → SoC (polarity depends on pad naming; functionally **DRDY asserts low**)
- `adc_rst_n` : reset (active-low) from SoC → ADC (recommended)

Optional / board-dependent:
- `adc_clkin` : external clock into ADC (preferred for best performance; see datasheet note about modulator clock sync)
- `adc_sync_reset` (if we decide to drive SYNC/RESET as a function rather than hard reset)

## SPI electrical/clocking (datasheet-verified)
### SPI mode
- **CPOL = 0, CPHA = 1**
- **CS transitions must occur while SCLK is low**

(From datasheet timing diagram.)

### Word length
The ADS131M08 SPI **word size** is programmable:
- 16 / 24 / 32 bits via `MODE.WLENGTH[1:0]`

Important nuance:
- Commands/responses/register words are **16 bits of real data**, MSB-aligned and padded with zeros to 24/32-bit word sizes.
- Conversion data are nominally **24-bit two’s complement**.
- In 32-bit mode, conversion words can be either **zero-padded** or **MSB sign-extended** depending on WLENGTH setting.

**v1 baseline preference:** use a 32-bit word mode that yields **sign-extended** samples, so the digital path stays 32-bit-clean.

## SPI framing (datasheet-verified)
SPI communication is performed in **frames** consisting of several words.

### Full-duplex pipeline behavior
- The **first input word** on DIN is always a **command**.
- The **first output word** on DOUT is always the **response to the command from the *previous* frame**.

Practical consequence:
- To continuously read data, firmware typically issues a **NULL command** each frame; the response word then contains the **STATUS register**.

### Typical “data collection” frame structure
For “most commands”, the datasheet describes a **10-word** frame:
- **DIN (host → ADC)**:
  1) `COMMAND`
  2) `INPUT_CRC` if enabled, else `0`
  3..10) eight words of `0`

- **DOUT (ADC → host)**:
  1) `RESPONSE` (for previous frame’s command; for NULL it is STATUS)
  2..9) `CH0..CH7` conversion data
  10) `OUTPUT_CRC` (**always present at end of output frame**) — host may ignore

CRC details:
- **Input CRC** is optional via `MODE.RX_CRC_EN`.
- **Output CRC cannot be disabled**; it always appears at end of output frame.

## DRDY behavior (datasheet-verified + v1 guidance)
- DRDY indicates “new data” and is tied to conversion timing.
- `MODE.DRDY_FMT` controls whether DRDY is a level-style signal or a short negative pulse.

**Strong v1 recommendation:** keep `DRDY_FMT = 0` (level-style), because when `DRDY_FMT = 1` (pulse), **missed reads can cause skipped conversion results and suppressed DRDY pulses**.

Also (important):
- “The DRDY pulse is blocked when new conversions complete while conversion data are read.”
  - So: avoid reading exactly at the moment new conversions complete if you need consistent DRDY behavior.

## What we expose to firmware (chip-inventory contract)
### “Frame” definition for our SoC
We define one captured ADC frame as:
- `status` (the response word when issuing NULL commands; effectively STATUS)
- `ch[0..7]` signed samples

We **do not** currently expose the output CRC to firmware in v1. (We may optionally verify CRC in RTL later, but it is not required to get first silicon bring-up.)

### Sample bit width
- Store raw samples at their native width (24-bit) but present them to firmware as **signed 32-bit**.

## Streaming FIFO contract (normative for v1)
When streaming is enabled, hardware pushes words into a FIFO which firmware drains via Wishbone.

### FIFO word packing (per captured conversion)
Per conversion event, push **9 words** in this exact order:
1) `STATUS_WORD` (32-bit; the DOUT response word when issuing NULL commands)
2) `CH0`
3) `CH1`
4) `CH2`
5) `CH3`
6) `CH4`
7) `CH5`
8) `CH6`
9) `CH7`

Each channel word is signed 32-bit with correct sign extension.

**CRC handling:** output CRC is present on the wire but dropped by v1 streaming.

### Register interface
See `spec/regmap.md` / `spec/regmap_v1.yaml` for the firmware-visible interface:
- `ADC_FIFO_STATUS.LEVEL_WORDS`
- `ADC_FIFO_STATUS.OVERRUN` (sticky, W1C)
- `ADC_FIFO_DATA` (RO pop)

## RTL implications (what to build)
The SPI capture RTL must support:
- CPOL=0/CPHA=1 sampling
- programmable word length (at least 24/32)
- fixed 10-word receive per frame on DOUT, with 1 response + 8 channel words + 1 CRC
- DRDY-paced framing (one data frame per conversion period)

Baseline implementation strategy:
- firmware drives repetitive NULL commands
- RTL uses DRDY falling edge as the “start capture next frame” event (with appropriate synchronization)
- capture 10 words, drop final CRC word, and push 9 words into FIFO

## Verification hooks
Cocotb can emulate the ADC as a “frame source”:
- drive DRDY
- drive DOUT words as response/ch data/CRC
- observe FIFO pushes + Wishbone drains

Minimum tests:
1) capture N frames → FIFO contains 9*N words in correct order
2) FIFO overrun sets sticky flag
3) Wishbone draining pops in order
4) reset/disable behavior

## TODOs (must close before tapeout)
- [ ] Decide whether we want to **verify** output CRC in RTL (debug vs complexity)
- [ ] Confirm exact `MODE.WLENGTH` setting that yields **sign-extended** 32-bit data (and reflect it in FW init sequence)
- [ ] Confirm clocking plan for ADC on the OpenMPW harness/PCB (`CLKIN` source)
