# Progress Tick Playbook (2-hour cadence)

This repo is used with a scheduled **2-hour progress tick**. The goal is to reliably move toward tapeout without requiring heavy tool installs or lots of disk.

## Definition of done (per tick)
A tick is **successful** only if all of these happen:
1) At least **one concrete improvement** lands (spec/docs/RTL/verify/tools).
2) The improvement is captured as a **git commit** (and pushed).
3) A progress email is sent using:
   - `bash /home/exedev/.openclaw/workspace/ops/progress_report.sh`

The email’s **Highlight (this 2-hour window)** section must come from the commits in the window.

## Recommended “low-disk” task menu
Prefer these when the environment is constrained:
- Specs: regmap tables, acceptance criteria, interface contracts
- Checklists: tapeout checklist, bring-up sequence, verification plan
- RTL skeletons: wiring stubs, parameter hooks, compile-time guards
- Verification: lightweight compile checks, simple directed testbenches
- Tooling: grep-based harness audits, placeholder detection gates

Avoid full OpenLane/PD flows if disk or toolchain availability is uncertain.

## Standard tick procedure
1) **Pick the smallest unblocked task** that is clearly tapeout-relevant.
2) Make the change and run a quick sanity check where applicable (markdown lint not required).
3) Commit with a message that answers: *what changed* + *why now*.
4) Push.
5) Run the progress report script:
   - `bash /home/exedev/.openclaw/workspace/ops/progress_report.sh`

## If blocked (no commit possible)
Do **not** send an email claiming progress.

Instead:
1) Update `docs/EXECUTION_PLAN.md` under `## Blockers` with:
   - the exact blocker
   - what was attempted
   - what would unblock it
2) Send a short message explaining why the window produced no commit.

## Suggested commit message format
- `docs: <topic> (<intent>)`
- `rtl: <module> (<intent>)`
- `verify: <test> (<intent>)`
- `tools: <script> (<intent>)`

Examples:
- `docs: add progress tick playbook (reduce missed windows)`
- `tools: add harness placeholder audit suite wrapper (one-shot)`
