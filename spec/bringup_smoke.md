# Bring-up smoke test (v1)

This is a **minimal, deterministic** register-level bring-up sequence for the v1 design.

Goals:
- validate Wishbone access + address decode
- validate W1P/W1C semantics
- validate ADC snapshot path (stub or real ADC ingest)
- provide a checklist DV + firmware can both follow

Source-of-truth for addresses/fields is `spec/regmap_v1.yaml`.

## Preconditions

- Wishbone master can perform 32-bit reads/writes.
- For writes, master can control byte-enables (`wbs_sel_i[3:0]`).
- Use **full-word writes** (`sel=0b1111`) unless explicitly testing byte-lane masking.

## Address map quick reference

All addresses are **byte addresses**.

- `ID`               = `0x0000_0000`
- `VERSION`          = `0x0000_0004`

- `CTRL`             = `0x0000_0100`
- `IRQ_EN`           = `0x0000_0104`
- `STATUS`           = `0x0000_0108`
- `TIME_NOW`         = `0x0000_010C`

- `ADC_CFG`          = `0x0000_0200`
- `ADC_CMD`          = `0x0000_0204`
- `ADC_FIFO_STATUS`  = `0x0000_0208`
- `ADC_FIFO_DATA`    = `0x0000_020C`
- `ADC_RAW_CH0..7`   = `0x0000_0210` + `4*ch`
- `ADC_SNAPSHOT_COUNT` = `0x0000_0230`

## Step-by-step

### 1) Basic ID/version sanity

1. Read `ID`.
   - Expect fixed ASCII tag (current RTL: `0x4849_4348` = "HICH").
2. Read `VERSION`.
   - Expect `0x0000_0001` for v1.

If either fails, stop: this indicates either bus wiring or address decode mismatch.

### 2) W1P semantics (CTRL.START)

1. Read `CTRL`.
   - Expect `START` bit reads as 0.
2. Write `CTRL.ENABLE=1` (bit 0 = 1).
3. Write `CTRL.START=1` (bit 1 = 1) with `sel=0b1111`.
4. Immediately read back `CTRL`.
   - Expect `START` reads as 0 (W1P).
   - Expect `ENABLE` remains 1.

Notes:
- This does not require the downstream core to fully function; it validates the register semantics.

### 3) TIME_NOW monotonicity

1. Read `TIME_NOW` twice with a small delay.
2. Expect `TIME_NOW_2 != TIME_NOW_1` and generally increases (wrap allowed).

### 4) ADC snapshot basic path

1. Read `ADC_SNAPSHOT_COUNT` -> `n0`.
2. Write `ADC_CMD.SNAPSHOT=1`.
3. Read `ADC_SNAPSHOT_COUNT` -> `n1`.
   - Expect `n1 = n0 + 1`.

4. For channels `0..NUM_CH-1`:
   - Read `ADC_RAW_CHx`.
   - In **stub** mode, values may be static, patterned, or 0.
   - In **real ADC ingest** mode, values should change over time.

5. Optional: read `ADC_FIFO_STATUS`.
   - If real ingest is enabled, `LEVEL_WORDS` may be non-zero during/after capture.
   - `CAPTURE_BUSY` indicates the ingest block is active (0 in stub mode).

### 5) FIFO pop semantics (if `LEVEL_WORDS != 0`)

1. Read `ADC_FIFO_STATUS.LEVEL_WORDS` -> `L0`.
2. Read `ADC_FIFO_DATA` once.
3. Read `ADC_FIFO_STATUS.LEVEL_WORDS` -> `L1`.
   - Expect `L1 = max(L0-1, 0)`.

If `LEVEL_WORDS == 0`, reads of `ADC_FIFO_DATA` must return 0 and not change state.

### 6) W1C semantics (ADC_FIFO_STATUS.OVERRUN)

This is easiest to validate when the FIFO can overflow.

1. Induce an overrun (design-specific).
2. Read `ADC_FIFO_STATUS` and confirm `OVERRUN=1`.
3. Clear with a full-word write of bit 16 = 1.
4. Re-read and confirm `OVERRUN=0`.

Byte-lane masking rule:
- clearing via W1C only applies to bits covered by asserted byte lanes in `sel`.
- firmware should prefer `sel=0b1111` for sticky-bit clears.

## Expected outputs to capture

For each run, capture:
- ID, VERSION
- CTRL writes + readbacks
- TIME_NOW samples
- ADC_SNAPSHOT_COUNT before/after
- ADC_RAW_CH0..7 snapshot
- ADC_FIFO_STATUS + a few FIFO_DATA pops (if applicable)

These logs are sufficient to triage most bring-up issues quickly.
