# Tapeout Checklist (v1)

This checklist is meant to be *actionable* and short. Check items off as they are *actually* done.

> Scope: OpenMPW (Caravel user project) submission with the **home-inventory** user project IP.

## 0) Decisions locked (pre-freeze)
- [ ] Top-level intent and boundaries clear (what v1 does / does not do)
- [ ] External ADC part locked (done: ADS131M08)
- [ ] SPI framing assumptions documented (DRDY, words-per-frame, CRC policy)
- [ ] Regmap v1 frozen (addresses + reset values)

## 1) Repo / build hygiene
- [ ] Canonical RTL filelist exists and is used by CI
- [ ] `iverilog` (or equivalent) compile check is green for:
  - [ ] chip-inventory IP (`rtl/`)
  - [ ] harness integration repo (Caravel user project)
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
- [ ] Directed smoke tests cover:
  - [ ] Wishbone regblock (reset values + R/W paths)
  - [ ] ADC DRDY sync edge pulse behavior
  - [ ] FIFO: push/pop, level, overrun sticky
- [ ] CDC/Reset review done (at least a written checklist + known crossings)
- [ ] Known limitations listed in `docs/KNOWN_LIMITATIONS.md`

## 4) Bring-up readiness (FW-facing)
- [ ] Bring-up sequence document exists and is realistic
- [ ] Minimal FW register pokes documented for:
  - [ ] reset sanity
  - [ ] enable capture
  - [ ] drain FIFO
- [ ] Error observability exists (sticky flags, counters, last-error code)

## 5) Precheck / submission gates
- [ ] OpenMPW precheck runs clean (document exact command + commit hash)
- [ ] Final tag created (e.g., `tapeout-v1.0.0`)
- [ ] Release notes written (what changed since last tag)

## 6) Signoff artifacts (lightweight, but explicit)
- [ ] `docs/ARCH.md` (top-level block diagram + interfaces)
- [ ] `docs/KNOWN_LIMITATIONS.md` (explicit list of v1 limitations + workarounds)
- [ ] `spec/regmap.md` frozen + referenced by RTL
- [ ] `docs/VERIFICATION_PLAN.md` updated with *what we actually ran*
