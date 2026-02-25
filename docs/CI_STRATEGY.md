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
- Regmap YAML validation + drift checks (generated artifacts match `spec/regmap_v1.yaml`)
- Regmap generated artifact drift checks (YAML → committed headers/packages)
- Icarus Verilog directed sims:
  - Wishbone smoke (`make -C verify sim`)
  - ADC FIFO (`make -C verify fifo-sim`)
  - ADC DRDY sync (`make -C verify drdy-sim`)
  - ADC SPI frame capture (`make -C verify spi-sim`)
  - Event detector (`make -C verify evt-sim`)
  - One-shot full Tier-1 suite: `make -C verify all`

### Harness (home-inventory-chip-openmpw)
- RTL compile sanity via `iverilog`:
  - `make sync-ip-filelist`
  - `make rtl-compile-check`
  - This ensures the harness filelist can’t silently drift from the IP submodule.

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
