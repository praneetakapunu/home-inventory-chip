# Tapeout Checklist (v1)

This is the end-to-end record of what must happen to reach tapeout. Keep it updated so we can optimize the process next time.

## 0) Product/spec freeze
- [x] Demo form factor: pads
- [x] Channels: 8
- [x] Target resolution: 5 g (effective, after calibration)
- [x] Repo visibility: public + open source (now)
- [ ] Define success metrics precisely (latency, false-positive rate, drift tolerance)
  - Drafted: `spec/acceptance_metrics.md` (needs Praneet sign-off)
- [ ] Finalize v1 feature list + explicit non-goals

## 1) Tapeout path selection
- [ ] Choose PDK + shuttle (Sky130A OpenMPW is default)
- [ ] Choose harness/integration approach (Caravel user project flow)
- [ ] Confirm budget fit (< $5k) including packaging + PCB
- [ ] Confirm IO constraints, package options, and shuttle schedule
- [ ] Decide target clock + perf class (conservative)

## 2) Architecture
- [x] External multi-channel ADC topology (digital-only chip)
- [ ] Select specific ADC part + interface (SPI vs I2C) + sampling plan
- [ ] Define SoC architecture: core, memory map, peripherals
- [ ] Define register map (draft) + bus choice inside harness
- [ ] Define host interface for demo (UART is minimum)

## 3) RTL implementation
- [ ] Set up RTL tree + lint rules
- [ ] Implement bus fabric + register map
- [ ] Implement ADC interface peripheral
- [ ] Implement timers/interrupts + UART
- [ ] Integrate CPU (or minimal MCU) + ROM/RAM

## 4) Verification
- [ ] Choose simulator flow (iverilog/verilator/etc.) + CI
- [x] Define v1 bring-up smoke tests (Wishbone reg block) — see `docs/VERIFICATION_PLAN.md`
- [ ] Create testbench harness + implement smoke tests (cocotb in harness repo)
- [ ] Add multi-channel ADC stimulus models
- [ ] Add regression tests: crosstalk, calibration, event detection

## 5) Firmware
- [ ] Bring-up firmware (UART printf, register reads)
- [ ] ADC sampling driver + per-channel calibration
- [ ] Filtering + event detection + telemetry protocol

## 6) Physical design
- [ ] Choose flow (OpenLane/OpenROAD) + constraints
- [ ] SDC + pin plan
- [ ] DRC/LVS clean
- [ ] STA timing closure (with margin)
- [ ] Generate GDS + signoff artifacts

## 7) Tapeout package + submission
- [ ] Assemble final deliverables per shuttle requirements
- [ ] Submit to MPW
- [ ] Archive submission bundle (for reproducibility)

## 8) Post-tapeout bring-up
- [ ] PCB design for pads + ADC + chip breakout
- [ ] Assembly + test plan
- [ ] Silicon validation + demo documentation
