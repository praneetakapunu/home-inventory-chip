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

## Fast checks (recommended every change)
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
