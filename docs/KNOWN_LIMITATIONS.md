# Known Limitations (v1)

This file is the honest list of what v1 **does not** do (or does only partially), so the harness + firmware + demo expectations stay aligned.

> Keep this list small and accurate. If we fix something, delete the limitation.

## Functional limitations

- **Event detector is minimal / in-progress:**
  - Comparator / hysteresis / counters are still being iterated.
  - Until finalized, treat event outputs as *best-effort* and validate via directed tests.

- **ADC interface assumptions are fixed to ADS131M08 framing:**
  - DRDY-driven frame capture assumptions are documented in `spec/ads131m08_interface.md`.
  - CRC policy and exact words-per-frame must match that document.

## Bus / register interface limitations

- **Wishbone byte-enable policy may be restricted:**
  - If only full 32-bit accesses are supported, firmware must avoid partial writes.
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
