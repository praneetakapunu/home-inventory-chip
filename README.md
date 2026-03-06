# Home Inventory Chip (Open-source tapeout)

Project dashboard: `docs/DASHBOARD.md`

This repo is the **source-of-truth IP/design repo** for the Home Inventory user project:
- Specs + decisions + checklists live here.
- RTL and low-disk verification live here.

The OpenMPW submission harness / Caravel wrapper lives in the sibling repo:
- `/home/exedev/.openclaw/workspace/home-inventory-chip-openmpw`

## Quick start (low-disk friendly)

From this repo root:

```bash
# 1) Run the fast, low-disk preflight suite (recommended)
bash ops/preflight_low_disk.sh

# 2) Or run just the verification suite
make -C verify all
```

## Key repo entry points

- Project status + priorities: `docs/DASHBOARD.md`
- Execution plan (what to do next): `docs/EXECUTION_PLAN.md`
- Tapeout readiness gates: `docs/TAPEOUT_CHECKLIST.md`
- Register map source-of-truth: `spec/regmap_v1.yaml`
- Harness integration checklist: `docs/HARNESS_INTEGRATION.md`

## Harness integration (OpenMPW / Caravel)

To keep the submission harness repo in sync:

```bash
cd ../home-inventory-chip-openmpw
make sync-ip-filelist
make rtl-compile-check
```

If anything is blocked (disk/tooling), record it explicitly in:
- `docs/EXECUTION_PLAN.md` → `## Blockers`
