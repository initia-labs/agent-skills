#!/usr/bin/env python3
"""Convert hex or bech32 addresses to a target bech32 prefix or hex.

Usage:
  python convert-address.py <address> [--prefix init] [--to-hex]
"""

from __future__ import annotations

import argparse
import sys

from bech32_utils import bech32_decode, bech32_encode, convert_bits


def hex_to_bech32(hex_addr: str, prefix: str) -> str:
    clean = hex_addr.lower().removeprefix("0x")
    if len(clean) != 40:
        raise ValueError("hex address must be 20 bytes (40 hex chars)")
    raw = bytes.fromhex(clean)
    data = convert_bits(list(raw), 8, 5)
    if data is None:
        raise ValueError("failed to convert hex address bits")
    return bech32_encode(prefix, data)


def bech32_to_bech32(bech_addr: str, prefix: str) -> str:
    _, data = bech32_decode(bech_addr)
    if data is None:
        raise ValueError("invalid bech32 address")
    return bech32_encode(prefix, data)

def bech32_to_hex(bech_addr: str) -> str:
    _, data = bech32_decode(bech_addr)
    if data is None:
        raise ValueError("invalid bech32 address")
    raw = convert_bits(data, 5, 8, pad=False)
    if raw is None:
        raise ValueError("failed to convert bech32 address bits")
    return "0x" + bytes(raw).hex()

def convert_address(address: str, prefix: str, to_hex: bool = False) -> str:
    address = address.strip()
    is_hex = address.startswith("0x") or (len(address) == 40 and all(c in "0123456789abcdefABCDEF" for c in address))
    
    if to_hex:
        if is_hex:
            clean = address.lower().removeprefix("0x")
            if len(clean) != 40 or not all(c in "0123456789abcdef" for c in clean):
                raise ValueError("hex address must be 20 bytes (40 hex chars)")
            return "0x" + clean
        return bech32_to_hex(address)
    
    if is_hex:
        return hex_to_bech32(address, prefix)
    return bech32_to_bech32(address, prefix)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert hex/bech32 address to a target bech32 prefix or hex")
    parser.add_argument("address", help="hex (0x...) or bech32 address")
    parser.add_argument("--prefix", default="init", help="target bech32 prefix (default: init)")
    parser.add_argument("--to-hex", action="store_true", help="convert address to hex (0x...) format")
    args = parser.parse_args()

    try:
        converted = convert_address(args.address, args.prefix.strip(), args.to_hex)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(converted)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
