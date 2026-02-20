#!/usr/bin/env python3
"""Validate spec/regmap_v1.yaml for internal consistency.

This is intentionally dependency-light (PyYAML only).

Usage:
  python3 ops/regmap_validate.py --yaml spec/regmap_v1.yaml

Checks:
- All register addresses are unique.
- All register addresses are 32-bit word-aligned.
- Register and field access types are from an allowed set.
- Reset values (when present) are valid 32-bit quantities.
- Field bit ranges are sane (0..31, msb>=lsb).
- Fields within a register do not overlap.
"""

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any, Dict, List, Tuple

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


_ALLOWED_REG_ACCESS = {"ro", "rw", "ro_w1c"}
_ALLOWED_FIELD_ACCESS = {"ro", "rw", "w1p", "w1c"}


def _check_u32(val: int) -> bool:
    return 0 <= val <= 0xFFFF_FFFF


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yaml", required=True, type=Path)
    args = ap.parse_args()

    spec = _load_yaml(args.yaml)

    errs: List[str] = []

    addrs: List[Tuple[str, int]] = []

    for blk in spec.get("blocks", []):
        bname = blk.get("name", "<unnamed>")
        base = _parse_int(blk.get("base", 0))

        for reg in blk.get("registers", []):
            rname = reg.get("name")
            if not rname:
                errs.append(f"Block {bname}: register missing name")
                continue

            # Access + reset validation
            racc = reg.get("access")
            if racc not in _ALLOWED_REG_ACCESS:
                errs.append(
                    f"{bname}.{rname}: invalid access {racc!r} (allowed: {', '.join(sorted(_ALLOWED_REG_ACCESS))})"
                )

            rreset = reg.get("reset", None)
            if rreset is None:
                pass
            else:
                try:
                    rr = _parse_int(rreset)
                    if not _check_u32(rr):
                        errs.append(f"{bname}.{rname}: reset out of u32 range: {rreset!r}")
                except Exception as e:
                    errs.append(f"{bname}.{rname}: invalid reset {rreset!r}: {e}")

            offset = _parse_int(reg.get("offset", 0))
            addr = base + offset

            if addr % 4 != 0:
                errs.append(f"{bname}.{rname}: address 0x{addr:08X} not 32-bit aligned")

            addrs.append((f"{bname}.{rname}", addr))

            # Fields
            used_mask = 0
            for f in reg.get("fields", []) or []:
                fname = f.get("name", "<unnamed>")

                facc = f.get("access")
                if facc not in _ALLOWED_FIELD_ACCESS:
                    errs.append(
                        f"{bname}.{rname}.{fname}: invalid access {facc!r} (allowed: {', '.join(sorted(_ALLOWED_FIELD_ACCESS))})"
                    )

                fres = f.get("reset", None)
                if fres is None:
                    pass
                else:
                    try:
                        fr = _parse_int(fres)
                        # field reset is allowed to be a small integer; still must fit u32
                        if not _check_u32(fr):
                            errs.append(f"{bname}.{rname}.{fname}: reset out of u32 range: {fres!r}")
                    except Exception as e:
                        errs.append(f"{bname}.{rname}.{fname}: invalid reset {fres!r}: {e}")

                bits = f.get("bits")
                if not (isinstance(bits, list) and len(bits) == 2):
                    errs.append(f"{bname}.{rname}.{fname}: bits must be [msb, lsb]")
                    continue
                msb, lsb = int(bits[0]), int(bits[1])

                if not (0 <= lsb <= 31 and 0 <= msb <= 31):
                    errs.append(f"{bname}.{rname}.{fname}: bit range out of 0..31: {msb}:{lsb}")
                    continue
                if msb < lsb:
                    errs.append(f"{bname}.{rname}.{fname}: msb<lsb: {msb}:{lsb}")
                    continue

                width = msb - lsb + 1
                mask = ((1 << width) - 1) << lsb

                if used_mask & mask:
                    errs.append(f"{bname}.{rname}: field overlap at {fname} ({msb}:{lsb})")
                used_mask |= mask

    # Uniqueness of addresses
    seen = {}
    for name, addr in addrs:
        if addr in seen:
            errs.append(f"Address collision: 0x{addr:08X} used by {seen[addr]} and {name}")
        else:
            seen[addr] = name

    if errs:
        print("regmap_validate: FAIL")
        for e in errs:
            print("- " + e)
        return 1

    print(f"regmap_validate: OK ({len(addrs)} registers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
