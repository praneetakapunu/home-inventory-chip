# Project TODO (owner-tagged)

This is the short list of *current* work. Keep it honest; move completed items out.

## Now (this week)
- **[Madhuri]** ADC streaming integration: frame-capture → FIFO → regmap pop end-to-end
- **[Madhuri]** Event detector integration polish + minimal acceptance behaviors (no address churn)
- **[Madhuri]** Keep low-disk gates green:
  - IP repo: `make -C verify all`
  - Harness repo: `make sync-ip-filelist` + `make rtl-compile-check`
- **[Madhuri]** Decide target shuttle/deadline and copy into `docs/DASHBOARD.md` + `docs/TAPEOUT_CHECKLIST.md`

## Done (recent)
- **[Madhuri]** v1 spec + acceptance metrics (`spec/v1.md`, `spec/acceptance_metrics.md`)
- **[Madhuri]** Tapeout path selection (`spec/tapeout-path.md`)
- **[Madhuri]** Regmap + generation pipeline (`spec/regmap_v1.yaml` → C header + SV pkg + VH params)
- **[Madhuri]** Directed RTL sims for ADC blocks + event detector (`verify/`)
- **[Madhuri]** Harness repo wiring (submodule + filelist sync + RTL compile-check)

## Inputs needed from Praneet (soon)
- Shuttle schedule + submission deadline (once chosen, we lock gates around it)

## Later
- **[Madhuri]** Full OpenLane hardening runs + mpw-precheck (disk/tooling permitting)
- **[Madhuri]** Firmware demo app beyond bring-up (event reporting + calibration UX)
- **[Madhuri]** PCB design + assembly order
- **[Madhuri]** Silicon bring-up + final demo
