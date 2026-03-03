# Known Limitations (v1)

This file is the honest list of what v1 **does not** do (or does only partially), so the harness + firmware + demo expectations stay aligned.

> Keep this list small and accurate. If we fix something, delete the limitation.

## Functional limitations

- **Event detector is intentionally minimal (v1):**
  - Treat it as a *directed-test driven* feature, not a fully tuned DSP block.
  - Any behavior not covered by a directed smoke test should be considered undefined until we lock it.
  - Source: `docs/EVENT_DETECTOR_SPEC.md` + `verify/event_detector_tb.v`.

- **ADC streaming contract is “good enough for tapeout”, not a full driver stack:**
  - The SoC pushes **9 words per conversion** (STATUS + CH0..CH7) into the FIFO; the on-wire CRC word is **dropped/ignored** in v1.
  - FIFO policy is **drop-on-full** with a sticky OVERRUN bit (W1C).
  - Source: `docs/ADC_STREAM_CONTRACT.md`.

- **Single-clock-domain assumption (v1):**
  - Streaming capture + FIFO + timestamp counter assume `wb_clk_i` drives the whole path.
  - If we introduce an ADC-specific clock later, we must revisit CDC + timestamp alignment.
  - Source: `docs/ADC_STREAM_CONTRACT.md` + `docs/TIMESTAMP_SOURCE.md`.

- **ADC interface assumptions are fixed to ADS131M08 framing:**
  - DRDY-driven frame capture assumptions are documented in `spec/ads131m08_interface.md`.
  - SPI word-length/framing must match that document.

## Bus / register interface limitations

- **Wishbone byte-enable policy may be restricted:**
  - Firmware should prefer full 32-bit accesses unless a register explicitly documents byte lanes.
  - Source of truth: `spec/regmap.md` + `rtl/home_inventory_wb.v`.

- **No DMA / high-throughput streaming guarantees:**
  - FIFO depth + servicing rate may limit sustained capture.
  - Overrun is signaled via sticky flags; software must poll/handle.

## Verification limitations

- **DV is directed-smoke level (not exhaustive):**
  - We rely on a small set of cocotb + compile checks.
  - Source: `docs/VERIFICATION_PLAN.md`.

## Bring-up / demo limitations

- **Bench acceptance metrics are system-level and depend on mechanics:**
  - The ~20 g goal is not purely digital; fixture + drift dominate.
  - Source: `spec/v1.md` + `spec/acceptance_metrics.md`.
