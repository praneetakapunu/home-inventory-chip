# Known Limitations (v1)

This file is a living list of **intentional** v1 limitations.
Anything listed here must be acceptable for OpenMPW submission / first-silicon bring-up.

## ADC / streaming

- Output CRC from ADS131M08 is **not** exposed to firmware in v1 streaming.
  - Rationale: keep first-silicon path simple.
  - Mitigation: firmware can do basic sanity checks (range/consistency), and we can add CRC verification in a later revision.

- After long pauses / missed reads, ADS131M08 internal buffering can require reading **two** frames to return to steady state.
  - See: `spec/ads131m08_interface.md`.

## Regmap / control

- `CTRL.START` is a **write-1-to-pulse** bit; reads return 0.
- Unknown/unimplemented addresses read as 0.

## DV / signoff

- Full-system OpenLane or timing signoff is not part of this repo; tapeout readiness is gated by OpenMPW precheck + basic compile/smoke tests.

TODO (before tapeout):
- Add any bring-up discoveries here (e.g., ADC clocking quirks, DRDY edge cases, firmware workarounds).
