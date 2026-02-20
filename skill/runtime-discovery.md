# Runtime Discovery

Use this flow whenever VM, `chain_id`, or endpoint values are unknown.

## Quick Verification

The fastest way to verify if a local appchain is running and healthy:

```bash
scripts/verify-appchain.sh --gas-station --bots
```

This will:
1. Auto-detect `chain_id` from `~/.minitia/artifacts/config.json`.
2. Check if blocks are being produced.
3. Show Gas Station L1 and L2 balances.
4. Check status of OPinit Executor and IBC Relayer.

## Manual Discovery Commands

```bash
weave rollup list
weave rollup log -n 20
weave gas-station show
test -f ~/.minitia/artifacts/config.json && cat ~/.minitia/artifacts/config.json
```

## How To Use Results

1. **Identify VM** (`evm`, `move`, `wasm`) from rollup metadata/config.
2. **Extract `chain_id`** (specifically `l2_config.chain_id` for rollup operations), RPC/REST/JSON-RPC endpoints, and denom defaults.
3. **Identify Gas Station address** from `weave gas-station show` or `genesis_accounts` in `config.json`.
4. **Confirm with the user** before wiring frontend or deployment config values.

Use a context-specific confirmation:
- Frontend task: "I found a local rollup config/runtime. Should I use this rollup for frontend integration?"
- Non-frontend task: "I found local runtime values (VM, chain ID, endpoints). Should I use these for this task?"