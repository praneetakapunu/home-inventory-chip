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
- **MSB-first**
- **CS transitions must occur while SCLK is low**
- **Hold CS low for the entire frame** (all words)

(From datasheet timing diagram.)

### Word length
The ADS131M08 SPI **word size** is programmable via `MODE.WLENGTH[1:0]`:
- `00b` = 16-bit
- `01b` = 24-bit (default)
- `10b` = 32-bit (zero-pad 24-bit ADC data)
- `11b` = 32-bit (**sign-extend** 24-bit ADC data)  ← **v1 choice**

Important nuance:
- Commands/responses/register words are **16 bits of real data**, MSB-aligned and padded with zeros to 24/32-bit word sizes.
- Conversion data are nominally **24-bit two’s complement**.

**v1 baseline (pragmatic, matches current RTL):** keep the ADS131M08 in its **default 24-bit word length** and perform **sign-extension in RTL** for channel words.

Rationale:
- Our current v1 SPI capture RTL drives MOSI low (NULL commands only), so it does **not** program `MODE.WLENGTH`.
- Keeping the on-wire word length at 24 avoids a dependency on early firmware-side ADC register programming.

Note: we may still choose to program `MODE.WLENGTH` to a 32-bit sign-extended mode later, but it is not required for the v1 streaming contract.

## SPI framing (datasheet-verified)
SPI communication is performed in **frames** consisting of several words.

### Full-duplex pipeline behavior
- The **first input word** on DIN is always a **command**.
- The **first output word** on DOUT is always the **response to the command from the *previous* frame**.

Practical consequence:
- To continuously read data, firmware typically issues a **NULL command** each frame; the response word then contains the **STATUS register**.

### Typical “data collection” frame structure
For “most commands”, the datasheet describes a **10-word** frame.

**Normative v1 framing assumption:** one conversion readout = **one 10-word SPI frame** with CS held low throughout.
- For 24-bit word length, this is **240 SCLK cycles per frame**.
- For 32-bit word length, this is **320 SCLK cycles per frame**.

We treat “word boundaries” as purely clock-count based (no byte lanes on the wire). The RTL must count bits and re-pack into 24/32-bit words.

If firmware ever changes the ADC word length (to 32-bit), RTL must either:
- be configured to match, or
- reject/flag unexpected word-length (preferred for debug).

For now, v1 capture assumes **24-bit words on the wire** (see earlier section).
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

### NULL command encoding (v1 operational assumption)
During continuous streaming, firmware (or the SoC wrapper) issues the NULL command each frame.

Normative v1 assumption:
- The on-wire `COMMAND` word is the **16-bit NULL command**, padded to the current word length.
  - 24-bit word length: `0x0000_00` on DIN (MSB-first)
  - 32-bit word length: `0x0000_0000` on DIN (MSB-first)

The RTL does not need to interpret DIN for v1 streaming; this is listed so the end-to-end contract is explicit.

### Frame → FIFO mapping (normative v1)
The ADC always outputs 10 words per data frame on DOUT:

1) `RESPONSE` (for previous frame’s command; for NULL this is the STATUS register)
2) `CH0`
3) `CH1`
4) `CH2`
5) `CH3`
6) `CH4`
7) `CH5`
8) `CH6`
9) `CH7`
10) `OUTPUT_CRC`

v1 streaming drops the final CRC word and pushes the first 9 words into the Wishbone FIFO in the same order.

## DRDY behavior (datasheet-verified + v1 guidance)
- DRDY indicates “new data” and is tied to conversion timing.
- `MODE.DRDY_FMT` controls whether DRDY is a level-style signal or a short negative pulse.

**Strong v1 recommendation:** keep `DRDY_FMT = 0` (level-style), because when `DRDY_FMT = 1` (pulse), **missed reads can cause skipped conversion results and suppressed DRDY pulses**.

Also (important):
- “The DRDY pulse is blocked when new conversions complete while conversion data are read.”
  - So: avoid reading exactly at the moment new conversions complete if you need consistent DRDY behavior.

### First data / after pause precaution (datasheet note; critical for predictable DRDY)
The ADS131M08 has an internal mechanism that behaves like a small FIFO (two samples per channel). If data were **not read for a while** or a sample was missed, the FIFO slots can be full and the per-channel DRDY flags in `STATUS` can remain asserted until **both samples are read**.

v1 guidance:
- After reset / first data collection / any pause, do **one** of:
  1) Strobe **SYNC/RESET** (or otherwise re-sync conversions) to clear the internal sample buffer, **or**
  2) Immediately read **two complete data packets/frames** before you trust steady-state DRDY/STATUS behavior.

This matters even if our RTL drops output CRC: the “two packets after pause” rule is about the ADC’s internal buffering and DRDY/STATUS semantics.

## What we expose to firmware (chip-inventory contract)
### “Frame” definition for our SoC
We define one captured ADC frame as:
- `status` (the response word when issuing NULL commands; effectively STATUS)
- `ch[0..7]` signed samples

We **do not** currently expose the output CRC to firmware in v1. (We may optionally verify CRC in RTL later, but it is not required to get first silicon bring-up.)

### Sample bit width
- Treat conversion data as **24-bit two’s complement** on the wire.
- Present them to firmware as **signed 32-bit** by **sign-extending in RTL** (word1..word8).
- The STATUS word is **zero-extended** (do not sign-extend).

Normative sign-extension formula (for each channel word captured as a 24-bit value `x[23:0]`):
- `sample32[23:0]  = x[23:0]`
- `sample32[31:24] = {8{x[23]}}`

Status word handling:
- The STATUS register is logically 16 bits of data; on the wire it is MSB-aligned and padded.
- v1 presents it as a 32-bit unsigned word with only the meaningful STATUS bits set (upper padding bits = 0).

### Word/byte ordering (firmware-visible)
Because the Wishbone FIFO is a **32-bit word stream**, firmware sees already-packed 32-bit integers.

Normative v1 rules:
- `ADC_FIFO_DATA` returns a **native 32-bit word** per read.
- For channel samples, bit [31:24] replicates bit [23] of the ADC sample (sign extension).
- No byte swapping is performed in hardware; software should treat each popped word as host-endian 32-bit.

(If we later add a DMA/USB packet format, that packet format must define endianness explicitly; this spec only defines the on-chip reg/FIFO contract.)

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

### Debug/robustness recommendations (non-normative but strongly suggested)
These are cheap checks that help during bring-up:
- **Word-length sanity:** when capture is configured for 24-bit words, assert that the frame completes after exactly 240 SCLK edges while CS is low (and analogously 320 for 32-bit).
- **Unexpected mode detection:** if the observed CS-low bitcount does not match the configured word length × 10 words, increment a sticky error counter and re-arm on next DRDY.

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

## Policy decisions (v1)
- SPI word length + CRC policy is locked for v1 in:
  - `decisions/009-ads131m08-word-length-and-crc.md`

## TODOs (must close before tapeout)
- [x] Lock the v1 **sample width policy**: ADC outputs 24-bit two’s complement; RTL sign-extends to 32-bit for firmware.
- [ ] Confirm clocking plan for ADC on the OpenMPW harness/PCB (`CLKIN` source).
  - Working notes live in: `docs/ADC_CLOCKING_PLAN.md`
  - Decision to accept (with evidence): `decisions/011-adc-clkin-source-and-frequency.md`

## Harness-dependent confirmations (must lock before tapeout)
These are not “nice to have” — they impact RTL pin polarity assumptions and whether we can hit the intended sample rate.

1) **DRDY polarity / naming**
   - Confirm whether the harness net is exposed as `adc_drdy` (active-low) or `adc_drdy_n`.
   - Our RTL should treat **assert = low**, but we must confirm that the pad naming and top-level wiring are consistent.

2) **CLKIN source and frequency**
   - Confirm if the harness provides a **continuous, free-running** `CLKIN` to the ADC (and at what frequency).
   - **Do not** plan around an “internal oscillator” fallback for ADS131M08 v1.
     If `CLKIN` is not routed/provided, treat it as a **hard tapeout blocker** and track it via:
     - `decisions/011-adc-clkin-source-and-frequency.md`
     - `docs/ADC_CLOCKING_PLAN.md`
   - Use the harness audit helper and update the harness docs once confirmed:
     - `tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw`

3) **SCLK budget vs. sample rate**
   For continuous capture (one 10-word frame per conversion), the minimum SCLK frequency must satisfy:

   - `f_sclk >= (10 * word_bits) * f_s`

   Where:
   - `word_bits` is 24 (v1 default) or 32 (if we switch later)
   - `f_s` is the per-channel sample rate (conversions/sec)

   Examples:
   - 24-bit words at 1 kSPS: `f_sclk >= 10*24*1k = 240 kHz`
   - 24-bit words at 32 kSPS: `f_sclk >= 10*24*32k = 7.68 MHz`
   - 32-bit words at 32 kSPS: `f_sclk >= 10*32*32k = 10.24 MHz`

   Practical guidance:
   - Add margin (protocol overhead, FW scheduling, clock tolerance); do not run the link at the exact minimum.
   - If the harness limits SCLK (routing/IO constraints), we must reduce `f_s` or change framing assumptions.

4) **CS framing guarantee**
   - Confirm the SoC wrapper can hold `CS` low for the full 10-word frame and that no other SPI target shares the bus with conflicting timing.

Once these are confirmed, update:
- `docs/ADC_CLOCKING_PLAN.md`
- `docs/HARNESS_INTEGRATION.md`
- (if needed) `docs/EXECUTION_PLAN.md` “Blockers” / “Risks”

## STATUS word: v1 “must-watch” bits (bring-up contract)
During continuous streaming with NULL commands, the first word we capture per frame is the **STATUS register** (padded/aligned per word length).

For v1 bring-up, we treat the STATUS word as a **health + alignment sentinel**. Firmware should log it during early testing; RTL may optionally expose lightweight counters.

### What to look for (semantics)
Firmware should at minimum be able to answer:
1) **Are we aligned to frame boundaries?**
   - STATUS values should be “reasonable” and change slowly relative to channel samples.
   - If STATUS appears to be pseudo-random, you are likely **bit-shifted** (wrong CPHA/CPOL) or **word-length mismatched**.
2) **Are we keeping up with conversions?**
   - If the ADC’s internal sample buffer behavior is triggered (missed reads), you may observe STATUS behavior consistent with backlog (see “two frames after pause” guidance earlier).
3) **Is DRDY behaving as expected?**
   - If DRDY is configured as pulse (`DRDY_FMT=1`), it can be suppressed when reads overlap conversions; this can masquerade as “missing data” even when SPI is active.

### Practical v1 debug checklist (logic analyzer friendly)
When probing the bus (scope/LA):
- Confirm **SCLK idles low** and data is sampled on the **falling edge** (CPOL=0, CPHA=1).
- Confirm **CS_n stays low** for exactly **10 words** per conversion frame.
- Confirm the total SCLK pulses per frame are exactly:
  - 240 pulses (24-bit words) or
  - 320 pulses (32-bit words)
- Confirm DOUT word boundaries: first word should look like a STATUS-like value (often with repeated upper bits = 0 due to padding), followed by 8 channel-like words.

## Optional RTL hooks (non-blocking, but strongly recommended)
These are small, low-risk RTL observability features that make bring-up faster without changing the external pin contract.

### Suggested counters/flags
1) **Frame counter**: increments once per captured 10-word frame.
2) **Bad-frame counter**: increments if the captured frame violates v1 expectations (e.g., wrong bitcount, wrong wordcount, or capture not started on DRDY edge).
3) **Status history**: keep last STATUS word (already implied by FIFO push) and optionally a sticky flag if STATUS == 0 for “too long” (often indicates wiring/pull issues).
4) **Overrun**: already present as FIFO overrun sticky; ensure it is W1C and test that it clears.

### Minimal firmware-facing expectation
Even if we do not implement extra RTL counters in v1, firmware should:
- read and log STATUS for first N frames,
- verify FIFO level behaves sensibly,
- verify overrun never asserts during steady-state drain.
