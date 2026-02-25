# Home Inventory Chip — Project Dashboard

**Last updated:** 2026-02-25 (UTC)

## Objective
Deliver a taped-out **digital** chip (open-source tools) + a demo system that demonstrates a practical **home inventory management** path.

**v1 approach (locked):** weight-sensor based inventory (load cells + off-chip ADC), controlled by a small RISC‑V SoC on the chip.

## Current status (as of this commit)
- Phase: **RTL baseline + regmap + harness integration (low-disk green)**
- Budget target: **<$5k**
- Tapeout path: **SKY130A via OpenMPW / Caravel harness**
- ADC part (locked): **TI ADS131M08**
- Effective resolution target (locked): **20 g**

## What’s already “green”
These are the things we can run repeatedly without needing a full OpenLane setup:

- **IP repo (`chip-inventory/`)**
  - `make -C verify all` (regmap checks + directed sims)
  - Regmap is source-of-truth in `spec/regmap_v1.yaml` and generated artifacts are checked in CI.

- **Harness repo (`home-inventory-chip-openmpw/`)**
  - `make rtl-compile-check` (sync filelist + compile wrapper/IP RTL)
  - GitHub Actions: a lightweight RTL compile-check runs on every push.
  - Cocotb user-project test exists: `home_inventory_wb_smoke` (mgmt-core firmware drives Wishbone).

## Milestones / schedule
Baseline dates: see `docs/TIMELINE.md` (baseline start 2026-02-25).

High level:
1) Spec/acceptance frozen (v1)
2) RTL baseline + verification passing (v1)
3) Physical design (OpenLane/OpenROAD) meets DRC/LVS/timing targets
4) Tapeout package submitted
5) Silicon arrives + bring-up
6) Demo system + documented walkthrough

## Near-term priorities (next 48 hours)
1) **ADC streaming path integration (RTL)**
   - Wire frame-capture → FIFO → regmap pop path end-to-end (keep snapshot path for bring-up).
2) **Event detector integration polish**
   - Confirm event detector is driven by the chosen sample source (snapshot now, streaming later).
   - Add any missing status/clear semantics to regmap if needed (avoid address churn).
3) **Tapeout gates (practical, repeatable)**
   - Keep `docs/TAPEOUT_CHECKLIST.md` actionable; ensure each gate has an exact command and expected artifact.
4) **Low-disk CI hygiene**
   - Keep harness compile-check + IP verify suite green as we iterate.

## What I need from Praneet
- Shuttle schedule/deadline to target (name + cutoff date). If unknown, we proceed with “continuous readiness” gates until chosen.

## Key decisions log
- See: `decisions/` (one file per decision)

## Repo map
- Spec: `spec/`
- Decisions: `decisions/`
- Docs/checklists: `docs/`
- RTL: `rtl/`
- Verification: `verify/`
- Physical design: `pd/`
- Firmware: `fw/`
- Bring-up: `bringup/`
