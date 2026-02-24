# Decision: ADC streaming FIFO depth + overrun/empty-read policy (v1)

- **Date:** 2026-02-24
- **Owner:** Madhuri
- **Status:** Decided

## Decision
For v1, the firmware-visible ADC streaming FIFO is **16 words deep** and implements a **sticky overrun flag** (W1C), with **reads-when-empty returning 0 and not changing state**.

## Rationale
- Keep the first-silicon / OpenMPW integration surface small and deterministic.
- A 16-word FIFO is large enough to buffer at least **one full ADC frame** (status + 8 channels = 9 words) plus slack, while staying modest in area.
- Sticky overrun is the simplest reliable way for firmware to detect missed drains without requiring precise cycle-level timing.

## Implications
- FIFO depth is a hard limit: if firmware does not drain fast enough, words will be dropped and `OVERRUN` must be treated as “data continuity lost”.
- Firmware must poll/drain using `ADC_FIFO_STATUS.LEVEL_WORDS` and may clear overrun with `ADC_FIFO_STATUS.OVERRUN` (W1C).
- The stub implementation used for bring-up pushes a complete frame on each `ADC_CMD.SNAPSHOT` pulse; the real ADC capture path must preserve the same FIFO packing and status behavior.

## Follow-ups
- Ensure `spec/regmap.md` and `spec/regmap_v1.yaml` explicitly encode:
  - FIFO depth assumption (documented)
  - Empty-read policy (documented)
  - Overrun sticky + W1C byte-lane semantics (already implemented)
- When the real ADC path lands, add a directed DV test that forces an overrun via sustained push and verifies that firmware-visible behavior matches this decision.
