#!/usr/bin/env python3
"""Generate the firmware C header from spec/regmap_v1.yaml.

Why:
- Avoid spec/RTL/DV/FW drift.
- Keep bring-up software usable early.

Usage:
  python3 ops/gen_regmap_header.py \
    --yaml spec/regmap_v1.yaml \
    --out  fw/include/home_inventory_regmap.h
"""

from __future__ import annotations

import argparse
import datetime as _dt
from pathlib import Path
from typing import Any, Dict, List, Tuple

import yaml

PREFIX = "HOMEINV"


def _hex32(x: int) -> str:
    return f"0x{x:08X}u"


def _field_mask(msb: int, lsb: int) -> int:
    width = msb - lsb + 1
    return ((1 << width) - 1) << lsb


def _load_yaml(path: Path) -> Dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("YAML top-level must be a mapping")
    return data


def _collect_registers(spec: Dict[str, Any]) -> List[Tuple[str, int, Dict[str, Any]]]:
    out: List[Tuple[str, int, Dict[str, Any]]] = []
    for blk in spec.get("blocks", []):
        base = int(blk["base"], 16) if isinstance(blk.get("base"), str) else int(blk.get("base", 0))
        for reg in blk.get("registers", []):
            name = reg["name"]
            offset = int(reg["offset"], 16) if isinstance(reg.get("offset"), str) else int(reg.get("offset", 0))
            addr = base + offset
            out.append((name, addr, reg))
    return out


def _emit(spec_path: Path, spec: Dict[str, Any]) -> str:
    regs = _collect_registers(spec)
    regs_sorted = sorted(regs, key=lambda t: t[1])

    # Header prelude
    lines: List[str] = []
    # NOTE: keep output deterministic so CI can diff the generated header
    # against the committed version without timestamp churn.

    gen_from = "spec/regmap_v1.yaml" if spec_path.name == "regmap_v1.yaml" else spec_path.as_posix()

    lines += [
        "// home_inventory_regmap.h",
        "//",
        "// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.",
        f"// Generated from: {gen_from}",
        "// Generated at:   (omitted for deterministic builds)",
        "//",
        "// Notes:",
        "//   - Offsets are byte offsets (Wishbone byte addresses).",
        "//   - Registers are 32-bit.",
        "//   - wbs_sel_i byte-enables must be honored on writes.",
        "//",
        "#pragma once",
        "",
        "#include <stdint.h>",
        "",
    ]

    # Register defines
    lines += ["// -----------------------------", "// Registers (byte offsets)", "// -----------------------------"]
    for name, addr, _reg in regs_sorted:
        lines.append(f"#define {PREFIX}_REG_{name:<16} {_hex32(addr)}")

    # Field defines
    lines += [
        "",
        "// -----------------------------",
        "// Bitfields",
        "// -----------------------------",
    ]

    for reg_name, _addr, reg in regs_sorted:
        fields = reg.get("fields")
        if not fields:
            continue
        lines += ["", f"// {reg_name} fields"]
        for f in fields:
            fname = f["name"]
            bits = f["bits"]
            if not (isinstance(bits, list) and len(bits) == 2):
                raise ValueError(f"Field bits for {reg_name}.{fname} must be [msb, lsb]")
            msb, lsb = int(bits[0]), int(bits[1])

            # Single-bit
            if msb == lsb:
                lines.append(f"#define {PREFIX}_{reg_name}_{fname}_BIT   {lsb}u")
                lines.append(
                    f"#define {PREFIX}_{reg_name}_{fname}_MASK  (1u << {PREFIX}_{reg_name}_{fname}_BIT)"
                )
            else:
                mask = _field_mask(msb, lsb)
                lines.append(f"#define {PREFIX}_{reg_name}_{fname}_LSB   {lsb}u")
                lines.append(f"#define {PREFIX}_{reg_name}_{fname}_MASK  {_hex32(mask)}")

    # Handy constants section (kept tiny)
    lines += [
        "",
        "// -----------------------------",
        "// Handy constants",
        "// -----------------------------",
        "// Q16.16 representation of 1.0 (matches SCALE_CHx reset)",
        f"#define {PREFIX}_SCALE_Q16_16_ONE  0x00010000u",
        "",
    ]

    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yaml", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    args = ap.parse_args()

    spec_path: Path = args.yaml
    out_path: Path = args.out

    spec = _load_yaml(spec_path)

    # Minimal sanity checks
    if spec.get("version") != 1:
        raise SystemExit(f"Unexpected regmap version: {spec.get('version')}")
    if spec.get("bus", {}).get("type") != "wishbone":
        raise SystemExit("Only wishbone bus supported by this generator")

    text = _emit(spec_path, spec)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(text + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
