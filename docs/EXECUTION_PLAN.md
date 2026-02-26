# Execution Plan (v1)

This file is the actionable plan to finish ASAP. Keep it short and current.

## Current phase
**OpenMPW tapeout path lock → harness/repo integration → RTL baseline**

## Next 2 hours (progress-tick target)
Pick *one* of these and land it as a small, reviewable commit:
1) **Event detector integration wiring plan**
   - Specify exact signal sources (sample stream(s) + timestamp source) at `rtl/home_inventory_top.v`
   - Specify which registers expose:
     - enable/mode bits
     - per-event counters + clear behavior
     - history FIFO depth/format + pop semantics
   - Add a “done when” checklist item so we can close it.
2) **ADC streaming end-to-end wiring plan**
   - Specify the signal contract between `adc_spi_frame_capture` → `adc_stream_fifo` → regbank pop
   - Define a minimal acceptance smoke (DV + FW) for “we can capture one frame and drain it”.

## Next 48 hours (Madhuri)
1) Submission mechanics: keep harness repo integrated and green on **low-disk** checks
   - IP repo: `bash ops/preflight_low_disk.sh` (one-shot low-disk suite)
     - (equivalent to: `bash ops/rtl_compile_check.sh` + `make -C verify all`)
   - Harness repo: `make sync-ip-filelist` + `make rtl-compile-check`
   - Notes/checklist: `docs/HARNESS_INTEGRATION.md`
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
   - RTL: `rtl/home_inventory_event_detector.v` + `verify/event_detector_tb.v` ✅
   - Integration wiring plan (next):
     - **Timestamp source**: define `ts_now` origin (likely a free-running counter in wb clock domain)
     - **Sample sources**: enumerate candidates + selection mux
       - raw ADC channel sample(s)
       - filtered/decimated channel(s) (future)
       - optional “synthetic” sources for DV (e.g., ramp)
     - **Top-level placement**: instantiate event detector in `rtl/home_inventory_top.v` with explicit CDC notes
     - **Regbank exposure**:
       - control: enable + mode + threshold(s)
       - status: sticky flags + overflow indicators
       - W1P clear: counters + history clear (already implemented in RTL)
     - **“Done when”**:
       - DV: one directed sim proves event triggers increment + history capture + clears work
       - Harness: RTL compile-check passes after wiring

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
