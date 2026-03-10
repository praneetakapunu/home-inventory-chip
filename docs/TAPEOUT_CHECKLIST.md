# Tapeout Checklist (v1)

This checklist is meant to be *actionable* and short. Check items off as they are *actually* done.

> Scope: ChipFoundry / chipIgnite shuttle submission for the **home-inventory** project IP.

## 0) Decisions locked (pre-freeze)
- [ ] Target shuttle + **commitment/cutoff date** chosen and recorded (`docs/SHUTTLE_LOCK_RECORD.md`; linked from `docs/DASHBOARD.md` + `docs/TIMELINE.md`)
  - [ ] Lock record is complete (strict): `bash ops/check_shuttle_lock_record.sh --strict`
- [ ] Top-level intent and boundaries clear (what v1 does / does not do)
- [ ] External ADC part locked (done: ADS131M08)
- [ ] SPI framing assumptions documented (DRDY, words-per-frame, CRC policy)
- [ ] Regmap v1 frozen (addresses + reset values)
  - Playbook: `docs/REGMAP_FREEZE_PLAYBOOK.md`
  - Baseline record: `docs/BASELINES.md` (Regmap v1 freeze)
  - [ ] `spec/regmap_v1.yaml` + `spec/regmap.md` updated together (no drift)
  - [ ] Regenerated derived artifacts committed:
    - [ ] `bash ops/regmap_update.sh`
    - [ ] `fw/include/home_inventory_regmap.h`
    - [ ] `rtl/include/home_inventory_regmap_pkg.sv`
    - [ ] `rtl/include/regmap_params.vh`
  - [ ] Consistency gates green:
    - [ ] `make -C verify regmap-check`
    - [ ] `make -C verify regmap-gen-check`

## 1) Repo / build hygiene
- [ ] Canonical RTL filelist exists and is used by CI
- [ ] Low-disk "sanity" suite is green (should run even when OpenLane is blocked by disk):
  - [ ] `bash ops/preflight_low_disk.sh` (IP repo)
- [ ] `iverilog` (or equivalent) compile check is green for:
  - [ ] chip-inventory IP (`rtl/`) — `bash ops/rtl_compile_check.sh`
  - [ ] harness integration repo (Caravel user project)
    - [ ] `cd ../home-inventory-chip-openmpw && make sync-ip-filelist`
    - [ ] `cd ../home-inventory-chip-openmpw && make rtl-compile-check`
- [ ] No generated blobs committed (build/ sim/ temp)
- [ ] License headers / third-party attributions handled

## 2) Harness integration (OpenMPW submission repo)
- [ ] User project wrapper wires the IP cleanly
- [ ] Clock/reset strategy documented (which clock, reset polarity, synchronizers)
- [ ] Wishbone integration verified:
  - [ ] Reads/writes work for a representative reg set
  - [ ] Byte enables handled (or explicitly unsupported + documented)
  - [ ] `ack` behavior meets expectations (no deadlocks)

## 3) Verification gates
- [ ] CDC/Reset review done (`docs/CDC_RESET_CHECKLIST.md` filled + reviewed)
  - [ ] All async inputs enumerated
  - [ ] All clock domains listed (incl. Wishbone)
  - [ ] Reset deassertion strategy documented (sync/async per domain)

- [ ] **One-command regression is green (IP repo)**
  - [ ] `make -C verify all`

- [ ] **Regmap consistency gates are green** (no simulator needed)
  - [ ] `make -C verify regmap-check`
  - [ ] `make -C verify regmap-gen-check`

- [ ] **Directed sims are green** (requires `iverilog`)
  - [ ] Wishbone regblock (`make -C verify sim`)
    - [ ] reset values + R/W paths
    - [ ] byte-enable policy (supported vs explicitly ignored)
  - [ ] ADC DRDY sync (`make -C verify drdy-sim`)
    - [ ] edge pulse behavior is correct + no double-pulses
  - [ ] ADC streaming FIFO (`make -C verify fifo-sim`)
    - [ ] push/pop, level reporting, overrun sticky
  - [ ] SPI frame capture (`make -C verify spi-sim`)
  - [ ] Event detector (`make -C verify evt-sim`)
    - [ ] threshold/enable semantics work (count increments only on hits)
    - [ ] timestamp monotonic + delta behavior is sane
    - [ ] `CLEAR_COUNTS` and `CLEAR_HISTORY` work (W1P, byte-lane masked)
    - [ ] DV-only sample injection path still works (`sim_evt_*` override; see `docs/EVENT_DETECTOR_INTEGRATION_PLAN.md`)

- [ ] ADC streaming contract (see `docs/ADC_STREAM_CONTRACT.md`):
  - [ ] One capture produces **9 FIFO words** (STATUS + CH0..CH7) in-order
  - [ ] Overrun behavior matches v1 policy (16-depth FIFO, drop-on-full, sticky OVERRUN W1C)

- [ ] Known limitations listed in `docs/KNOWN_LIMITATIONS.md` (and match reality)

## 4) Bring-up readiness (FW-facing)
- [ ] Bring-up sequence document exists and is realistic
  - Suggested starting points:
    - `docs/BRINGUP_SEQUENCE.md`
    - `docs/ADC_FW_INIT_SEQUENCE.md`
- [ ] Minimal FW register pokes documented for:
  - [ ] reset sanity
  - [ ] enable capture
  - [ ] drain FIFO
- [ ] Error observability exists (sticky flags, counters, last-error code)

## 5) Precheck / submission gates
- [ ] OpenMPW precheck runs clean (harness repo)
  - [ ] Install/update precheck tooling (one-time, Docker required)
    - `cd home-inventory-chip-openmpw && make precheck`
  - [ ] Run precheck (from harness repo root)
    - `cd home-inventory-chip-openmpw && make run-precheck`
    - Optional: disable LVS if you only want “fast sanity” (still log it):
      - `DISABLE_LVS=1 cd home-inventory-chip-openmpw && make run-precheck`
  - [ ] Record *exact* invocation + repo commit hashes in `chip-inventory/docs/PRECHECK_LOG.md`
  - [ ] Attach/log the final summary (PASS/FAIL) and any waived warnings
- [ ] Final tag created (e.g., `tapeout-v1.0.0`)
- [ ] Release notes written (what changed since last tag)

## 6) Signoff artifacts (lightweight, but explicit)
- [ ] `docs/ARCH.md` (top-level block diagram + interfaces)
- [ ] `docs/KNOWN_LIMITATIONS.md` (explicit list of v1 limitations + workarounds)
- [ ] `spec/regmap.md` frozen + referenced by RTL
- [ ] `docs/VERIFICATION_PLAN.md` updated with *what we actually ran*
