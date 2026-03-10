# Baselines / frozen commit hashes (v1)

Purpose: record the exact **git commits** that we treat as "frozen" reference points.

Why this exists: during tapeout crunch, we need a single place to answer:
- *Which regmap is frozen?*
- *Which harness integration commit was last known-green?*
- *Which precheck run corresponds to which commits?*

Update policy:
- Only update this file when a baseline is intentionally (re)frozen.
- Every update should be part of the same PR/commit that creates the baseline (or immediately after, as an atomic follow-up).

---

## Regmap v1 freeze

- Status: **NOT_FROZEN / FROZEN**
- Freeze commit (chip-inventory): `TBD`
- Notes:
  - Source of truth: `spec/regmap_v1.yaml`
  - Freeze playbook: `docs/REGMAP_FREEZE_PLAYBOOK.md`

Checklist to claim **FROZEN**:
- `bash ops/regmap_update.sh`
- `make -C verify regmap-check`
- `make -C verify regmap-gen-check`

---

## RTL baseline ("last known good" for IP repo)

- Status: **TRACKING / FROZEN**
- Baseline commit (chip-inventory): `TBD`
- Gates that must be green at this commit:
  - `bash ops/preflight_low_disk.sh`
  - `make -C verify all`

---

## Harness integration baseline (last known good)

- Status: **TRACKING / FROZEN**
- Baseline commit (home-inventory-chip-openmpw): `TBD`
- Gates that must be green at this commit:
  - `make sync-ip-filelist`
  - `make rtl-compile-check`

---

## Precheck runs

Record each real precheck invocation as a row.

Format:
- Date (UTC)
- Result (PASS/FAIL)
- Harness commit
- IP commit
- Log reference (file/path/link)

Entries:
- (none yet)
