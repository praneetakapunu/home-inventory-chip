# Execution Plan (v1)

This file is the actionable plan to finish ASAP. Keep it short and current.

## Current phase
**OpenMPW tapeout path lock → harness/repo integration → RTL baseline**

## Next 48 hours (Madhuri)
1) Submission mechanics: get harness repo to a state where `make setup` + precheck can run with our stub
2) Land RTL baseline in source-of-truth (done, keep iterating):
   - `rtl/home_inventory_top.v` skeleton
   - `rtl/home_inventory_wb.v` Wishbone reg block
   - `spec/regmap.md` v1 register map
3) Add a minimal verification + bring-up surface:
   - `docs/VERIFICATION_PLAN.md` (spec-level smoke list) ✅
   - `docs/BRINGUP_SEQUENCE.md` (FW-facing bring-up checklist + acceptance) ✅
   - `make -C verify regmap-check` (YAML ↔ RTL address-map consistency) ✅
   - Harness repo: cocotb tests for the Wishbone reg block (next)
4) Define tapeout gates so we stop guessing "done":
   - `docs/TAPEOUT_CHECKLIST.md` (v1 submission readiness checklist) ✅
5) Tighten v1 acceptance criteria (so we can pick ADC + filtering intentionally):
   - Decided: v1 effective target is **20 g** (`spec/acceptance_metrics.md` + `decisions/007-effective-resolution-definition.md`)
6) Choose a specific external 8ch load-cell ADC part and lock SPI vs I2C ✅
   - Locked: **TI ADS131M08** (`decisions/008-adc-part-selection.md`)
   - Shortlist + rubric: `spec/adc_selection.md`
7) Define ADC interface contract for RTL/FW (new, draft):
   - `spec/ads131m08_interface.md` (signals, framing assumptions, FIFO + regmap hooks)
   - `docs/ADC_FW_INIT_SEQUENCE.md` (firmware bring-up sequence + FIFO drain/validate)
8) Break ADC RTL into implementable modules:
   - `docs/ADC_RTL_ARCH.md` (module split + FIFO contract recap) ✅
   - `rtl/adc/adc_spi_frame_capture.v` (generic framed SPI capture; param CPOL/CPHA + packing) ✅
   - `rtl/adc/adc_drdy_sync.v` (2FF sync + falling-edge pulse) ✅
   - `rtl/adc/adc_stream_fifo.v` (32-bit FIFO + level + sticky overrun) ✅

9) Event detector (minimal v1): define intended semantics & wire into regbank
   - Spec: `docs/EVENT_DETECTOR_SPEC.md` ✅
   - Next: implement comparator + saturating counters + timestamp/delta in RTL

## Blockers (must be explicit)
- None.

## Notes / setup
- DV toolchain notes: `docs/SIM_TOOLCHAIN.md`

## Pending from Praneet
- None.

## Risks (watchlist)
- Even 20 g effective resolution may be dominated by mechanical + drift; acceptance criteria must stay realistic.
- **ADC clocking on the harness/PCB must be explicitly confirmed**; see `docs/ADC_CLOCKING_PLAN.md`.
- ADC part selection is a dependency for interface details + firmware formats.
