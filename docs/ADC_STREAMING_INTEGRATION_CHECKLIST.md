# ADC streaming integration checklist (v1)

This checklist turns the streaming path into a set of **small, verifiable** steps.

Goal: ADC frames flow end-to-end:
**ADC interface → frame packer → FIFO → regmap pop (WB reads)**

Normative references:
- Streaming contract: `docs/ADC_STREAM_CONTRACT.md`
- RTL architecture: `docs/ADC_RTL_ARCH.md`
- Regmap: `spec/regmap_v1.yaml` (`adc` block)
- Bring-up steps: `docs/BRINGUP_SEQUENCE.md` (Step 7)

---

## Definitions (shared)

A **frame** is the unit pushed into the FIFO:
- Word 0: ADC status word (or `0` if none)
- Word 1..8: CH0..CH7 raw samples

Acceptance criteria for *streaming enabled* builds:
- `ADC_FIFO_STATUS.LEVEL_WORDS` increases by **exactly 9** per accepted frame.
- `ADC_FIFO_DATA` pops **one word per read** when non-empty.
- Reads when empty return `0` and do not underflow/alter state.
- `OVERRUN` is sticky and clears on **W1C** write (respecting `wbs_sel_i`).

---

## Phase A — RTL wiring (no functional change, compile only)

1. **Plumb named signals** from the ADC interface block to the Wishbone regblock:
   - `adc_frame_valid`
   - `adc_status_word[31:0]` (or constant 0)
   - `adc_ch_raw[0..7][31:0]` (sign-extended / right-justified)

2. Keep an explicit top-level flag/parameter:
   - `ENABLE_ADC_STREAMING` (default: 0 until validated)

3. Update `rtl/` modules so a *streaming-enabled* build still compiles cleanly even if the upstream ADC is stubbed.

Deliverable: `make -C verify rtl-compile-check` (or equivalent) passes.

---

## Phase B — Frame packer (unit-testable in isolation)

1. Implement a frame packer with a simple handshake:
   - input: one-cycle `frame_valid` + stable word bundle
   - output: `fifo_push` + `fifo_din[31:0]`

2. Packing order is **normative**:
   - push status word first
   - then CH0..CH7

3. For a one-cycle `frame_valid`, the packer must generate **9 pushes** over 9 cycles (or faster if the FIFO supports multiword push, but assume 1/clk).

Deliverable:
- A small directed sim (or SystemVerilog test) that asserts push count/order for a synthetic frame.

---

## Phase C — FIFO integration + overflow policy

1. FIFO depth target for v1: see `decisions/010-adc-fifo-depth-and-overrun-policy.md`.

2. Overrun policy (normative):
   - If FIFO is full when a new word arrives, **drop the incoming word** and set sticky `OVERRUN`.
   - Do **not** corrupt already-buffered words.

3. Reset behavior:
   - FIFO empties on reset.
   - `OVERRUN` clears on reset.

Deliverable:
- Directed sim that forces FIFO full and demonstrates sticky `OVERRUN` + no corruption of earlier words.

---

## Phase D — Regmap pop semantics (Wishbone)

1. `ADC_FIFO_STATUS.LEVEL_WORDS` must reflect the current fill level.

2. `ADC_FIFO_DATA` read behavior (normative):
   - if `LEVEL_WORDS != 0`: return oldest word and pop exactly one entry.
   - if empty: return `0` and do nothing.

3. W1C behavior for `ADC_FIFO_STATUS.OVERRUN`:
   - Only bits in selected byte lanes participate (per `wbs_sel_i`).
   - Firmware should clear with full-word write (`SEL=0xF`).

Deliverable:
- Wishbone DV smoke test that:
  - drains 9 words and observes `LEVEL_WORDS` count down
  - checks empty reads are stable
  - checks `OVERRUN` W1C works

---

## Phase E — End-to-end acceptance (streaming-enabled)

Minimum end-to-end test (bring-up style):
1. Enable streaming build.
2. Generate N frames (real ADC or synthetic/stub).
3. Poll `LEVEL_WORDS` until at least 9.
4. Read 9 words from `ADC_FIFO_DATA`.
5. Validate packing order and that `LEVEL_WORDS` decremented by 9.

Acceptance:
- No Wishbone hangs.
- No underflow corruption.
- Overrun behavior is deterministic and observable.

---

## Common failure modes (what to check)

- `LEVEL_WORDS` increases but popped words are all zero:
  - packer pushing wrong bus / `fifo_din` not connected.

- `LEVEL_WORDS` never increases:
  - streaming disabled (`ENABLE_ADC_STREAMING=0`)
  - upstream `frame_valid` never asserted
  - FIFO held in reset

- `OVERRUN` never sets even with forced full FIFO:
  - full detection wrong, or overflow policy still drops frames silently.

- `OVERRUN` won’t clear:
  - W1C byte-lane masking bug; ensure clear logic respects `wbs_sel_i`.
