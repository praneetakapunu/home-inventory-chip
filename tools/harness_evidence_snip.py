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

Unlike naive grep, it *merges overlapping context windows* so one file with many
hits does not explode into dozens of near-identical blocks.

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


@dataclass(frozen=True)
class Hit:
    path: Path
    line_no: int
    line: str


@dataclass
class Block:
    path: Path
    lo: int
    hi: int
    hit_lines: List[int]


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


def read_lines(path: Path) -> List[str]:
    try:
        return path.read_text(errors="replace").splitlines()
    except Exception:
        return []


def merge_blocks_for_file(path: Path, hit_lines: List[int], context: int, total_lines: int) -> List[Block]:
    """Merge overlapping hit windows into blocks.

    Each hit proposes a window [hit-context, hit+context]. We merge any windows
    that overlap or touch.
    """
    if not hit_lines:
        return []

    hit_lines = sorted(set(hit_lines))

    windows: List[Tuple[int, int, int]] = []  # (lo, hi, hit_line)
    for ln in hit_lines:
        lo = max(1, ln - context)
        hi = min(total_lines, ln + context)
        windows.append((lo, hi, ln))

    windows.sort(key=lambda t: (t[0], t[1], t[2]))

    blocks: List[Block] = []
    cur_lo, cur_hi, _ = windows[0]
    cur_hits: List[int] = [windows[0][2]]

    for lo, hi, hit_ln in windows[1:]:
        if lo <= cur_hi + 1:
            cur_hi = max(cur_hi, hi)
            cur_hits.append(hit_ln)
        else:
            blocks.append(Block(path=path, lo=cur_lo, hi=cur_hi, hit_lines=sorted(set(cur_hits))))
            cur_lo, cur_hi = lo, hi
            cur_hits = [hit_ln]

    blocks.append(Block(path=path, lo=cur_lo, hi=cur_hi, hit_lines=sorted(set(cur_hits))))
    return blocks


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
    ap.add_argument("--max", type=int, default=120, help="max blocks to print")
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
    patterns: List[re.Pattern] = []
    for t in terms:
        if args.regex:
            patterns.append(re.compile(t, re.IGNORECASE))
        else:
            patterns.append(re.compile(re.escape(t), re.IGNORECASE))

    # First collect hits; keep scan deterministic.
    all_hits: List[Hit] = []
    for fp in iter_files(root, rel_dirs):
        all_hits.extend(find_hits(fp, patterns))

    all_hits.sort(key=lambda h: (str(h.path), h.line_no))

    # Convert hits -> merged blocks per file.
    blocks: List[Block] = []
    last_path: Path | None = None
    file_hit_lines: List[int] = []
    file_total_lines = 0

    def flush() -> None:
        nonlocal blocks, last_path, file_hit_lines, file_total_lines
        if last_path is None:
            return
        blocks.extend(merge_blocks_for_file(last_path, file_hit_lines, args.context, file_total_lines))
        last_path = None
        file_hit_lines = []
        file_total_lines = 0

    for h in all_hits:
        if last_path is None:
            last_path = h.path
            file_hit_lines = [h.line_no]
            file_total_lines = len(read_lines(h.path))
            if file_total_lines == 0:
                file_total_lines = h.line_no  # best-effort
            continue

        if h.path != last_path:
            flush()
            last_path = h.path
            file_hit_lines = [h.line_no]
            file_total_lines = len(read_lines(h.path))
            if file_total_lines == 0:
                file_total_lines = h.line_no
        else:
            file_hit_lines.append(h.line_no)

    flush()

    # Sort blocks by path then starting line.
    blocks.sort(key=lambda b: (str(b.path), b.lo, b.hi))

    if args.markdown:
        print("## Harness evidence snips")
        print(f"- Harness repo: `{root}`")
        print(f"- Dirs scanned: `{', '.join(rel_dirs) if rel_dirs else '(none)'}`")
        print(f"- Terms: `{', '.join(terms)}`")
        print(f"- Total hits: **{len(all_hits)}**")
        print(f"- Total blocks (merged): **{len(blocks)}**")
        print()
    else:
        print("== Harness evidence snips ==")
        print(f"Harness repo: {root}")
        print(f"Dirs scanned: {', '.join(rel_dirs) if rel_dirs else '(none)'}")
        print(f"Terms: {', '.join(terms)}")
        print(f"Total hits: {len(all_hits)}")
        print(f"Total blocks (merged): {len(blocks)}")
        print()

    shown = 0
    for b in blocks:
        if shown >= args.max:
            print(f"(stopping at --max {args.max})")
            break

        lines = read_lines(b.path)
        rel = b.path.relative_to(root)
        hits = set(b.hit_lines)

        if args.markdown:
            hit_list = ",".join(str(x) for x in b.hit_lines)
            print(f"- Source: `{rel}:{b.lo}-{b.hi}` (hit lines: {hit_list})")
            print("```text")
            for ln in range(b.lo, b.hi + 1):
                txt = lines[ln - 1] if 1 <= ln <= len(lines) else ""
                marker = ">" if ln in hits else " "
                print(f"{marker} {ln:4d}: {txt}")
            print("```")
            print()
        else:
            hit_list = ",".join(str(x) for x in b.hit_lines)
            print(f"--- Source: {rel}:{b.lo}-{b.hi} (hit lines: {hit_list}) ---")
            for ln in range(b.lo, b.hi + 1):
                txt = lines[ln - 1] if 1 <= ln <= len(lines) else ""
                marker = ">" if ln in hits else " "
                print(f"{marker} {ln:4d}: {txt}")
            print()

        shown += 1

    tip = "Tip: paste a `Source: path:line` entry plus the excerpt into the decision record."
    print(tip)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
