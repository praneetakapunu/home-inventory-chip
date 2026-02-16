# Decision 008: ADC part selection (v1)

## Status
**Proposed** (not yet locked)

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

## Options considered
1) **TI ADS131M08** (SPI, multi-channel delta-sigma)
2) **Analog Devices AD7124-8** (SPI, register-map controlled sigma-delta)
3) **TI ADS124S08** (SPI, precision ADC with mux/PGA)
4) **Backup alternate vendor part** (availability-driven)

## Decision
Not decided yet.

## Decision criteria (must satisfy)
- Practical path to **20 g effective** with realistic drift + filtering assumptions
- 8-channel requirement without unacceptable throughput collapse
- Bring-up simplicity: a transaction model we can simulate/test in harness
- IO voltage + clock/power constraints compatible with Caravel / harness expectations
- Availability + package manageable for v1 prototyping

## Required evidence before locking
- Datasheet-backed comparison table filled in `spec/adc_selection.md` (no “memory specs”)
- A quick “readout model” sketch for the chosen part:
  - reset/boot sequence
  - steady-state read sequence (frame contents, word counts)
  - error checking (CRC/status)
  - how we represent samples in Wishbone-visible registers

## Consequences (once locked)
- `spec/regmap.md` will be updated with ADC-facing controls and status
- RTL stubs can be shaped to match the chosen interface (even if the physical ADC is off-chip)
- Harness repo tests can be written to emulate the chosen ADC protocol
