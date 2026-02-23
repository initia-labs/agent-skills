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
- `customChain.apis` MUST include `rpc`, `rest`, AND `indexer` (even as a placeholder).
- For EVM appchains, `customChain.apis` MUST also include `json-rpc`.
- `metadata` MUST include `is_l1: false`. `fees` MUST include `fee_tokens`.

### Security & Key Protection (STRICTLY ENFORCED)
- You MUST NOT export raw private keys from the keyring.
- For EVM deployment, use `minitiad tx evm create` with `--from`.
- Extract bytecode from Foundry artifacts using `jq`; ensure NO `0x` prefix and NO trailing newlines in `.bin` files.
- If a tool requires a private key, find an alternative workflow using Initia CLI or `InterwovenKit`.

### Frontend Requirements (CRITICAL)
- **Polyfills**: Define `Buffer` and `process` global polyfills at the TOP of `main.jsx`.
- **Styles**: Inject styles using `injectStyles(InterwovenKitStyles)` and import `styles.css`.
- **Provider Order**: `WagmiProvider` -> `QueryClientProvider` -> `InterwovenKitProvider`.
- **Wallet Modal**: Use `openConnect` (not `openModal`) to open the connection modal (v2.4.0+).
- **REST Client**: Instantiate `RESTClient` from `@initia/initia.js` manually; it is NOT exported from the hook.

### Transaction Message Flow (CRITICAL)
- **Wasm**: ALWAYS include `chainId`. Prefer `requestTxSync`.
- **EVM Sender**: Use **bech32** address for `sender` in `MsgCall`, but **hex** for `contractAddr`.
- **EVM Payload**: Use **camelCase** for fields (`contractAddr`, `accessList`, `authList`) and include empty arrays for lists.
- **Move MsgExecute**: Use **camelCase** for fields; `moduleAddress` MUST be **bech32**.

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
