# Verification Plan (v1)

Goal: keep verification lightweight but real, so we can iterate fast and still have confidence before OpenMPW submission.

This plan is intentionally scoped to **bring-up confidence** first:
- Wishbone register interface correctness
- Reset behavior
- Byte-enable correctness
- No-bus-hang behavior (ACK discipline)

## Scope (this phase)

### DUT(s)
- `rtl/home_inventory_wb.v` (Wishbone register block)
- `rtl/home_inventory_top.v` (top wrapper, once it wires core signals)

### Non-goals (this phase)
- Full ADC stimulus / event-detection modeling
- Firmware-driven system tests
- Gate-level / SDF simulations

## Smoke test list (must-have)

### 1) Reset defaults
- Apply reset
- Read `ID` and `VERSION`
- Read `CTRL`, `IRQ_EN`, `STATUS`
- Expect:
  - `CTRL.ENABLE` = 0
  - `IRQ_EN` = 0
  - `STATUS[7:0]` reflects `core_status` input (tie 0 for now)

### 2) RO registers are stable
- Write random data to `ID` / `VERSION`
- Re-read
- Expect values unchanged

### 3) CTRL.ENABLE sticky RW
- Write `CTRL.ENABLE=1`
- Re-read `CTRL`
- Expect `ENABLE=1`
- Write `CTRL.ENABLE=0`
- Re-read `CTRL`
- Expect `ENABLE=0`

### 4) CTRL.START is write-1-to-pulse
- Hold `ENABLE` constant
- Write `CTRL.START=1` (bit[1])
- Expect `ctrl_start` asserted for exactly 1 `wb_clk` cycle
- Re-read `CTRL` and expect `START` reads back as 0

### 5) Byte enables on IRQ_EN
- For each `wbs_sel_i` combination (at least 0x1, 0x2, 0x4, 0x8, 0xF):
  - Write to `IRQ_EN`
  - Read back
  - Expect only selected bytes changed

### 6) ACK discipline (no stalls)
- For back-to-back valid Wishbone cycles:
  - Ensure `wbs_ack_o` pulses exactly once per request
  - Ensure no double-acks for a single request

## Nice-to-have (next)
- Add a tiny *digital filter + event detector* reference model and unit-test it at the spec level (even before the real RTL exists).
  - Inputs: signed fixed-point sample stream (scaled in grams in the model)
  - Outputs: filtered weight + event pulses
  - Properties to check:
    - hysteresis prevents chatter around threshold
    - minimum-duration qualification works
    - no event when |delta| < threshold
  - Align thresholds/latency expectations with `spec/v1.md` ("~5 g effective resolution" definition).

- Randomized Wishbone sequences (reads/writes/byte-enables) with a simple reference model
- Assertions:
  - `wbs_ack_o` is never high for two consecutive cycles when `wb_valid` stays high
  - `ctrl_start` pulses only on a write of `CTRL` with bit[1]=1

## Implementation notes

Primary implementation should live in the **harness repo** (OpenMPW user project) using the existing cocotb infrastructure:
- repo: `home-inventory-chip-openmpw`
- tests: `verilog/dv/cocotb/`

The source-of-truth repo (this repo) should keep the *spec-level* test list + any tiny reference models that are reusable.
