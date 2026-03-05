# Timestamp Source (v1)

This document defines the **v1 timestamp** that the Home Inventory IP uses for event history, counters, and any future sample tagging.

## Goals

- Simple and synthesizable.
- Deterministic in simulation.
- No cross-domain ambiguity for v1.
- Good enough for *relative* ordering / time deltas in bring-up.

## Non-goals (v1)

- Absolute wall-clock time.
- A calibrated timebase in seconds.
- Cross-clock-domain globally consistent time.

## Definition

- **Signal name (conceptual):** `ts_now`
- **Domain:** `wb_clk_i`
- **Reset:** synchronous to `wb_clk_i` using `wb_rst_i`
- **Behavior:** free-running up-counter incrementing by 1 every `wb_clk_i` cycle

Pseudo:

```verilog
if (wb_rst_i) ts_now <= 0;
else          ts_now <= ts_now + 1;
```

### Width

- Default: **32 bits** (wraps naturally)
- Justification:
  - Minimizes area.
  - Matches Wishbone register width.
  - Wrap handling is straightforward for relative deltas.

If/when needed, we can widen to 48/64 bits and/or make width a parameter.

## Consumers

### Event detector

- Event history entries store `ts_now` at the moment the detector records an event.
- Consumers must treat timestamps as **modulo-2^N** values.

**Delta computation** (modular subtraction):

```c
uint32_t dt = (uint32_t)(t_new - t_old);
```

This is valid as long as the time between `t_old` and `t_new` is less than 2^31 cycles.

## CDC notes

- v1 assumes the event detector and its register-visible history are in the **Wishbone clock domain**.
- If a future ADC ingestion path runs in another clock domain, it must either:
  1) cross samples/events into `wb_clk_i` before timestamping, or
  2) introduce a separate timebase in that domain and explicitly define correlation.

Do **not** mix timestamps from different domains without an explicit contract.

## Verification guidance

- DV should reset the DUT, then expect `ts_now` to start at 0 and monotonically increment.
- When testing event history:
  - capture `ts_now` around the trigger point
  - allow a small +/-1 cycle tolerance depending on when the event is latched

## Firmware guidance

- Firmware should treat timestamps as relative.
- For humans/logging, firmware may convert cycles to microseconds using the configured/known `wb_clk_i` frequency.

## Open questions (future)

- Do we want an explicit register exposing the current timestamp?
- Do we need a prescaler or tick mode (e.g., 1 tick per N cycles) for long captures?
