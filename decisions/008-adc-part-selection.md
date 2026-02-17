# Decision 008: ADC part selection (v1)

- **Date:** 2026-02-17
- **Owner:** Praneet
- **Status:** Decided

## Decision
Select **TI ADS131M08** as the external ADC target part for v1.

Links:
- TI product page: https://www.ti.com/product/ADS131M08
- Datasheet: https://www.ti.com/lit/gpn/ads131m08

## Context
For v1 we decided to use an **external ADC** and target **8 channels**. We also aligned the v1 **effective resolution target** to **20 g**. To proceed with RTL/harness integration, we need to lock one concrete ADC part so that:
- The digital interface (SPI framing vs SPI register-map vs I2C) is stable
- The register map fields are stable (e.g., decimation/filter selection, channel enable, CRC enable)
- Firmware packet formats can be defined
- Harness tests can be written against a deterministic “ADC transaction model”

References:
- `decisions/004-pad-channel-count.md`
- `decisions/005-adc-topology.md`
- `decisions/007-effective-resolution-definition.md`
- `spec/acceptance_metrics.md`
- `spec/adc_selection.md`

## Rationale
ADS131M08 best matches the tapeout-risk profile for v1:
- **8 channels, simultaneously sampling** (avoids throughput/cycle-time surprises from muxed architectures).
- **SPI interface** (preferred for deterministic timing and harness wiring).
- Has integrated **PGA** and optional **CRC** support (useful for robust bring-up).
- Leaves room to simplify the on-chip digital by treating the ADC as an off-chip sampled-data source with a stable framing/transaction model.

## Alternatives considered (and why not)
- **ADI AD7124-8**: attractive filtering + register-map control, but muxed front-end complicates per-channel throughput budgeting and “simultaneous 8ch” behavior.
- **TI ADS124S08**: great precision ADC with PGA and many sensor-oriented features, but muxed architecture and lower headline SPS make 8-channel cycle-time riskier.

## What this unlocks / next concrete steps
1) Define a minimal “ADC readout model” for ADS131M08 that we can emulate in simulation/harness:
   - reset/boot
   - steady-state frame read (word count/order)
   - status/CRC handling
2) Update `spec/regmap.md` with ADC-interface-visible controls and status aligned to this model.
3) Implement/adjust RTL + harness tests to this one stable target.

## Notes
This decision locks the *digital integration target*. It does **not** imply we’ve fully validated analog performance (noise/drift/mechanics) end-to-end; that remains a bench/system task, but ADS131M08 is a strong fit for low-bandwidth precision sensing and avoids mux-throughput pitfalls.
