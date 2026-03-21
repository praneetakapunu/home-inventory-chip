# Evidence capture (review-friendly)

Goal: for any “gate” (preflight scripts, shuttle lock, precheck), capture enough evidence so a reviewer can confirm status **without rerunning tools**.

## Tool: `ops/capture_gate_evidence.sh`

Append a structured evidence snippet to `reports/YYYY-MM-DD.md`.

### Usage

```bash
bash ops/capture_gate_evidence.sh "<label>" -- <command...>
```

### Examples

Capture a low-disk preflight run:

```bash
bash ops/capture_gate_evidence.sh "preflight_low_disk" -- bash ops/preflight_low_disk.sh
```

Capture the strict shuttle lock record check:

```bash
bash ops/capture_gate_evidence.sh "shuttle_lock_record_strict" -- bash ops/check_shuttle_lock_record.sh --strict
```

Capture a harness placeholder suite run (from IP repo):

```bash
bash ops/capture_gate_evidence.sh "harness_placeholder_suite" -- bash tools/harness_placeholder_suite.sh ../home-inventory-chip-openmpw
```

## Minimum standard (what every snippet should include)

Automatically captured by the script:
- time (UTC)
- repo path + current git branch/commit
- exact command
- exit code
- relevant stdout/stderr (tail-truncated if long)

If you *don’t* use the script, still ensure these are present in `reports/YYYY-MM-DD.md`.
