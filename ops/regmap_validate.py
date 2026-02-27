#!/usr/bin/env python3
"""Validate spec/regmap_v1.yaml for internal consistency.

This is intentionally dependency-light (PyYAML only).

Usage:
  python3 ops/regmap_validate.py --yaml spec/regmap_v1.yaml

Hard checks (FAIL):
- All register addresses are unique.
- All register addresses are 32-bit word-aligned.
- Block base addresses are 32-bit word-aligned.
- Register and field access types are from an allowed set.
- Reset values (when present) are valid 32-bit quantities.
- Field bit ranges are sane (0..31, msb>=lsb).
- Fields within a register do not overlap.
- Field access is compatible with the parent register access.
- When both register reset and field reset are provided, they must agree.

Soft checks (WARN):
- Register names should be globally unique.
- Every register should have a description string.

The WARN checks are printed but do not cause failure (so they can be rolled out
incrementally without blocking tapeout).
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


def _allowed_field_access_for_reg(reg_access: str) -> set[str]:
    # Keep this conservative; it can always be relaxed later.
    if reg_access == "ro":
        return {"ro"}
    if reg_access == "ro_w1c":
        return {"ro", "w1c"}
    if reg_access == "rw":
        return {"ro", "rw", "w1p", "w1c"}
    return set()


def _extract_bits(val: int, msb: int, lsb: int) -> int:
    width = msb - lsb + 1
    return (val >> lsb) & ((1 << width) - 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--yaml", required=True, type=Path)
    args = ap.parse_args()

    spec = _load_yaml(args.yaml)

    errs: List[str] = []
    warns: List[str] = []

    addrs: List[Tuple[str, int]] = []
    reg_names_global: Dict[str, str] = {}

    for blk in spec.get("blocks", []):
        bname = blk.get("name", "<unnamed>")
        base = _parse_int(blk.get("base", 0))

        if base % 4 != 0:
            errs.append(f"Block {bname}: base 0x{base:08X} not 32-bit aligned")

        for reg in blk.get("registers", []):
            rname = reg.get("name")
            if not rname:
                errs.append(f"Block {bname}: register missing name")
                continue

            fq = f"{bname}.{rname}"

            # Soft check: global uniqueness of register names
            prev = reg_names_global.get(rname)
            if prev is None:
                reg_names_global[rname] = fq
            else:
                warns.append(f"Register name reused: {rname!r} appears in {prev} and {fq}")

            # Soft check: description present
            desc = reg.get("desc")
            if not (isinstance(desc, str) and desc.strip()):
                warns.append(f"{fq}: missing/empty desc")

            # Access + reset validation
            racc = reg.get("access")
            if racc not in _ALLOWED_REG_ACCESS:
                errs.append(
                    f"{fq}: invalid access {racc!r} (allowed: {', '.join(sorted(_ALLOWED_REG_ACCESS))})"
                )

            rreset = reg.get("reset", None)
            rreset_int: int | None
            if rreset is None:
                rreset_int = None
            else:
                try:
                    rr = _parse_int(rreset)
                    if not _check_u32(rr):
                        errs.append(f"{fq}: reset out of u32 range: {rreset!r}")
                    rreset_int = rr
                except Exception as e:
                    errs.append(f"{fq}: invalid reset {rreset!r}: {e}")
                    rreset_int = None

            offset = _parse_int(reg.get("offset", 0))
            if offset % 4 != 0:
                errs.append(f"{fq}: offset 0x{offset:08X} not 32-bit aligned")

            addr = base + offset

            if addr % 4 != 0:
                errs.append(f"{fq}: address 0x{addr:08X} not 32-bit aligned")

            addrs.append((fq, addr))

            # Fields
            used_mask = 0
            allowed_field_acc = _allowed_field_access_for_reg(str(racc))

            for f in reg.get("fields", []) or []:
                fname = f.get("name", "<unnamed>")

                facc = f.get("access")
                if facc not in _ALLOWED_FIELD_ACCESS:
                    errs.append(
                        f"{fq}.{fname}: invalid access {facc!r} (allowed: {', '.join(sorted(_ALLOWED_FIELD_ACCESS))})"
                    )
                else:
                    if racc in _ALLOWED_REG_ACCESS and facc not in allowed_field_acc:
                        errs.append(f"{fq}.{fname}: field access {facc!r} incompatible with reg access {racc!r}")

                bits = f.get("bits")
                if not (isinstance(bits, list) and len(bits) == 2):
                    errs.append(f"{fq}.{fname}: bits must be [msb, lsb]")
                    continue
                msb, lsb = int(bits[0]), int(bits[1])

                if not (0 <= lsb <= 31 and 0 <= msb <= 31):
                    errs.append(f"{fq}.{fname}: bit range out of 0..31: {msb}:{lsb}")
                    continue
                if msb < lsb:
                    errs.append(f"{fq}.{fname}: msb<lsb: {msb}:{lsb}")
                    continue

                width = msb - lsb + 1
                mask = ((1 << width) - 1) << lsb

                if used_mask & mask:
                    errs.append(f"{fq}: field overlap at {fname} ({msb}:{lsb})")
                used_mask |= mask

                # Reset validation (field reset must fit the field width)
                fres = f.get("reset", None)
                if fres is None:
                    continue

                try:
                    fr = _parse_int(fres)
                    if not _check_u32(fr):
                        errs.append(f"{fq}.{fname}: reset out of u32 range: {fres!r}")
                        continue
                    if fr >= (1 << width):
                        errs.append(
                            f"{fq}.{fname}: reset 0x{fr:X} does not fit in field width {width} ({msb}:{lsb})"
                        )
                        continue

                    # If the parent register reset is present, it must match.
                    if rreset_int is not None:
                        r_field = _extract_bits(rreset_int, msb, lsb)
                        if r_field != fr:
                            errs.append(
                                f"{fq}.{fname}: field reset 0x{fr:X} disagrees with reg reset bits 0x{r_field:X}"
                            )
                except Exception as e:
                    errs.append(f"{fq}.{fname}: invalid reset {fres!r}: {e}")

    # Uniqueness of addresses
    seen: Dict[int, str] = {}
    for name, addr in addrs:
        if addr in seen:
            errs.append(f"Address collision: 0x{addr:08X} used by {seen[addr]} and {name}")
        else:
            seen[addr] = name

    if warns:
        print("regmap_validate: WARN")
        for w in warns:
            print("- " + w)

    if errs:
        print("regmap_validate: FAIL")
        for e in errs:
            print("- " + e)
        return 1

    print(f"regmap_validate: OK ({len(addrs)} registers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
