# Event detector integration notes (v1)

This doc turns the event-detector “integration plan” into a concrete contract so we can wire it into the top-level without re-deciding basics.

## What exists today
- RTL: `rtl/home_inventory_event_detector.v` implements:
  - per-channel enable (`EVT_CFG.EVT_EN`)
  - per-channel threshold registers (`EVT_THRESH_CHx`)
  - per-channel event counters + last-delta + last-ts capture
  - W1P clears for counts/history (via `EVT_CFG.CLEAR_COUNTS` / `EVT_CFG.CLEAR_HISTORY`)
- Wishbone integration (current): `rtl/home_inventory_wb.v`
  - Drives the event detector from the **ADC SNAPSHOT stub** (write `ADC_CMD.SNAPSHOT=1`).
  - Uses `TIME_NOW` (`r_time_now`) as the timestamp source.
  - Provides SIM-only override wires (force-based) so DV can inject samples without changing the regmap.

This is *intentionally* useful even before real ADC wiring: firmware can validate enable/threshold/clear/readback semantics.

## Timestamp source (normative for v1)
**Timestamp** is `TIME_NOW`, a free-running 32-bit counter in the Wishbone clock domain:
- increments by 1 every `wb_clk_i`
- wraps naturally
- resets to 0 on `wb_rst_i`

This means **timestamp units are “wb_clk cycles”**.

Rationale:
- No extra clock domains are required.
- Firmware can convert to seconds once the harness clock frequency is known.
- Good enough for v1 “event happened” / “relative timing” use.

## Sample source(s)
### v1 bring-up (today)
Event detector sample updates occur on **ADC SNAPSHOT**:
- `sample_valid` is 1-cycle when firmware writes `ADC_CMD.SNAPSHOT=1`
- sample values are deterministic patterns derived from `ADC_SNAPSHOT_COUNT`

This provides a stable debug surface.

### v1 real mode (implemented behind `USE_REAL_ADC_INGEST`)
When `USE_REAL_ADC_INGEST` is enabled, `rtl/home_inventory_wb.v` drives the event detector from the **same captured frame tap** that mirrors into `ADC_RAW_CHx`:
- `sample_valid` = `adc_streaming_ingest.tap_valid` (= `frame_valid`), a 1-cycle pulse **after the full SPI frame has been captured**
- `sample_ch0..7` = `tap_words_packed[word1..word8]` (STATUS is word0)
- channel words are **sign-extended** from `BITS_PER_WORD` to 32-bit in `adc_streaming_ingest` (STATUS word is left as-is)

So for v1 we are locking the timing choice as:
- `sample_valid` asserts at *end* of capture (capture-done), not on the DRDY edge.

## Register exposure (current)
See `spec/regmap.md` / `spec/regmap_v1.yaml` for exact addresses.

Key regs:
- `EVT_CFG.EVT_EN[7:0]` (RW)
- `EVT_CFG.CLEAR_COUNTS` (W1P)
- `EVT_CFG.CLEAR_HISTORY` (W1P)
- `EVT_THRESH_CHx` (RW)
- `EVT_COUNT_CHx` (RO)
- `EVT_LAST_DELTA_CHx` (RO)
- `EVT_LAST_TS` + `EVT_LAST_TS_CHx` (RO)

## “Done when” (integration milestone)
We can call the event detector **integrated** when:
1) In DV, a directed test proves:
   - enabling a channel + setting a threshold causes `EVT_COUNT_CHx` to increment on crossings
   - `CLEAR_COUNTS` resets counters without disturbing config
   - `CLEAR_HISTORY` clears `EVT_LAST_*` state
2) Harness RTL compile-check passes with the real sample stream wired (no SIM force required).

## Follow-ups / TODOs
- [ ] When real ADC wiring lands, update this doc with the exact `sample_valid` timing choice (DRDY-edge vs capture-done).
- [ ] Add a cocotb/Wishbone-directed test that exercises `EVT_CFG` + threshold + clear semantics using the SIM override hooks.
