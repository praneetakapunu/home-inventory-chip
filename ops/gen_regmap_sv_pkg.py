#!/usr/bin/env python3
"""Generate a SystemVerilog package with regmap constants.

Why:
- Let RTL/DV import a *single*, spec-derived set of addresses + bitfield masks.
- Avoid YAML/RTL drift while keeping the RTL readable.

Usage:
  python3 ops/gen_regmap_sv_pkg.py \
    --yaml spec/regmap_v1.yaml \
    --out  rtl/include/home_inventory_regmap_pkg.sv

Notes:
- Output is deterministic (no timestamps) so CI can diff it.
- Addresses are byte addresses (Wishbone wbs_adr_i).
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Dict, List, Tuple

import yaml

PKG_NAME = "home_inventory_regmap_pkg"
PREFIX = "HOMEINV"


def _hex32(x: int) -> str:
    return f"32'h{x:08X}"


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
    regs = sorted(_collect_registers(spec), key=lambda t: t[1])

    gen_from = "spec/regmap_v1.yaml" if spec_path.name == "regmap_v1.yaml" else spec_path.as_posix()

    lines: List[str] = []
    lines += [
        "// home_inventory_regmap_pkg.sv",
        "//",
        "// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.",
        f"// Generated from: {gen_from}",
        "// Generated at:   (omitted for deterministic builds)",
        "//",
        "// Notes:",
        "//   - Addresses are byte addresses (Wishbone wbs_adr_i).",
        "//   - Registers are 32-bit.",
        "",
        "package " + PKG_NAME + ";",
        "",
        "  // -----------------------------",
        "  // Registers (byte addresses)",
        "  // -----------------------------",
    ]

    for name, addr, _reg in regs:
        lines.append(f"  localparam logic [31:0] {PREFIX}_ADR_{name} = {_hex32(addr)};")

    lines += [
        "",
        "  // -----------------------------",
        "  // Bitfields",
        "  // -----------------------------",
    ]

    for reg_name, _addr, reg in regs:
        fields = reg.get("fields")
        if not fields:
            continue
        lines += ["", f"  // {reg_name} fields"]
        for f in fields:
            fname = f["name"]
            bits = f["bits"]
            if not (isinstance(bits, list) and len(bits) == 2):
                raise ValueError(f"Field bits for {reg_name}.{fname} must be [msb, lsb]")
            msb, lsb = int(bits[0]), int(bits[1])

            if msb == lsb:
                lines.append(f"  localparam int unsigned {PREFIX}_{reg_name}_{fname}_BIT = {lsb};")
                lines.append(
                    f"  localparam logic [31:0] {PREFIX}_{reg_name}_{fname}_MASK = (32'h1 << {PREFIX}_{reg_name}_{fname}_BIT);"
                )
            else:
                mask = _field_mask(msb, lsb)
                lines.append(f"  localparam int unsigned {PREFIX}_{reg_name}_{fname}_LSB  = {lsb};")
                lines.append(f"  localparam logic [31:0] {PREFIX}_{reg_name}_{fname}_MASK = {_hex32(mask)};")

    lines += [
        "",
        "  // -----------------------------",
        "  // Handy constants",
        "  // -----------------------------",
        "  // Q16.16 representation of 1.0 (matches SCALE_CHx reset)",
        "  localparam logic [31:0] HOMEINV_SCALE_Q16_16_ONE = 32'h0001_0000;",
        "",
        "endpackage",
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
