# ADS131M08 Firmware Init Sequence (v1)

This is the **minimum** firmware configuration sequence we expect for ADS131M08 bring-up, aligned with our v1 digital contract (`spec/ads131m08_interface.md`).

Scope:
- what firmware must do on the **ADS131M08 SPI bus**
- not the Caravel/Wishbone bring-up (see `docs/BRINGUP_SEQUENCE.md`)

> Datasheet source: TI ADS131M08 (SBAS950B). If anything here conflicts with the datasheet, the datasheet wins.

## Goals (v1)
- Stream continuous 8-channel conversions.
- Use a word length that yields **sign-extended 32-bit** samples on the wire (preferred), or otherwise define a fixed sign-extension rule in firmware.
- Use **DRDY level-style** signaling (avoid pulse mode).
- Treat output CRC as present-on-wire but **ignored** in v1 (RTL drops it; firmware does not validate).

## SPI requirements (must)
- **CPOL=0, CPHA=1**.
- Change CS only when SCLK is low.
- Implement the frame pipeline rule: **response in frame N corresponds to command from frame N-1**.

## Reset + boot
1) Hold `RST_n` low for datasheet minimum reset time.
2) Release `RST_n`.
3) Wait for oscillator/clock stabilization (datasheet timing).

## Register configuration (recommended ordering)
Write registers using the ADS131M08 register read/write commands.

### 1) MODE (core framing / CRC / DRDY)
Set:
- `MODE.WLENGTH` → choose a 32-bit word length mode that produces **sign-extended** conversion words (preferred).
- `MODE.DRDY_FMT = 0` → level-style DRDY.
- `MODE.RX_CRC_EN = 0` (v1) → do not require input CRC.

Notes:
- **Output CRC is always present** at end of each output frame; v1 ignores it.

### 2) CLOCK (if applicable)
- Select clock source and rate per the board plan.
- If using `CLKIN`, confirm the SoC clocking meets datasheet jitter/spec.

### 3) Channel enables + gains
- Enable channels 0..7.
- Set gain per analog front-end plan (keep conservative for bring-up).

### 4) Verify configuration (readback)
- Read back MODE/CLOCK/CHx config registers and log them.

## Start continuous data
Two common patterns exist; v1 assumes the **NULL-command streaming** pattern.

### Pattern A (v1): NULL-command streaming
1) Issue the required command to enter continuous conversion / data mode (per datasheet).
2) For each conversion period, clock a full **10-word frame** while sending:
   - Word0: **NULL command**
   - Word1: `0` (no input CRC)
   - Word2..9: `0`
3) Capture DOUT:
   - Word0: response (for NULL, this is effectively STATUS)
   - Word1..8: CH0..CH7 conversion words
   - Word9: output CRC (ignore)

### Pattern B: Explicit read-data command (not preferred for v1)
If the chosen ADS131M08 mode requires explicit `RDATA` commands, document the exact framing and ensure the RTL emulator/testbench matches.

## Error handling (v1 minimum)
- If DRDY stalls or frames are corrupted, re-run reset + init.
- Log STATUS words periodically for debug.

## TODO (must close before tapeout)
- [ ] Confirm the exact `MODE.WLENGTH` encoding that yields sign-extended 32-bit conversion words and lock it in this doc (include the literal bitfield value).
- [ ] Capture a golden logic-analyzer trace: CS/SCLK/DRDY/MISO during steady-state streaming.
