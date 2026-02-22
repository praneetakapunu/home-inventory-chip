# OpenLane skeleton (v1)

This folder is a **non-running** placeholder intended to make PD requirements explicit early.

## What this is
- A starting point for an OpenLane/OpenROAD flow targeting Sky130 (OpenMPW).
- Captures the *assumptions* we need to lock (top module, clocks, pin strategy).

## What this is not (yet)
- A complete, runnable OpenLane setup.
- Any attempt to run the flow inside CI (disk/time heavy).

## Next steps
1) Confirm top module name and clocks are stable:
   - Top: `home_inventory_top` (RTL: `rtl/home_inventory_top.v`)
   - Wishbone clock: `wb_clk_i` (default PD clock)
2) Decide whether we need additional clocks for the ADC SPI engine.
3) Add an initial pin order / pin constraints once we know the harness wrapper pins.
4) When ready, add a minimal OpenLane config + `make pd-setup` helper.

## References
- `docs/OPENMPW_SUBMISSION.md`
- `docs/TAPEOUT_CHECKLIST.md`
