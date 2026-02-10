# Decision: Pad channel count

- **Date:** 2026-02-10
- **Owner:** Praneet
- **Status:** Decided

## Decision
Support **8 pad channels** in the v1 demo.

## Implications
- Data path + firmware should model 8 independent channels.
- Off-chip ADC / mux strategy must scale to 8 channels.
- Verification should include multi-channel sampling + per-channel calibration.
