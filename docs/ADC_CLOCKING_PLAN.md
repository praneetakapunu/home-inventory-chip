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

### Option C — ADC internal oscillator (if supported by the part)
- Some ADCs allow internal clocking; if ADS131M08 supports it, it reduces board dependency.
- Pros:
  - Simplifies board.
- Cons:
  - Must be explicitly validated from the datasheet.
  - Could reduce performance / increase drift.

## Bring-up verification checklist (scope-first)
At first hardware bring-up, before trusting any samples:
1) Verify `CLKIN` is toggling at the expected frequency.
2) Verify `DRDY` toggles (or asserts) at the expected conversion rate.
3) Verify SPI `SCLK/CS` timing does not violate the “CS transitions while SCLK low” rule.

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
