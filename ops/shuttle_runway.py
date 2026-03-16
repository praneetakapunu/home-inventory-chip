#!/usr/bin/env python3
"""Compute simple runway metrics from docs/SHUTTLE_LOCK_RECORD.md.

Goal: make shuttle planning less hand-wavy.

- Parses the *canonical formatting* block from docs/SHUTTLE_LOCK_RECORD.md.
- Extracts the "Internal safe deadline ... utc:" value.
- Computes time remaining from now (UTC) and prints a short summary.

This is intentionally dependency-free (std lib only) so it runs in low-disk CI.

Usage:
  python3 ops/shuttle_runway.py
  python3 ops/shuttle_runway.py --record docs/SHUTTLE_LOCK_RECORD.md

Exit codes:
  0 = success
  2 = could not parse a usable internal-safe-deadline utc line
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import re
import sys


UTC_RE = re.compile(r"^\s*utc:\s*(?P<utc>.+?)\s*$")
LAST_VERIFIED_RE = re.compile(r"^\s*-\s*\*\*Last verified \(UTC\):\*\*\s*(?P<ts>.+?)\s*$")


def parse_utc(s: str) -> dt.datetime:
    """Parse a small set of UTC timestamp formats we use in docs.

    Accepted examples:
      - 2026-03-18 06:59Z
      - 2026-03-18 06:59:00Z
      - 2026-03-18T06:59Z
      - 2026-03-18T06:59:00Z
    """

    s = s.strip()

    # Accept common UTC suffixes.
    if s.upper().endswith(" UTC"):
        s = s[:-4]
    if s.endswith("Z"):
        s = s[:-1]

    # Normalize separators.
    s = s.replace("T", " ")

    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
        try:
            return dt.datetime.strptime(s, fmt).replace(tzinfo=dt.timezone.utc)
        except ValueError:
            pass

    raise ValueError(f"Unrecognized UTC timestamp format: {s!r}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--record",
        default="docs/SHUTTLE_LOCK_RECORD.md",
        help="Path to the shuttle lock record markdown file.",
    )
    ap.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON (still dependency-free).",
    )
    ap.add_argument(
        "--write-derived",
        action="store_true",
        help=(
            "Write the derived milestone dates back into the lock record (updates only the "
            "'Derived deadlines (internal; compute from the cutoff)' bullet lines)."
        ),
    )
    ap.add_argument(
        "--strict",
        action="store_true",
        help=(
            "Fail (exit 1) if the derived deadline is in the past, or if the lock record appears stale."
        ),
    )
    ap.add_argument(
        "--stale-days",
        type=int,
        default=7,
        help="In --strict mode, fail if 'Last verified (UTC)' is older than this many days.",
    )
    ap.add_argument(
        "--freeze-days",
        type=int,
        default=10,
        help="Days before deadline to target the internal freeze tag milestone.",
    )
    ap.add_argument(
        "--final-integration-days",
        type=int,
        default=5,
        help="Days before deadline to target the internal final-integration milestone.",
    )
    args = ap.parse_args()

    record_path = pathlib.Path(args.record)
    if not record_path.exists():
        print(f"ERROR: record not found: {record_path}", file=sys.stderr)
        return 2

    text = record_path.read_text(encoding="utf-8")

    # Parse 'Last verified (UTC)' so we can detect stale lock records.
    last_verified = None
    for line in text.splitlines():
        m = LAST_VERIFIED_RE.match(line)
        if m:
            try:
                last_verified = parse_utc(m.group("ts"))
            except ValueError:
                # Keep it non-fatal unless --strict; downstream will report it.
                last_verified = None
            break

    # Heuristic parse: find the 'Internal safe deadline' block and then the first `utc:` within it.
    anchor = "Internal safe deadline"
    pos = text.find(anchor)
    if pos < 0:
        print("ERROR: could not find 'Internal safe deadline' block in record", file=sys.stderr)
        return 2

    tail = text[pos:].splitlines()

    utc_line = None
    for line in tail:
        m = UTC_RE.match(line)
        if m:
            utc_line = m.group("utc")
            break

    if not utc_line:
        print(
            "ERROR: could not find a parsable 'utc:' line after 'Internal safe deadline'",
            file=sys.stderr,
        )
        return 2

    try:
        deadline = parse_utc(utc_line)
    except ValueError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    now = dt.datetime.now(tz=dt.timezone.utc)
    delta = deadline - now

    stale_days = None
    is_stale = False
    if last_verified is not None:
        stale_days = (now - last_verified).total_seconds() / 86400.0
        is_stale = stale_days > float(args.stale_days)

    # Compute human-ish breakdown.
    seconds = int(delta.total_seconds())
    sign = "" if seconds >= 0 else "-"
    seconds = abs(seconds)

    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes, _ = divmod(rem, 60)

    weeks = days / 7.0

    # Suggested internal milestones.
    #
    # These are intentionally simple (calendar-day offsets) and exist to reduce
    # hand-calculated drift across docs/.
    freeze_days = int(args.freeze_days)
    final_integration_days = int(args.final_integration_days)

    freeze_dt = deadline - dt.timedelta(days=freeze_days)
    final_integration_dt = deadline - dt.timedelta(days=final_integration_days)

    if args.write_derived:
        # Update only the derived milestone bullet lines in the record.
        # This keeps the canonical cutoff fields human-authored while ensuring
        # the planning dates don't drift.
        freeze_date = freeze_dt.strftime("%Y-%m-%d")
        final_integration_date = final_integration_dt.strftime("%Y-%m-%d")
        freeze_tag = f"v1-freeze-{freeze_date.replace('-', '')}"

        new_lines = []
        for line in text.splitlines():
            if line.startswith("- **Internal freeze tag (v1-freeze):**"):
                new_lines.append(
                    f"- **Internal freeze tag (v1-freeze):** {freeze_date} (tag: `{freeze_tag}`) *(derived)*"
                )
                continue
            if line.startswith("- **Internal final-integration target:**"):
                new_lines.append(
                    f"- **Internal final-integration target:** {final_integration_date} *(derived; keep margin before internal safe deadline)*"
                )
                continue
            new_lines.append(line)

        new_text = "\n".join(new_lines) + "\n"
        if new_text != text:
            record_path.write_text(new_text, encoding="utf-8")
            text = new_text
            print(f"WROTE: updated derived milestone dates in {record_path}")
        else:
            print(f"OK: derived milestone dates already up to date in {record_path}")

    if args.json:
        payload = {
            "record": str(record_path),
            "now_utc": now.strftime("%Y-%m-%d %H:%MZ"),
            "deadline_utc": deadline.strftime("%Y-%m-%d %H:%MZ"),
            "remaining_seconds": int(delta.total_seconds()),
            "remaining_days": int(delta.total_seconds() // 86400),
            "weeks": float(weeks) * (1.0 if delta.total_seconds() >= 0 else -1.0),
            "last_verified_utc": last_verified.strftime("%Y-%m-%d %H:%MZ") if last_verified else None,
            "stale_days": stale_days,
            "is_stale": is_stale,
            "suggested": {
                "freeze_days": freeze_days,
                "freeze_date": freeze_dt.strftime("%Y-%m-%d"),
                "final_integration_days": final_integration_days,
                "final_integration_date": final_integration_dt.strftime("%Y-%m-%d"),
            },
        }
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        print("Shuttle runway (from lock record)")
        print(f"  Record:        {record_path}")
        print(f"  Now UTC:        {now.strftime('%Y-%m-%d %H:%MZ')}")
        print(
            f"  Deadline:       {deadline.strftime('%Y-%m-%d %H:%MZ')}  (internal safe deadline)"
        )
        if last_verified is None:
            print("  Last verified:  (missing/unparsable)")
        else:
            print(f"  Last verified:  {last_verified.strftime('%Y-%m-%d %H:%MZ')}  (~{stale_days:.1f} days ago)")
        print(f"  Remaining:      {sign}{days}d {hours}h {minutes}m  (~{sign}{weeks:.1f} weeks)")

        if delta.total_seconds() < 0:
            print("  STATUS: deadline is in the past (record likely stale)")
        elif is_stale:
            print(
                f"  STATUS: lock record is stale (> {args.stale_days} days since verification). Re-check official schedule."
            )
        elif weeks < 2:
            print("  STATUS: extremely tight (<2 weeks). Freeze scope immediately.")
        elif weeks < 4:
            print("  STATUS: tight (<4 weeks). Avoid scope churn; prioritize precheck readiness.")
        else:
            print("  STATUS: reasonable runway (>=4 weeks). Still avoid address-map churn.")

        print("  Suggested internal milestones (derived):")
        print(
            f"    Freeze tag target:        {freeze_dt.strftime('%Y-%m-%d')}  (deadline - {freeze_days}d)"
        )
        print(
            f"    Final integration target: {final_integration_dt.strftime('%Y-%m-%d')}  (deadline - {final_integration_days}d)"
        )

    if args.strict:
        if delta.total_seconds() < 0:
            return 1
        if last_verified is None:
            print(
                "ERROR: lock record missing or has unparseable 'Last verified (UTC)' line",
                file=sys.stderr,
            )
            return 1
        if is_stale:
            print(
                f"ERROR: lock record stale (~{stale_days:.1f}d since verification; threshold={args.stale_days}d)",
                file=sys.stderr,
            )
            return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
