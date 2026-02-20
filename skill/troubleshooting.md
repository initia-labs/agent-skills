# Troubleshooting Playbook

## Table of Contents

1. Weave / Rollup
2. Frontend / InterwovenKit
3. Contracts
4. Configuration

## Weave / Rollup

### 1. Gas station missing or underfunded

Symptoms:
- Launch/setup fails with funding errors.

Checks:

```bash
weave gas-station show
```

Actions:
- Re-run `weave gas-station setup`.
- Fund the account (testnet faucet for testnet).

### 2. Rollup not producing blocks

Checks:

```bash
weave rollup log -n 100
curl http://localhost:26657/status
```

Then run:

```bash
scripts/verify-appchain.sh --chain-id <CHAIN_ID> --rpc-url <RPC_URL>
```

Actions:
- Confirm `chain_id` and RPC URL alignment.
- Restart rollup: `weave rollup restart`.

### 3. Port conflicts

Symptoms:
- Startup fails due to occupied ports (`1317`, `26657`, `9090`, `8545`).

Checks:

```bash
lsof -i :1317 -i :26657 -i :9090 -i :8545
```

Actions:
- Stop conflicting processes or update service config.

## Frontend / InterwovenKit

### 4. Missing VM/chain/endpoints before frontend work

Checks:

Use `runtime-discovery.md`.

Actions:
- If rollup details are found, confirm with user before wiring frontend values.
- If VM resolves to `evm` and no InterwovenKit features are needed, use `frontend-evm-rpc.md`.

### 5. Wallet/connect UI does not appear

Checks:
- Provider order includes `QueryClientProvider` -> `WagmiProvider` -> `InterwovenKitProvider`.
- If `PrivyProvider` is present, ensure it wraps the stack.

Run:

```bash
scripts/check-provider-setup.sh --mode interwovenkit <providers-file.tsx>
```

### 6. Chain not found / wrong chain selected

Symptoms:
- Runtime error like `Chain not found: <CHAIN_ID>`.
- Runtime error like `URL not found`.

Checks:
- Ensure `customChain` is passed to `InterwovenKitProvider`.
- **CRITICAL**: The `apis` object in `customChain` MUST include `rpc`, `rest`, AND an `indexer` array (even if it's a placeholder like `[{ address: "http://localhost:8080" }]`). The kit will crash if any are missing.
- For testnet, prefer `defaultChainId={TESTNET.defaultChainId}`.

### 7. Global Errors (Buffer/Process)

Symptoms:
- `ReferenceError: Buffer is not defined`
- `Module "buffer" has been externalized for browser compatibility`

Fix:
- Install `buffer`, `util`, and `vite-plugin-node-polyfills`.
- In `main.jsx`, initialize the globals:
  ```javascript
  import { Buffer } from 'buffer'
  window.Buffer = Buffer
  window.process = { env: {} }
  ```
- Add the `nodePolyfills` plugin to `vite.config.js`.

### 8. Transaction submission or Query fails

Checks:
- Wallet connected and `initiaAddress` is present.
- **SDK Usage**: `LCDClient` is not an export in the current `initia.js`. Use `RESTClient` instead.
- **View Function 400/500**: Ensure Move arguments are correctly prefixed (e.g., `address:init1...`).
- **State Reliability**: Prefer `rest.move.resource()` over `viewFunction()` for querying simple contract state (like an Inventory struct).
- **EVM Simulation (Hex Prefix)**: `minitiad tx evm call` and `eth_call` often fail if the input hex or contract address is missing the `0x` prefix.
- **EVM Simulation (Address Format)**: Simulation can fail with "empty address string" if the message fields (e.g., `contractAddr`) don't match the expected casing (camelCase vs snake_case).
- For minievm calls via InterwovenKit, use `typeUrl: "/minievm.evm.v1.MsgCall"` and ensure fields are **camelCase** (`contractAddr`, `accessList`) if using a raw object.

### 9. NPM install interrupted / dependency state corrupted

Symptoms:
- Repeated install errors after timeout/interrupted install (`ENOTEMPTY`, rename conflicts).

Actions:

```bash
rm -rf node_modules package-lock.json
npm install
```

## Contracts

### 10. Build/import errors from wrong VM assumptions

Checks:
- Confirm VM target first (`evm`, `move`, `wasm`).
- Confirm toolchain and dependency set for that VM.
- **Move 2.0 Compatibility:** Projects default to Move 2.0 (`edition = "2024.alpha"`). If you see "unsupported language construct", ensure your `minitiad` version is `v1.1.10` or higher. You can update it by running `make install` in the `minimove` repository.
- **Hex Addresses:** `Move.toml` requires addresses in hex format (`0x...`). Use `scripts/to_hex.py <address>` to convert Bech32 addresses.
- **Library Naming:** Use `initia_std` (not `initia_stdlib`) when importing core modules: `use initia_std::table;`.
- **Receiver Syntax:** Not all standard library modules support receiver functions yet. If `account.address_of()` fails, use the classic `signer::address_of(account)`.

Actions:
- Re-scaffold using:

```bash
scripts/scaffold-contract.sh <evm|move|wasm> <target-dir>
```

## Configuration

### 11. Common CLI Errors

| Error | Cause | Fix |
|---|---|---|
| `insufficient gas price` | L1 (initiation-2) requires a base gas price of `0.015uinit`. | Use `--fees` (e.g., `--fees 5000uinit`) to satisfy the requirement. |
| `account sequence mismatch` | Rapidly sending transactions without waiting for indexing. | Add `sleep 2` between transactions or verify the previous tx is indexed. |
| `signature verification failed` | Incorrect `chain-id` or account sequence mismatch. | Run `minitiad status` to find the correct `network` (chain-id) and use it in your command. |
| `invalid denom` or `insufficient funds` | Using incorrect token precision (e.g., 100 vs 10^20). | Query total supply: `minitiad q bank total`. Most L2 tokens (like `umin`) use 18 decimals. |
| `failed to convert address field` | Using a Bech32 address (`init1...`) where a key name is expected. | Use the key name (e.g., `gas-station`) or ensure the address is in the local keyring. |

### 12. Network & Chain ID Discovery

If you are unsure of the correct `chain-id` for a layer:

- **L1 (Initia Testnet)**: `initiad status --node https://rpc.testnet.initia.xyz \| jq -r '.NodeInfo.network'` (usually `initiation-2`).
- **L2 (Local Appchain)**: `minitiad status \| jq -r '.NodeInfo.network'` (usually `social-1`).

### 13. Launch config rejected by Weave

Checks:
- Field names are snake_case.
- Required sections exist (`l1_config`, `l2_config`, `op_bridge`).
- `chain_id`, `rpc_url`, and denom values are valid for target network/VM.

Reference:
- `weave-config-schema.md`
