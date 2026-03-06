# Verification Plan (v1)

This is the **minimum** verification surface needed to de-risk the first MPW submission.

## Scope (v1)
- Wishbone register block (`rtl/home_inventory_wb.v`)
- Event detector semantics (`rtl/home_inventory_event_detector.v`)
- ADC sub-block RTL units (SPI framed capture, DRDY sync, stream FIFO)
- Top-level integration sanity (`rtl/home_inventory_top.v`) (elaboration + wiring)

## Principles
- Start with **fast** smoke tests that run in CI.
- Prefer deterministic checks: reset defaults, bus protocol, address decode.
- Keep tests small and additive; one failure should point to one bug.

## How to run (authoritative commands)
From a clean checkout of **chip-inventory**:

- Full smoke suite:
  - `make -C verify all`
- Individual sims:
  - `make -C verify sim` (Wishbone regblock)
  - `make -C verify evt-sim` (event detector)
  - `make -C verify spi-sim` (SPI frame capture)
  - `make -C verify drdy-sim` (DRDY sync)
  - `make -C verify fifo-sim` (stream FIFO)
  - `make -C verify f2f-sim` (ADC frame → FIFO packing)
  - `make -C verify ingest-sim` (end-to-end ingest: DRDY + SPI capture + FIFO)
  - `make -C verify overrun-sim` (FIFO overrun sticky flag semantics)
  - `make -C verify unpack-sim` (SoC-side frame unpacking helper)
  - `make -C verify real-adc-sim` (compiles top with `USE_REAL_ADC_INGEST`)
  - `make -C verify wb-real-adc-smoke-sim` (Wishbone + real ADC ingest smoke)

## Single source of truth (regmap)
- **Source:** `spec/regmap_v1.yaml`
- **Derived (committed) artifacts:**
  - `fw/include/home_inventory_regmap.h`
  - `rtl/include/home_inventory_regmap_pkg.sv`
  - `rtl/include/regmap_params.vh`

Guards:
- `make -C verify regmap-check` checks RTL decode vs YAML.
- `make -C verify regmap-gen-check` asserts the committed derived artifacts match the YAML.

## Test matrix

### 0) CDC + reset review (written)
**Goal:** enumerate async inputs/crossings and reset behavior.

Deliverable:
- `docs/CDC_RESET_CHECKLIST.md` matches the current RTL.

### 1) Wishbone register block — protocol + decode
**Goal:** prove basic Wishbone correctness and that the regmap matches `spec/regmap_v1.yaml`.

Implemented by:
- `verify/wb_tb.v`

Checks:
1. Reset defaults for readable regs
2. Read path + ACK behavior
3. Write path: field masks + RO ignore
4. Address alignment behavior (`adr[1:0]` ignored for decode)
5. Byte enables (`sel`) honored for RW regs
6. Side effects: `CTRL.START` W1P pulse semantics

### 2) Event detector semantics
**Goal:** lock v1 behavior so FW can rely on it.

Implemented by:
- `verify/event_detector_tb.v`

Checks:
- Threshold compare rule (>=)
- Per-channel enable gating
- First-event delta semantics (0 after reset or enable 0→1)
- Global `EVT_LAST_TS` update-on-any-event
- Counter saturation
- Regression: glitchy enable pulse doesn’t clear history if no sample consumed while enabled

### 3) ADC unit blocks (pre-integration)
**Goal:** validate small RTL building blocks without needing the full ADC integration.

Implemented by:
- `verify/adc_spi_frame_capture_tb.v` (SPI mode + word capture)
- `verify/adc_drdy_sync_tb.v` (CDC + edge detect)
- `verify/adc_stream_fifo_tb.v` (FIFO core: push/pop/level)

### 3.1) ADC pipeline + integration-ish unit tests (still fast)
**Goal:** validate the *wiring* between blocks (frame → FIFO, FIFO overrun semantics) before harness integration.

Implemented by:
- `verify/adc_frame_to_fifo_tb.v` (frame packing order + CRC drop policy)
- `verify/adc_stream_pipe_tb.v` (frame_to_fifo + fifo together)
- `verify/adc_stream_overrun_tb.v` (sticky overrun behavior)
- `verify/adc_streaming_ingest_tb.v` (DRDY-paced ingest: drdy_sync + spi_frame_capture + frame_to_fifo + fifo)

### 3.2) Wishbone + real ADC ingest smoke
**Goal:** prove the real ADC ingest path works through the Wishbone FIFO interface (pop semantics + status bits) when compiled with `USE_REAL_ADC_INGEST`.

Implemented by:
- `verify/real_adc_compile_tb.v` (compile/elaboration guard)
- `verify/wb_real_adc_ingest_smoke_tb.v` (Wishbone-driven smoke)

### 4) Top-level integration sanity
**Goal:** ensure the top can elaborate and placeholder outputs are stable (no accidental Xs).

Implemented by:
- `verify/top_tb.v` (runs via `make -C verify top-sim`)

Notes:
- v1 top-level is still a skeleton (no Wishbone interface yet), so this test only checks reset/placeholder output stability.

## Definition of Done (v1 smoke)
- `make -C verify all` passes on a clean checkout (CI + local).
- Any regmap change requires updating `spec/regmap_v1.yaml` **and** regenerating + committing the derived artifacts in the same PR.
