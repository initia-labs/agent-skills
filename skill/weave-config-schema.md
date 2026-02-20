# Weave Launch Config Schema

Use this schema for `~/.weave/launch_config.json`. Keep field names in snake_case.

## Full Shape

```json
{
  "l1_config": {
    "chain_id": "string",
    "rpc_url": "string",
    "gas_prices": "string"
  },
  "l2_config": {
    "chain_id": "string",
    "denom": "string",
    "moniker": "string",
    "bridge_id": "uint64 (optional, assigned after launch)"
  },
  "op_bridge": {
    "output_submission_interval": "string (duration)",
    "output_finalization_period": "string (duration)",
    "output_submission_start_height": "uint64",
    "batch_submission_target": "INITIA|CELESTIA",
    "enable_oracle": "boolean"
  },
  "system_keys": {
    "validator": { "l1_address": "string", "l2_address": "string", "mnemonic": "string" },
    "bridge_executor": { "l1_address": "string", "l2_address": "string", "mnemonic": "string" },
    "output_submitter": { "l1_address": "string", "l2_address": "string", "mnemonic": "string" },
    "batch_submitter": { "da_address": "string", "mnemonic": "string" },
    "challenger": { "l1_address": "string", "l2_address": "string", "mnemonic": "string" }
  },
  "genesis_accounts": [
    { "address": "string", "coins": "string" }
  ]
}
```

## Network Values

| Network | chain_id | rpc_url |
|---|---|---|
| Testnet | `initiation-2` | `https://rpc.testnet.initia.xyz:443` |
| Mainnet | `initia-1` | `https://rpc.initia.xyz:443` |

## Defaults for Internal/Test Launches

- `gas_prices`: `0.015uinit`
- `denom`: `GAS` (EVM), `umin` (Move/Wasm)
- `moniker`: `operator`
- `output_submission_interval`: `1m`
- `output_finalization_period`: `168h`
- `batch_submission_target`: `INITIA`
- `enable_oracle`: `false`

## Generating `system_keys` Safely

Use `scripts/generate-system-keys.py` with explicit VM selection so default `genesis_accounts[].coins` matches denom expectations:

```bash
# EVM default coins: 1GAS
python3 scripts/generate-system-keys.py --vm evm

# Move/Wasm default coins: 1umin
python3 scripts/generate-system-keys.py --vm move
```

By default, mnemonics are redacted. To include real mnemonics, require file output:

```bash
python3 scripts/generate-system-keys.py --vm wasm --include-mnemonics --output ./system-keys.json
```

## Example (Testnet + EVM)

```json
{
  "l1_config": {
    "chain_id": "initiation-2",
    "rpc_url": "https://rpc.testnet.initia.xyz:443",
    "gas_prices": "0.015uinit"
  },
  "l2_config": {
    "chain_id": "myrollup-1",
    "denom": "GAS",
    "moniker": "operator"
  },
  "op_bridge": {
    "output_submission_interval": "1m",
    "output_finalization_period": "168h",
    "output_submission_start_height": 1,
    "batch_submission_target": "INITIA",
    "enable_oracle": false
  },
  "genesis_accounts": [
    { "address": "init1...", "coins": "1GAS" }
  ]
}
```

## Address Rules

- Convert user-supplied addresses to expected format before insertion.
- `genesis_accounts.address` should be `init1...`.
- `batch_submitter.da_address` should be:
  - `init1...` for INITIA DA
  - `celestia1...` for CELESTIA DA
