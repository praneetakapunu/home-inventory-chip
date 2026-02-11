# Execution Plan (v1)

This file is the actionable plan to finish ASAP. Keep it short and current.

## Current phase
**OpenMPW tapeout path lock → harness/repo integration → RTL baseline**

## Next 48 hours (Madhuri)
1) Submission mechanics: get harness repo to a state where `make setup` + precheck can run with our stub
2) Land RTL baseline in source-of-truth:
   - `rtl/home_inventory_top.v` skeleton
   - `spec/regmap.md` draft
3) Tighten v1 acceptance criteria: define what “5 g effective” means (noise/drift/latency)
4) Choose a specific external 8ch load-cell ADC part and lock SPI vs I2C

## Blockers (must be explicit)
- None currently.

## Pending from Praneet
- None.

## Risks (watchlist)
- 5 g effective resolution may be dominated by mechanical + drift; spec must define realistic acceptance criteria.
- ADC part selection is a dependency for interface details + firmware formats.
