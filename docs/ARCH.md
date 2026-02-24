# Architecture (v1)

> Scope: **home-inventory** user-project IP for OpenMPW/Caravel.
> This document is the top-level “what exists” reference for tapeout.

## 1) System context

- Caravel SoC exposes:
  - Wishbone (WB) bus to the user project
  - a user clock + reset
  - GPIO/IRQ pins
- This IP is a **Wishbone slave** that provides:
  - a small control/status register file
  - an ADC streaming interface (FIFO) for external ADC samples

## 2) Top-level block diagram (logical)

```
            +------------------------------+
WB (32b) -->| Wishbone regblock            |
            |  - ID/VERSION                |
            |  - CTRL/STATUS               |
            |  - ADC_CFG/ADC_CMD           |
            |  - ADC_FIFO_STATUS/DATA      |
            |  - CAL (tare/scale regs)     |
            +--------------+---------------+
                           |
                           | internal (sample words)
                           v
                    +-------------+
DRDY/MISO/SCLK/CS ->| ADC capture |
                    |  (SPI frame |
                    |   capture)  |
                    +------+------+ 
                           |
                           v
                    +-------------+
                    | Stream FIFO |
                    |  32-bit     |
                    |  level +    |
                    |  overrun    |
                    +-------------+
```

## 3) Interfaces

### 3.1 Wishbone

- 32-bit Wishbone slave
- Byte addresses (`wbs_adr_i` is a byte address)
- Registers decode as **word aligned**; ignore `wbs_adr_i[1:0]`
- Must honor `wbs_sel_i` byte enables on writes

Register map:
- Human-readable: `spec/regmap.md`
- Source of truth: `spec/regmap_v1.yaml`

### 3.2 External ADC (ADS131M08)

- SPI framing + DRDY behavior assumptions: `spec/ads131m08_interface.md`
- Firmware init sequence expectations: `docs/ADC_FW_INIT_SEQUENCE.md`

v1 streaming contract:
- For each conversion, hardware pushes **9 words** into FIFO:
  1) STATUS word
  2..9) CH0..CH7 samples (signed 32-bit, sign-extended)

## 4) Clocking / reset assumptions (v1)

- **Primary clock:** single primary user clock from Caravel (no internal PLLs in v1).
- **Async inputs:** all externally-sourced async signals (notably `adc_drdy`) are synchronized before use.
- **ADC clocking:** the *board/harness* must provide a valid ADS131M08 clock source.
  - See: `docs/ADC_CLOCKING_PLAN.md` (decision + bring-up checklist).

### What must be explicitly recorded before tapeout
- Caravel/user-project clock frequency used by the harness (Hz)
- ADC `CLKIN` source + frequency (Hz)
- SPI `SCLK` strategy (derive from user clock, divider value, max SCLK)
- Reset polarity and deassertion strategy:
  - what reset reaches the user project (active high/low)
  - which internal blocks treat reset as async assertion / sync deassertion

## 5) Observability / debug

- FIFO `OVERRUN` sticky flag via `ADC_FIFO_STATUS.OVERRUN` (W1C)
- Minimal status bits via `STATUS.CORE_STATUS`
- Event detector exposes per-channel last-timestamp regs (`EVT_LAST_TS*`) and counters (see regmap).

### Optional (only if bring-up needs it)
- A small `LAST_ERROR` code register (sticky, W1C) for quick “what went wrong” reporting.
  - If added, it must be reflected in `spec/regmap_v1.yaml` + `spec/regmap.md` + RTL + directed sim.
