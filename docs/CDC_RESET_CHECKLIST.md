# CDC / Reset Checklist (v1)

This is a lightweight, explicit checklist to avoid tapeout-killers.
Fill this out as the RTL/harness wiring settles.

> Scope: `chip-inventory/rtl/**` as integrated into the OpenMPW harness repo.

## 1) Clock domains (enumerate)

- [ ] **wb_clk_i** (Wishbone / bus clock)
  - Source in harness: TBD (document exact net)
  - Frequency: TBD
- [ ] **adc_sclk** (ADC SPI clock)
  - Source: TBD (generated vs external)
  - Frequency: TBD
- [ ] **core_clk** (CPU / fabric clock, if present)
  - Source: TBD

Notes:
- If we end up using only one clock for v1, explicitly state it and delete unused sections.

## 2) Resets (enumerate)

- [ ] **wb_rst_i** polarity: [ ] active-high  [ ] active-low
- [ ] Reset deassertion strategy:
  - [ ] synchronous to wb clock
  - [ ] asynchronous assert, synchronous deassert

For each clock domain above, document:
- [ ] what reset signal applies
- [ ] whether reset deassertion is synchronized

## 3) Async inputs (enumerate + mitigation)

List every signal that can be asynchronous to a receiving clock domain.

### Candidate list (update as wiring is finalized)

- [ ] **adc_drdy** (from ADC)
  - Receiving domain: wb_clk_i (currently assumed)
  - Mitigation:
    - [ ] 2FF synchronizer
    - [ ] edge detector uses synchronized signal only

- [ ] **gpio inputs** (if used)
  - Receiving domain: TBD
  - Mitigation: [ ] 2FF per bit  [ ] other (document)

- [ ] **interrupts** (if any external)
  - Receiving domain: TBD

## 4) Cross-domain transfers (explicitly identify)

For each transfer, state the mechanism (FIFO, handshake, Gray counter, etc.).

- [ ] ADC capture → Wishbone-visible FIFO
  - Mechanism: [ ] same clock (no CDC)  [ ] async FIFO  [ ] handshake
  - Notes: `rtl/adc/adc_stream_fifo.v` currently assumes synchronous push/pop.

## 5) Reset-safe state + X-prop assumptions

- [ ] All state elements have reset values (or are otherwise safe)
- [ ] No latches inferred
- [ ] No reliance on X-initialization for functional correctness

## 6) Byte enable policy (Wishbone)

- [ ] Supported byte enables: [ ] full 32-bit only  [ ] per-byte writes  [ ] other
- [ ] If unsupported, reads/writes behavior is explicitly documented in:
  - [ ] `docs/KNOWN_LIMITATIONS.md`
  - [ ] `spec/regmap.md`

## 7) Evidence (what we actually checked)

- [ ] Manual review complete (record who/when)
- [ ] Lint/CDC tool run (if any):
  - Tool:
  - Command:
  - Result summary:

## 8) Open items

- [ ] (fill)
