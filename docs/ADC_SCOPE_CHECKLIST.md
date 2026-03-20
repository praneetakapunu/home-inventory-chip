# ADC Scope Checklist (ADS131M08 bring-up)

This is a **hardware-side** checklist to run *before* spending time debugging firmware/RTL.
It is designed to produce **reviewable evidence** (scope screenshots + notes) that can be checked in and referenced by `decisions/011-adc-clkin-source-and-frequency.md`.

## Why this exists
If `CLKIN` is missing/wrong, the ADS131M08 will not behave predictably and *everything* downstream (DRDY, SPI frames, FIFO level) will look broken.

## What to capture (minimum evidence)
Record the following in a bring-up log (preferred: `reports/YYYY-MM-DD.md`), plus scope screenshots:

- **Board/harness version** (anything identifying)
- **Repo commits**
  - IP repo (`chip-inventory`) commit hash
  - Harness repo (`home-inventory-chip-openmpw`) commit hash
- **CLKIN route** (Option A oscillator vs Option B SoC clock-out)
- **Measured CLKIN frequency** (Hz) and approximate duty cycle
- **DRDY behavior**
  - toggles? (Y/N)
  - approximate rate (Hz) while streaming
  - idle level when not streaming (high/low)
- **Reset behavior** (`adc_rst_n`)
  - does it toggle on reset?
  - polarity observed

When the above is known, update:
- `decisions/011-adc-clkin-source-and-frequency.md` (status → **Accepted**)
- `docs/ADC_CLOCKING_PLAN.md` (lock the plan + evidence)

## Step-by-step (scope)

### 0) Preconditions
- ADS131M08 powered.
- Scope probe ground is solid; keep leads short.
- Know where you can probe:
  - **CLKIN pin** (or a labeled testpoint)
  - **DRDY pin** (or testpoint)
  - **SCLK/CS** (optional but helpful)
  - **RSTn** (if present)

### 1) Measure CLKIN (must-pass)
1. Probe `CLKIN` as close to the ADS131M08 pin/testpoint as possible.
2. Confirm:
   - clean periodic waveform (not stuck high/low)
   - frequency is stable
3. Measure and note:
   - frequency (Hz)
   - amplitude (approx)
   - duty cycle (approx)

**Pass condition:** stable, free-running clock is present and matches the planned source/frequency.

If CLKIN is absent or wrong: **stop**. Debug board/harness clocking first and keep `decisions/011` in **Proposed**.

### 2) Measure DRDY (sanity)
1. Probe `DRDY`.
2. With the ADC in its default state (no explicit configuration), DRDY may or may not toggle depending on reset/standby mode.
3. After enabling streaming (firmware writes `CTRL.ENABLE` + `CTRL.START`), confirm:
   - `DRDY` toggles periodically
   - the rate looks plausible (order-of-magnitude check)

**Notes:**
- The *exact* DRDY rate depends on ADC configuration (OSR/decimation/mode). For v1, we only need it to be **present and stable**.

### 3) Optional: correlate SPI activity
Probe `SCLK` and `CSn` while streaming:
- `CSn` should assert during frame reads
- `SCLK` should burst during reads

This helps distinguish:
- “ADC not converting” vs
- “ADC converting but SPI not happening” vs
- “SPI happening but data packing wrong”.

### 4) Optional: reset polarity/behavior
Probe `adc_rst_n` during SoC reset.
- Confirm polarity (active-low)
- Confirm it actually toggles when expected

## Where to put the evidence
- Short log: `chip-inventory/reports/YYYY-MM-DD.md`
- Decision record (must include **source** pointers): `chip-inventory/decisions/011-adc-clkin-source-and-frequency.md`

Template snippet (paste into reports/):

```markdown
## ADC scope check (ADS131M08)
- Date/time (UTC):
- Board/harness:
- chip-inventory: <commit>
- home-inventory-chip-openmpw: <commit>

### CLKIN
- Route (A osc / B SoC clk-out):
- Frequency measured (Hz):
- Evidence: <scope screenshot filename>

### DRDY
- Toggles after streaming enabled (Y/N):
- Rate (Hz, approx):
- Idle level:
- Evidence: <scope screenshot filename>
```
