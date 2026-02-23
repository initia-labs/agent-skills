---
name: initia-appchain-dev
description: End-to-end Initia development and operations guide. Use when asked to build Initia smart contracts (MoveVM/WasmVM/EVM), build React frontends (InterwovenKit or EVM direct JSON-RPC), launch or operate Interwoven Rollups with Weave CLI, or debug appchain/transaction integration across these layers.
---

# Initia Appchain Dev

Deliver practical guidance for full-stack Initia development: contracts, frontend integration, and appchain operations.

## Intake Questions (Ask First)

Collect missing inputs before implementation:

1. Which VM is required (`evm`, `move`, `wasm`)?
2. Which network is targeted (`testnet` or `mainnet`)?
3. Is this a fresh rollup launch or operation/debug on an existing rollup?
4. For frontend work, is this an EVM JSON-RPC app or an InterwovenKit wallet/bridge app?
5. What chain-specific values are known (`chain_id`, RPC URL, module address, denom)?

If critical values are missing, ask concise follow-up questions before generating final code/config.

If `chain_id`/endpoints/VM are missing, run the discovery flow in `references/runtime-discovery.md` before assuming defaults.

Then ask a context-specific confirmation:
- Frontend task: "I found a local rollup config/runtime. Should I use this rollup for frontend integration?"
- Non-frontend task: "I found local runtime values (VM, chain ID, endpoints). Should I use these for this task?"

## Opinionated Defaults

| Area | Default | Notes |
|---|---|---|
| VM | `evm` | Use `move`/`wasm` only when requested |
| Move Version | `2.1` | Uses `minitiad move build`. `edition = "2024.alpha"` warnings are safe to ignore. |
| Network | `testnet` | Use `mainnet` only when explicitly requested |
| Frontend (EVM VM) | wagmi + viem JSON-RPC | Default for pure EVM apps |
| Frontend (Move/Wasm) | `@initia/interwovenkit-react`| Use when InterwovenKit features are required |
| Tx UX | `requestTxBlock` | Prefer confirmation UX; use `requestTxSync` for local dev robustness. |
| Provider order | Wagmi -> Query -> InterwovenKit | Stable path for Initia SDKs |
| Rollup DA | `INITIA` | Prefer Celestia only when explicitly needed |
| Keys & Keyring | `gas-station` / `test` | Default key and `--keyring-backend test` for hackathon tools |
| Denoms | `GAS` (EVM) / `umin` (Move) | Typical defaults for test/internal rollups |

## Strict Constraints (NEVER VIOLATE)

### Initia Usernames (STRICTLY OPT-IN)
- You MUST NOT implement username support in any scaffold, component, or code snippet unless explicitly requested (e.g., "add username support").
- When requested, ALWAYS use the `username` property from `useInterwovenKit()`.
- Pattern: `{username ? username : shortenAddress(initiaAddress)}`
- Do NOT resolve via REST unless the hook property is insufficient.

### Workspace Hygiene (CRITICAL)
- You MUST NOT leave temporary files or metadata JSON files (e.g., `store_tx.json`, `tx.json`, `.bin`) in the project directory after a task.
- Delete binary files used for deployment before finishing.

### InterwovenKit Local Appchains (CRITICAL)
- When configuring a frontend for a local appchain, you MUST use the `customChain` (singular) property in `InterwovenKitProvider`.
- **Address Prefix**: `customChain` MUST include a top-level `bech32_prefix` string (e.g., `bech32_prefix: "init"`). This is **mandatory for all appchain types** (minimove, miniwasm, minievm) to correctly derive session wallets for Auto-Sign.
- **Example `customChain` Structure**:
  ```javascript
  const customChain = {
    chain_id: 'my-appchain-1',
    chain_name: 'My Appchain',
    bech32_prefix: 'init', // CRITICAL: Required for Auto-Sign on ALL VMs
    apis: {
      rpc: [{ address: 'http://localhost:26657' }],
      rest: [{ address: 'http://localhost:1317' }],
      indexer: [{ address: 'http://localhost:8080' }],
      'json-rpc': [{ address: 'http://localhost:8545' }], // Required for minievm
    },
    metadata: { is_l1: false },
    fees: { fee_tokens: [{ denom: 'umin', ... }] },
  }
  ```
- `customChain.apis` MUST include `rpc`, `rest`, AND `indexer` (even if indexer is a placeholder).
- For EVM appchains, `customChain.apis` MUST also include `json-rpc`.
- `metadata` MUST include `is_l1: false`. `fees` MUST include `fee_tokens`.

### Security & Key Protection (STRICTLY ENFORCED)
- You MUST NOT export raw private keys from the keyring.
- **Move Development**: `minitiad move build` requires **Hex** addresses (`0x...`) for named addresses.
- For EVM deployment, use `minitiad tx evm create` with `--from`.
- Extract bytecode from Foundry artifacts using `jq`; ensure NO `0x` prefix and NO trailing newlines in `.bin` files.
- If a tool requires a private key, find an alternative workflow using Initia CLI or `InterwovenKit`.

### Frontend Requirements (CRITICAL)
- **Polyfills**: Define `Buffer` and `process` global polyfills at the TOP of `main.jsx`.
- **Styles**: Inject styles using `injectStyles(InterwovenKitStyles)` and import `styles.css`.
- **Provider Order**: `WagmiProvider` -> `QueryClientProvider` -> `InterwovenKitProvider`.
- **Wallet Modal**: Use `openConnect` (not `openModal`) to open the connection modal (v2.4.0+).
- **Auto-Sign Implementation**: 
  - **Provider**: Pass `enableAutoSign={true}` to `InterwovenKitProvider`.
  - **Hook**: Destructure the `autoSign` *object* (not functions) from `useInterwovenKit`.
  - **Safety**: Use optional chaining (`autoSign?.`) and check status via `autoSign?.isEnabledByChain[chainId]`.
  - **Actions**: `await autoSign?.enable(chainId)` and `await autoSign?.disable(chainId)` are asynchronous.
  - **Permissions (CRITICAL)**: To ensure the session key can sign specific message types, ALWAYS include explicit permissions in `autoSign.enable`:
    ```javascript
    await autoSign.enable(chainId, { permissions: ["/initia.move.v1.MsgExecute"] })
    ```
  - **Error Handling**: If `autoSign.disable` fails with "authorization not found", handle it by calling `autoSign.enable` with the required permissions to reset the session.
- **REST Client**: Instantiate `RESTClient` from `@initia/initia.js` manually; it is NOT exported from the hook.

### Transaction Message Flow (CRITICAL)
- **Wasm**: ALWAYS include `chainId`. Prefer `requestTxSync`.
- **Auto-Sign (Headless)**: To ensure auto-signed transactions are "headless" (no fee selection prompt), ALWAYS include an explicit `feeDenom` (e.g., `feeDenom: "umin"`) AND the `autoSign: true` flag in the request:
  ```javascript
  await requestTxSync({ 
    chainId, 
    autoSign: true, // CRITICAL: Required for silent signing flow
    messages: [...] 
  })
  ```
- **EVM Sender**: Use **bech32** address for `sender` in `MsgCall`, but **hex** for `contractAddr`.
- **EVM Payload**: Use **camelCase** for fields (`contractAddr`, `accessList`, `authList`) and include empty arrays for lists.
- **Move MsgExecute**: Use **camelCase** for fields; `moduleAddress` MUST be **bech32**.
### Move REST Queries (CRITICAL)
- When querying Move contract state using the `RESTClient` (e.g., `rest.move.view`), the module address MUST be in **bech32** format.
- **Address Arguments**: Address arguments in `args` MUST be converted to hex, stripped of `0x`, **padded to 64 chars** (32 bytes), and then Base64-encoded.
- **Example Implementation**:
  ```javascript
  const b64Addr = Buffer.from(
    AccAddress.toHex(addr).replace('0x', '').padStart(64, '0'), 
    'hex'
  ).toString('base64');
  const res = await rest.move.view(mod_bech32, mod_name, func_name, [], [b64Addr]);
  ```
- **Response Parsing**: The response from `rest.move.view` is a `ViewResponse` object; you MUST parse `JSON.parse(res.data)` to access the actual values.

## Operating Procedure (How To Execute Tasks)

1. **Classify Layer**: Contract, Frontend, Appchain Ops, or Integration.
2. **Environment Check**: Verify tools (`cargo`, `forge`, `minitiad`) are in PATH. Use absolute paths if needed.
3. **Workspace Awareness**: Check for existing `Move.toml` or `package.json` before scaffolding. Use provided scripts for non-interactive scaffolding.
4. **Scaffolding Cleanup**: Delete placeholder modules/contracts after scaffolding.
5. **Appchain Health**: If RPC is down, attempt `weave rollup start -d` and verify with `scripts/verify-appchain.sh`.
6. **Move 2.1 Syntax**: Place doc comments (`///`) **AFTER** attributes like `#[view]`.
7. **Wasm Optimization**: ALWAYS use the CosmWasm optimizer Docker image for production-ready binaries.
8. **Visual Polish**: Prioritize sticky glassmorphism headers, centered app-card layouts, and clear visual hierarchy.
9. **UX Excellence**: Feed ordering (newest first), input accessibility (above feed), and interactive feedback (hover/focus).
10. **Bridge Support**: Use `openBridge` from `useInterwovenKit`. Default `srcChainId` to a public testnet (e.g., `initiation-2`) for local demos.
11. **Validation**: Run `scripts/verify-appchain.sh --gas-station --bots` and confirm transaction success before handoff.

## Progressive Disclosure (Read When Needed)

- **Common Tasks (Funding, Addresses, Precision)**: `references/common-tasks.md`
- **Contracts (Move/Wasm/EVM)**: `references/contracts.md`
- **Frontend (InterwovenKit)**: `references/frontend-interwovenkit.md`
- **Frontend (EVM JSON-RPC)**: `references/frontend-evm-rpc.md`
- **End-to-End Recipes**: `references/e2e-recipes.md`
- **Runtime Discovery**: `references/runtime-discovery.md`
- **Weave CLI Reference**: `references/weave-commands.md`
- **Rollup Config Schema**: `references/weave-config-schema.md`
- **Troubleshooting & Recovery**: `references/troubleshooting.md`

## Documentation Fallback

- Core docs: `https://docs.initia.xyz`
- InterwovenKit docs: `https://docs.initia.xyz/interwovenkit`

## Script Usage

- Scaffolding: `scripts/scaffold-contract.sh`, `scripts/scaffold-frontend.sh`
- Health: `scripts/verify-appchain.sh`
- Utils: `scripts/convert-address.py`, `scripts/to_hex.py`, `scripts/generate-system-keys.py`
- Setup: `scripts/install-tools.sh`, `scripts/fund-user.sh`

## Expected Deliverables

1. Exact files changed.
2. Commands for setup/build/test.
3. Verification steps and outputs.
4. Risk notes (security, keys, fees).
