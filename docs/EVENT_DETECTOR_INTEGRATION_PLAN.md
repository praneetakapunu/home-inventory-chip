# Event Detector Integration Plan (v1)

Goal: integrate `rtl/home_inventory_event_detector.v` into the *real* sample stream so firmware can enable event detection, read counters/history, and clear state via the Wishbone regfile.

This plan is intentionally specific enough that wiring can be landed as a small, reviewable change in the harness/IP repos.

## What already exists

- RTL module: `rtl/home_inventory_event_detector.v`
- Wishbone reg block instantiates it today:
  - `rtl/home_inventory_wb.v` instantiates `home_inventory_event_detector` as `u_evt`
  - Today it is driven by a **stub** sample source:
    - `sample_valid` = `ADC_CMD.SNAPSHOT` pulse
    - `sample_ch*` = deterministic pattern (same values as `ADC_RAW_CH*`)
    - `ts_now` = `TIME_NOW` free-running counter in Wishbone clock domain
- Readback registers already exist in regmap (see `spec/regmap.md` / `spec/regmap_v1.yaml`):
  - `EVT_COUNT_CH0..7`
  - `EVT_LAST_DELTA_CH0..7`
  - `EVT_LAST_TS` + per-channel `EVT_LAST_TS_CHx`
- Control registers already exist:
  - `EVT_CFG.EVT_EN[7:0]` (RW)
  - `EVT_CFG.CLEAR_COUNTS` (W1P, bit 8)
  - `EVT_CFG.CLEAR_HISTORY` (W1P, bit 9)
  - `EVT_THRESH_CH0..7` (RW)

So: *firmware-visible contract is already in place*; the missing piece is wiring the detector to the real ADC stream.

## Integration targets

### Clock / reset domain

- Keep the event detector in the **Wishbone clock domain** (`wb_clk_i`) for v1.
  - Rationale: registers and clear pulses are already synchronous to `wb_clk_i`.
  - If ADC capture is in another clock domain, add an explicit CDC boundary.

### Timestamp source (`ts_now`)

Current: `r_time_now` free-running counter in `home_inventory_wb`.

v1 proposal:
- Continue using `r_time_now` as `ts_now`.
- Define it as: “number of Wishbone clock cycles since reset deassertion (wraps mod 2^32).”

Notes:
- If/when ADC sample cadence is not 1:1 with Wishbone clock, timestamps are still valid as a *monotonic* timebase.
- Later: optionally add an ADC-synchronous timestamp (frame counter) as a separate field.

### Sample sources (`sample_ch0..7`, `sample_valid`)

The event detector expects 8 parallel 32-bit channel samples plus a `sample_valid` strobe.

v1 wiring choice (recommended): drive from **ADC frame capture** at the moment a full frame is available.

Define a single internal strobe:
- `adc_frame_valid` : 1-cycle pulse when a complete ADS131M08 frame has been captured and unpacked into 8 channel words.

Define 8 sample wires:
- `adc_frame_ch0..adc_frame_ch7` : **32-bit sign-extended** samples derived from the ADS131M08 24-bit channel words.

**Exact mapping (ADS131M08 framing assumption, v1):**
- Wire-level ADS131M08 frames are 10 words (last word = OUTPUT_CRC).
  For v1, we **drop OUTPUT_CRC** and treat the internal "frame" as 9 words: STATUS + CH0..CH7.

- ADC capture produces a packed vector `frame_words_packed` from `adc_spi_frame_capture`.
- For ADS131M08 bring-up, instantiate capture with:
  - `BITS_PER_WORD = 32` (sign-extended samples on the wire)
  - `WORDS_PER_FRAME = 10` (STATUS + CH0..CH7 + OUTPUT_CRC)
- Word indices (captured):
  - word[0] = STATUS (ignored by event detector for v1)
  - word[1] = CH0
  - word[2] = CH1
  - ...
  - word[8] = CH7
  - word[9] = OUTPUT_CRC (dropped)

Unpack to channels as:
- If capture uses `BITS_PER_WORD=32` (ADS131M08 WLENGTH=32b sign-extend):
  - `adc_frame_chN = word[N+1]`
- If capture uses 24-bit words (older DV mode):
  - `adc_frame_chN = {{8{word[N+1][23]}}, word[N+1][23:0]}` (two’s complement sign-extension to 32b)

Then:
- `evt_sample_valid <= adc_frame_valid`
- `evt_sample_ch*  <= adc_frame_ch*`

**Data format decision (v1):**
- Use **sign-extended 32-bit** samples in two’s complement.
- Threshold compare uses the same numeric domain.

Future (not v1): add a small selection mux so the event detector can choose among multiple sources:
- raw ADC channels (as above)
- filtered/decimated channels
- DV-only synthetic sources (ramp/PRBS), behind a synthesis guard

If we *cannot* produce a full frame strobe early:
- Alternative is to trigger `sample_valid` once per channel update, but that breaks “simultaneous” semantics and complicates deltas.
- Avoid for v1.

## Where to place the wiring

### In IP repo (`chip-inventory`)

Short-term (v1): keep event detector instantiated inside `home_inventory_wb.v`.

**Concrete code hook (current state):**
- `rtl/home_inventory_wb.v` currently drives the event detector via these stub wires:
  - `evt_sample_valid = adc_snapshot_fire` (i.e. `ADC_CMD.SNAPSHOT`)
  - `evt_sample_ch0..7 = 0x0000_1000 + snapshot_count + channel_index`
  - `evt_ts_now = r_time_now`

**Change needed (v1 integration target):**
1) Replace the stub `evt_sample_valid` and `evt_sample_ch*` with real ADC frame samples.
2) Keep `evt_ts_now = r_time_now` (Wishbone-domain monotonic timestamp) for v1.

### Mechanical wiring checklist (for the eventual RTL change)

This is the “do it without thinking” list for the commit that flips the detector from stub → real samples.

Target files (expected):
- `rtl/home_inventory_wb.v` (remove stub, drive `u_evt` from ADC frame)
- `rtl/adc/adc_spi_frame_capture.v` (already exists)
- `rtl/adc/adc_drdy_sync.v` (already exists)
- `rtl/adc/adc_stream_fifo.v` (already exists; optional for event-detector path)
- Harness filelists as needed (in `home-inventory-chip-openmpw`)

Signals to create (naming suggestion, keep consistent):
- `wire        adc_frame_valid;` — 1-cycle pulse when a complete frame has been captured
- `wire [31:0] adc_frame_ch0;` .. `adc_frame_ch7;` — sign-extended samples

Stub removal steps (inside `home_inventory_wb.v`):
1) Delete/disable the deterministic pattern generator used for `evt_sample_ch*`.
2) Replace:
   - `evt_sample_valid = adc_snapshot_fire` → `evt_sample_valid = adc_frame_valid`
   - `evt_sample_ch*` pattern → `evt_sample_ch* = adc_frame_ch*`
3) Keep `evt_ts_now = r_time_now`.

DV hook (so we don’t lose testability when the stub disappears):
- Add a DV-only mode (guarded by `ifdef SIM`) that lets the testbench inject a synthetic `adc_frame_valid` + 8 sample words (bypassing SPI).

Concrete SIM override implemented (no regmap changes):
- In `rtl/home_inventory_wb.v` (guarded by `ifdef SIM`), the testbench may `force` these wires:
  - `sim_evt_override_en` (set to 1 to select SIM path)
  - `sim_evt_sample_valid` (1-cycle pulse)
  - `sim_evt_sample_ch0..7` (32-bit signed samples)
  - Goal: keep `verify/wb_tb.v` able to trigger a known event without modeling the real ADC.

This implies `home_inventory_wb.v` must see the decoded ADC frame signals. Two options:
- Option A (preferred): instantiate ADC capture + unpack inside `home_inventory_wb.v` (still in wb clock domain) and produce:
  - `adc_frame_valid` (1-cycle pulse when a complete frame is ready)
  - `adc_frame_ch0..7` (sign-extended 32-bit samples)
- Option B: instantiate ADC logic in `home_inventory_top.v` and pass the decoded frame into `home_inventory_wb` ports.

Given `home_inventory_top.v` is currently a placeholder and the harness expects `home_inventory_wb` as DUT, **Option A** keeps integration smallest.

**Important:** keep the `EVT_*` register semantics stable while swapping the sample source. `verify/wb_tb.v` already exercises the enable/clear semantics via the current stub; after real wiring lands, we should update/add a directed test that injects a synthetic frame into the capture/unpack path (or uses a DV-friendly ADC model) so event behavior remains testable without silicon.

### In harness repo (`home-inventory-chip-openmpw`)

- Ensure the harness connects the physical ADC pins to the DUT module (if/when DUT exposes them).
- Ensure build rules include any new RTL files added under `rtl/adc/` (filelist updates).

## Register semantics (confirm / lock)

These are the semantics firmware will rely on:

- `EVT_CFG.EVT_EN[7:0]`:
  - Per-channel enable mask.
  - If a bit is 0: the channel does **not** generate events; its counters/history should not change.

- `EVT_THRESH_CHx`:
  - Threshold used by the event detector for that channel.
  - Units: same numeric units as `sample_chx` (sign-extended sample codes).

- `EVT_CFG.CLEAR_COUNTS` (W1P):
  - Clears all `EVT_COUNT_CHx` counters.
  - Does **not** clear timestamps/deltas (history is unaffected).
  - Does **not** clear thresholds or enable bits.

- `EVT_CFG.CLEAR_HISTORY` (W1P):
  - Clears per-channel timestamp history.
  - Clears **global** `EVT_LAST_TS`.
  - Clears per-channel `EVT_LAST_TS_CHx`.
  - Clears `EVT_LAST_DELTA_CHx` to 0.

- Readbacks:
  - `EVT_COUNT_CHx` increments once per detected event.
  - `EVT_LAST_DELTA_CHx` holds the last observed delta that triggered (or last computed delta).
  - `EVT_LAST_TS` holds timestamp of last event across all channels.
  - `EVT_LAST_TS_CHx` holds last event timestamp for that channel.

If any of the above is not true in `home_inventory_event_detector.v`, update RTL or this doc before harness integration.

## CDC / reset notes

- If ADC capture logic runs off a separate clock (e.g., `adc_sck` derived), provide a clean crossing into `wb_clk_i`:
  - Preferred: capture full frame into a small async FIFO (frame-level), pop into wb domain.
  - Minimal: use a toggle + synchronizer for `frame_valid` plus stable sample registers with handshake.

For v1, aim to keep capture in wb domain to avoid extra CDC complexity.

## Done-when checklist

Consider the event detector “integrated” when:

1) RTL: `home_inventory_wb.v` drives `u_evt` from **real** ADC frame samples (not the SNAPSHOT stub).
2) DV: one directed sim test proves:
   - enabling a channel causes `EVT_COUNT_CHx` to increment on a synthetic sample step crossing threshold
   - `CLEAR_COUNTS` clears the counters
   - `CLEAR_HISTORY` clears history/ts state
3) Harness: `make rtl-compile-check` passes after the wiring + filelist changes.

4) Doc hygiene: this plan is updated with the *exact* word→channel mapping and sign-extension rule (so the eventual wiring commit is purely mechanical).

