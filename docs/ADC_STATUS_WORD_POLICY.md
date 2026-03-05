# ADC STATUS word policy (v1)

This document defines what the **STATUS word** (word0) in our firmware-visible ADC FIFO stream *means* in v1, and—equally important—what it **does not** mean.

Context:
- On the ADS131M08, the first DOUT word in a “NULL command” data frame is the **response to the previous frame’s command**.
- In steady-state streaming where we issue only NULL commands, this response word behaves like the device **STATUS** information.
- In our SoC FIFO packing, this response/STATUS word is **word0** of every 9-word “SoC frame”.

See also:
- `spec/ads131m08_interface.md` (chip-level framing assumptions)
- `docs/ADC_STREAM_CONTRACT.md` (FIFO packing rules)
- `spec/firmware_api.md` (recommended firmware drain patterns)

## v1 contract (normative)

For every captured conversion frame, hardware pushes 9 words into the FIFO:
1) `STATUS_WORD` (32-bit)
2) `CH0` .. 9) `CH7` (signed 32-bit)

The **STATUS_WORD** is defined as:
- the raw DOUT “response” word captured from the ADC as word0 of the on-wire frame
- **zero-extended** to 32-bit (do not sign-extend)

### Firmware expectations
Firmware must treat `STATUS_WORD` as **opaque payload** in v1:
- It is safe to log/telemetry this word for debugging.
- It is *not* safe to gate correctness (“discard sample”, “trust sample”) on any particular bitfield unless we explicitly lock a decode later.

Rationale:
- Early bring-up frequently runs with simplified/partial ADC configuration.
- The response word semantics can differ depending on the prior frame’s command history.
- Keeping this word opaque avoids false assumptions and keeps v1 tapeout risk low.

## What we do *not* guarantee in v1

- No guaranteed decode of per-channel DRDY flags, CRC flags, or error bits in firmware.
- No guaranteed relationship between `STATUS_WORD` and the corresponding channel data if the ADC is misconfigured or if frames are dropped (e.g., due to FIFO overrun).

If firmware needs robust “data-valid” semantics in v1, prefer using **our own** on-chip indicators:
- FIFO `OVERRUN` sticky bit (`ADC_FIFO_STATUS.OVERRUN`) for drop detection
- event detector counters/timestamps for activity detection (where applicable)

## Recommended future extension (post-v1)

If we later want firmware-friendly status semantics, add **separate, SoC-owned** status fields (without reinterpreting the raw STATUS word):
- `ADC_STREAM_ERR` (sticky flags like frame_dropped, CRC_fail, unexpected_word_length)
- `ADC_STREAM_STATS` (frame counters, drop counters)

This keeps the raw `STATUS_WORD` available for low-level debug while giving firmware a stable contract.
