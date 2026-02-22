# Event Detector Spec (v1 draft)

This document defines the intended **v1** semantics for the event reporting registers under `0x0000_0400` (see `spec/regmap.md`).

Goal: provide a **very small** hardware feature that lets firmware detect "interesting" activity without streaming every sample.

## Inputs / scope

- Input samples are the **raw ADC samples** as exposed in `ADC_RAW_CHx` (sign-extended to 32-bit).
- Thresholds are configured in **raw ADC LSBs** via `EVT_THRESH_CHx`.
- Per-channel enable is controlled by `EVT_CFG.EVT_EN[ch]`.

Non-goals for v1:
- No hysteresis/debounce.
- No programmable edge direction.
- No timestamp in real time units; only sample ticks.

## Definitions

- `sample_tick`: increments by 1 for each **accepted** sample update per channel (i.e. at the effective sample cadence of the core).
- `event[ch]`: a single-cycle pulse indicating an event detection for channel `ch`.

## Proposed detection rule (v1)

For each channel `ch` when `EVT_EN[ch] = 1`:

- An event occurs when the sample is **greater than or equal to** the programmed threshold:

```
if (sample[ch] >= EVT_THRESH_CH[ch]) event[ch] = 1;
else                               event[ch] = 0;
```

Rationale: this is the simplest comparator. If we later need "crossing" semantics (edge detect), we can add an `EVT_MODE` register without moving existing addresses.

## Register semantics

### `EVT_COUNT_CHx` (RO)
- Increments by 1 on each `event[ch]`.
- Saturates at `0xFFFF_FFFF`.

### `EVT_LAST_DELTA_CHx` (RO)
- On each `event[ch]`, updates to the delta (in sample ticks) since the last event on that channel:

```
EVT_LAST_DELTA_CHx <= sample_tick[ch] - last_event_tick[ch]
```

- For the **first** event after reset (or after enabling `EVT_EN[ch]`), define `EVT_LAST_DELTA_CHx = 0`.

### `EVT_LAST_TS` (RO)
- On any channel event, updates to the **global** sample tick at which the event occurred.
- If multiple channels assert `event[ch]` in the same cycle, `EVT_LAST_TS` may reflect any one of them (implementation-defined).

### `EVT_CFG` (RW)
- `EVT_EN[7:0]` gates event detection per channel.
- Writing `0` disables detection.
- Reset value `0x0` (all disabled).

### `EVT_THRESH_CHx` (RW)
- Signed 32-bit threshold in raw ADC LSBs.
- Reset value `0x0`.

## Reset / enable behavior

When `EVT_EN[ch]` transitions 0→1:
- `last_event_tick[ch]` should be treated as uninitialized.
- The next detected event sets `EVT_LAST_DELTA_CHx` to 0.

## Implementation note

This spec is deliberately conservative so it can be implemented with:
- 8 signed compares
- 8 saturating counters
- 8 tick registers for `last_event_tick`

and minimal routing into the Wishbone register bank.
