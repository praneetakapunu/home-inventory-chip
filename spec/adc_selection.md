# ADC Selection (v1)

Goal: pick **one specific external ADC** for v1 so we can lock the digital interface (SPI vs I2C), register map fields, firmware packet formats, and harness tests.

This is a working document. **All numerical specs must be verified against the latest datasheets** before locking a decision.

## v1 constraints (from decisions/spec)
- Channel count: **8 channels** target (see `decisions/004-pad-channel-count.md`).
- Topology: **external ADC** (see `decisions/005-adc-topology.md`).
- Effective resolution target: **20 g** (see `decisions/007-effective-resolution-definition.md` and `spec/acceptance_metrics.md`).

## What we actually need (requirements)
### Electrical / sensing
- 8x load-cell / strain-gauge inputs (likely bridge → instrumentation front-end assumptions TBD)
- Differential inputs (preferred)
- Programmable gain (nice-to-have; depends on analog front-end architecture)
- Input common-mode range compatible with our front-end plan

### Data quality
- Noise / ENOB adequate to support **20 g effective** after filtering and realistic drift
- Stable sampling mode (continuous conversion) suitable for slow-moving weight signals
- Sample rate: enough for multi-channel scanning + digital filtering (exact number TBD; weight is low bandwidth, but we need headroom)

### Digital interface & integration
- Interface: **SPI strongly preferred** for predictable timing + multi-device scalability
- 3.3V / 1.8V digital IO compatibility (depends on harness / caravel IO constraints)
- Simple command/response model (for a minimal bring-up)

### Packaging / availability
- Package that is realistic for assembly in the v1 proto flow
- Reasonable availability (avoid unobtainium)

## Shortlist (candidates to evaluate)

### Candidate A: TI ADS131M08 (SPI, 8ch delta-sigma)
- Why it’s attractive:
  - Native 8-channel part; avoids muxing
  - SPI interface with a “streaming” style readout is common on this family
  - Delta-sigma ADC family is generally a good fit for low-bandwidth, high-resolution sensing
- Integration questions (must confirm from datasheet):
  - Digital IO voltage levels (1.8V/3.3V?)
  - Exact framing for multi-channel reads (word length / status / CRC)
  - Clocking (external crystal/clk in?) and power rails
- Risk:
  - Framing/command model can be more involved than a simple register-based I2C ADC

### Candidate B: Analog Devices AD7124-8 (SPI, 8ch sigma-delta)
- Why it’s attractive:
  - 8 analog inputs with flexible muxing + programmable digital filter options
  - Strong ecosystem + common in precision sensor designs
  - SPI + register map (often easier to bring up than pure “streaming frames”)
- Integration questions (must confirm from datasheet):
  - Per-channel throughput at our chosen resolution/OSR
  - Input type/range constraints and whether we need an external instrumentation amp
  - Digital IO voltage + clocking
- Risk:
  - Muxed architecture means “simultaneous 8ch” isn’t guaranteed; need to budget per-channel sample rate

### Candidate C: TI ADS124S08 (SPI, precision ADC with mux/PGA)
- Why it’s attractive:
  - Known in precision sensor space; PGA options in some variants
  - SPI + register map style control
- Integration questions:
  - Can it meet the **8-channel** requirement without throughput collapse or awkward external muxing?
  - Total noise / ENOB at the sample rates we want

### Candidate D: Backup/availability-driven alternate vendor part
- Keep a slot open for a second-source if availability or packaging becomes the gating factor.

## Comparison table (fill from datasheets; do not “memory-spec” this)

| Part | Vendor | Channels (simultaneous vs muxed) | Interface | PGA? | Digital filter / decimation | IO voltage | Clocking | Key risk | Datasheet link |
|---|---|---:|---|---|---|---|---|---|---|
| ADS131M08 | TI | 8 (simultaneous?) | SPI (framed) | TBD | TBD | TBD | TBD | framing complexity | TBD |
| AD7124-8 | ADI | 8 (muxed) | SPI (register) | TBD | TBD | TBD | TBD | per-ch throughput | TBD |
| ADS124S08 | TI | muxed | SPI (register) | TBD | TBD | TBD | TBD | 8ch requirement | TBD |

## Decision rubric (what we compare)
1) **Can it practically yield 20 g effective** with reasonable digital filtering and drift budget?
2) Channel count without ugly muxing / throughput collapse
3) Interface simplicity for our bring-up + harness tests
4) Power/clock requirements compatible with the rest of the system
5) Availability + package

## Next actions (to close this)
- [ ] Confirm whether we need an instrumentation amplifier / dedicated bridge front-end before the ADC decision.
- [ ] Pull 2–3 datasheets and fill the table above (noise @ SPS, input type, PGA, framing, IO levels, clocks).
- [ ] Pick 1 part and create a decision record: `decisions/008-adc-part-selection.md`.
- [ ] Update `spec/regmap.md` with any ADC-interface-visible controls (e.g., channel enables, decimation, CRC enable) as needed.
