# ADC Clocking Plan (ADS131M08) — v1

This document captures the **practical clocking plan** for the ADS131M08 on the OpenMPW tapeout path.

It exists because the ADC digital interface (SPI + DRDY) is easy to simulate, but **real silicon bring-up** will fail or look “random” if the ADC clock source is undefined.

Related:
- Chip-level interface assumptions: `spec/ads131m08_interface.md`
- FW bring-up sequence: `docs/ADC_FW_INIT_SEQUENCE.md`

## What we need (requirements)
1) A **known, stable ADC clock source** that is present on the board/harness.
2) A way to verify at bring-up time that the clock is present (scope point, test pad, or observable behavior).
3) A documented assumption for sample rate / DRDY rate so firmware can set expectations.

**Non-negotiable datasheet implication (v1):** ADS131M08 requires a *continuous, free‑running external master clock* on `CLKIN` for normal operation. The ΔΣ modulators will not run (and `DRDY` behavior will not make sense) if `CLKIN` is not toggling.

References:
- TI ADS131M08 datasheet: https://www.ti.com/lit/ds/symlink/ads131m08.pdf
- TI E2E clarification thread (clocking): https://e2e.ti.com/support/data-converters-group/data-converters/f/data-converters-forum/905809/ads131m08-datasheet-clarification-for-clocking-the-adc

## Candidate clock sources

### Option A — Dedicated oscillator into `CLKIN` (preferred)
- Put an oscillator (or crystal + driver) on the board feeding `ADC_CLKIN`.
- Pros:
  - Decouples ADC performance from SoC clocks and harness quirks.
  - Easiest to reason about.
- Cons:
  - Requires board support; may not be available on the OpenMPW harness as-is.

### Option B — Drive `CLKIN` from a Caravel clock output (possible)
- Provide a clock out from the SoC/harness into the ADC `CLKIN`.
- Pros:
  - No extra BOM if the harness routes it.
- Cons:
  - Must ensure clock quality, frequency, and that it is present early enough.
  - Adds coupling between SoC clock domains and ADC behavior.

### Option C — ADC internal oscillator
- **Do not assume this exists.** For ADS131M08, treat `CLKIN` as required (external free‑running clock).
- Pros:
  - (N/A for ADS131M08 v1 plan)
- Cons:
  - If we plan around an internal oscillator that isn’t actually available, bring-up will fail (no conversions / unexpected `DRDY`).

## Bring-up verification checklist (scope-first)
At first hardware bring-up, before trusting any samples:
1) Verify `CLKIN` is toggling at the expected frequency (free-running, continuous).
2) Verify `DRDY` transitions after power-on reset completes **only once `CLKIN` is present**.
3) Verify `DRDY` toggles at the expected conversion rate once conversions are started/configured.
4) Verify SPI `SCLK/CS` timing does not violate the “CS transitions while SCLK low” rule.

If (1) fails, **do not** debug RTL first.

## Clock ↔ data-rate expectations (so DV + bring-up agree)
We need a *numerical* expectation for what "normal" looks like on the scope.

The ADS131M08 conversion rate is derived from the modulator clocking; in practice, we should lock a **single `CLKIN` frequency** and a **single sample rate target** (at least for v1 bring-up).

### Proposed v1 baseline (PROVISIONAL — not locked until harness is confirmed)
Because the OpenMPW harness may constrain what clocks we can practically provide, we keep this as a *recommendation* until we can point to an actual schematic/net.

**Recommendation:** prefer one of these two `CLKIN` frequencies, chosen for “easy to generate and verify”:
- **8.192 MHz** (common audio-ish clock; easy divider chains)
- **4.096 MHz** (half-rate alternative)

Then select an ADS131M08 data-rate configuration such that **DRDY is in the low-kHz range** during initial bring-up.

Why low-kHz:
- Fast enough to observe quickly and stress FIFO + drain loops.
- Slow enough that a simple firmware loop can keep up without DMA.

**Bring-up target:** 1 kSps per channel (order-of-magnitude target; exact register settings to be filled once we lock the final `CLKIN` + OSR).

### What firmware must log (so we can debug clocking remotely)
Even in “minimal” bring-up firmware, always log these fields at start:
- assumed/selected `CLKIN` source (oscillator vs SoC clock output name)
- assumed/selected `CLKIN` frequency (Hz)
- configured ADS131M08 data-rate / decimation registers (raw values)
- **measured DRDY rate** (Hz) from a timer-based measurement over ~1s
- streaming FIFO overrun flag status (`ADC_FIFO_STATUS.OVERRUN`)

If measured DRDY is zero or wildly off, treat it as **clocking/config** first—not RTL.

### What must be documented once we confirm the board/harness
- `CLKIN` frequency (Hz) and its source (oscillator part# or SoC clock output name)
- expected DRDY rate (samples/sec) at v1 defaults
- any required straps (SYNC/RESET, START pin behavior, etc.)

## Questions to answer from the harness/PCB (must close before tapeout)
1) Is ADS131M08 `CLKIN` physically routed? To where?
2) Is there an oscillator footprint/populated? If yes: frequency + part number.
3) If `CLKIN` is driven from SoC/harness:
   - which clock net?
   - is it present immediately after reset?
   - what is the tolerance/jitter expectation?
4) Is `DRDY` level shifted / inverted on the harness? (we assume active-low semantics)
5) Is `RST_n` controllable from SoC, or only POR?

## How to confirm clocking quickly (repo-local procedure)
We have **two** repos in play:
- IP/spec repo: `chip-inventory/` (this repo)
- Harness repo: `home-inventory-chip-openmpw/`

The fastest way to find any existing decisions/assumptions is to grep the harness repo.

### One-liner helper (preferred)
From the IP repo root:
```bash
tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw
```

### Manual grep (if you don’t want scripts)
```bash
cd ../home-inventory-chip-openmpw
rg -n "adc_clkin|ADC_CLKIN|CLKIN|ADS131|ads131" docs verilog caravel spi
```

### What “confirmed” means for v1
We are confirmed only when we can answer (with a source link/path):
- Is `CLKIN` physically routed on the harness/board?
- If yes, what is the **source** (oscillator part# OR which SoC clock output net)?
- What is the expected **frequency** (Hz)?
- Is the signal present immediately after reset / before FW starts SPI?

When confirmed, fill in the **Decision record** below with:
- `Source:` path (e.g. harness doc, schematic page, netlist snippet)
- expected `CLKIN` frequency
- expected steady-state `DRDY` rate at v1 defaults

## Current v1 status
- **Clock source:** TBD.
- **Action required:** confirm what the OpenMPW harness/board actually provides:
  - Is `CLKIN` routed?
  - Is there an oscillator footprint/populated?
  - Is there a stable SoC clock that can be routed out?

### Last harness repo audit (evidence snapshot)
**Audit date:** 2026-03-09 (UTC)

As of this audit, the harness repo contains **only** a placeholder mention that we *might* add `adc_clkin` if we decide to drive ADS131M08 `CLKIN` from the SoC; there is **no locked routing/net/pad assignment** yet.

**Evidence (harness repo):**
- `docs/source/adc_pinout_plan.md`:
  - mentions optional `adc_clkin` (“if we decide to drive CLKIN from SoC”)
  - explicitly calls out the open question: “will the board provide `CLKIN`, or do we need to synthesize/route one from Caravel?”
- `docs/source/pinout.md`: mentions eventual need for external ADS131M08 GPIO routing (SPI + DRDY + reset)
- `verilog/rtl/home_inventory_user_project.v`: contains a comment stub for the external ADS131M08 interface

Run (from the IP repo root):
```bash
tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw
```

**Observed output (2026-03-09, abridged):**
```text
--- rg -n "adc_clkin" (docs verilog) ---
docs/source/adc_pinout_plan.md:26:- `adc_clkin` (if we decide to drive CLKIN from SoC)

--- rg -n "ADC_CLKIN" (docs verilog) ---
(no matches)

--- rg -n "ADS131" (docs verilog) ---
docs/source/pinout.md:27:However, v1 will eventually need GPIO routing for the external ADS131M08 ADC (SPI + DRDY + reset).
docs/source/adc_pinout_plan.md:1:# ADC (ADS131M08) GPIO Pinout Plan — v1 (DRAFT)
verilog/rtl/home_inventory_user_project.v:67:    // external ADS131M08 interface.

--- rg -n "\\bCLKIN\\b" (docs/verilog, word-boundary) ---
docs/source/adc_pinout_plan.md:60:- Clocking plan: will the board provide `CLKIN`, or do we need to synthesize/route one from Caravel?
```

## Decision record (to fill)
When decided, add a short entry here and link the decision in `decisions/`.

- Decision: (TBD)
- Source: (schematic / harness docs / datasheet)
- Expected `CLKIN` frequency: (TBD)
- Expected DRDY rate: (TBD)
