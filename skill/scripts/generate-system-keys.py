#!/usr/bin/env python3
"""Generate Initia rollup system keys.

Requires: bip_utils

By default, mnemonics are redacted from output to avoid leaking secrets in logs/stdout.
To emit mnemonics, use --include-mnemonics together with --output <path>.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from dataclasses import dataclass

from bech32_utils import bech32_encode, convert_bits


def require_bip_utils():
    try:
        from bip_utils import (  # type: ignore
            Bip39MnemonicGenerator,
            Bip39SeedGenerator,
            Bip39WordsNum,
            Bip44,
            Bip44Changes,
            Bip44Coins,
        )
    except Exception as exc:  # pragma: no cover
        py_ver = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
        raise RuntimeError(
            "Failed to import 'bip_utils'. Install with: pip install bip_utils. "
            f"Current Python: {py_ver}. "
            "If install/import fails on this runtime, use Python 3.11 or 3.12 in a virtual environment."
        ) from exc

    return Bip39MnemonicGenerator, Bip39SeedGenerator, Bip39WordsNum, Bip44, Bip44Changes, Bip44Coins


def pubkey_to_bech32(pub_key_compressed: bytes, hrp: str) -> str:
    sha = hashlib.sha256(pub_key_compressed).digest()
    ripe = hashlib.new("ripemd160", sha).digest()
    data = convert_bits(list(ripe), 8, 5)
    if data is None:
        raise ValueError("failed to convert pubkey hash bits")
    return bech32_encode(hrp, data)


@dataclass
class RoleSpec:
    role: str
    needs_l1_l2: bool


def default_coins_for_vm(vm: str) -> str:
    if vm == "evm":
        return "1GAS"
    if vm in {"move", "wasm"}:
        return "1umin"
    raise ValueError(f"unsupported vm: {vm}")


def write_json_file(path: str, payload: dict, overwrite: bool) -> None:
    if os.path.exists(path) and not overwrite:
        raise RuntimeError(f"Refusing to overwrite existing file: {path}. Use --force to overwrite.")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    os.chmod(path, 0o600)


def generate(args: argparse.Namespace) -> dict:
    Bip39MnemonicGenerator, Bip39SeedGenerator, Bip39WordsNum, Bip44, Bip44Changes, Bip44Coins = require_bip_utils()

    roles = [
        RoleSpec("validator", True),
        RoleSpec("bridge_executor", True),
        RoleSpec("output_submitter", True),
        RoleSpec("batch_submitter", False),
        RoleSpec("challenger", True),
    ]

    da_hrp = "celestia" if args.da == "celestia" else "init"

    system_keys: dict[str, dict[str, str]] = {}
    genesis_accounts: list[dict[str, str]] = []

    for role in roles:
        mnemonic = str(Bip39MnemonicGenerator().FromWordsNumber(Bip39WordsNum.WORDS_NUM_24))

        seed = Bip39SeedGenerator(mnemonic).Generate()

        bip = Bip44.FromSeed(
            seed_bytes=seed,
            coin_type=Bip44Coins.COSMOS,
        ).Purpose().Coin().Account(0).Change(Bip44Changes.CHAIN_EXT).AddressIndex(0)

        pub_key = bip.PublicKey().RawCompressed().ToBytes()
        key_data: dict[str, str] = {}
        if args.include_mnemonics:
            key_data["mnemonic"] = mnemonic
        else:
            key_data["mnemonic"] = "REDACTED"

        if role.needs_l1_l2:
            addr = pubkey_to_bech32(pub_key, "init")
            key_data["l1_address"] = addr
            key_data["l2_address"] = addr
            genesis_accounts.append({"address": addr, "coins": args.coins})
        else:
            key_data["da_address"] = pubkey_to_bech32(pub_key, da_hrp)

        system_keys[role.role] = key_data

    return {
        "system_keys": system_keys,
        "genesis_accounts": genesis_accounts,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate system keys for Initia rollup launch config")
    parser.add_argument(
        "--vm",
        choices=["evm", "move", "wasm"],
        required=True,
        help="target VM; determines default genesis coins denom",
    )
    parser.add_argument("--da", choices=["initia", "celestia"], default="initia", help="DA layer for batch_submitter")
    parser.add_argument(
        "--coins",
        default=None,
        help="coins value for generated genesis_accounts entries (default: 1GAS for evm, 1umin for move/wasm)",
    )
    parser.add_argument(
        "--include-mnemonics",
        action="store_true",
        help="include raw mnemonics in output (requires --output to avoid stdout leakage)",
    )
    parser.add_argument(
        "--output",
        help="write JSON output to a file (recommended; created with 0600 permissions)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="overwrite --output file if it already exists",
    )
    args = parser.parse_args()

    if args.coins is None:
        args.coins = default_coins_for_vm(args.vm)

    if args.include_mnemonics and not args.output:
        print("Error: --include-mnemonics requires --output to avoid leaking secrets to stdout.", file=sys.stderr)
        return 1

    try:
        payload = generate(args)
    except (RuntimeError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    try:
        if args.output:
            write_json_file(args.output, payload, args.force)
            print(f"Wrote key payload to {args.output}")
        else:
            print(json.dumps(payload, indent=2))
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except OSError as exc:
        print(f"Error: failed to write output file: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
