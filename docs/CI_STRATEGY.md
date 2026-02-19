# CI Strategy

We run CI with two goals:
1) Keep the repo **always green** for lightweight, deterministic checks.
2) Avoid running **heavy OpenMPW/OpenLane** flows automatically on every push (too slow + disk hungry).

## Repos
- **Source of truth:** https://github.com/praneetakapunu/home-inventory-chip
- **OpenMPW harness:** https://github.com/praneetakapunu/home-inventory-chip-openmpw

## Tier 1: Always-on (runs on every push/PR)
These must be fast and reliable.

### Source of truth (home-inventory-chip)
- Regmap drift checks (generated artifacts match `spec/regmap_v1.yaml`)
- Icarus Verilog sims (Wishbone smoke, directed tests)

### Harness (home-inventory-chip-openmpw)
- RTL compile sanity via `iverilog`:
  - `make rtl-compile-check`
  - Includes syncing the IP filelist so the harness can’t silently drift from the submodule.

## Tier 2: Heavy flows (manual / gated)
These are run only when we’re ready for an OpenMPW submission checkpoint.

Examples:
- Download large PDKs
- Pull OpenLane Docker image
- Run hardening
- Run mpw-precheck

Why gated:
- Requires significant disk (recommend **>= 30 GB free**)
- Can take hours
- GitHub-hosted runners can be flaky for these workloads

## Rule
If Tier 1 fails, fix immediately. Tier 2 failures are tracked as work items and fixed as we approach submission.
