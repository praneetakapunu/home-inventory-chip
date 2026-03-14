#!/usr/bin/env python3
"""Generate a C header from spec/regmap_v1.yaml.

Goal: give firmware a single, copy/paste-able set of register offsets and bitfield
masks without hand-transcribing tables.

This is intentionally simple and stable:
- emits #define HIP_REG_<REGNAME> <addr>
- emits #define HIP_<REGNAME>_<FIELD>_SHIFT / _MASK for bitfields

Usage:
  python3 tools/regmap/gen_c_header.py \
    --in spec/regmap_v1.yaml \
    --out spec/regmap_v1.h

Note: addresses are byte addresses (Wishbone wbs_adr_i).
"""

from __future__ import annotations

import argparse
import datetime
from pathlib import Path

try:
    import yaml  # type: ignore
except Exception as e:
    raise SystemExit(
        "PyYAML is required to run this generator. Install with: pip install pyyaml\n"
        f"Original import error: {e}"
    )


def u32_hex(x: int) -> str:
    return f"0x{x:08X}u"


def sanitize(name: str) -> str:
    out = []
    for ch in name:
        if ch.isalnum():
            out.append(ch.upper())
        else:
            out.append("_")
    s = "".join(out)
    while "__" in s:
        s = s.replace("__", "_")
    return s.strip("_")


def bits_to_shift_mask(bits) -> tuple[int, int]:
    # bits: [msb, lsb]
    msb, lsb = int(bits[0]), int(bits[1])
    if msb < lsb:
        msb, lsb = lsb, msb
    width = msb - lsb + 1
    mask = ((1 << width) - 1) << lsb
    return lsb, mask


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", dest="outp", required=True)
    args = ap.parse_args()

    inp = Path(args.inp)
    outp = Path(args.outp)

    data = yaml.safe_load(inp.read_text())

    version = data.get("version")
    blocks = data.get("blocks", [])

    lines: list[str] = []
    lines.append("// AUTO-GENERATED FILE. DO NOT EDIT BY HAND.")
    lines.append(f"// Source: {inp.as_posix()}")
    now_utc = datetime.datetime.now(datetime.UTC)
    lines.append(f"// Generated: {now_utc.isoformat(timespec='seconds').replace('+00:00','Z')}")
    lines.append(f"// Regmap version: {version}")
    lines.append("")
    guard = "HIP_REGMAP_V1_H_"
    lines.append(f"#ifndef {guard}")
    lines.append(f"#define {guard}")
    lines.append("")
    lines.append("#include <stdint.h>")
    lines.append("")
    lines.append("// All addresses are byte offsets from the IP base address.")
    lines.append("")

    for blk in blocks:
        blk_name = blk.get("name", "")
        base = int(blk.get("base", 0), 0) if isinstance(blk.get("base"), str) else int(blk.get("base", 0))
        regs = blk.get("registers", [])

        lines.append(f"// ---- block: {blk_name} (base {u32_hex(base)}) ----")
        for reg in regs:
            rname = sanitize(reg["name"])
            offset = int(reg.get("offset", 0), 0) if isinstance(reg.get("offset"), str) else int(reg.get("offset", 0))
            addr = base + offset
            lines.append(f"#define HIP_REG_{rname:<24} {u32_hex(addr)}")

            fields = reg.get("fields")
            if fields:
                for f in fields:
                    fname = sanitize(f["name"])
                    shift, mask = bits_to_shift_mask(f["bits"])
                    lines.append(f"#define HIP_{rname}_{fname}_SHIFT{'' :<8} {shift}u")
                    lines.append(f"#define HIP_{rname}_{fname}_MASK{'' :<9} {u32_hex(mask)}")

        lines.append("")

    lines.append("#endif")
    lines.append("")

    outp.write_text("\n".join(lines))


if __name__ == "__main__":
    main()
