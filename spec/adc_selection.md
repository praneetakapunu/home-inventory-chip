# ADC Selection (v1)

Goal: pick **one specific external ADC** for v1 so we can lock the digital interface (SPI vs I2C), register map fields, firmware packet formats, and harness tests.

This is a working document. **All numerical specs must be verified against the latest datasheets** before locking a decision.

## v1 constraints (from decisions/spec)
- Channel count: **8 channels** target (see `decisions/004-pad-channel-count.md`).
- Topology: **external ADC** (see `decisions/005-adc-topology.md`).
- Effective resolution target: **20 g** (see `decisions/007-effective-resolution-definition.md` and `spec/acceptance_metrics.md`).

## What we actually need (requirements)
### Electrical / sensing
- 8x load-cell / strain-gauge inputs (bridge → analog front-end details TBD)
- Differential inputs (preferred)
- Programmable gain (nice-to-have; depends on analog front-end architecture)

### Data quality
- Noise / ENOB adequate to support **20 g effective** after filtering + drift budget
- Continuous conversion mode suitable for slow-moving weight signals
- Sample rate: enough headroom for 8-channel scan + digital filtering (weight is low bandwidth)

### Digital interface & integration
- Interface: **SPI strongly preferred** (predictable timing + simple harness wiring)
- Digital IO compatibility with our harness/caravel IO plan
- Bring-up surface should be small (basic init + read frames/regs)

### Packaging / availability
- Package realistic for assembly in the v1 proto flow
- Availability (avoid unobtainium)

## Shortlist (candidates)

### Candidate A: TI ADS131M08 (SPI, 8ch delta-sigma, simultaneous)
- TI product page: https://www.ti.com/product/ADS131M08
- Datasheet (TI /lit): https://www.ti.com/lit/gpn/ads131m08
- Key facts (from TI product page; verify in datasheet):
  - 8 channels, **simultaneous sampling**
  - 24-bit ΔΣ
  - SPI interface
  - PGA (gain up to 128)
  - Digital supply range includes **1.65 V to 3.6 V** (check exact DVDD and IO levels)
- Primary integration risk:
  - Framed SPI readout / command model can be more involved than a simple I2C ADC

### Candidate B: Analog Devices AD7124-8 (SPI, precision sigma-delta, muxed)
- Product page: https://www.analog.com/en/products/ad7124-8.html
- Why it’s attractive:
  - Precision sensor ADC ecosystem; flexible digital filtering
  - SPI + register-map style control is often easy to bring up
- Primary integration risk:
  - Input muxing means 8 channels are not truly simultaneous; per-channel throughput budget must be confirmed

### Candidate C: TI ADS124S08 (SPI, precision ADC with mux/PGA)
- TI product page: https://www.ti.com/product/ADS124S08
- Datasheet (TI /lit): https://www.ti.com/lit/gpn/ads124s08
- Key facts (from TI product page; verify in datasheet):
  - 24-bit ΔΣ, **multiplexed**, up to 12 inputs
  - SPI interface with optional CRC
  - PGA (gain 1 to 128)
  - Data rate up to 4 kSPS
- Primary integration risk:
  - Throughput/cycle time for 8 channels may be tight depending on OSR/filter settings

## Comparison table (fill from datasheets; do not “memory-spec” this)

| Part | Vendor | Channels (simultaneous vs muxed) | Interface | PGA | Max SPS (headline) | IO / supply notes | Key risk | Links |
|---|---|---:|---|---:|---:|---|---|---|
| ADS131M08 | TI | 8 (simultaneous) | SPI | up to 128 | 32 kSPS | DVDD down to 1.65 V (verify IO) | framed SPI complexity | https://www.ti.com/product/ADS131M08 ; https://www.ti.com/lit/gpn/ads131m08 |
| AD7124-8 | ADI | muxed | SPI | TBD | TBD | TBD | per-ch throughput | https://www.analog.com/en/products/ad7124-8.html |
| ADS124S08 | TI | muxed (12 inputs) | SPI | 1..128 | 4 kSPS | DVDD 2.7..3.6 V (verify IO) | 8ch cycle time | https://www.ti.com/product/ADS124S08 ; https://www.ti.com/lit/gpn/ads124s08 |

## Decision rubric (what we compare)
1) **Can it practically yield 20 g effective** with reasonable filtering and drift budget?
2) Channel count without ugly muxing / throughput collapse
3) Interface simplicity for our bring-up + harness tests
4) Power/clock requirements compatible with the rest of the system
5) Availability + package

## Next actions (to close this)
- [ ] Decide whether we require a dedicated instrumentation amplifier / bridge front-end before locking the ADC.
- [ ] For each candidate, extract *from datasheet*:
  - input type/range + common-mode constraints
  - noise / RMS noise at chosen data rate (per-channel)
  - true per-channel sample rate achievable for 8 channels
  - IO levels, clocking, and SPI framing
- [ ] Pick 1 part and create/land the decision record: `decisions/008-adc-part-selection.md`.
- [ ] Update `spec/regmap.md` with any ADC-interface-visible controls (channel enables, decimation/filter config, CRC enable, etc.).
