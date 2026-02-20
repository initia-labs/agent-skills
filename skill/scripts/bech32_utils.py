#!/usr/bin/env python3
"""Minimal Bech32 helpers used by skill scripts."""

from __future__ import annotations

BECH32_CHARSET = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"


def bech32_polymod(values: list[int]) -> int:
    generator = [0x3B6A57B2, 0x26508E6D, 0x1EA119FA, 0x3D4233DD, 0x2A1462B3]
    chk = 1
    for value in values:
        top = chk >> 25
        chk = ((chk & 0x1FFFFFF) << 5) ^ value
        for i in range(5):
            chk ^= generator[i] if ((top >> i) & 1) else 0
    return chk


def bech32_hrp_expand(hrp: str) -> list[int]:
    return [ord(x) >> 5 for x in hrp] + [0] + [ord(x) & 31 for x in hrp]


def bech32_create_checksum(hrp: str, data: list[int]) -> list[int]:
    values = bech32_hrp_expand(hrp) + data
    polymod = bech32_polymod(values + [0, 0, 0, 0, 0, 0]) ^ 1
    return [(polymod >> 5 * (5 - i)) & 31 for i in range(6)]


def bech32_verify_checksum(hrp: str, data: list[int]) -> bool:
    return bech32_polymod(bech32_hrp_expand(hrp) + data) == 1


def bech32_encode(hrp: str, data: list[int]) -> str:
    combined = data + bech32_create_checksum(hrp, data)
    return hrp + "1" + "".join(BECH32_CHARSET[d] for d in combined)


def bech32_decode(bech: str) -> tuple[str | None, list[int] | None]:
    if any(ord(x) < 33 or ord(x) > 126 for x in bech):
        return None, None
    if bech.lower() != bech and bech.upper() != bech:
        return None, None
    bech = bech.lower()
    pos = bech.rfind("1")
    if pos < 1 or pos + 7 > len(bech) or len(bech) > 90:
        return None, None
    if not all(x in BECH32_CHARSET for x in bech[pos + 1 :]):
        return None, None
    hrp = bech[:pos]
    data = [BECH32_CHARSET.find(x) for x in bech[pos + 1 :]]
    if not bech32_verify_checksum(hrp, data):
        return None, None
    return hrp, data[:-6]


def convert_bits(data: list[int], from_bits: int, to_bits: int, pad: bool = True) -> list[int] | None:
    acc = 0
    bits = 0
    ret: list[int] = []
    max_v = (1 << to_bits) - 1
    max_acc = (1 << (from_bits + to_bits - 1)) - 1
    for value in data:
        if value < 0 or (value >> from_bits):
            return None
        acc = ((acc << from_bits) | value) & max_acc
        bits += from_bits
        while bits >= to_bits:
            bits -= to_bits
            ret.append((acc >> bits) & max_v)
    if pad:
        if bits:
            ret.append((acc << (to_bits - bits)) & max_v)
    elif bits >= from_bits or ((acc << (to_bits - bits)) & max_v):
        return None
    return ret
