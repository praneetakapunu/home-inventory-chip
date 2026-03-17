#!/usr/bin/env python3
"""Low-disk helper to capture *committable evidence snippets* from the harness repo.

Goal
----
When we need to lock something (e.g., ADC CLKIN source/frequency), we want a quick,
reproducible way to extract small excerpts with file:line numbers that can be
pasted into chip-inventory decision records.

This script:
- recursively scans a small set of harness directories (docs/verilog by default)
- searches for a set of keywords
- prints short context excerpts with 1-indexed line numbers

Usage
-----
  tools/harness_evidence_snip.py [PATH_TO_HARNESS_REPO] [--terms t1,t2,...] [--regex]

Examples
--------
  tools/harness_evidence_snip.py ../home-inventory-chip-openmpw
  tools/harness_evidence_snip.py ../home-inventory-chip-openmpw --terms adc_clkin,CLKIN,frequency
  tools/harness_evidence_snip.py ../home-inventory-chip-openmpw --terms "adc_clkin|CLKIN" --regex
  tools/harness_evidence_snip.py ../home-inventory-chip-openmpw --markdown > /tmp/harness_snips.md

Notes
-----
- Stdlib-only; intended to run in low-disk environments.
- This is *not* a replacement for schematics; it just surfaces any already-committed
  assumptions in the harness repo.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple


DEFAULT_DIRS = ["docs", "verilog"]
DEFAULT_TERMS = [
    "USE_REAL_ADC_INGEST",
    "adc_clkin",
    "CLKIN",
    "oscillator",
    "frequency",
    "MHz",
    "kHz",
    "DRDY",
    "adc_drdy",
    "adc_rst",
    "pinout",
    "io[??]",
    "io[",
]

# Keep scan small and deterministic.
SKIP_DIR_NAMES = {"lvs", ".git", "node_modules", "venv", "build"}
SKIP_EXTS = {".spice", ".gds", ".lef", ".def", ".o", ".a"}


@dataclass
class Hit:
    path: Path
    line_no: int
    line: str


def iter_files(root: Path, rel_dirs: List[str]) -> Iterable[Path]:
    for d in rel_dirs:
        base = root / d
        if not base.exists():
            continue
        for dirpath, dirnames, filenames in os.walk(base):
            # Prune heavy dirs
            dirnames[:] = [dn for dn in dirnames if dn not in SKIP_DIR_NAMES]
            for fn in filenames:
                p = Path(dirpath) / fn
                if p.suffix in SKIP_EXTS:
                    continue
                # Skip clearly-binary-ish artifacts by extension
                yield p


def find_hits(path: Path, patterns: List[re.Pattern]) -> List[Hit]:
    hits: List[Hit] = []
    try:
        text = path.read_text(errors="replace")
    except Exception:
        return hits

    for i, line in enumerate(text.splitlines(), start=1):
        for pat in patterns:
            if pat.search(line):
                hits.append(Hit(path=path, line_no=i, line=line.rstrip("\n")))
                break
    return hits


def excerpt(path: Path, center_line: int, context: int) -> Tuple[int, int, List[str]]:
    try:
        lines = path.read_text(errors="replace").splitlines()
    except Exception:
        return center_line, center_line, []

    lo = max(1, center_line - context)
    hi = min(len(lines), center_line + context)
    return lo, hi, lines[lo - 1 : hi]


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("harness_repo", nargs="?", default="../home-inventory-chip-openmpw")
    ap.add_argument("--dirs", default=",".join(DEFAULT_DIRS), help="comma-separated subdirs to scan")
    ap.add_argument(
        "--terms",
        default=",".join(DEFAULT_TERMS),
        help="comma-separated search terms (treated as literal strings unless --regex is set)",
    )
    ap.add_argument(
        "--regex",
        action="store_true",
        help="treat --terms as regex patterns (case-insensitive); otherwise terms are literals",
    )
    ap.add_argument("--context", type=int, default=2, help="lines of context before/after")
    ap.add_argument("--max", type=int, default=120, help="max hits to print")
    ap.add_argument(
        "--markdown",
        action="store_true",
        help="print results in markdown (paste-ready) instead of plain text",
    )
    args = ap.parse_args(argv)

    root = Path(args.harness_repo).resolve()
    if not root.exists() or not root.is_dir():
        print(f"ERROR: harness repo not found at: {root}", file=sys.stderr)
        return 2

    rel_dirs = [d.strip() for d in args.dirs.split(",") if d.strip()]
    terms = [t.strip() for t in args.terms.split(",") if t.strip()]

    # By default treat terms as literals (fast, predictable). Use --regex for power users.
    patterns = []
    for t in terms:
        if args.regex:
            patterns.append(re.compile(t, re.IGNORECASE))
        else:
            patterns.append(re.compile(re.escape(t), re.IGNORECASE))

    all_hits: List[Hit] = []
    for fp in iter_files(root, rel_dirs):
        all_hits.extend(find_hits(fp, patterns))

    # Sort by path then line
    all_hits.sort(key=lambda h: (str(h.path), h.line_no))

    if args.markdown:
        print("## Harness evidence snips")
        print(f"- Harness repo: `{root}`")
        print(f"- Dirs scanned: `{', '.join(rel_dirs) if rel_dirs else '(none)'}`")
        print(f"- Terms: `{', '.join(terms)}`")
        print(f"- Total hits: **{len(all_hits)}**")
        print()
    else:
        print(f"== Harness evidence snips ==")
        print(f"Harness repo: {root}")
        print(f"Dirs scanned: {', '.join(rel_dirs) if rel_dirs else '(none)'}")
        print(f"Terms: {', '.join(terms)}")
        print(f"Total hits: {len(all_hits)}")
        print()

    shown = 0
    last_key = None
    for h in all_hits:
        if shown >= args.max:
            print(f"(stopping at --max {args.max})")
            break

        key = (h.path, h.line_no)
        if key == last_key:
            continue
        last_key = key

        lo, hi, lines = excerpt(h.path, h.line_no, args.context)
        rel = h.path.relative_to(root)

        if args.markdown:
            print(f"- Source: `{rel}:{h.line_no}` (showing {lo}-{hi})")
            print("```text")
            for ln, txt in enumerate(lines, start=lo):
                marker = ">" if ln == h.line_no else " "
                print(f"{marker} {ln:4d}: {txt}")
            print("```")
            print()
        else:
            print(f"--- Source: {rel}:{h.line_no} (showing {lo}-{hi}) ---")
            for ln, txt in enumerate(lines, start=lo):
                marker = ">" if ln == h.line_no else " "
                print(f"{marker} {ln:4d}: {txt}")
            print()

        shown += 1

    if args.markdown:
        print("Tip: paste a `Source: path:line` entry plus the excerpt into the decision record.")
    else:
        print("Tip: paste the 'Source: path:line' plus the relevant excerpt into the decision record.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
