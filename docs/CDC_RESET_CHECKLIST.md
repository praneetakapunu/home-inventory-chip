# CDC / Reset Checklist (v1)

This is a lightweight, explicit checklist to avoid tapeout-killers.
Fill this out as the RTL/harness wiring settles.

> Scope: `chip-inventory/rtl/**` as integrated into the OpenMPW harness repo.

## 1) Clock domains (enumerate)

- [x] **wb_clk_i** (Wishbone / bus clock)
  - Source in harness: **TBD** (record exact net/clock generator in harness repo)
  - Frequency: **TBD**
  - Evidence:
    - All state in `rtl/home_inventory_wb.v` is clocked by `wb_clk_i`.

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

Open item:
- [ ] Confirm the harness-provided reset polarity for the user project wrapper and ensure it matches `wb_rst_i` expectations.

## 3) Async inputs (enumerate + mitigation)

List every signal that can be asynchronous to a receiving clock domain.

### Current v1 wiring (as implemented in IP RTL)

- [x] **No asynchronous pacing inputs are consumed by the v1 IP RTL today.**
  - `adc_miso` is sampled relative to `adc_sclk` that we generate; it is treated as synchronous to that interface.
  - No `adc_drdy` pin is currently in the top-level port list; capture is started by a Wishbone W1P (`CTRL.START`).

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

- [ ] All state elements have reset values (or are otherwise safe)
- [ ] No latches inferred
- [ ] No reliance on X-initialization for functional correctness

## 6) Byte enable policy (Wishbone)

- [x] Supported byte enables: [ ] full 32-bit only  [x] per-byte writes  [ ] other
  - Evidence: `rtl/home_inventory_wb.v` uses `apply_wstrb()` and explicitly masks W1C/W1P semantics by byte lane.
- [x] Behavior is documented in:
  - [x] `docs/KNOWN_LIMITATIONS.md` (firmware guidance to prefer full 32-bit writes)
  - [x] `spec/regmap.md` (normative byte-select semantics)

## 7) Evidence (what we actually checked)

- [ ] Manual review complete (record who/when)
- [ ] Lint/CDC tool run (if any):
  - Tool:
  - Command:
  - Result summary:

## 8) Open items

- [ ] (fill)
