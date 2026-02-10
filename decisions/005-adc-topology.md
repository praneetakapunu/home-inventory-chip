# Decision: ADC / sensor front-end topology (v1)

- **Date:** 2026-02-10
- **Owner:** Madhuri
- **Status:** Decided

## Decision
Use a **single off-chip multi-channel load-cell ADC** (8 channels) for v1, accessed over a simple digital interface (SPI/I2C depending on part selection).

## Rationale
- Minimizes BOM + PCB complexity vs 8 separate ADCs.
- Keeps the chip digital-only (as intended) while still enabling 8 channels.
- Offloads analog/noise headaches to a purpose-built external ADC.

## Notes / follow-ups
- Exact part TBD; select one with documented multi-channel performance at the 5 g target.
- Firmware will implement per-channel calibration + filtering.
