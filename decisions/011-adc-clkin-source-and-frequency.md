# Decision 011 — ADS131M08 CLKIN source + frequency (v1)

## Status
**Proposed (must accept before tapeout)**

## Context
The ADS131M08 requires a continuous, free-running master clock on `CLKIN` for normal operation.
If `CLKIN` is missing or unstable, conversion results and `DRDY` behavior will be undefined and bring-up will fail.

We currently have two repos in play:
- IP/spec repo: `chip-inventory/`
- Harness repo: `home-inventory-chip-openmpw/`

We need to lock (with evidence) what the OpenMPW harness/board actually provides for `CLKIN`.

Reference working notes:
- `docs/ADC_CLOCKING_PLAN.md`
- `spec/ads131m08_interface.md`

## Decision
We will lock **exactly one** of the following for v1:

### Option A — Board oscillator drives `CLKIN`
- `CLKIN` is sourced from a dedicated oscillator on the harness/PCB.
- We must lock the oscillator part number and nominal frequency.

### Option B — SoC/harness clock drives `CLKIN`
- `CLKIN` is sourced from a known Caravel/harness clock output net.
- We must lock which net/pad drives it and the nominal frequency.

(We explicitly do **not** plan around an “internal oscillator” assumption.)

### Frequency
We will lock a single nominal `CLKIN` frequency (Hz): **TBD**.

Guiding principle: choose a frequency that is:
- easy to generate reliably on the harness,
- easy to verify on the scope,
- compatible with a “low-kHz DRDY” initial bring-up configuration.

## Evidence required (acceptance criteria)
This decision is **Accepted** only when we can point to at least one concrete source:
- harness schematic/netlist snippet, or
- harness docs that explicitly name the net + frequency, or
- a committed harness RTL/pinout file that assigns `adc_clkin` to a specific IO.

Record evidence as:
- **Source:** `<path>:<line>` (or URL)
- **CLKIN route:** (oscillator part# OR SoC clock net/pad)
- **Expected CLKIN frequency:** (Hz)
- **Expected DRDY rate at v1 defaults:** (Hz)

### Current evidence snapshot (as of harness HEAD 08e3dea)
Running:
```bash
tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw
```
Found **no explicit CLKIN mapping or frequency** in committed harness RTL/openlane docs; only draft planning notes.

Evidence:
- Source: `home-inventory-chip-openmpw/docs/source/adc_pinout_plan.md:26` — mentions optional `adc_clkin` only if we decide to drive `CLKIN` from SoC.
- Source: `home-inventory-chip-openmpw/docs/source/adc_pinout_plan.md:34` — states intent to route/drive `adc_clkin` from a known SoC clock output (not yet specified).
- Source: `home-inventory-chip-openmpw/docs/source/adc_pinout_plan.md:58` — `io[??]` placeholder for `adc_clkin`.
- Source: `home-inventory-chip-openmpw/docs/source/adc_pinout_plan.md:62` — notes that if `adc_clkin` is not routed, harness/PCB must provide an oscillator into `CLKIN`.

Implication: we must still lock either Option A (board oscillator) or Option B (SoC clock-out net), plus frequency, with real evidence before tapeout.

### Low-disk confirmation procedure (repo-local)
Use this when you *don’t* want to open schematics yet, and just want to find any already-committed assumptions.

From `chip-inventory/`:
```bash
tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw
```

If it finds a candidate mapping, capture the evidence in this decision in the format:
- Source: `home-inventory-chip-openmpw/<path>:<line>`
- CLKIN route: `io[*]` (or named net) → `ADC_CLKIN/CLKIN`
- Expected CLKIN frequency: `<Hz>`

If it finds **no** mapping and only “TBD/placeholder” text, that is still useful evidence:
- it means we must treat `CLKIN` routing/frequency as an explicit tapeout requirement (Option A oscillator or Option B SoC clock-out) and track it as an open item until the harness repo/board design is updated.

## Consequences
- Firmware bring-up (`docs/ADC_FW_INIT_SEQUENCE.md`) will treat missing/incorrect `CLKIN` as the *first* debug item.
- RTL verification continues to assume an ideal clock; real-hardware validation depends on this being correct.

## Follow-ups
- [ ] Update `docs/ADC_CLOCKING_PLAN.md` decision record with the accepted values + evidence.
- [ ] Update `spec/ads131m08_interface.md` TODO list to reference the accepted source.
