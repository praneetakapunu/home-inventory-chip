# ADC Streaming Bring-up Checklist (v1)

This is the practical checklist for first-silicon / harness integration bring-up of the ADS131M08 streaming path.

Scope:
- Confirms **clocking + DRDY + SPI framing** are sane.
- Confirms the **SoC FIFO contract** (STATUS + CH0..CH7, 9 words per conversion) matches `spec/ads131m08_interface.md`.

Non-goals:
- Tuning analog performance, noise, or achieving the final effective-resolution target.

References:
- Interface contract: `spec/ads131m08_interface.md`
- Clocking plan notes: `docs/ADC_CLOCKING_PLAN.md`
- Harness integration notes: `docs/HARNESS_INTEGRATION.md`

---

## 0) Pre-req: lock the harness facts (must be evidence-based)

Before debugging RTL, lock these harness/PCB facts with a *source link or schematic snippet*:

1) **CLKIN source and frequency**
   - What net drives `ADC_CLKIN`?
   - What is the expected frequency (Hz) and tolerance?
   - If the SoC drives it: what clock divider / PLL / source is used?

2) **DRDY polarity and naming**
   - Confirm whether the top-level exposes `adc_drdy` vs `adc_drdy_n`.
   - Functionally: ADS131M08 DRDY asserts **low**; ensure our pad naming matches.

3) **SPI mode**
   - ADS131M08 requires **CPOL=0, CPHA=1** for the project baseline.

Track the final decision in:
- `decisions/011-adc-clkin-source-and-frequency.md`

Quick harness greps (no toolchain):
- `bash tools/harness_adc_clocking_audit.sh ../home-inventory-chip-openmpw`
- `bash tools/harness_adc_pinout_audit.sh   ../home-inventory-chip-openmpw`

---

## 1) Sanity: RTL unit tests (fast, low-disk)

Run the IP-level verification suite that exercises the streaming pieces in simulation.

From `chip-inventory/`:

- Minimal compile/smoke:
  - `bash ops/rtl_compile_check.sh`

- Run all DV tests:
  - `make -C verify all`

If any test fails, fix **in IP repo first** before involving the harness.

---

## 2) Bring-up: confirm SPI framing is exactly one 10-word frame per conversion

Normative v1 assumption (see `spec/ads131m08_interface.md`):
- One conversion readout corresponds to one **10-word** wire frame on DOUT:
  1) RESPONSE/STATUS
  2..9) CH0..CH7
  10) OUTPUT_CRC (dropped by v1)

The SoC FIFO must see **9 pushed words per conversion**:
- STATUS + CH0..CH7

Acceptance checks:
- FIFO word-count grows by exactly 9 per conversion event.
- STATUS word is not sign-extended.
- Channel words are **sign-extended** 24b → 32b.

---

## 3) Bring-up: DRDY behavior (avoid false debugging loops)

Important ADS131M08 behavior (datasheet note captured in `spec/ads131m08_interface.md`):
- After reset or any long pause, the ADC can behave as if it has a small internal sample FIFO.
- DRDY/STATUS can remain asserted until **two** complete data packets are read.

Rule for first-silicon bring-up:
- After reset/pause, read **two full frames** before trusting steady-state DRDY cadence.

---

## 4) Firmware-facing checklist (Wishbone)

Once the harness is wired and the SoC boots:

1) **Enable streaming** via the Wishbone control register(s) defined in `spec/regmap.md`.
2) Poll FIFO level until non-zero.
3) Drain FIFO and validate the 9-word grouping:
   - word[0] = STATUS
   - word[1] = CH0
   - ...
   - word[8] = CH7

4) Confirm overrun behavior:
   - If you stop draining, FIFO should eventually assert sticky overrun.
   - Clear via W1C per regmap.

---

## 5) If anything is wrong: triage order

1) **Clocking** (CLKIN present? right frequency?)
2) **DRDY polarity** (active-low? synchronized?)
3) **SPI mode** (CPOL/CPHA)
4) **Frame length** (bit/word count: 10 words on the wire; 9 words into FIFO)
5) **Word alignment** (MSB-first)

Write down the evidence as you go. If blocked by harness uncertainty, update:
- `docs/EXECUTION_PLAN.md` → `## Blockers`
