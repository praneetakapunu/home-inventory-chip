# Execution Plan (v1)

This file is the actionable plan to finish ASAP. Keep it short and current.

## Current phase
**OpenMPW tapeout path lock → harness/repo integration → RTL baseline**

Runway note:
- `python3 ops/shuttle_runway.py` currently reports **~0.4 weeks** to the internal safe deadline in `docs/SHUTTLE_LOCK_RECORD.md`.
- Treat this as **scope-freeze time**: only land changes that reduce risk or are directly required for tapeout.

## Next 2 hours (progress-tick target)
Pick *one* of these and land it as a small, reviewable commit:
1) **Shuttle selection rubric + lock fields** ✅ (see `docs/SHUTTLE_SELECTION.md`)
   - Document the exact fields we must lock (shuttle name, cutoff date/time/tz, source link)
   - Add a simple rubric so we can pick an aggressive-but-realistic shuttle.
2) **ADC streaming end-to-end wiring (RTL)**
   - Wire real `adc_streaming_ingest` path into `home_inventory_wb` behind a build flag.
   - Keep SNAPSHOT stub path for bring-up until the real ADC pins are available in the harness.
3) **ADC clocking confirmation (docs + harness grep helper)** ✅
   - Made the `CLKIN` unknown actionable by documenting an explicit confirmation procedure.
   - Added/confirmed a low-disk grep helper script:
     - `tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw`

## Next 48 hours (Madhuri)
1) Submission mechanics: keep harness repo integrated and green on **low-disk** checks
   - If targeting ChipFoundry/chipIgnite, keep the open questions tracked in: `docs/CHIPFOUNDRY_SUBMISSION_NOTES.md`
   - IP repo: `bash ops/preflight_low_disk.sh` (one-shot low-disk suite)
     - (equivalent to: `bash ops/rtl_compile_check.sh` + `make -C verify all`)
   - Cross-repo (preferred): `bash ops/preflight_all_low_disk.sh` (IP preflight + harness compile-check)
   - Harness repo (manual): `make sync-ip-filelist` + `make rtl-compile-check`
   - Quick harness audit helpers (grep-based, no toolchain):
     - `tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw`
     - `tools/harness_adc_clocking_placeholder_check.sh ../home-inventory-chip-openmpw` (fail-fast)
     - `tools/harness_adc_pinout_audit.sh ../home-inventory-chip-openmpw`
     - `tools/harness_adc_pinout_placeholder_check.sh ../home-inventory-chip-openmpw` (fail-fast)
     - `tools/harness_adc_streaming_audit.sh ../home-inventory-chip-openmpw`
     - `tools/harness_adc_streaming_placeholder_check.sh ../home-inventory-chip-openmpw` (fail-fast)
     - `tools/harness_event_detector_audit.sh ../home-inventory-chip-openmpw`
     - `tools/harness_wb_wiring_audit.sh ../home-inventory-chip-openmpw`
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
     - **Timestamp source**: define `ts_now` origin (v1: free-running counter in wb clock domain; see `docs/TIMESTAMP_SOURCE.md`) ✅
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
- **ADC pin mapping (io[*] indices) is still placeholder in the harness wrapper.**
  - `home-inventory-chip-openmpw/verilog/rtl/home_inventory_user_project.v` currently defaults:
    - `ADC_SCLK_IO=0, ADC_CSN_IO=1, ADC_MOSI_IO=2, ADC_MISO_IO=3, ADC_DRDYN_IO=4, ADC_RSTN_IO=5`
  - This is *not* a real pinout and must be replaced/overridden before tapeout.
  - Canonical mapping location: `docs/ADC_PINOUT_CONTRACT.md`
  - Audit/check helpers:
    - `tools/harness_adc_pinout_audit.sh ../home-inventory-chip-openmpw`
    - `tools/harness_adc_pinout_placeholder_check.sh ../home-inventory-chip-openmpw`

- **ADS131M08 CLKIN source/frequency is not yet locked in the harness repo.**
  - Harness has only draft notes with `io[??]` and no frequency evidence.
  - Until we lock either (A) board oscillator → CLKIN, or (B) SoC clock-out → adc_clkin, plus frequency, real ADC bring-up is at risk.
  - Track decision + evidence: `decisions/011-adc-clkin-source-and-frequency.md`.

## Notes / setup
- DV toolchain notes: `docs/SIM_TOOLCHAIN.md`

## Pending from Praneet
- None.

## Risks (watchlist)
- Even 20 g effective resolution may be dominated by mechanical + drift; acceptance criteria must stay realistic.
- **ADC clocking on the harness/PCB must be explicitly confirmed**; see `docs/ADC_CLOCKING_PLAN.md`.
- ADC part selection is a dependency for interface details + firmware formats.
