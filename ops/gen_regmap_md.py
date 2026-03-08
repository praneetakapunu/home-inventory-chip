#!/usr/bin/env python3
"""Generate a Markdown register map table from spec/regmap_v1.yaml.

Goal:
- Keep a mechanically-generated, reviewable Markdown view of the YAML source-of-truth.
- Be dependency-light (PyYAML only).

Usage:
  python3 ops/gen_regmap_md.py --yaml spec/regmap_v1.yaml --out spec/regmap_v1_table.md

This generator is intentionally minimal: it produces per-block address tables and
per-register field tables when fields exist.

The hand-written narrative doc remains at spec/regmap.md.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Dict

import yaml


def _load_yaml(path: Path) -> Dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("YAML top-level must be a mapping")
    return data


def _parse_int(x: Any) -> int:
    if isinstance(x, int):
        return x
    if isinstance(x, str):
        return int(x, 16) if x.startswith("0x") else int(x)
    raise TypeError(f"Unsupported int value: {x!r}")


def _fmt_reset(x: Any) -> str:
    if x is None:
        return "—"
    try:
        val = _parse_int(x)
        return f"0x{val:08X}"
    except Exception:
        return str(x)


def _md_escape(s: str) -> str:
    # Very small escaping set for Markdown tables.
    return s.replace("|", "\\|").replace("\n", " ").strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yaml", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    spec = _load_yaml(args.yaml)

    lines: list[str] = []
    lines.append("# Register Map Table (generated)")
    lines.append("")
    lines.append("This file is **auto-generated** from `spec/regmap_v1.yaml`. Do not edit by hand.")
    lines.append("")
    lines.append(f"- Source: `{args.yaml.as_posix()}`")
    lines.append(f"- Version: {spec.get('version', '—')}")

    bus = spec.get("bus", {}) or {}
    if isinstance(bus, dict):
        lines.append(f"- Bus: {bus.get('type', '—')} ({bus.get('data_width', '—')}-bit)")
        lines.append(f"- Address unit: {bus.get('addr_unit', '—')}; word_align: {bus.get('word_align', '—')}")

    lines.append("")

    for blk in spec.get("blocks", []) or []:
        if not isinstance(blk, dict):
            continue
        bname = blk.get("name", "<unnamed>")
        base = _parse_int(blk.get("base", 0))

        lines.append(f"## 0x{base:08X} — {bname}")
        lines.append("")
        lines.append("| Address | Name | Access | Reset | Description |")
        lines.append("|---:|---|---|---:|---|")

        regs = blk.get("registers", []) or []
        for reg in regs:
            if not isinstance(reg, dict):
                continue
            rname = reg.get("name", "<unnamed>")
            offset = _parse_int(reg.get("offset", 0))
            addr = base + offset
            access = reg.get("access", "—")
            reset = _fmt_reset(reg.get("reset", None))
            desc = _md_escape(str(reg.get("desc", "")))
            lines.append(f"| 0x{addr:08X} | `{rname}` | {access} | {reset} | {desc} |")

        lines.append("")

        # Field tables
        for reg in regs:
            if not isinstance(reg, dict):
                continue
            fields = reg.get("fields", None)
            if not fields:
                continue
            rname = reg.get("name", "<unnamed>")
            offset = _parse_int(reg.get("offset", 0))
            addr = base + offset

            lines.append(f"### `{rname}` fields @ 0x{addr:08X}")
            lines.append("")
            lines.append("| Bits | Field | Access | Reset | Description |")
            lines.append("|---:|---|---|---:|---|")

            for f in fields:
                if not isinstance(f, dict):
                    continue
                bits = f.get("bits", ["?", "?"])
                if isinstance(bits, list) and len(bits) == 2:
                    msb, lsb = bits[0], bits[1]
                    bit_str = f"{msb}:{lsb}" if msb != lsb else f"{msb}"
                else:
                    bit_str = "?"
                fname = f.get("name", "<unnamed>")
                facc = f.get("access", "—")
                fres = _fmt_reset(f.get("reset", None))
                fdesc = _md_escape(str(f.get("desc", "")))
                lines.append(f"| {bit_str} | `{fname}` | {facc} | {fres} | {fdesc} |")

            lines.append("")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
