#!/usr/bin/env python3
"""Decode home-inventory v1 ADC FIFO words into frames.

The RTL contract (see spec/ads131m08_interface.md) packs each captured conversion
into 9 32-bit words:
  0: STATUS word
  1: CH0
  2: CH1
  ...
  8: CH7

This tool helps during bring-up when you have a raw dump of FIFO reads (from a
logic analyzer log, UART printf, etc.) and want to sanity-check ordering and
sign-extension.

Input format: one 32-bit word per line, in hex or decimal.
Examples of accepted tokens:
  0x00001001
  00001001
  4097

Usage:
  python3 fw/tools/decode_adc_fifo.py dump.txt
  cat dump.txt | python3 fw/tools/decode_adc_fifo.py -

Exit code is non-zero on malformed input.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from typing import Iterable, List


_HEX_RE = re.compile(r"^(0x)?[0-9a-fA-F]+$")


def _parse_u32(tok: str) -> int:
    tok = tok.strip().rstrip(",")
    if not tok:
        raise ValueError("empty token")

    # Allow hex with or without 0x; treat pure hex digits as hex.
    if _HEX_RE.match(tok):
        base = 16
        if tok.lower().startswith("0x"):
            tok = tok[2:]
        val = int(tok, base)
    else:
        val = int(tok, 10)

    if val < 0 or val > 0xFFFF_FFFF:
        raise ValueError(f"out of u32 range: {val}")
    return val


def _to_i32(u: int) -> int:
    u &= 0xFFFF_FFFF
    return u - 0x1_0000_0000 if (u & 0x8000_0000) else u


def _read_words(lines: Iterable[str]) -> List[int]:
    words: List[int] = []
    for ln, raw in enumerate(lines, 1):
        s = raw.strip()
        if not s or s.startswith("#"):
            continue

        # If the line contains multiple tokens (e.g. C array dumps), split.
        for tok in re.split(r"[\s\[\]{}()]+", s):
            tok = tok.strip()
            if not tok:
                continue
            # Further split on commas/semicolons.
            for subtok in re.split(r"[;,]", tok):
                subtok = subtok.strip()
                if not subtok:
                    continue
                try:
                    words.append(_parse_u32(subtok))
                except Exception as e:
                    raise ValueError(f"line {ln}: cannot parse token '{subtok}': {e}")
    return words


@dataclass
class Frame:
    idx: int
    status_u32: int
    ch_u32: List[int]  # len 8


def _frames_from_words(words: List[int], *, start_index: int = 0) -> List[Frame]:
    if start_index < 0 or start_index > len(words):
        raise ValueError("start_index out of range")

    words = words[start_index:]
    frames: List[Frame] = []
    n_full = len(words) // 9
    for i in range(n_full):
        base = i * 9
        status = words[base + 0]
        ch = words[base + 1 : base + 9]
        frames.append(Frame(idx=i, status_u32=status, ch_u32=ch))
    return frames


def main(argv: List[str]) -> int:
    ap = argparse.ArgumentParser(description="Decode ADC FIFO 9-word frames")
    ap.add_argument(
        "path",
        help="Input file path, or '-' for stdin",
    )
    ap.add_argument(
        "--skip-words",
        type=int,
        default=0,
        help="Skip N initial words before framing (default: 0)",
    )
    ap.add_argument(
        "--max-frames",
        type=int,
        default=None,
        help="Limit output to first N frames",
    )
    ap.add_argument(
        "--show-unsigned",
        action="store_true",
        help="Also print channel words as unsigned u32",
    )

    args = ap.parse_args(argv)

    if args.path == "-":
        lines = sys.stdin
    else:
        lines = open(args.path, "r", encoding="utf-8")

    try:
        words = _read_words(lines)
    finally:
        if args.path != "-":
            lines.close()

    if args.skip_words:
        if args.skip_words > len(words):
            raise SystemExit(f"--skip-words={args.skip_words} exceeds input length {len(words)}")

    frames = _frames_from_words(words, start_index=args.skip_words)

    leftover = (len(words) - args.skip_words) % 9
    if leftover:
        print(
            f"[warn] input length after skip is not multiple of 9: {leftover} trailing word(s) ignored",
            file=sys.stderr,
        )

    if args.max_frames is not None:
        frames = frames[: args.max_frames]

    if not frames:
        print("no complete frames found", file=sys.stderr)
        return 2

    for fr in frames:
        print(f"frame {fr.idx}:")
        print(f"  status: 0x{fr.status_u32:08X}")
        for ch, u in enumerate(fr.ch_u32):
            i = _to_i32(u)
            if args.show_unsigned:
                print(f"  ch{ch}: i32={i:11d}  u32=0x{u:08X}")
            else:
                print(f"  ch{ch}: i32={i:11d}  (0x{u:08X})")
        print("")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
