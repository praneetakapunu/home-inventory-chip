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

1) **Run ADS131M08 in a 32-bit word mode** that yields **sign-extended** conversion samples on DOUT.
   - Rationale: keeps the digital path **32-bit clean** end-to-end (FIFO + Wishbone + firmware).
   - Requirement: confirm the exact `MODE.WLENGTH` encoding in firmware init (datasheet wins).

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
- Firmware should expect 32-bit sign-extended samples.
- We defer CRC verification until after first “known-good samples” milestone.

## Follow-ups (must close)
- [ ] In `spec/ads131m08_interface.md`, fill in the exact `MODE.WLENGTH[1:0]` value used for the chosen 32-bit sign-extended mode (cite datasheet section/table).
- [ ] In FW bring-up notes (`docs/ADC_FW_INIT_SEQUENCE.md`), document the ADS131M08 register writes that implement this policy.
