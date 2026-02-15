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
  - SPI interface and a “streaming” style readout is common on this family
  - Delta-sigma ADC family is generally a good fit for low-bandwidth, high-resolution sensing
- Integration questions:
  - Digital IO voltage levels
  - Exact framing for multi-channel reads (word length / CRC / status)
  - Power/clocking requirements
- Risk:
  - More complex digital framing than simple I2C ADCs

### Candidate B: TI ADS124S08 (SPI, 4–8 muxed inputs depending on mode)
- Why it’s attractive:
  - Known in precision sensor space; good PGA options in some variants
  - SPI
- Integration questions:
  - True simultaneous 8ch vs muxed (throughput per channel)
  - Does it meet 8-channel requirement without compromises?

### Candidate C: ADI / Maxim / others (to fill)
- Keep a slot open for an alternate vendor part if availability or interface constraints bite us.

## Decision rubric (what we compare)
1) **Can it practically yield 20 g effective** with reasonable digital filtering and drift budget?
2) Channel count without ugly muxing / throughput collapse
3) Interface simplicity for our bring-up + harness tests
4) Power/clock requirements compatible with the rest of the system
5) Availability + package

## Next actions (to close this)
- [ ] Confirm whether we need an instrumentation amplifier / dedicated bridge front-end before the ADC decision.
- [ ] Pull 2–3 datasheets and fill a comparison table (noise @ SPS, input type, PGA, interface framing, IO levels, clocks).
- [ ] Pick 1 part and create a decision record: `decisions/008-adc-part-selection.md`.
- [ ] Update `spec/regmap.md` with any ADC-interface-visible controls (e.g., channel enables, decimation, CRC enable) as needed.
