# Harness Integration (OpenMPW / Caravel)

This doc is a **low-disk, fast-feedback** checklist for keeping the OpenMPW submission harness repo (`home-inventory-chip-openmpw`) integrated with the source-of-truth design repo (`chip-inventory`).

> Harness repo: `/home/exedev/.openclaw/workspace/home-inventory-chip-openmpw`
>
> Source-of-truth IP repo: `/home/exedev/.openclaw/workspace/chip-inventory`

## Goal
At any time, we should be able to:
1) pull the latest RTL via the IP submodule,
2) compile the user-project wrapper with Icarus (fast sanity), and
3) run regmap/RTL consistency checks.

This is the minimum baseline before we burn time/disk on OpenLane or full `mpw-precheck`.

## Repo relationship (intended)
- The harness repo contains the OpenMPW scaffolding (Caravel wrapper, Makefiles, precheck CI).
- The actual design RTL/spec live in the IP repo and are brought into the harness as a submodule:
  - `home-inventory-chip-openmpw/ip/home-inventory-chip/`

## Filelists / single source of truth
- Canonical IP RTL filelist (lives in IP repo):
  - `chip-inventory/rtl/ip_home_inventory.f`
- Harness-consumed copy:
  - `home-inventory-chip-openmpw/verilog/rtl/ip_home_inventory.f`

### Sync procedure
From the harness repo root:
```bash
make sync-ip-filelist
```
This copies the IP filelist from the submodule into the harness `verilog/rtl/` tree.

## Regmap drift check (IP ↔ harness submodule)
The harness includes the IP repo as a submodule under `ip/home-inventory-chip/`.
It’s easy for the harness submodule pointer to lag behind the IP repo (or for
regenerated artifacts to drift).

From `chip-inventory/` you can run a fast, tool-light diff against the harness:
```bash
tools/harness_regmap_drift_check.sh ../home-inventory-chip-openmpw
```
This compares:
- `spec/regmap_v1.yaml` (source-of-truth)
- derived artifacts used by firmware/RTL (`regmap_params.vh`, regmap pkg, C header, table)

If it reports drift, update/commit the harness submodule SHA in the harness repo.

## Fast checks (recommended every change)
If you want a single command that checks **both** repos (IP + harness) without running OpenLane:
```bash
bash ops/preflight_ip_and_harness_low_disk.sh
```
This currently runs:
- IP repo low-disk preflight (`ops/preflight_low_disk.sh`)
- Harness: `make sync-ip-filelist`
- Harness: **filelist drift check** (ensures `verilog/rtl/ip_home_inventory.f` matches the IP submodule)
- Harness: `make rtl-compile-check`
- Harness: `make rtl-compile-check-real-adc` (catches wrapper/port drift under `USE_REAL_ADC_INGEST`)

### 1) IP repo: regmap + directed sims
From `chip-inventory/`:
```bash
make -C verify all
```
This runs:
- YAML schema validation
- regmap drift checks (YAML ↔ RTL)
- generated artifact drift checks
- directed sims for Wishbone + ADC helpers + event detector

### 2) Harness repo: wrapper compile sanity (no OpenLane)
From `home-inventory-chip-openmpw/`:
```bash
make rtl-compile-check
```
This does a fast Icarus compile of:
- `verilog/rtl/user_project_wrapper.v`
- `verilog/rtl/home_inventory_user_project.v`
- the IP RTL listed by `verilog/rtl/ip_home_inventory.f`

If this fails, fix the wrapper wiring / filelist **before** attempting precheck/OpenLane.

## Naming / integration contract (v1)
- Harness instantiates the IP Wishbone block as:
  - `home_inventory_wb` (see `chip-inventory/rtl/home_inventory_wb.v`)
- Addressing is byte-addressed Wishbone; registers are 32-bit aligned; see:
  - `chip-inventory/spec/regmap_v1.yaml`

## Optional: enabling real ADC ingest (USE_REAL_ADC_INGEST)
By default, the Wishbone block uses a **stub ADC snapshot path** that feeds a small FIFO so firmware + DV can make progress without real pins.

If you want to exercise the real SPI capture + FIFO path in simulation/bring-up, compile the IP RTL with:
- `-DUSE_REAL_ADC_INGEST`

What this changes:
- `home_inventory_wb` *adds* ADC SPI ports (only when the define is present):
  - `adc_sclk`, `adc_cs_n`, `adc_mosi`, `adc_miso`
- Internally, `home_inventory_wb` instantiates `rtl/adc/adc_streaming_ingest.v` and routes `CTRL.START` into the capture `start` pulse.

Harness expectations:
- Wrapper modules must conditionally expose/wire these pins when `USE_REAL_ADC_INGEST` is enabled.
- For purely tool-light compile sanity (no ADC model), it is OK to:
  - leave `adc_miso` tied low, and
  - leave `adc_sclk/cs_n/mosi` unconnected (or routed to dummy wires)
  as long as port lists match under the same compile-time define.

Fast sanity checks:
- IP repo already compiles both configurations via: `bash ops/rtl_compile_check.sh`
- Harness repo supports a matching compile-check with the define enabled:
  - `make rtl-compile-check-real-adc`
- Low-disk grep audits (no toolchain):
  - Pin exposure + io[*] mapping intent:
    - `../chip-inventory/tools/harness_adc_pinout_audit.sh .`
  - Fail-fast check for placeholder io[*] indices (should fail until mapping is locked):
    - `../chip-inventory/tools/harness_adc_pinout_placeholder_check.sh .`
  - Streaming/real-ingest wiring surfaces (make target + define + adc_* ports):
    - `../chip-inventory/tools/harness_adc_streaming_audit.sh .`

This catches wrapper/port-list drift early, without running any DV.

## Common failure modes
- **Stale filelist in harness**: run `make sync-ip-filelist`.
- **Include path issues** (`regmap_params.vh` etc): ensure the harness compile includes `rtl/include` in the IP filelist and/or Icarus include paths.
- **Wrapper drift** (top-level port names mismatch): fix `home_inventory_user_project.v` wiring to match the current `home_inventory_wb` ports.

## When to run `mpw-precheck`
Only after:
- `make -C chip-inventory/verify all` is clean, and
- `make rtl-compile-check` in the harness is clean.

If precheck/OpenLane is blocked by disk/tool constraints, record the blocker in:
- `chip-inventory/docs/EXECUTION_PLAN.md` under `## Blockers`.
