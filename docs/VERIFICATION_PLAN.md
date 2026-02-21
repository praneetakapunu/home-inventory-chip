# Verification Plan (v1)

This is the **minimum** verification surface needed to de-risk the first MPW submission.

## Scope (v1)
- Wishbone register block (`rtl/home_inventory_wb.v`)
- Top-level integration sanity (`rtl/home_inventory_top.v`)
- No real ADC model yet (that comes after we pick the part + bus).

## Principles
- Start with **spec-level smoke tests** that can run fast in CI.
- Prefer deterministic checks: reset defaults, bus protocol, address decode.
- Keep tests small and additive; one failure should point to one bug.

## Test matrix

### 0) CDC + reset review (written)
**Goal:** ensure we explicitly enumerate async inputs/crossings and reset behavior.

Deliverable:
- `docs/CDC_RESET_CHECKLIST.md` is filled to match the current RTL.

### 1) Wishbone register block — protocol + decode
**Goal:** prove basic Wishbone correctness and that the regmap matches `spec/regmap.md`.

Checks:
1. **Reset behavior**
   - On reset deassertion, all readable registers return documented reset values.
   - Any write-only/side-effect regs read back as specified (or are unmapped).
2. **Read path**
   - Single-cycle read returns stable `dat_o` with proper `ack` behavior.
3. **Write path**
   - Writes update only documented fields.
   - Writes to RO fields have no effect.
4. **Addressing**
   - Word addressing: verify that `adr` increments by 1 per 32-bit word.
   - Out-of-range addresses return a safe value (0) and still ACK (or match chosen behavior).
5. **Byte enables (`sel`)**
   - If supported: verify partial writes update only selected bytes.
   - If not supported: document behavior and assert `sel == 4'hF` in sim.
6. **Side effects**
   - `CTRL.START` is **write-1-to-pulse (W1P)**: writing 1 produces a 1-cycle pulse; writing 0 does nothing.
   - Confirm pulse does not persist across cycles.

### 2) Register map conformance
**Goal:** keep the RTL and spec from drifting.

Approach:
- Maintain a single source of truth in `spec/regmap.md`.
- The cocotb test enumerates expected addresses/reset values from a small python dict.

### 3) Top-level integration sanity
**Goal:** ensure the top can elaborate and basic signals are wired.

Checks:
- Instantiate `home_inventory_top` with a clock/reset and stub pads.
- Drive a minimal Wishbone bus sequence through the top into the reg block.

## Deliverables (what to implement next)
1. **chip-inventory**: keep this plan current + align regmap/spec.
2. **home-inventory-chip-openmpw**: add cocotb tests:
   - `test_wb_reset_defaults.py`
   - `test_wb_rw_and_decode.py`
   - `test_wb_ctrl_start_w1p.py`

## Definition of Done (v1 smoke)
- Tests above pass on a clean checkout in CI.
- Any future regmap change requires updating the test dict + spec in the same PR.
