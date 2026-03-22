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

## Test methodology (what we’ll actually run)
These are the *real* tests we should be able to run on bring-up boards to claim v1 meets the metrics above.

### 1) Step-response test (±20 g detectability)
Setup:
- Tare the channel under test.
- Apply a known **+20 g** step (and separately **-20 g**) using calibration weights.
- Keep all other channels unloaded and stable.

Procedure:
- Record the timestamp of the physical step.
- Log the first time the firmware reports an “event” for that channel.

Pass criteria:
- Detection latency ≤ **2 s**.
- The reported signed delta is correct in sign.

Evidence to capture:
- A short log excerpt showing: tare, step time, event timestamp, delta.

### 2) False-event soak test (no intentional changes)
Setup:
- Tare all channels.
- Leave the system untouched on a stable surface.

Procedure:
- Run for **≥ 2 hours**.
- Count events per channel.

Pass criteria:
- ≤ **1 event / channel / hour**.

Evidence to capture:
- Event counters at start/end and the elapsed duration.

### 3) Post-tare drift test
Setup:
- Tare all channels.

Procedure:
- Log reported weight estimate (or filtered weight) at **1 Hz** for **30 minutes**.

Pass criteria:
- Stays within **±20 g** of zero (or the tare baseline) for the full window.

Evidence to capture:
- Min/max observed estimate per channel over the 30 min window.

### 4) Crosstalk sanity test
Setup:
- Tare all channels.

Procedure:
- Apply a **+200 g** step on one channel.
- Observe other channels’ reported deltas/estimates after the normal filtering window.

Pass criteria:
- No other channel shows an apparent change > **20 g** attributable to that step.

Evidence to capture:
- Before/after per-channel estimates for the window.

## What counts as an “event” (contract)
To prevent firmware/RTL drift, define the event interface explicitly:
- An event is recorded when the **event detector** asserts a per-channel hit (edge) and firmware increments a counter / sets a sticky flag.
- For v1 acceptance testing, the system must expose:
  - per-channel event count (monotonic, clearable)
  - a timestamp or sample-counter for the most recent event
  - the signed delta estimate used for the decision (even if coarse)

If any of these are not currently present in the regmap, add them *before* regmap freeze.

## Open questions (must be answered to de-risk the demo)
- What is the expected maximum per-pad weight (range) and typical bin mass?
- What is the expected ambient temperature range during the demo?
- How is the demo surface mounted (table vs wall vs shelving)? (affects vibration/noise)
- Do we need per-channel calibration coefficients in nonvolatile storage for v1, or is one global scale factor acceptable?
