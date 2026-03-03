# Decision 009 — ADS131M08 SPI word length + CRC policy (v1)

## Status
**Accepted (v1 baseline)**

## Context
We selected the TI ADS131M08 as the external 8-channel load-cell ADC (see `decisions/008-adc-part-selection.md`).

For v1, we need to lock a *practical* SPI framing policy so that:
- RTL can implement a deterministic frame capture path,
- firmware can bring up the system without ambiguity,
- we avoid unnecessary complexity before first silicon.

Key choices:
- SPI **word length** (16/24/32) via `MODE.WLENGTH`
- whether to use **input CRC** (optional) via `MODE.RX_CRC_EN`
- what to do with **output CRC** (always present at end of frame)

## Decision
For v1 bring-up and tapeout:

1) **Do not require programming ADS131M08 into a 32-bit word mode** for v1 baseline.
   - Rationale: our current v1 SPI capture RTL drives MOSI low (NULL commands only), so we cannot depend on early ADC register writes.
   - Baseline: capture **24-bit** conversion words and **sign-extend in RTL** for the FIFO/firmware interface (32-bit clean at the SoC boundary).
   - Note: we can still add ADC register programming later (either via RTL enhancements or a dedicated FW-controlled SPI mode), but it is not a tapeout gate for the streaming path.

2) **Disable input CRC** (`MODE.RX_CRC_EN = 0`).
   - Rationale: reduces host-side computation and simplifies early RTL/FW; we can enable later if needed.

3) **Ignore output CRC in v1 RTL streaming.**
   - The ADS131M08 always appends an output CRC word at end-of-frame.
   - v1 behavior: capture it on the wire (as part of the 10-word frame) but **drop it**; do not expose to firmware.

4) **Keep DRDY in level-style mode** (`MODE.DRDY_FMT = 0`) for predictable timing.
   - Rationale: pulse mode can suppress DRDY pulses when reads overlap conversions (easy to trip during early bring-up).

## Consequences
- RTL captures **10 output words** per frame and pushes **9 FIFO words**:
  `STATUS_WORD` + `CH0..CH7` (CRC dropped).
- Firmware should expect **32-bit signed** channel samples.
  - If the ADC is in default 24-bit mode, RTL sign-extends before the FIFO.
- We defer CRC verification until after first “known-good samples” milestone.

## Follow-ups (must close)
- [x] In `spec/ads131m08_interface.md`, lock the v1 policy: 24-bit conversion words captured; RTL sign-extends to 32-bit for firmware.
- [x] In FW bring-up notes (`docs/ADC_FW_INIT_SEQUENCE.md`), document that v1 bring-up does not require ADS131M08 register programming.
