# Timestamp source (v1)

This document defines the on-chip timestamp used by the **event detector** and exposed to firmware via the **TIME_NOW** register.

## Why this exists
The event detector stores `last_ts` / `last_ts_chx` values when an event triggers. Firmware and DV need a stable, well-defined timebase so those timestamps are meaningful and consistent across implementations.

## v1 definition
### Clock domain
- **Domain:** `wb_clk_i` (Wishbone / register clock domain)
- **Reset:** `wb_rst_i`

### Implementation
- A **free-running 32-bit counter** `r_time_now` increments by **+1 every `wb_clk_i` cycle**.
- On `wb_rst_i` assertion, `r_time_now` resets to **0**.
- The counter **wraps naturally** on overflow (mod 2^32).

### Register visibility
- `TIME_NOW` is a **read-only** register reflecting `r_time_now`.
- `TIME_NOW` is intended for:
  - correlating event detector timestamps with firmware actions
  - basic relative timing measurements during bring-up

## Event detector usage
- The event detector receives `ts_now = r_time_now` each cycle.
- When an event triggers:
  - `last_ts` captures `ts_now`
  - `last_ts_chx` captures the per-channel `ts_now`

## Notes / future
- v1 chooses the Wishbone clock domain intentionally:
  - it is always present in DV and the harness
  - it avoids early CDC complexity
- If later we need timestamps aligned to ADC sample rate, we can add a separate sample-time counter and explicitly define CDC/serialization into the Wishbone domain.
