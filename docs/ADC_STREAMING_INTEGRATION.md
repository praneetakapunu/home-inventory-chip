# ADC Streaming Integration (v1)

This doc captures the **end-to-end contract** for ADC streaming as it exists *today* in the RTL + regmap, so harness + firmware can integrate without guesswork.

Scope:
- **IP repo:** `chip-inventory/`
- **Harness repo:** `home-inventory-chip-openmpw/`
- ADC part: **TI ADS131M08** (see `decisions/008-adc-part-selection.md`)

> TL;DR: The design produces **frames**; each captured frame is pushed into a small 32-bit FIFO as **9 words**:
> 1) a status word, then
> 2) 8 channel words (CH0..CH7), with the sample in the **lower 24 bits**.

---

## Build configurations

### Default (stub / snapshot mode)
When **`USE_REAL_ADC_INGEST` is NOT defined**:
- `home_inventory_wb` does **not** expose ADC SPI pins.
- A firmware write to `CTRL.START` generates a **snapshot** of synthetic ADC words (DV/bring-up path).

This mode exists so firmware + Wishbone + regmap work can progress without real board IO.

### Real ingest (SPI capture → frame → FIFO)
When compiling with **`-DUSE_REAL_ADC_INGEST`**:
- `home_inventory_wb` *adds* ADC SPI ports:
  - `adc_sclk`, `adc_cs_n`, `adc_mosi`, `adc_miso`
- `CTRL.START` becomes the trigger for the ingest pipeline (`rtl/adc/adc_streaming_ingest.v`).

Harness should provide a matching compile target:
- `make rtl-compile-check-real-adc`

See also:
- `docs/HARNESS_INTEGRATION.md` (define behavior + expected harness wiring)

---

## Module/dataflow (real ingest)

Conceptually:

1) **SPI frame capture** reads one ADC frame (ADS131M08 framing assumptions live in `spec/ads131m08_interface.md`).
2) Captured words are **sequenced** into a FIFO as a compact SW-visible stream.
3) Firmware drains the FIFO using Wishbone reads.

Key modules:
- `rtl/adc/adc_streaming_ingest.v` — top-level sequencing for “capture one frame then push words into FIFO”
- `rtl/adc/adc_stream_fifo.v` — 32-bit FIFO with level + sticky overrun
- `rtl/home_inventory_wb.v` — Wishbone register block and FIFO pop interface

---

## Regmap contract (what firmware sees)

Authoritative register definitions:
- `spec/regmap_v1.yaml`
- Human-readable summary: `spec/regmap.md`

### FIFO word format
Each captured frame pushes exactly **9 FIFO words** in this order:

0. **Frame status word**
1. **CH0 sample word**
2. **CH1 sample word**
3. **CH2 sample word**
4. **CH3 sample word**
5. **CH4 sample word**
6. **CH5 sample word**
7. **CH6 sample word**
8. **CH7 sample word**

Channel sample words:
- Sample value is in the **lower 24 bits** (`[23:0]`).
- Upper bits are currently reserved (treat as 0; mask defensively in FW).

> The exact bit semantics of the *status word* are intentionally minimal in v1; treat it as an opaque word unless the spec explicitly assigns bits.

### FIFO status + pop semantics
- `ADC_FIFO_STATUS` reports:
  - current FIFO **level** (in words)
  - **sticky OVERRUN** flag when pushes occur while the FIFO is full
- `ADC_FIFO_DATA` is a **pop** register:
  - each read returns the next FIFO word and decrements the level
  - reads while empty return **0** and must not change state

Overrun clear behavior:
- OVERRUN is **write-1-to-clear** (W1C) on its documented bit.
- Byte-strobes apply: clearing must use the correct lane.

---

## Firmware quick sequence (recommended)

The exact register names/addresses should be pulled from the generated headers.

1) **Enable** the block (`CTRL.ENABLE=1`).
2) Program any ADC configuration fields used in v1 (e.g. channel count, if applicable).
3) Trigger capture:
   - write `CTRL.START=1` (W1P)
4) Poll for data:
   - read `ADC_FIFO_STATUS` until `level_words >= 9`
5) Drain the FIFO:
   - read `ADC_FIFO_DATA` 9 times
   - interpret `[0]` as status, `[1..8]` as CH0..CH7
6) If OVERRUN was set:
   - clear with W1C

---

## Verification hooks

Directed sims that prove the above behavior:
- `make -C verify sim` (Wishbone + snapshot FIFO push/pop semantics)
- `make -C verify wb-real-adc-smoke-sim` (Wishbone + real ingest + FIFO pop semantics)

The real-ingest smoke test in particular proves:
- FIFO level reaches 9 words after capture
- pop ordering is stable
- FIFO drains back to empty

---

## Known open items (intentional)

- **CLKIN source/frequency in the harness is not fully locked yet.**
  - Track decision + evidence: `decisions/011-adc-clkin-source-and-frequency.md`
- Any additional status bits (CRC, framing errors, etc.) should only be added if they do not churn addresses.
