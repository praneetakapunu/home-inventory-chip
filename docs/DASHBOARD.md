# Home Inventory Chip — Project Dashboard

**Last updated:** (auto via commits / daily reports)

## Objective
Deliver a taped-out **digital** chip (open-source tools only) + a demo board/system that demonstrates a practical **home inventory management** solution.

**v1 approach (default):** weight-sensor based inventory (load cells + off-chip ADC), controlled by a small RISC‑V SoC on the chip.

## Current status
- Phase: **Kickoff / spec freeze**
- Budget: **$5k**
- Daily reports: **Email at 06:00 IST** → praneetkbhatia@gmail.com

## Milestones (high level)
1) v1 spec + acceptance tests frozen
2) RTL baseline + simulation passing
3) Physical design (OpenROAD/OpenLane) meets DRC/LVS/timing targets
4) Tapeout package submitted to MPW shuttle
5) Silicon arrives + bring-up
6) Demo system + documented walkthrough

## Today’s top priorities
- Draft **v1 spec** + acceptance tests
- Select tapeout path (MPW shuttle + PDK) within $5k
- Stand up verification + PD flow skeleton

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
