# CDC + Reset Checklist (v1)

This is a **lightweight** checklist to keep us honest about clock-domain crossings (CDC) and reset behavior for the first MPW submission.

> Goal: we don’t need formal CDC tooling for v1, but we *do* need to explicitly enumerate crossings, pick a policy, and make sure reset can’t wedge the design.

## 0) Clock / reset assumptions (write down)
- [ ] Which clock(s) are used in v1? (expected: Caravel `wb_clk_i` / `clk`)
- [ ] Reset polarity and type (sync/async) for each domain (expected: `wb_rst_i` is **active-high**, treated as **sync** inside the WB domain)
- [ ] Are any derived clocks used? (v1 should avoid them)

## 1) Enumerate all domains and crossings
Fill in the table as we add logic.

- **WB domain**: Wishbone bus + register block
- **ADC sample domain**: any external DRDY-derived logic (if not using a separate clock, still treat DRDY as an async input)

Crossings to track (v1 expected set):
- [ ] `adc_drdy` (async pin) → WB clocked logic (must be synchronized)
- [ ] SPI `sclk` / `mosi` / `miso` interactions (define: is `sclk` generated internally or external?)
- [ ] Any interrupt/status signals (sticky flags) crossing into WB readout

## 2) CDC implementation policy (v1)
- **Async single-bit status / event** (e.g., DRDY):
  - [ ] Use 2-FF synchronizer into WB clock domain
  - [ ] For edge/event pulses: synchronize level, then detect edge in WB domain
  - [ ] Minimum pulse width requirement documented if needed

- **Multi-bit data buses**:
  - [ ] Avoid raw multi-bit CDC in v1
  - [ ] If unavoidable: use an async FIFO or a full handshake (req/ack) with stability guarantees

## 3) Reset behavior checklist
- [ ] On reset assertion, all state is driven to known values
- [ ] Reset deassertion cannot create spurious pulses (e.g., START, FIFO pop)
- [ ] Sticky flags clear policy is explicit (reset clears all sticky flags)
- [ ] FIFO pointers/level reset to empty; no X-prop into WB read mux

## 4) “Known good” building blocks in this repo
- [ ] `rtl/adc/adc_drdy_sync.v` is the *only* path from raw DRDY to internal event pulse
- [ ] Any future async inputs must have a named `*_sync` module (avoid ad-hoc 2FF copies)

## 5) Verification hooks (minimum)
- [ ] Directed sim verifies DRDY sync produces **one** pulse per falling edge
- [ ] Directed sim toggles reset around DRDY edges and proves no double-count / wedge
- [ ] FIFO overrun sticky is stable and clears on reset

## 6) Signoff notes (fill when done)
- Date:
- Reviewer:
- Summary of crossings & how they’re handled:
