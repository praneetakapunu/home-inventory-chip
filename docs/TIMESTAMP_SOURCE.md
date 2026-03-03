# Timestamp source (ts_now) — v1 plan

We need a single, unambiguous timebase for:
- event-detector history entries
- any “data age” / ordering sanity checks in bring-up
- potential future decimation/filters

This doc defines the *v1* timestamp source used inside the IP repo RTL.

## Goal
Provide a monotonically increasing `ts_now` value in the **Wishbone clock domain**.

- **Clock domain:** wb/SoC clock (`clk` in `home_inventory_wb` / top-level)
- **Reset behavior:** synchronous reset preferred; on reset, counter becomes 0
- **Width:** 32-bit for v1 (`ts_now[31:0]`)
- **Tick rate:** 1 tick per wb clock
- **Wrap:** natural wrap-around is acceptable; consumers must treat timestamps mod 2^32

Rationale:
- It avoids CDC complexity during early bring-up.
- It is “free” (no calibration needed) and adequate for ordering/relative timing.
- Absolute time is *not* required for v1 acceptance.

## Proposed RTL module
A minimal module (name suggestion): `home_inventory_ts_counter`.

Interface:
- inputs: `clk`, `rst`
- output: `ts_now[31:0]`

Behavior:
- `ts_now <= ts_now + 1` every cycle when not in reset.

## Integration points
1) Instantiate the counter in the same clock domain as the event detector.
2) Feed `ts_now` into `home_inventory_event_detector`.

If the event detector ever moves to a different domain:
- keep `ts_now` local to that domain, OR
- cross with a standard CDC scheme *and* document it.

## Future extensions (not v1 blockers)
- Add prescaler (programmable tick rate)
- Add capture/compare for scheduled sampling
- Add a 64-bit counter if long run-times without wrap are required

## Verification notes
- A directed test should confirm:
  - `ts_now` resets to 0
  - `ts_now` increments monotonically
  - event history entries store the `ts_now` observed at trigger time
