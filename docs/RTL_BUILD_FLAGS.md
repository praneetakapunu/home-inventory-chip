# RTL build flags (compile-time defines)

This repo uses a **small set of Verilog compile-time defines** to control optional wiring.
The goal is to keep the default build low-risk and low-disk, while still letting us compile/verify the “real ADC ingest” path early.

## `USE_REAL_ADC_INGEST`
**Purpose:** Enable the real ADS131M08 SPI ingest path (`rtl/adc/adc_streaming_ingest.v`) and expose ADC SPI pins at the Wishbone block boundary.

### Effects
When **not** defined (default / stub mode):
- `home_inventory_wb` does **not** expose ADC SPI pins.
- `ADC_CMD.SNAPSHOT` generates a deterministic ramp pattern:
  - updates `ADC_RAW_CH0..CH7`
  - pushes one **9-word** stub frame into the FIFO (`STATUS + CH0..CH7`)

When **defined** (real ingest mode):
- `home_inventory_wb` exposes the real SPI pins:
  - `adc_sclk`, `adc_cs_n`, `adc_mosi`, `adc_miso`
- `CTRL.START` requests a capture via `adc_streaming_ingest`.
- Captured frames are mirrored into `ADC_RAW_CH0..CH7` and pushed into the FIFO.

### How to compile
Low-disk compile checks already cover both modes:

```bash
# From chip-inventory/
bash ops/rtl_compile_check.sh
```

Manual iverilog example:

```bash
iverilog -g2012 -Wall -Irtl -DUSE_REAL_ADC_INGEST -o /tmp/hip_real_adc.out \
  -s home_inventory_top \
  -f rtl/ip_home_inventory.f
```

### Notes for harness integration
Because the port list changes under this define, the **harness wrapper must match**:
- stub build: do not connect ADC pins
- real ingest build: connect ADC pins to the harness pads (or tie off for simulation)

See also:
- `docs/ADC_STREAMING_INTEGRATION_CHECKLIST.md`
- `docs/HARNESS_INTEGRATION.md`

## `SIM`
**Purpose:** Enable DV-only hooks that are safe to force in simulation, without changing the regmap or adding top-level ports.

### Effects
When `-DSIM` is defined:
- `home_inventory_wb` includes `(* keep *)` internal wires that can be `force`d by a testbench to:
  - override the event-detector sample stream
  - (stub mode) override the ADC FIFO push stream

This is used by the `verify/` testbenches.

### How to compile
The `verify/Makefile` uses this by default:

```bash
make -C verify all
```

## Policy
- **Tapeout RTL** should not depend on `SIM`.
- `USE_REAL_ADC_INGEST` is optional at tapeout time only if we intentionally choose to keep the stub path; otherwise it should be enabled and fully harness-integrated.
