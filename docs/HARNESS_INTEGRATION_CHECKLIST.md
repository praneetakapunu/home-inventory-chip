# Harness Integration Checklist (Caravel / OpenMPW)

Goal: make the submission harness repo (`home-inventory-chip-openmpw`) *boring* and reproducible, while this repo (`chip-inventory`) stays the source-of-truth for RTL/spec.

This checklist is intentionally concrete: if we can tick every box, we should be able to run OpenLane + mpw-precheck (disk permitting) with minimal drama.

## A) Repo wiring (submodule)
In the harness repo root:

- [ ] `ip/home-inventory-chip/` exists and points at this repo
- [ ] Submodule init/update works in a fresh clone

Commands:

```bash
git submodule update --init --recursive
# optional: to verify it's not detached in a weird way
git -C ip/home-inventory-chip status
```

## B) Filelists (single source)
We want **one** canonical filelist in the harness repo that enumerates the IP RTL files.

- [ ] Harness has `verilog/rtl/ip_home_inventory.f`
- [ ] Filelist only references paths under `ip/home-inventory-chip/rtl/...`
- [ ] Filelist order is stable (top last if tool requires)

Example `verilog/rtl/ip_home_inventory.f` (harness repo):

```text
# relative to harness repo root
ip/home-inventory-chip/rtl/home_inventory_pkg.sv
ip/home-inventory-chip/rtl/home_inventory_wb.v
ip/home-inventory-chip/rtl/home_inventory_top.v
```

## C) Wrapper instantiation
- [ ] `verilog/rtl/user_project_wrapper.v` instantiates the IP top module (currently: `home_inventory_top`)
- [ ] Wrapper connects only the pins we intend to own (everything else tied off deterministically)
- [ ] Any bus (Wishbone) signals are named consistently with Caravel conventions

Sanity commands (harness repo):

```bash
# fast compile check using Icarus
iverilog -g2012 -o /tmp/wrapper.out \
  -f verilog/rtl/ip_home_inventory.f \
  verilog/rtl/user_project_wrapper.v

# or syntax/lint-ish compile using Verilator
verilator -Wall --cc \
  -f verilog/rtl/ip_home_inventory.f \
  verilog/rtl/user_project_wrapper.v \
  --top-module user_project_wrapper
```

## D) Pinout + interface freeze artifacts
These are the human-reviewed “contract” files.

- [ ] `docs/pinout.md` exists in the harness repo (or equivalent) and matches wrapper IO
- [ ] This repo’s top module IO matches the pinout (no surprise ports)
- [ ] Any clock/reset assumptions are written down (freq, polarity, sync domain)

Recommended content for pinout doc:
- List of IOs used (digital only for now)
- Direction, pull/tie behavior on reset
- Any shared bus usage (GPIO, LA, WB)

## E) OpenLane configuration hooks (when we’re ready)
Don’t attempt a full harden until A–D pass.

- [ ] `openlane/user_project_wrapper/config.tcl` points at `user_project_wrapper.v` and the IP filelist
- [ ] Clock defined (even if conservative)
- [ ] Constraints are explicit (don’t rely on tool defaults)

## F) Precheck readiness
- [ ] Harness repo has a documented, repeatable `make precheck` entrypoint (or the shuttle’s equivalent)
- [ ] There is a place to store artifacts (e.g., `reports/` or CI artifacts)

## G) “When blocked” policy
If you hit disk/tooling blockers (OpenLane installs, PDK download, precheck container size), do **not** thrash.

- Record the failure and the exact requirement (e.g., “needs +18 GB free in /home”) in:
  - `chip-inventory/docs/EXECUTION_PLAN.md` → `## Blockers`
