# Tapeout Path (v1)

Goal: pick an MPW/tapeout path that fits **< $5k** and is compatible with a digital-only SoC.

## Candidate paths (initial)

### Option A: SkyWater SKY130 (open PDK) + MPW shuttle
- Pros: mature open-source ecosystem; lots of community examples.
- Cons: availability/schedule varies by shuttle; packaging options vary.

### Option B: GlobalFoundries GF180MCU (open PDK) + MPW
- Pros: good for mixed-signal historically (even though we’re digital-only), robust node.
- Cons: tool/flow details may differ; shuttle cadence depends on program.

## What we must confirm (before locking)
- Shuttle schedule + submission deadlines
- Total cost breakdown: shuttle fee + packaging + shipping + PCB/assembly
- Allowed IO count and padframe constraints
- Any restrictions on CPU cores / SRAM macros (if needed)

## Recommendation (v1)
**Target SKY130A via an OpenMPW-style shuttle using the Caravel user-project flow.**

This is the lowest-friction path for a first open-source digital tapeout because the ecosystem (OpenLane + mpw-precheck + known harness) is well-traveled.

## Integration plan (concrete)
- Use `efabless/caravel_user_project` as the submission harness.
- Keep *this* repo as the product/spec/RTL source of truth.
- Create a separate submission repo (derived from the template) that pulls our hardened macro/IP (submodule or vendored snapshot).

## What I will do next
1) Turn `docs/OPENMPW_SUBMISSION.md` into a step-by-step checklist we can follow repeatedly.
2) Identify the exact shuttle + deadline and copy it into `docs/DASHBOARD.md` + checklist.
3) Add an initial RTL “user project” wrapper skeleton and OpenLane config to start running prechecks early.
