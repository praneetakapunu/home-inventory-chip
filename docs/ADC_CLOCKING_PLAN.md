# ADC Clocking Plan (ADS131M08) — v1

This document captures the **practical clocking plan** for the ADS131M08 on the OpenMPW tapeout path.

It exists because the ADC digital interface (SPI + DRDY) is easy to simulate, but **real silicon bring-up** will fail or look “random” if the ADC clock source is undefined.

Related:
- Chip-level interface assumptions: `spec/ads131m08_interface.md`
- FW bring-up sequence: `docs/ADC_FW_INIT_SEQUENCE.md`

## What we need (requirements)
1) A **known, stable ADC clock source** that is present on the board/harness.
2) A way to verify at bring-up time that the clock is present (scope point, test pad, or observable behavior).
3) A documented assumption for sample rate / DRDY rate so firmware can set expectations.

**Non-negotiable datasheet implication (v1):** ADS131M08 requires a *continuous, free‑running external master clock* on `CLKIN` for normal operation. The ΔΣ modulators will not run (and `DRDY` behavior will not make sense) if `CLKIN` is not toggling.

References:
- TI ADS131M08 datasheet: https://www.ti.com/lit/ds/symlink/ads131m08.pdf
- TI E2E clarification thread (clocking): https://e2e.ti.com/support/data-converters-group/data-converters/f/data-converters-forum/905809/ads131m08-datasheet-clarification-for-clocking-the-adc

## Candidate clock sources

### Option A — Dedicated oscillator into `CLKIN` (preferred)
- Put an oscillator (or crystal + driver) on the board feeding `ADC_CLKIN`.
- Pros:
  - Decouples ADC performance from SoC clocks and harness quirks.
  - Easiest to reason about.
- Cons:
  - Requires board support; may not be available on the OpenMPW harness as-is.

### Option B — Drive `CLKIN` from a Caravel clock output (possible)
- Provide a clock out from the SoC/harness into the ADC `CLKIN`.
- Pros:
  - No extra BOM if the harness routes it.
- Cons:
  - Must ensure clock quality, frequency, and that it is present early enough.
  - Adds coupling between SoC clock domains and ADC behavior.

### Option C — ADC internal oscillator
- **Do not assume this exists.** For ADS131M08, treat `CLKIN` as required (external free‑running clock).
- Pros:
  - (N/A for ADS131M08 v1 plan)
- Cons:
  - If we plan around an internal oscillator that isn’t actually available, bring-up will fail (no conversions / unexpected `DRDY`).

## Bring-up verification checklist (scope-first)
At first hardware bring-up, before trusting any samples:
1) Verify `CLKIN` is toggling at the expected frequency (free-running, continuous).
2) Verify `DRDY` transitions after power-on reset completes **only once `CLKIN` is present**.
3) Verify `DRDY` toggles at the expected conversion rate once conversions are started/configured.
4) Verify SPI `SCLK/CS` timing does not violate the “CS transitions while SCLK low” rule.

If (1) fails, **do not** debug RTL first.

## Current v1 status
- **Clock source:** TBD.
- **Action required:** confirm what the OpenMPW harness/board actually provides:
  - Is `CLKIN` routed?
  - Is there an oscillator footprint/populated?
  - Is there a stable SoC clock that can be routed out?

## Decision record (to fill)
When decided, add a short entry here and link the decision in `decisions/`.

- Decision: (TBD)
- Source: (schematic / harness docs / datasheet)
- Expected `CLKIN` frequency: (TBD)
- Expected DRDY rate: (TBD)
