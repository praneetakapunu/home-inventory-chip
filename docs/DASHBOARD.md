# Home Inventory Chip — Project Dashboard

**Last updated:** (auto via commits / daily reports)

## Objective
Deliver a taped-out **digital** chip (open-source tools only) + a demo board/system that demonstrates a practical **home inventory management** solution.

**v1 approach (default):** weight-sensor based inventory (load cells + off-chip ADC), controlled by a small RISC‑V SoC on the chip.

## Current status
- Phase: **Tapeout path lock / OpenMPW harness integration**
- Budget: **$5k**
- Daily reports: **Email at 06:00 IST** → praneetkbhatia@gmail.com

## Milestones (high level)
1) v1 spec + acceptance tests frozen
2) RTL baseline + simulation passing
3) Physical design (OpenROAD/OpenLane) meets DRC/LVS/timing targets
4) Tapeout package submitted to MPW shuttle
5) Silicon arrives + bring-up
6) Demo system + documented walkthrough

## Today’s top priorities (owner-tagged)
- **[Madhuri]** Draft **v1 spec** + acceptance tests
- **[Madhuri]** Select tapeout path (MPW shuttle + PDK) within $5k
- **[Madhuri]** Stand up verification + PD flow skeleton

## What I need from Praneet (to go faster)
**Nothing is blocking kickoff right now**, but these items will become blocking soon. If you do them early, we compress the schedule.

1) **Shipping address + phone** (for fab/packaging/board houses) — needed before ordering anything.
2) **Name to print on silkscreen / chip demo branding** (optional).
3) **Preferred demo form factor**: one “smart shelf scale”, or 4–8 small pads (under bins), or a full kitchen shelf?
4) **Success metrics** (pick one set):
   - A) Detect add/remove events ≥ **20 g**; per-bin totals; calibration flow.
   - B) Detect ≥ **5 g** changes (harder: noise + drift).
5) **GitHub visibility**: keep repo **private** or make **public** later?

When you answer #3–#4, I can freeze the v1 spec without waiting.

## Key decisions log
- See: `decisions/` (one file per decision)

## Repo map
- Spec: `spec/`
- Decisions: `decisions/`
- Daily reports: `reports/`
- RTL: `rtl/`
- Verification: `verify/`
- Physical design: `pd/`
- Firmware: `fw/`
- Bring-up: `bringup/`

## Links
- Local dashboard: `chip-inventory/docs/DASHBOARD.md`
- (GitHub link will appear once remote is connected)
