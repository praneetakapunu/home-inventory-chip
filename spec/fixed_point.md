# Fixed-point conventions (v1)

This document defines **numeric formats** used by the v1 register map / firmware bring-up.

Goal: avoid “format TBD” ambiguity so that firmware + verification can be written **now**, even if the analog front-end evolves.

## General rules

- All fixed-point values are stored in **32-bit registers**.
- Unless stated otherwise:
  - Signed values are **2’s complement**.
  - Unsigned values are standard binary.
- The hardware shall treat reserved/unused bits as 0 on read.

## ADC raw sample representation

`ADC_RAW_CHx` registers expose the *latest* raw sample for each channel.

- Bits `[23:0]`: sample code (LSBs), right-justified.
- Bit `[23]` is the sign bit if the ADC is bipolar; if the ADC is unipolar, firmware should treat the value as unsigned.
- Bits `[31:24]`: sign-extension (bipolar) or 0 (unipolar).

This convention supports common 24-bit ADCs while keeping a stable software surface.

## Calibration model

Firmware-visible calibration is expressed as an **affine transform** applied per channel:

```
raw_code      = ADC_RAW_CHx
code_zeroed   = raw_code - TARE_CHx
code_scaled   = (code_zeroed * SCALE_CHx) >> 16
```

Where:

- `TARE_CHx` is a **signed 32-bit integer** in raw ADC LSBs.
  - Reset = 0.
- `SCALE_CHx` is an **unsigned Q16.16** multiplier.
  - Reset = `0x0001_0000` (1.0).

Notes:
- This allows firmware to implement calibration deterministically, even before a final physical unit conversion is frozen.
- If later we decide to do calibration in hardware, these registers remain valid as control inputs.

## Event timing representation

Event/counter blocks (when implemented) use the following conventions:

- `EVT_COUNT_CHx`: unsigned 32-bit **saturating** event count.
- `EVT_LAST_DELTA_CHx`: unsigned 32-bit **delta in sample ticks** (time between the last two events on that channel).
- `EVT_LAST_TS`: unsigned 32-bit **timestamp in sample ticks** for the most recent event across any channel.

Rationale: “sample ticks” avoids committing to a wall-clock frequency before the sampling architecture is finalized. Firmware can convert ticks to time once `sample_rate_hz` is known.
