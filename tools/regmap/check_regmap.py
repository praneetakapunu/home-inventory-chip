#!/usr/bin/env python3
"""check_regmap.py

Purpose:
  Keep RTL decode constants (localparam ADR_*) in sync with the single
  source-of-truth register map (spec/regmap_v1.yaml).

Checks:
  - YAML register addresses are unique and 32-bit word-aligned
  - Each YAML register has a corresponding ADR_* localparam in RTL
  - Each RTL ADR_* localparam corresponds to a YAML register
  - Addresses match exactly (byte address)

Usage:
  python3 tools/regmap/check_regmap.py \
    --yaml spec/regmap_v1.yaml \
    --rtl  rtl/home_inventory_wb.v

Exit codes:
  0 on success, non-zero on mismatch.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

import yaml


ADR_RE = re.compile(
    r"^\s*localparam\s+\[[^\]]+\]\s+(ADR_[A-Z0-9_]+)\s*=\s*32'h([0-9A-Fa-f_]+)\s*;\s*$"
)


@dataclass(frozen=True)
class Problem:
    kind: str
    msg: str


def load_yaml_regs(yaml_path: Path) -> Dict[str, int]:
    data = yaml.safe_load(yaml_path.read_text())
    if not isinstance(data, dict) or "blocks" not in data:
        raise ValueError(f"Unexpected YAML shape in {yaml_path}")

    regs: Dict[str, int] = {}
    problems: List[Problem] = []

    for blk in data.get("blocks", []):
        base = int(str(blk.get("base", "0")), 0)
        for r in blk.get("registers", []):
            name = r.get("name")
            if not name:
                problems.append(Problem("yaml", f"register missing name in block {blk.get('name')!r}"))
                continue
            offset = int(str(r.get("offset", "0")), 0)
            addr = base + offset
            key = f"ADR_{name}"
            if key in regs:
                problems.append(Problem("yaml", f"duplicate register name {name} (key {key})"))
                continue
            regs[key] = addr

            if addr % 4 != 0:
                problems.append(Problem("yaml", f"{name} address 0x{addr:08X} not word-aligned"))

    # also ensure unique addresses
    addr_to_keys: Dict[int, List[str]] = {}
    for k, a in regs.items():
        addr_to_keys.setdefault(a, []).append(k)
    for a, ks in addr_to_keys.items():
        if len(ks) > 1:
            problems.append(Problem("yaml", f"duplicate address 0x{a:08X}: {', '.join(sorted(ks))}"))

    if problems:
        for p in problems:
            print(f"ERROR[{p.kind}]: {p.msg}", file=sys.stderr)
        raise SystemExit(2)

    return regs


def _read_rtl_with_includes(path: Path, *, _seen: set[Path] | None = None) -> str:
    """Return RTL text with simple `include expansion.

    We expand `include "..." directives so ADR_* localparams can live in a
    generated include file.

    Rules:
      - Only quote-form includes are supported.
      - Include paths are resolved relative to the including file.
      - Cycles are detected and rejected.
    """

    if _seen is None:
        _seen = set()
    path = path.resolve()
    if path in _seen:
        raise ValueError(f"include cycle detected at {path}")
    _seen.add(path)

    out_lines: list[str] = []
    inc_re = re.compile(r"^\s*`include\s+\"([^\"]+)\"\s*$")

    for line in path.read_text().splitlines():
        m = inc_re.match(line)
        if not m:
            out_lines.append(line)
            continue
        inc_path = (path.parent / m.group(1)).resolve()
        out_lines.append(f"// BEGIN_INCLUDE {inc_path}")
        out_lines.append(_read_rtl_with_includes(inc_path, _seen=_seen))
        out_lines.append(f"// END_INCLUDE {inc_path}")

    return "\n".join(out_lines) + "\n"


def load_rtl_adrs(rtl_path: Path) -> Dict[str, int]:
    regs: Dict[str, int] = {}
    problems: List[Problem] = []

    try:
        rtl_text = _read_rtl_with_includes(rtl_path)
    except Exception as e:
        problems.append(Problem("rtl", f"failed to read RTL/includes: {e}"))
        rtl_text = ""

    for ln, line in enumerate(rtl_text.splitlines(), start=1):
        m = ADR_RE.match(line)
        if not m:
            continue
        name, hexv = m.group(1), m.group(2)
        hexv = hexv.replace("_", "")
        addr = int(hexv, 16)
        if name in regs:
            problems.append(Problem("rtl", f"duplicate localparam {name} (expanded) at {rtl_path}:{ln}"))
            continue
        regs[name] = addr

    if not regs:
        problems.append(Problem("rtl", f"no ADR_* localparams found in {rtl_path} (after include expansion)"))

    if problems:
        for p in problems:
            print(f"ERROR[{p.kind}]: {p.msg}", file=sys.stderr)
        raise SystemExit(2)

    return regs


def diff_maps(yaml_regs: Dict[str, int], rtl_regs: Dict[str, int]) -> List[Problem]:
    problems: List[Problem] = []

    y_keys = set(yaml_regs.keys())
    r_keys = set(rtl_regs.keys())

    missing_in_rtl = sorted(y_keys - r_keys)
    extra_in_rtl = sorted(r_keys - y_keys)

    for k in missing_in_rtl:
        problems.append(Problem("mismatch", f"missing in RTL: {k} (expected 0x{yaml_regs[k]:08X})"))

    for k in extra_in_rtl:
        problems.append(Problem("mismatch", f"extra in RTL: {k} (has 0x{rtl_regs[k]:08X})"))

    for k in sorted(y_keys & r_keys):
        ya = yaml_regs[k]
        ra = rtl_regs[k]
        if ya != ra:
            problems.append(
                Problem(
                    "mismatch",
                    f"addr mismatch {k}: YAML=0x{ya:08X} RTL=0x{ra:08X}",
                )
            )

    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yaml", required=True, type=Path)
    ap.add_argument("--rtl", required=True, type=Path)
    args = ap.parse_args()

    yaml_regs = load_yaml_regs(args.yaml)
    rtl_regs = load_rtl_adrs(args.rtl)

    problems = diff_maps(yaml_regs, rtl_regs)
    if problems:
        for p in problems:
            print(f"ERROR[{p.kind}]: {p.msg}", file=sys.stderr)
        return 1

    # lightweight summary for CI logs
    print(f"OK: {len(yaml_regs)} regs match between {args.yaml} and {args.rtl}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
