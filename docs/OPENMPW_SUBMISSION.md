# OpenMPW submission notes (working)

This doc is the practical “how we tape out” record for OpenMPW-style shuttles.

## Working assumption (v1)
- **PDK:** `sky130A`
- **Flow:** OpenLane-based hardening + mpw-precheck
- **Harness/template:** `efabless/caravel_user_project` (user project wrapper inside a known harness)

## Why Caravel-style harness
It reduces tapeout friction:
- Fixed padframe / IO conventions
- Known precheck tooling
- Known reference CI flows

## Required actions (to make our repo submission-ready)
1) Decide whether we:
   - A) **Migrate** this repo to the `caravel_user_project` structure, or
   - B) Keep this repo as “source-of-truth” and create a separate `caravel_user_project`-based submission repo that pulls our IP as a submodule.

   **Recommendation:** B (separates product/spec/firmware from shuttle harness mechanics).

2) Ensure repo is public + has a license (done: Apache-2.0).
3) Add a minimal user-project top module + OpenLane config.
4) Run mpw-precheck and track results.

## References
- Caravel user project docs: https://caravel-user-project.readthedocs.io/
- `caravel_user_project` template generator: https://github.com/efabless/caravel_user_project/generate

## Open questions
- Which specific shuttle (name/deadline) are we targeting? (Needed to lock schedule.)
