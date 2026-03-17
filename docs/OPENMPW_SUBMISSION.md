# OpenMPW submission notes (working)

This doc is the practical “how we tape out” record for **OpenMPW/Caravel-style** shuttles.

If the target shuttle is ChipFoundry/chipIgnite (see `docs/SHUTTLE_LOCK_RECORD.md`), also read:
- `docs/CHIPFOUNDRY_SUBMISSION_NOTES.md`

That doc tracks the **open questions / required confirmations** so we don’t spend disk/time on the wrong precheck flow.

## Working assumption (v1)
- **PDK:** `sky130A`
- **Flow:** OpenLane-based hardening + mpw-precheck
- **Harness/template:** `efabless/caravel_user_project` (user project wrapper inside a known harness)

## Why Caravel-style harness
It reduces tapeout friction:
- Fixed padframe / IO conventions
- Known precheck tooling
- Known reference CI flows

## Repo strategy (recommended)
Keep **two repos**:
- **Source-of-truth IP/spec repo:** `chip-inventory` (this repo)
- **Submission harness repo:** `home-inventory-chip-openmpw`

Reason: this keeps specs/firmware/verification and design iteration clean, while the harness repo stays “boring” and optimized for the shuttle checklist.

## Wiring plan: how the harness repo consumes this repo
Goal: the harness repo should pull the IP via submodule (or subtree) and expose only the *wrapper-facing* views under its expected paths.

### Option A (preferred): git submodule
In the harness repo:

```bash
# from home-inventory-chip-openmpw/
mkdir -p ip

git submodule add \
  https://github.com/praneetakapunu/home-inventory-chip \
  ip/home-inventory-chip

git submodule update --init --recursive
```

Then define a *single* canonical place the harness repo imports RTL from.

Recommended mapping (update paths to match actual top names as they evolve):
- `ip/home-inventory-chip/rtl/**` → primary RTL source
- `ip/home-inventory-chip/spec/**` → reference only (not needed by OpenLane)

In the harness repo, prefer **thin “include files”** over copying RTL:
- `verilog/rtl/user_project_wrapper.v` instantiates `home_inventory_top` (or whatever the IP top is)
- `verilog/rtl/ip_home_inventory.f` (filelist) lists RTL files from `ip/home-inventory-chip/rtl/...`

That way OpenLane / Yosys gets stable inputs without duplicating source.

### Option B: subtree (if submodules are annoying)
If CI/submodules become painful, use `git subtree` to vendor the RTL snapshot into the harness repo. This trades clean separation for simplicity.

## Minimal submission readiness checklist
These are “gate” items we should be able to do on demand.

Canonical checklists:
- Harness integration: `docs/HARNESS_INTEGRATION_CHECKLIST.md`
- Full tapeout: `docs/TAPEOUT_CHECKLIST.md`

High-level gates (submission repo):

1) **Harness repo boots:** `make setup` completes (downloads deps, builds env)
2) **Wrapper compiles:** `user_project_wrapper.v` and filelists resolve all RTL
3) **Pinout frozen:** `docs/pinout.md` (or equivalent) matches top module IO
4) **OpenLane config exists:** `openlane/user_project_wrapper/config.tcl` (or equivalent) points at the correct filelists and constraints
5) **Precheck runnable:** mpw-precheck can be invoked and produces a report artifact

## Repeatable submission runbook (copy/paste)
This is the practical, repeatable “what we do” sequence when cutting a submission candidate.

### A) In the IP repo (`chip-inventory`)
```bash
cd chip-inventory

# 1) confirm repo is clean and tests can run in a low-disk environment
bash ops/preflight_low_disk.sh

# 2) (optional but common) update any derived regmap artifacts
# bash ops/regmap_update.sh
# bash ops/regmap_check.sh

git status -sb
```

If any of the above fails due to disk/toolchain constraints, **stop early** and record the blocker:
- `docs/EXECUTION_PLAN.md` → `## Blockers` (include command + error + current free space)

### B) In the harness repo (`home-inventory-chip-openmpw`)
```bash
cd ../home-inventory-chip-openmpw

# 0) bring in latest IP snapshot
# (submodule or subtree depending on strategy)

git status -sb

# 1) sync the wrapper-facing filelist(s)
make sync-ip-filelist

# 2) fast compile sanity checks (no PDK)
make rtl-compile-check
make rtl-compile-check-real-adc

# 3) only now do heavy setup + precheck
make setup
make run-precheck
```

### C) Evidence + bookkeeping (don’t skip)
- Record *exact* precheck invocation + summary + both repo commit hashes in:
  - `chip-inventory/docs/PRECHECK_LOG.md`
- If you updated IP/submodule pointers in the harness repo, include the IP commit hash in the harness commit message.

### D) Submission PR “Definition of Done” (minimum)
A submission candidate PR (in the harness repo) is considered reviewable when it includes:
- A green `make rtl-compile-check` + `make rtl-compile-check-real-adc`
- A recorded precheck result in `chip-inventory/docs/PRECHECK_LOG.md` (PASS/FAIL + warnings)
- A linked baseline/freeze note (e.g., regmap v1 freeze) if the PR changes interfaces
- Updated `docs/DASHBOARD.md` if schedule/deadline info changed

## Fast local loop (no PDK/OpenLane) — do this *first*
Before downloading big toolchains, keep a tiny “does it compile?” loop that exercises the wrapper + filelists.

This is the “continuous readiness” loop we can keep green even on tight disk:
- IP repo: `bash ops/preflight_low_disk.sh`
- Harness repo: `make sync-ip-filelist` + `make rtl-compile-check`

If these are green, we’re not *taped out*, but we are steadily reducing integration risk while we sort out
PDK/OpenLane disk needs.

Suggested pattern in the harness repo:

```bash
# from home-inventory-chip-openmpw/
# 1) ensure submodules are present
git submodule update --init --recursive

# 2) compile the wrapper + included IP RTL using a lightweight sim
# (choose one tool you have installed)
iverilog -g2012 -o /tmp/wrapper.out \
  -f verilog/rtl/ip_home_inventory.f \
  verilog/rtl/user_project_wrapper.v

# or, Verilator syntax-check / lint-style compile
verilator -Wall --cc \
  -f verilog/rtl/ip_home_inventory.f \
  verilog/rtl/user_project_wrapper.v \
  --top-module user_project_wrapper
```

This catches:
- missing/incorrect filelist paths
- module name mismatches (`home_inventory_top` vs wrapper instantiation)
- accidental SystemVerilog features not supported by the chosen tool

Once this passes, *then* it’s worth spending disk/time on OpenLane + precheck.

## Precheck quickstart (harness repo)
Exact commands can vary per shuttle. This is the typical sequence:

```bash
# from home-inventory-chip-openmpw/
make setup

# optional: sanity lint/compile step if provided
make verify-rtl || true

# typical hardening entrypoint (varies)
make user_project_wrapper

# mpw-precheck entrypoint (varies)
make precheck
```

## Disk budgeting (don’t guess)
OpenLane/precheck setup is the first place we can get stuck on disk. Don’t “try a bunch of times” and fill the disk.

Do this *before* running heavy steps:

```bash
df -h
```

Then after each large setup step (usually in the harness repo), measure what changed:

```bash
# from home-inventory-chip-openmpw/
du -sh . | cat
# or inspect the usual suspects
for d in .git submodules dependencies openlane pdks docker_cache; do
  [ -d "$d" ] && du -sh "$d"
done
```

If disk space becomes a blocker for full OpenLane runs, **do not thrash**; record the exact failure (command + error)
*and* the current free space in:
- `chip-inventory/docs/EXECUTION_PLAN.md` → `## Blockers`

That keeps the project honest: we can keep RTL/DV/integration moving while we plan a disk fix.

## References
- Caravel user project docs: https://caravel-user-project.readthedocs.io/
- `caravel_user_project` template generator: https://github.com/efabless/caravel_user_project/generate

## Open questions
- Which specific shuttle (name/deadline) are we targeting? (Needed to lock schedule.)

## Repos
- Harness repo (Caravel user project): https://github.com/praneetakapunu/home-inventory-chip-openmpw
- Source-of-truth repo: https://github.com/praneetakapunu/home-inventory-chip
