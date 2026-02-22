# CDC + Reset Checklist (v1)

This is a **lightweight** checklist to keep us honest about clock-domain crossings (CDC) and reset behavior for the first MPW submission.

> Goal: we don’t need formal CDC tooling for v1, but we *do* need to explicitly enumerate crossings, pick a policy, and make sure reset can’t wedge the design.

## 0) Clock / reset assumptions (write down)
- [x] Which clock(s) are used in v1?
  - **Single domain:** Caravel Wishbone clock (`wb_clk_i` in harness; `clk` inside IP RTL).
- [x] Reset polarity and type (sync/async) for each domain
  - `wb_rst_i` is **active-high**. Inside the IP we treat `rst` as **synchronous** to `clk` (all state resets in `always @(posedge clk)` blocks).
- [x] Are any derived clocks used?
  - None planned for v1 (avoid derived/gated clocks).

## 1) Enumerate all domains and crossings

Domains present (v1 intent):
- **WB domain (`clk`)**: Wishbone bus + register block + FIFO readout
- **Async inputs (not a clock domain):** external ADC `DRDY` (active-low) treated as asynchronous input into WB domain.

Crossings to track:
- [x] `adc_drdy_n_async` (async pin) → WB clocked logic
  - Implemented via `rtl/adc/adc_drdy_sync.v` (2FF sync + falling-edge detect pulse).
- [ ] SPI `sclk` / `mosi` / `miso` interactions
  - **Open item:** need to explicitly decide whether `sclk` is generated internally (in WB domain) or provided externally by the ADC (and if so, what capture strategy is used).
- [x] WB-visible status/sticky flags
  - Implemented in WB domain and read out synchronously; no multi-bit CDC planned for v1.

## 2) CDC implementation policy (v1)
- **Async single-bit status / event** (e.g., DRDY):
  - [x] Use 2-FF synchronizer into WB clock domain
  - [x] For edge/event pulses: synchronize level, then detect edge in WB domain
  - [ ] Minimum pulse width requirement documented if needed
    - DRDY is expected to be long compared to `clk` period; if we ever see missed DRDY pulses, document the minimum width requirement here.

- **Multi-bit data buses**:
  - [x] Avoid raw multi-bit CDC in v1
  - [x] If unavoidable: use an async FIFO or a full handshake (req/ack) with stability guarantees

## 3) Reset behavior checklist
- [x] On reset assertion, all state is driven to known values
  - Example: `adc_drdy_sync` resets synchronizer regs to `1'b1` (idle-high for active-low DRDY).
- [x] Reset deassertion cannot create spurious pulses (e.g., START, FIFO pop)
  - Ensure pulse-style controls read as 0 and only assert for one cycle on WB write.
- [x] Sticky flags clear policy is explicit (reset clears all sticky flags)
- [x] FIFO pointers/level reset to empty; no X-prop into WB read mux

## 4) “Known good” building blocks in this repo
- [x] `rtl/adc/adc_drdy_sync.v` is the *only* path from raw DRDY to internal event pulse
- [x] Any future async inputs must have a named `*_sync` module (avoid ad-hoc 2FF copies)

## 5) Verification hooks (minimum)
- [ ] Directed sim verifies DRDY sync produces **one** pulse per falling edge
- [ ] Directed sim toggles reset around DRDY edges and proves no double-count / wedge
- [ ] FIFO overrun sticky is stable and clears on reset

## 6) Signoff notes
- Date: 2026-02-22
- Reviewer: Madhuri (self-check)
- Summary of crossings & how they’re handled:
  - v1 is designed to be a **single synchronous WB clock domain**. The only explicit CDC item is ADC `DRDY` (async, active-low), synchronized with a 2FF chain and edge-detected in WB domain (`adc_drdy_sync`).
  - SPI clocking strategy is still open and must be pinned down before hardening.
