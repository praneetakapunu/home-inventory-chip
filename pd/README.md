# Physical Design (skeleton)

## Goal
Stand up an OpenLane/OpenROAD flow early so constraints/pinout decisions happen before RTL is "done".

## Next
- Choose flow (OpenLane recommended for v1) and capture versions.
- Add placeholder config (clock, die size guess, IO constraints).

## Status
- `pd/openlane/` now contains a **skeleton** (config + notes) to force early decisions.
  It is intentionally **not** wired into CI or a runnable make target yet.
