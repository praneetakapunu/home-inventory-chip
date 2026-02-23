# Bring-up Sequence (v1)

This document is the **firmware bring-up checklist** for the v1 digital block in the Caravel / OpenMPW harness.

Goal: if firmware can complete this sequence, we have high confidence that:
- the Wishbone slave is decoded correctly,
- the wrapper wiring is correct,
- basic control/status is sane,
- the ADC surface (snapshot + optional FIFO) is reachable.

Source-of-truth register map: `spec/regmap_v1.yaml` / `spec/regmap.md`.

## Assumptions
- Bus: Wishbone slave, 32-bit data.
- Addressing: Wishbone address is **byte addressed**, but the block decodes **word-aligned** registers (ignore `adr[1:0]`).
- Writes must respect byte enables (SEL).

## Step 0 — Power-on sanity
- Ensure the CPU can do **aligned 32-bit reads/writes** to the user project Wishbone window.
- Ensure no caching is interfering (MMIO region should be strongly ordered / uncached).

## Step 1 — Read ID and VERSION (must match)
Read:
- `ID` @ `0x0000_0000` → expect ASCII tag `"HICH"` (`0x4849_4348`) until changed.
- `VERSION` @ `0x0000_0004` → expect `0x0000_0001` for v1.

If either value is wrong:
- suspect wrapper wiring (Wishbone signals), address decode base, or a mismatched RTL build.

## Step 2 — Baseline STATUS
Read:
- `STATUS` @ `0x0000_0108`

Record the raw value in logs. For early silicon, **any stable, non-bus-error read** is a good sign.

## Step 3 — Enable the core
Write:
- `CTRL.ENABLE = 1` @ `0x0000_0100`

Then read back `CTRL`.

Notes:
- `CTRL.START` is **write-1-to-pulse** and must read back as 0.
- Reserved bits must read as 0.

## Step 4 — Issue START pulse (optional)
Write:
- `CTRL.START = 1` @ `0x0000_0100`

Then read:
- `STATUS` @ `0x0000_0108`

Expected behavior is design-dependent; for bring-up we mainly care that:
- the write does not hang,
- `STATUS` changes deterministically (or stays stable) across repeated runs.

## Step 5 — Configure ADC surface (bring-up)
If the ADC is present on the board, firmware should also follow the ADS131M08 init checklist:
- `fw/ADS131M08_INIT_SEQUENCE.md`

Write:
- `ADC_CFG.NUM_CH = 8` (or the expected populated channel count) @ `0x0000_0200`

Then read back `ADC_CFG` and confirm:
- only bits `[3:0]` are non-zero,
- reserved bits read back as 0.

## Step 6 — ADC snapshot path
Trigger snapshot:
- write `ADC_CMD.SNAPSHOT = 1` @ `0x0000_0204`

Then read:
- `ADC_RAW_CH0..CH7` @ `0x0000_0210 .. 0x0000_022C`

Bring-up acceptance:
- reads complete and are repeatable,
- if ADC is not yet wired, these may be 0 (that’s okay), but must not be random bus junk.

## Step 7 — FIFO path (if streaming is enabled in RTL)
Read:
- `ADC_FIFO_STATUS` @ `0x0000_0208`

If `LEVEL_WORDS > 0`, drain:
- repeatedly read `ADC_FIFO_DATA` @ `0x0000_020C` until `LEVEL_WORDS == 0`

If `OVERRUN == 1`, clear it:
- write `1` to `ADC_FIFO_STATUS.OVERRUN`

Normative packing (if streaming is enabled):
- Word0: ADC status word (or 0)
- Word1..8: CH0..CH7 raw samples

## Step 8 — Event detector surface (bring-up)
This validates that the RTL can:
- accept writes to event config/threshold registers,
- update event counters/timestamps, and
- read back per-channel state.

**Important (current RTL behavior):** until the real ADC pipeline is wired, the event detector is driven by the **ADC snapshot pulse** (not continuous sampling). Each write of `ADC_CMD.SNAPSHOT=1` produces exactly one `sample_valid` into the event detector.

### 8.1 Configure thresholds + enable
Write:
- `EVT_CFG.EVT_EN = 0xFF` @ `0x0000_0444` (enable all channels)
- `EVT_THRESH_CHx` @ `0x0000_0480 .. 0x0000_049C`

For the current stubbed sample pattern (see `rtl/home_inventory_wb.v`):
- `ts_now` increments by 1 per snapshot.
- `sample_chN = 0x0000_1000 + ts_now + N`.

So, a simple deterministic test is:
- set all thresholds to `0x0000_1000` and confirm **every snapshot increments every channel**, or
- set thresholds to `0x0000_1000 + 100` and confirm **no events for the first 100 snapshots**, then events start.

### 8.2 Trigger a few snapshots and confirm state updates
Perform 2–3 snapshots (Step 6), then read:
- `EVT_COUNT_CH0..CH7` @ `0x0000_0400 .. 0x0000_041C`
- `EVT_LAST_TS` @ `0x0000_0440`
- `EVT_LAST_TS_CH0..CH7` @ `0x0000_0448 .. 0x0000_0464`
- `EVT_LAST_DELTA_CH0..CH7` @ `0x0000_0420 .. 0x0000_043C`

Bring-up acceptance:
- counters increment monotonically (saturating at 0xFFFF_FFFF),
- `EVT_LAST_TS` tracks the most recent snapshot in which any enabled channel hit,
- per-channel `LAST_DELTA` is 0 for the first event after enable, then matches the delta between snapshots that hit.

## Logging requirements
When running bring-up on real silicon, always log:
- raw reads of ID/VERSION/STATUS
- the exact addresses used
- the number of snapshot reads performed
- FIFO level/overrun occurrences

## Minimal pseudocode
```c
uint32_t mmio_read(uint32_t addr);
void     mmio_write(uint32_t addr, uint32_t data);

#define REG_ID            0x00000000
#define REG_VERSION       0x00000004
#define REG_CTRL          0x00000100
#define REG_STATUS        0x00000108
#define REG_ADC_CFG       0x00000200
#define REG_ADC_CMD       0x00000204
#define REG_ADC_FIFO_ST   0x00000208
#define REG_ADC_FIFO_DATA 0x0000020C
#define REG_ADC_RAW_CH0     0x00000210

#define REG_EVT_CFG         0x00000444
#define REG_EVT_THRESH_CH0  0x00000480
#define REG_EVT_COUNT_CH0   0x00000400
#define REG_EVT_LAST_TS     0x00000440

void bringup(void) {
  uint32_t id = mmio_read(REG_ID);
  uint32_t v  = mmio_read(REG_VERSION);

  // enable
  mmio_write(REG_CTRL, 1u << 0);

  // snapshot
  mmio_write(REG_ADC_CFG, 8u);

  // event detector: enable all channels + low threshold so every snapshot hits
  mmio_write(REG_EVT_CFG, 0x000000FFu);
  for (int ch = 0; ch < 8; ch++) {
    mmio_write(REG_EVT_THRESH_CH0 + 4u*ch, 0x00001000u);
  }

  // take a few snapshots
  for (int i = 0; i < 3; i++) {
    mmio_write(REG_ADC_CMD, 1u);
    for (int ch = 0; ch < 8; ch++) {
      (void)mmio_read(REG_ADC_RAW_CH0 + 4u*ch);
      (void)mmio_read(REG_EVT_COUNT_CH0 + 4u*ch);
    }
    (void)mmio_read(REG_EVT_LAST_TS);
  }
}
```
