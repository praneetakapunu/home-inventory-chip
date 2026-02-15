# Acceptance metrics (v1 draft)

This document defines what **“20 g effective resolution”** means for the v1 demo, so RTL/firmware/verification don’t drift.

> Status: **decided** (Praneet chose 20 g for v1)

## Definitions

- **Channel:** one pad/bin weight sensor input.
- **Sample rate (host-visible):** the rate at which firmware reports weight estimates to the host (or logs internally). Draft: **50 Hz**.
- **Effective resolution:** the smallest step change that can be *reliably detected* (not the ADC LSB), under a defined observation window and false-alarm constraint.

## Success criteria (v1)

### A) Step-change detectability
A step change of **±20 g** on any channel shall be detected within **≤ 2 s**.

- Detection is defined as: firmware asserts an event flag / increments an event counter and reports a signed delta.
- Observation conditions:
  - After tare has been performed.
  - No additional weight changes during the 500 ms window.

### B) False event rate
With no intentional weight change:
- **False event rate** shall be **≤ 1 event / channel / hour**.

(We can tighten later, but this is a realistic first constraint that forces sensible filtering + thresholds.)

### C) Drift after tare
After a tare operation and with no intentional weight change:
- Reported weight estimate shall remain within **±20 g** for **30 minutes**.

Notes:
- This explicitly acknowledges low-frequency drift (temperature, creep).
- v2 can target tighter drift or periodic auto-re-tare.

### D) Cross-channel coupling (crosstalk)
A step change of **+200 g** on one channel should not create a spurious **> 20 g** apparent change on any other channel (after filtering).

## Non-goals (v1)
- Absolute accuracy in grams across temperature and long time horizons.
- Metrology-grade linearity.
- Handling continuous motion/oscillation; v1 is for discrete add/remove events.

## What this implies for design

- ADC choice + sampling plan must support enough ENOB and bandwidth margin for 20 g steps.
- Filtering must be explicitly parameterized (window length / IIR constants) and testable.
- Verification needs directed tests for:
  - detect ±20 g steps
  - no-change false event rate (simulated noise)
  - drift envelope

## Open questions
- What is the expected maximum per-pad weight (range) and typical bin mass?
