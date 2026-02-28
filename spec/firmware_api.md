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
  uint32_t status;
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

Registers (selected):
- `EVT_CFG` @ `0x0000_0444` bit[7:0] `EVT_EN`
- `EVT_THRESH_CHx` @ `0x0000_0480 + 4*x`

Enable rule:
- Transition `EVT_EN[x]` from 0→1 clears that channel’s timestamp history; the first event after enabling will report `EVT_LAST_DELTA_CHx = 0`.

## Reserved bits and unknown addresses

- Firmware must treat reserved bits as read-as-0 / write-ignored.
- Firmware should not rely on reads from unknown/unimplemented addresses; RTL must return 0.
