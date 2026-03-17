# CDC / Reset Checklist (v1)

This is a lightweight, explicit checklist to avoid tapeout-killers.
Fill this out as the RTL/harness wiring settles.

> Scope: `chip-inventory/rtl/**` as integrated into the OpenMPW harness repo.

## 1) Clock domains (enumerate)

- [x] **wb_clk_i** (Wishbone / bus clock)
  - Source in harness: **Caravel WB MI A clock** passed straight through the OpenMPW wrapper.
    - Evidence: harness `user_project_wrapper.v` instantiates `home_inventory_user_project` and wires `.wb_clk_i(wb_clk_i)` (repo: `../home-inventory-chip-openmpw/verilog/rtl/user_project_wrapper.v`).
  - Frequency: **harness/Caravel-defined** (treat as a parameter of the platform; measure/confirm in harness docs).
  - Evidence:
    - All state in `rtl/home_inventory_wb.v` is clocked by `wb_clk_i`.

- [x] **user_clock2** (Caravel independent clock input)
  - v1 status: **not used** by the home-inventory user project.
  - Evidence: harness exposes `user_clock2` at the wrapper top, but `home_inventory_user_project` does not have a `user_clock2` port (repo: `../home-inventory-chip-openmpw/verilog/rtl/user_project_wrapper.v`).

- [x] **adc_sclk** (ADC SPI clock)
  - v1 implementation: **derived from `wb_clk_i`** inside `rtl/adc/adc_spi_frame_capture.v` via divider (`SCLK_DIV`).
  - Net is exported to top-level only under `USE_REAL_ADC_INGEST`.
  - Frequency: `wb_clk_i / (2*SCLK_DIV)` (per `adc_spi_frame_capture` toggling policy; confirm if changed).

- [ ] **core_clk** (CPU / fabric clock, if present)
  - v1 IP RTL does **not** currently instantiate a CPU/fabric clock domain.

Notes:
- v1 assumes a **single functional clock domain** (`wb_clk_i`) for regbank, timestamping, event detector, and (when enabled) ADC capture sequencing.
- If the harness later supplies an *independent* ADC pacing signal (e.g. DRDY), we must revisit this checklist and add explicit CDC handling.

## 2) Resets (enumerate)

- [x] **wb_rst_i** polarity: [x] active-high  [ ] active-low
- [x] Reset deassertion strategy:
  - [x] synchronous to wb clock (implemented as `if (wb_rst_i)` inside `always @(posedge wb_clk_i)`)
  - [ ] asynchronous assert, synchronous deassert

For each clock domain above, document:
- [x] what reset signal applies
  - `wb_clk_i` domain: `wb_rst_i`
  - `adc_sclk`: derived from `wb_clk_i`, so reset is effectively `wb_rst_i` via the parent logic.
- [x] whether reset deassertion is synchronized
  - Yes: reset is sampled on `wb_clk_i`.

Evidence (harness wiring):
- Run: `tools/harness_wb_wiring_audit.sh ../home-inventory-chip-openmpw`
- Snapshot (harness commit `f6d7178`):
  - `../home-inventory-chip-openmpw/verilog/rtl/user_project_wrapper.v:91` → `.wb_clk_i(wb_clk_i)`
  - `../home-inventory-chip-openmpw/verilog/rtl/user_project_wrapper.v:92` → `.wb_rst_i(wb_rst_i)`

Open item:
- [ ] Confirm the **timing** of `wb_rst_i` deassertion from the harness/Caravel side (async vs sync). The IP RTL *treats* `wb_rst_i` as a synchronous reset (sampled on `wb_clk_i`). If Caravel deasserts it asynchronously, we should add a small synchronizer or document the assumption explicitly.

## 3) Async inputs (enumerate + mitigation)

List every signal that can be asynchronous to a receiving clock domain.

### Current v1 wiring (as implemented in IP RTL)

- [x] **No asynchronous pacing inputs are consumed by the v1 IP RTL today.**
  - `adc_miso` is sampled relative to `adc_sclk` that we generate (in the real-ingest build); it is treated as synchronous to that SPI interface.
  - No `adc_drdy_n` pin is currently consumed by the IP RTL; capture is started by a Wishbone W1P (`CTRL.START`).
    - Note: the harness wrapper *does* reserve an `adc_drdy_n` wire when `HOMEINV_ENABLE_ADC_GPIO` is enabled, but it is currently unused by the IP.

### Candidate list (update as harness/PCB wiring is finalized)

- [ ] **adc_drdy_n** (from ADC, active-low DRDY)
  - Receiving domain: `wb_clk_i`
  - Mitigation (planned):
    - [ ] 2FF synchronizer + armed edge detector
    - [ ] use `rtl/adc/adc_drdy_sync.v` (already exists) and add a directed sim in `verify/` that matches real harness polarity
  - Note: if we decide DRDY is required for correct capture timing, it must be added to the top-level/harness wiring and captured explicitly in `docs/ADC_CLOCKING_PLAN.md`.

- [ ] **gpio inputs** (if used)
  - Receiving domain: TBD
  - Mitigation: [ ] 2FF per bit  [ ] other (document)

- [ ] **external interrupts** (if any)
  - Receiving domain: TBD

## 4) Cross-domain transfers (explicitly identify)

For each transfer, state the mechanism (FIFO, handshake, Gray counter, etc.).

- [x] ADC capture → Wishbone-visible FIFO
  - Mechanism: [x] same clock (no CDC)  [ ] async FIFO  [ ] handshake
  - Notes:
    - Stub path: SNAPSHOT logic pushes into `adc_stream_fifo` in the `wb_clk_i` domain.
    - Real ingest path (`USE_REAL_ADC_INGEST`): capture + internal FIFO run on `clk=wb_clk_i`.
    - If we later add an external DRDY clocking/pacing requirement, this item must be revisited.

## 5) Reset-safe state + X-prop assumptions

- [x] All state elements have reset values (or are otherwise safe)
  - Evidence: `rtl/home_inventory_wb.v` and `rtl/home_inventory_event_detector.v` use explicit synchronous resets for all architectural state.
  - FIFO and ADC helper blocks also implement reset (`rtl/adc/adc_stream_fifo.v`, `rtl/adc/adc_frame_to_fifo.v`, `rtl/adc/adc_spi_frame_capture.v`).
- [x] No latches inferred
  - Evidence: `bash ops/rtl_compile_check.sh` (via `bash ops/preflight_low_disk.sh`) passes elaboration for both stub + `USE_REAL_ADC_INGEST` builds.
- [x] No reliance on X-initialization for functional correctness
  - Evidence: directed sims under `make -C verify all` pass from reset (Wishbone, FIFO, SPI capture, event detector, etc.).

## 6) Byte enable policy (Wishbone)

- [x] Supported byte enables: [ ] full 32-bit only  [x] per-byte writes  [ ] other
  - Evidence: `rtl/home_inventory_wb.v` uses `apply_wstrb()` and explicitly masks W1C/W1P semantics by byte lane.
- [x] Behavior is documented in:
  - [x] `docs/KNOWN_LIMITATIONS.md` (firmware guidance to prefer full 32-bit writes)
  - [x] `spec/regmap.md` (normative byte-select semantics)

## 7) Evidence (what we actually checked)

- [x] Manual review complete
  - Who: Madhuri (assistant)
  - When: 2026-03-13
  - Scope: reset/clocking assumptions and async input list for current RTL + harness wiring notes.

- [x] Regression / compile evidence (low-disk suite)
  - Command: `bash ops/preflight_low_disk.sh`
  - Result summary: PASS (RTL elaborates in both stub + `USE_REAL_ADC_INGEST`; regmap gates pass; `make -C verify all` passes).

- [x] "Lint" evidence (tool-light, low-disk)
  - Tool: Icarus Verilog warnings (`iverilog -Wall`)
  - Command: `bash ops/rtl_compile_check.sh` (invoked by `bash ops/preflight_low_disk.sh`)
  - Result summary: PASS (no compile/elaboration errors; warnings reviewed as part of this suite)

- [ ] Dedicated CDC tool run (optional; not available on this host yet)
  - Tool: (e.g. Verilator lint/CDC, commercial CDC)
  - Command: (TBD)
  - Result summary: (TBD)

## 8) Open items

- [ ] Confirm harness/Caravel reset deassertion timing for `wb_rst_i` (async vs sync). If async, add a small reset synchronizer (or document the assumption explicitly in the harness repo).
- [ ] Decide whether `adc_drdy_n` is required for correct ADS131M08 capture timing.
  - If required: wire pin in harness + add `adc_drdy_sync` into ingest path and update this checklist + sims to match polarity.
- [ ] If any true multi-clock behavior is introduced (e.g., external ADC clock domain), revise this checklist and implement proper CDC (async FIFO or handshake).
