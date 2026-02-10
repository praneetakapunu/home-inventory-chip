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

## Recommendation (draft)
Start with **SKY130 MPW** unless schedule/cost conflicts appear, because it is the lowest friction for open-source digital tapeouts.

## Next actions
- Collect current shuttle program details (cost/schedule/package).
- Decide whether we use hardened SRAM macros vs small synthesized memories.
