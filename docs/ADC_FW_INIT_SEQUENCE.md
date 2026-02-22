# ADC Firmware Init & Bring-up Sequence (v1)

This document is the **firmware-side** bring-up sequence for the v1 ADC path.
It is intentionally pragmatic: it tells you what to do first to see sane samples.

Related specs:
- ADC chip interface assumptions: `spec/ads131m08_interface.md`
- Register map: `spec/regmap.md` (source-of-truth: `spec/regmap_v1.yaml`)

## Goals (v1)
1) Prove we can talk to the Wishbone register block (ID/VERSION).
2) Prove the ADC streaming FIFO path works end-to-end (capture → FIFO → drain).
3) Provide a repeatable sequence that avoids common ADS131M08 “first data after pause” gotchas.

## Terminology
- **SoC**: Caravel user project / our RTL block
- **ADC**: TI ADS131M08 on the board
- **Frame**: one ADC conversion packet captured by RTL
  - In v1 we push **9 words** into FIFO per frame: `STATUS_WORD` + `CH0..CH7`.

## Preconditions (hardware)
- ADC has power.
- The board provides the ADC clocking expected by the design (see TODO in `spec/ads131m08_interface.md`).
- `adc_rst_n` is controllable (preferred) or at least well-behaved at power-up.

## Firmware sequence (recommended)

### 0) Basic sanity: ID/VERSION
1) Read `ID` @ `0x0000_0000` → expect ASCII tag (currently `"HICH"`).
2) Read `VERSION` @ `0x0000_0004` → expect `0x1` for regmap v1.

If either read is wrong, stop and debug bus/harness before touching ADC.

### 1) Configure channel count (enumeration only)
Write `ADC_CFG.NUM_CH` @ `0x0000_0200`.
- Set to the number of physically populated channels (1–8).
- This value is used for firmware-side loops and reporting.

### 2) Enable the core
Write `CTRL.ENABLE=1` @ `0x0000_0100`.

### 3) Clear any stale FIFO/overrun state
The FIFO status is visible in `ADC_FIFO_STATUS` @ `0x0000_0208`:
- `LEVEL_WORDS[15:0]`: number of 32-bit words currently in FIFO
- `OVERRUN[16]`: sticky; W1C

Do:
1) If `OVERRUN=1`, clear it by writing `1` to bit 16.
2) Drain any existing FIFO words by reading `ADC_FIFO_DATA` until `LEVEL_WORDS==0`.

Notes:
- Draining is safe even during early bring-up. It makes later checks unambiguous.
- For v1, the FIFO depth and exact watermark behavior are RTL-defined; firmware must handle non-zero level at any time.

### 4) ADS131M08 first-data precaution (important)
The ADS131M08 can retain two samples/channel internally if data weren’t read for a while.
Result: DRDY/STATUS behavior can be confusing on the first read.

Recommended v1 approach:
- After reset / any long pause, **discard the first two captured frames** before trusting steady-state.

(See `spec/ads131m08_interface.md` for rationale.)

### 5) Start capture (v1 generic)
The v1 register map includes `CTRL.START` (write-1-to-pulse) @ `0x0000_0100`.

Write `CTRL.START=1` once.
- This is a *pulse* request; reads return 0.

Expectation:
- If the ADC SPI capture path is active, frames begin appearing in the FIFO.

### 6) Drain frames + validate packing
Each captured frame contributes **9 FIFO words**, in order:
1) `STATUS_WORD`
2) `CH0`
3) `CH1`
4) `CH2`
5) `CH3`
6) `CH4`
7) `CH5`
8) `CH6`
9) `CH7`

Suggested smoke test:
1) Wait until `LEVEL_WORDS >= 18` (at least two frames buffered).
2) Read 18 words.
3) Discard the first 18 words (two frames) per the “first-data precaution”.
4) For subsequent frames:
   - Check that `STATUS_WORD` changes at the expected rate.
   - Check that channel words look like signed values (not all 0 / not stuck at a single code).

### 7) Snapshot path (optional bring-up)
The regmap also provides a snapshot mechanism:
- Write `ADC_CMD.SNAPSHOT=1` @ `0x0000_0204`
- Then read `ADC_RAW_CH0..CH7` @ `0x0000_0210..0x0000_022C`

Use this when you want a quick “single capture” sanity check without FIFO draining loops.

## Minimal bring-up pseudocode (C-like)
This snippet is deliberately boring: it’s meant to be copy/paste-able into whatever bare-metal harness you’re using.

```c
// Base address: depends on harness integration.
#define HIP_BASE            0x30000000u

#define REG_ID              0x0000u
#define REG_VERSION         0x0004u

#define REG_CTRL            0x0100u
#define   CTRL_ENABLE       (1u << 0)
#define   CTRL_START        (1u << 1)   // W1P

#define REG_ADC_CFG         0x0200u
#define REG_ADC_CMD         0x0204u
#define   ADC_CMD_SNAPSHOT  (1u << 0)   // W1P

#define REG_FIFO_STATUS     0x0208u
#define   FIFO_LEVEL_MASK   0xFFFFu
#define   FIFO_OVERRUN      (1u << 16)  // W1C

#define REG_FIFO_DATA       0x020Cu

static inline uint32_t rd(uint32_t off) { return mmio_read32(HIP_BASE + off); }
static inline void     wr(uint32_t off, uint32_t v) { mmio_write32(HIP_BASE + off, v); }

static void fifo_drain_all(void) {
  while ((rd(REG_FIFO_STATUS) & FIFO_LEVEL_MASK) != 0) {
    (void)rd(REG_FIFO_DATA);
  }
}

void adc_bringup(void) {
  // 0) ID/VERSION sanity
  uint32_t id = rd(REG_ID);
  uint32_t ver = rd(REG_VERSION);
  // Expect "HICH" in ASCII for id (endianness depends on your printing).
  // Expect ver == 1.

  // 1) Enumerate how many channels you expect populated
  wr(REG_ADC_CFG, 8);

  // 2) Enable core
  wr(REG_CTRL, CTRL_ENABLE);

  // 3) Clear sticky + drain
  if (rd(REG_FIFO_STATUS) & FIFO_OVERRUN) {
    wr(REG_FIFO_STATUS, FIFO_OVERRUN); // W1C
  }
  fifo_drain_all();

  // 5) Start capture
  wr(REG_CTRL, CTRL_START);

  // 6) First-data precaution: discard 2 frames (2 * 9 words)
  for (int i = 0; i < 18; i++) {
    while ((rd(REG_FIFO_STATUS) & FIFO_LEVEL_MASK) == 0) {}
    (void)rd(REG_FIFO_DATA);
  }

  // 6) Now consume frames normally
  while (1) {
    // Wait for one full frame buffered
    while ((rd(REG_FIFO_STATUS) & FIFO_LEVEL_MASK) < 9) {}

    uint32_t status = rd(REG_FIFO_DATA);
    int32_t ch[8];
    for (int k = 0; k < 8; k++) ch[k] = (int32_t)rd(REG_FIFO_DATA);

    // TODO: print/log status + ch[]
    (void)status; (void)ch;
  }
}
```

Notes:
- Treat channel samples as **signed** (`int32_t`). With `WLENGTH=11b`, the ADC data are already sign-extended by the ADS131M08.
- If you see `FIFO_OVERRUN`, don’t trust gaps in the stream: drain + clear + restart capture.

## Error handling / debug checklist
- `ADC_FIFO_STATUS.OVERRUN=1`:
  - Drain faster; increase poll rate; reduce ADC output rate; consider enlarging FIFO (RTL change).
- FIFO `LEVEL_WORDS` never increases after `CTRL.START`:
  - Check `CTRL.ENABLE`.
  - Confirm ADC clocking and DRDY toggling on the board.
  - Confirm SPI mode/word length expectations match `spec/ads131m08_interface.md`.
- Channel samples look byte-swapped or misaligned:
  - Likely word-length/packing mismatch (24 vs 32-bit mode); confirm WLENGTH choice.

## ADS131M08 register bit policy (v1)
These are the ADS131M08-side bit choices we are standardizing on for v1 bring-up:
- `MODE.WLENGTH[1:0] = 11b` → **32-bit words with sign-extension** for 24-bit ADC conversion data
- `MODE.RX_CRC_EN = 0` → **no input CRC**
- `MODE.DRDY_FMT = 0` → **level-style DRDY** (avoid pulse gotchas)
- Output CRC word is always present on DOUT; v1 RTL streaming **drops** it.

The high-level policy is tracked in:
- `decisions/009-ads131m08-word-length-and-crc.md`

## Open items (must be resolved before tapeout)
- Confirm ADC clocking plan on the harness/PCB (`CLKIN` source) — tracked in `spec/ads131m08_interface.md`.
