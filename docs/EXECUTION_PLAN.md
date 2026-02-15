# Execution Plan (v1)

This file is the actionable plan to finish ASAP. Keep it short and current.

## Current phase
**OpenMPW tapeout path lock → harness/repo integration → RTL baseline**

## Next 48 hours (Madhuri)
1) Submission mechanics: get harness repo to a state where `make setup` + precheck can run with our stub
2) Land RTL baseline in source-of-truth (done, keep iterating):
   - `rtl/home_inventory_top.v` skeleton
   - `rtl/home_inventory_wb.v` Wishbone reg block
   - `spec/regmap.md` v1 register map
3) Add a minimal verification surface:
   - `docs/VERIFICATION_PLAN.md` (spec-level smoke list) ✅
   - Harness repo: cocotb tests for the Wishbone reg block (next)
4) Tighten v1 acceptance criteria (so we can pick ADC + filtering intentionally):
   - Draft created: `spec/acceptance_metrics.md`
   - Proposed decision: `decisions/007-effective-resolution-definition.md`
   - Pending: Praneet sign-off (or relax target to 20 g for v1)
5) Choose a specific external 8ch load-cell ADC part and lock SPI vs I2C

## Blockers (must be explicit)
- None currently.

## Pending from Praneet
- None.

## Risks (watchlist)
- 5 g effective resolution may be dominated by mechanical + drift; spec must define realistic acceptance criteria.
- ADC part selection is a dependency for interface details + firmware formats.
