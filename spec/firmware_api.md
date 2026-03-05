# Firmware API (Wishbone) — v1

This document defines **how firmware should talk to the v1 register map** over Caravel’s Wishbone bus.

Source-of-truth for addresses/fields: `spec/regmap_v1.yaml` (and the human-readable summary in `spec/regmap.md`).

## Conventions

- **Bus**: Wishbone slave, 32-bit data.
- **Addressing**: Caravel provides a **byte address** on `wbs_adr_i`.
  - All registers are **32-bit word-aligned**; firmware must use 32-bit accesses.
  - RTL ignores `wbs_adr_i[1:0]`.
- **Endianness**: byte lanes follow little-endian Wishbone convention.
- **Writes must honor byte-enables** (`wbs_sel_i[3:0]`).

## Reference C snippets (drop-in)

These are **illustrative** and intended to make bring-up firmware less error-prone.
They assume you have a memory-mapped Wishbone window (e.g. via Caravel house-keeping SPI loader or a CPU).

```c
#include <stdint.h>
#include <stdbool.h>

// Base of this block in your SoC address space.
// (Project-specific: set this to your Wishbone bridge mapping.)
#ifndef HICH_WB_BASE
#define HICH_WB_BASE (0x00000000u)
#endif

static inline void wb_write32(uint32_t byte_addr, uint32_t data) {
  volatile uint32_t *p = (volatile uint32_t *)(HICH_WB_BASE + byte_addr);
  *p = data;
}

static inline uint32_t wb_read32(uint32_t byte_addr) {
  volatile uint32_t *p = (volatile uint32_t *)(HICH_WB_BASE + byte_addr);
  return *p;
}

// Addresses (byte addresses). Keep in sync with spec/regmap_v1.yaml.
enum {
  ADR_ID               = 0x00000000u,
  ADR_VERSION          = 0x00000004u,
  ADR_CTRL             = 0x00000100u,
  ADR_TIME_NOW         = 0x0000010Cu,
  ADR_ADC_CFG          = 0x00000200u,
  ADR_ADC_CMD          = 0x00000204u,
  ADR_ADC_FIFO_STATUS  = 0x00000208u,
  ADR_ADC_FIFO_DATA    = 0x0000020Cu,
  ADR_ADC_RAW_CH0      = 0x00000210u,
  ADR_ADC_SNAPSHOT_CNT = 0x00000230u,
  ADR_EVT_CFG          = 0x00000444u,
  ADR_EVT_THRESH_CH0   = 0x00000480u,
};

// Bit helpers
#define BIT(x) (1u << (x))

// CTRL
#define CTRL_ENABLE  BIT(0)
#define CTRL_START   BIT(1)  // W1P

// ADC_CMD
#define ADC_CMD_SNAPSHOT BIT(0)  // W1P

// ADC_FIFO_STATUS
#define ADC_FIFO_LEVEL_MASK   (0xFFFFu)
#define ADC_FIFO_OVERRUN_BIT  (16u)
#define ADC_FIFO_OVERRUN      BIT(ADC_FIFO_OVERRUN_BIT) // W1C

// EVT_CFG
#define EVT_CFG_CLEAR_COUNTS  BIT(8)  // W1P
#define EVT_CFG_CLEAR_HISTORY BIT(9)  // W1P

static inline uint32_t adc_raw_addr(uint32_t ch) {
  return ADR_ADC_RAW_CH0 + 4u * ch;
}

static inline uint32_t evt_thresh_addr(uint32_t ch) {
  return ADR_EVT_THRESH_CH0 + 4u * ch;
}
```

### Read/modify/write recommendation

When updating a multi-bit field in a RW register:
1) Read full 32-bit word
2) Modify bits in software
3) Write full 32-bit word with `sel = 0b1111`

This avoids surprises with partial writes and reserved bits.

### Special bit types

- **W1P** (write-1-to-pulse): writing a `1` triggers a **one-cycle** internal pulse; the stored value reads back as `0`.
- **W1C** (write-1-to-clear): writing a `1` clears a sticky bit. Only bits in selected byte lanes participate.

## Bring-up smoke sequence (minimal)

A minimal “is the peripheral alive?” sequence:

1) Read `ID` @ `0x0000_0000` and confirm ASCII tag.
2) Read `VERSION` @ `0x0000_0004` and confirm `>= 1`.
3) Read `TIME_NOW` twice and confirm it changes.

If any of these fail, stop and verify Wishbone connectivity in the harness.

## Core control

Registers:
- `CTRL` @ `0x0000_0100`
  - bit0 `ENABLE` (RW)
  - bit1 `START` (W1P)

### Enable + start

Recommended sequence:

1) Set `CTRL.ENABLE = 1` (write full word)
2) Pulse `CTRL.START = 1` (write with only bit1 = 1)

Notes:
- Writing `START=1` **must not** disturb `ENABLE`; firmware should write a value that preserves bit0.
  - Example: if `ENABLE` is already 1, write `CTRL = (1<<0) | (1<<1)`.

## ADC snapshot mode (bring-up)

Registers:
- `ADC_CMD` @ `0x0000_0204` bit0 `SNAPSHOT` (W1P)
- `ADC_RAW_CHx` @ `0x0000_0210 + 4*x` (RO)
- `ADC_SNAPSHOT_COUNT` @ `0x0000_0230` (RO)

Sequence:

1) (Optional) read `ADC_SNAPSHOT_COUNT` (call it N0)
2) Pulse `ADC_CMD.SNAPSHOT = 1`
3) Read back `ADC_SNAPSHOT_COUNT` until it increments (N0+1) or a timeout elapses
4) Read `ADC_RAW_CH0..ADC_RAW_CH(N-1)` where N = `ADC_CFG.NUM_CH`

Timeout guidance:
- In simulation: a few dozen cycles is enough.
- On silicon: use a conservative loop with a software counter.

## ADC streaming FIFO mode (preferred)

### Read one complete frame (9 words) helper

```c
typedef struct {
  uint32_t status;  // Opaque v1 payload; see docs/ADC_STATUS_WORD_POLICY.md
  uint32_t ch[8];
} adc_frame_t;

// Returns true on success; false on timeout.
static inline bool adc_read_frame(adc_frame_t *out, uint32_t timeout_iters) {
  while (timeout_iters--) {
    uint32_t st = wb_read32(ADR_ADC_FIFO_STATUS);
    uint32_t level = st & ADC_FIFO_LEVEL_MASK;
    if (level >= 9u) break;
  }
  if ((wb_read32(ADR_ADC_FIFO_STATUS) & ADC_FIFO_LEVEL_MASK) < 9u) return false;

  out->status = wb_read32(ADR_ADC_FIFO_DATA);
  for (uint32_t i = 0; i < 8u; i++) out->ch[i] = wb_read32(ADR_ADC_FIFO_DATA);
  return true;
}
```

Registers:
- `ADC_FIFO_STATUS` @ `0x0000_0208`
  - bits[15:0] `LEVEL_WORDS` (RO)
  - bit16 `OVERRUN` (W1C)
- `ADC_FIFO_DATA` @ `0x0000_020C` (RO pop)

### Draining the FIFO

1) Read `ADC_FIFO_STATUS.LEVEL_WORDS` (L)
2) While `L != 0`:
   - Read `ADC_FIFO_DATA` once (pops one word)
   - Read `LEVEL_WORDS` again (or decrement L if firmware guarantees no producer writes during drain)

Empty-read semantics:
- Reads when empty **return 0** and **do not** change FIFO state.

### Draining exactly one ADC frame (recommended pattern)

v1 FIFO packing pushes **9 words per ADC conversion frame** in this exact order:
1) STATUS word
2) CH0
3) CH1
4) CH2
5) CH3
6) CH4
7) CH5
8) CH6
9) CH7

Firmware pattern:
1) Poll until `LEVEL_WORDS >= 9` (bounded timeout).
2) Read 9 consecutive pops from `ADC_FIFO_DATA` and interpret them as one frame.

Notes:
- Do **not** assume the FIFO level jumps to 9 in the same cycle the capture completes; the RTL push sequencer may take multiple cycles.
- If `LEVEL_WORDS` is not a multiple of 9, firmware should still drain safely but may want to resynchronize by draining until the next boundary (or by gating producer during drain in future FW).

### Clearing OVERRUN (W1C)

To clear the sticky overrun bit:
- Write `1<<16` to `ADC_FIFO_STATUS` with `sel=0b1111`.

Because W1C respects byte enables, firmware should **avoid partial-lane writes** when clearing sticky status.

## Event detector

This block is intended to let firmware cheaply detect “interesting” activity (threshold compares) without streaming every sample.
Normative register semantics: `docs/EVENT_DETECTOR_SPEC.md` + `spec/regmap_v1.yaml`.

Registers (selected):
- `EVT_CFG` @ `0x0000_0444`
  - bit[7:0] `EVT_EN` (RW)
  - bit8 `CLEAR_COUNTS` (W1P)
  - bit9 `CLEAR_HISTORY` (W1P)
- `EVT_COUNT_CHx` @ `0x0000_0400 + 4*x` (RO)
- `EVT_LAST_DELTA_CHx` @ `0x0000_0420 + 4*x` (RO)
- `EVT_LAST_TS` @ `0x0000_0440` (RO)
- `EVT_LAST_TS_CHx` @ `0x0000_0448 + 4*x` (RO)
- `EVT_THRESH_CHx` @ `0x0000_0480 + 4*x` (RW)

### Enable/clear rules (v1)

- Transition `EVT_EN[x]` from 0→1 clears that channel’s timestamp history; the first event after enabling will report `EVT_LAST_DELTA_CHx = 0`.
- `CLEAR_COUNTS` clears all `EVT_COUNT_CH0..7` (timestamps unaffected).
- `CLEAR_HISTORY` clears `EVT_LAST_TS`, `EVT_LAST_TS_CHx`, and `EVT_LAST_DELTA_CHx` (counts unaffected).

### Reference C snippet: configure + poll

```c
static inline uint32_t evt_count_addr(uint32_t ch) {
  return 0x00000400u + 4u * ch;
}
static inline uint32_t evt_last_delta_addr(uint32_t ch) {
  return 0x00000420u + 4u * ch;
}
static inline uint32_t evt_last_ts_ch_addr(uint32_t ch) {
  return 0x00000448u + 4u * ch;
}

// Configure a simple per-channel threshold and enable mask.
static inline void evt_configure(uint32_t en_mask, const int32_t thresh[8]) {
  // Program thresholds first so the enable-edge doesn’t immediately “detect” against a stale default.
  for (uint32_t ch = 0; ch < 8u; ch++) {
    wb_write32(evt_thresh_addr(ch), (uint32_t)thresh[ch]);
  }

  // Optional: clear prior state (if reconfiguring live).
  wb_write32(ADR_EVT_CFG, EVT_CFG_CLEAR_COUNTS | EVT_CFG_CLEAR_HISTORY);

  // Enable selected channels (0→1 edges clear history per-channel).
  wb_write32(ADR_EVT_CFG, (en_mask & 0xFFu));
}

// Example “poll”: detect if any channel saw an event since last time.
// (In v1 there is no IRQ; firmware can poll counts or timestamps.)
static inline bool evt_any_fired(uint32_t prev_count[8], uint32_t *fired_ch_mask) {
  uint32_t mask = 0;
  for (uint32_t ch = 0; ch < 8u; ch++) {
    uint32_t c = wb_read32(evt_count_addr(ch));
    if (c != prev_count[ch]) {
      prev_count[ch] = c;
      mask |= BIT(ch);
    }
  }
  if (fired_ch_mask) *fired_ch_mask = mask;
  return (mask != 0);
}

// When a channel fires, firmware can read:
// - EVT_LAST_DELTA_CHx: how long since last event on that channel (sample ticks)
// - EVT_LAST_TS_CHx: timestamp of last event on that channel
// - EVT_LAST_TS: timestamp of most recent event (any channel)
```

Notes:
- Prefer writing thresholds *before* setting `EVT_EN` to avoid a spurious “immediate detect” against reset threshold values.
- In v1, event semantics are level-compare (`sample >= threshold`), so if the signal stays above threshold, firmware may see counts increment every sample tick. If we need edge/crossing semantics later, we should add an `EVT_MODE` register (without moving existing addresses).

## Reserved bits and unknown addresses

- Firmware must treat reserved bits as read-as-0 / write-ignored.
- Firmware should not rely on reads from unknown/unimplemented addresses; RTL must return 0.
