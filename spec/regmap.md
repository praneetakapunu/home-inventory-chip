# Register Map (draft)

This is the draft register map for the digital chip block that will live in the OpenMPW harness.

## Goals
- Minimal set to support 8-channel sampling, calibration, and event reporting.

## Proposed blocks

### 0x0000_0000: ID / version
- `ID` (RO)
- `VERSION` (RO)

### 0x0000_0100: Control
- `CTRL` (RW): enable, start/stop
- `IRQ_EN` (RW)
- `STATUS` (RO)

### 0x0000_0200: ADC interface
- `ADC_CFG` (RW): mode, rate
- `ADC_CMD` (WO)
- `ADC_RAW_CH0..CH7` (RO)

### 0x0000_0300: Calibration
- `TARE_CH0..CH7` (RW)
- `SCALE_CH0..CH7` (RW)

### 0x0000_0400: Events
- `EVT_COUNT_CH0..CH7` (RO)
- `EVT_LAST_DELTA_CH0..CH7` (RO)
- `EVT_LAST_TS` (RO)

## Notes
- Exact fixed-point formats TBD after ADC part selection.
