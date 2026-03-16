---
name: initia-appchain-dev
description: End-to-end Initia development and operations guide. Use when asked to build Initia smart contracts (MoveVM/WasmVM/EVM), build React frontends (InterwovenKit or EVM direct JSON-RPC), launch or operate Interwoven Rollups with Weave CLI, or debug appchain/transaction integration across these layers.
---

# Initia Appchain Dev

Deliver practical guidance for full-stack Initia development: contracts, frontend integration, and appchain operations.

Command examples in this file assume the working directory is `skill/`; use `scripts/...` paths accordingly.

## Intake Questions (Ask First)

Collect missing inputs before implementation:

1. Which VM is required (`evm`, `move`, `wasm`)?
2. Which network is targeted (`testnet` or `mainnet`)?
3. Is this a fresh rollup launch or operation/debug on an existing rollup?
4. For frontend work, is this an EVM JSON-RPC app or an InterwovenKit wallet/bridge app?
5. What chain-specific values are known (`chain_id`, RPC URL, deployed contract address, denom)?

If critical values are missing, ask concise follow-up questions before generating final code/config.

If `chain_id`/endpoints/VM are missing, run the discovery flow in `references/runtime-discovery.md` before assuming defaults.

If `weave` is installed but fails with shell-level errors, continue discovery
with `~/.minitia/artifacts/config.json` and direct `minitiad` commands instead
of blocking on `weave`.

Then ask a context-specific confirmation:
- Frontend task: "I found a local rollup config/runtime. Should I use this rollup for frontend integration?"
- Non-frontend task: "I found local runtime values (VM, chain ID, endpoints). Should I use these for this task?"

## Environment Setup Workflow (One-Prompt Setup)

When the user asks to "set up my environment for the [Track] track" (Step 5), execute this sequence:

### 1. Identify Track Requirements & Prerequisites
- **[MOVE] Track:** `minimove` repo -> `minitiad`. Requires `go`.
- **[EVM] Track:** `minievm` repo -> `minitiad`. Requires `go`, `foundry`.
- **[WASM] Track:** `miniwasm` repo -> `minitiad`. Requires `go`, `rust/cargo`.

### 2. Check System Prerequisites
Check prerequisites by selected track (always check `docker` for tool installer compatibility):
- **[MOVE] Track:** `go`, `docker`
- **[EVM] Track:** `go`, `docker`, `foundry`
- **[WASM] Track:** `go`, `docker`, `cargo`

For each required tool in the selected track:
- If **missing**: Inform the user and **propose** the installation command (e.g., "I see you're missing Cargo. Would you like me to install it for you using `rustup`?").
- If **present**: Proceed silently.

### 3. Install Core Initia Tools
Run `scripts/install-tools.sh` to install `jq`, `weave`, and `initiad` (L1).
- **Security**: If the script requires `sudo`, explain this to the user before running.
- If the required tools are already present, prefer verifying versions over reinstalling. Pinned installer versions may lag behind what is already installed on the machine.

### 4. Build VM-Specific Binary (`minitiad`)
Clone, build, and **clean up** the relevant VM from source.

Run the build from the repository directory itself. Do not rely on shell-chained `cd ... && make install` examples if your execution environment manages working directories separately.

- **[MOVE]:**
  ```sh
  git clone --depth 1 https://github.com/initia-labs/minimove.git /tmp/minimove
  cd /tmp/minimove
  make install
  rm -rf /tmp/minimove
  ```
- **[EVM]:**
  ```sh
  git clone --depth 1 https://github.com/initia-labs/minievm.git /tmp/minievm
  cd /tmp/minievm
  make install
  rm -rf /tmp/minievm
  ```
- **[WASM]:**
  ```sh
  git clone --depth 1 https://github.com/initia-labs/miniwasm.git /tmp/miniwasm
  cd /tmp/miniwasm
  make install
  rm -rf /tmp/miniwasm
  ```

### 5. Configure PATH
- Ensure `~/go/bin` is in the user's `PATH`.
- Check shell config files (`.zshrc`, `.bashrc`) and suggest the `export` command if missing.
- After updating shell config, tell the user to run `source ~/.zshrc` (or open a new terminal) to apply changes in their current shell.
- For verification, you may run `zsh -lc 'source ~/.zshrc && <command>'` in a single command; this does not persist across separate assistant commands.

### 6. Final Verification
Run:
- `weave version`
- `initiad version`
- `minitiad version --long | rg '^(name|server_name|version|commit):'`

Required VM match:
- **[EVM] track:** `name: minievm`
- **[MOVE] track:** `name: minimove`
- **[WASM] track:** verify the reported `name` matches the Wasm VM you built

Do not treat a successful `minitiad version` command by itself as sufficient verification. The binary on `PATH` may still be from a different VM track.

## Opinionated Defaults

| Area | Default | Notes |
|---|---|---|
| VM | `evm` | Use `move`/`wasm` only when requested |
| Move Version | `2.1` | Uses `minitiad move build`. Prefer omitting `edition` from `Move.toml` unless a specific compiler version requires it. |
| Network | `testnet` | Use `mainnet` only when explicitly requested |
| Frontend (EVM VM) | wagmi + viem JSON-RPC | Default for pure EVM apps |
| Frontend (Move/Wasm) | `@initia/interwovenkit-react`| Use when InterwovenKit features are required |
| Tx UX | `requestTxBlock` | Prefer confirmation UX; use `requestTxSync` for local dev robustness. |
| Provider order | Wagmi -> Query -> InterwovenKit | Stable path for Initia SDKs |
| Rollup DA | `INITIA` | Prefer Celestia only when explicitly needed |
| Keys & Keyring | `gas-station` / `test` | Default key and `--keyring-backend test` for hackathon tools |
| Denoms | `GAS` (EVM) / `umin` (Move) | Typical defaults for test/internal rollups |

## Strict Constraints (NEVER VIOLATE)

### Tagging Standard
- Use VM-first tags for VM-specific guidance: `[EVM]`, `[MOVE]`, `[WASM]`, `[ALL-VM]`.
- Add optional context tags after VM: `[CLI]`, `[DEV]`, `[REST]`, `[RPC]`, `[FRONTEND]`, `[INTERWOVENKIT]`, `[BUILD]`, `[TEST]`.
- Prefer stacked tags (example: `[EVM][CLI]`) over combined tags (for example, avoid `[EVM CLI]`).
- Required workflow for any skill markdown edit: run `scripts/lint-tags.sh` before changes and run it again before handoff.

### Initia Usernames (STRICTLY OPT-IN)
- You MUST NOT implement username support in any scaffold, component, or code snippet unless explicitly requested (e.g., "add username support").
- When requested, use `useInterwovenKit().username` only for the connected wallet's own display name.
- Pattern: `{username ? username : shortenAddress(initiaAddress)}`
- For resolving usernames of arbitrary wallet addresses (for example, MemoBoard sender rows), use `useUsernameQuery(address?)` with the sender address; this requires `@initia/interwovenkit-react` `2.4.6` or newer.
- For feeds, boards, or any rendered list of messages/accounts, resolve sender usernames inside a child row component (for example `MessageRow`) and call `useUsernameQuery(address)` there. Do NOT call hooks directly inside a parent component's `.map()` callback or conditional loop body.
- Do NOT resolve via REST unless hook-based resolution is insufficient.
- `useUsernameQuery` behavior:
  - No param: resolves connected wallet address (`useAddress()` fallback).
  - With param: resolves the provided address.

### Workspace Hygiene (CRITICAL)
- You MUST NOT leave temporary files or metadata JSON files (e.g., `store_tx.json`, `tx.json`, `.bin`) in the project directory after a task.
- Delete binary files used for deployment before finishing.

### InterwovenKit Local Appchains (CRITICAL)
- When configuring a frontend for a local appchain, you MUST use BOTH the `customChain` AND `customChains: [customChain]` properties in `InterwovenKitProvider`.
- **Example Usage**:
  ```jsx
  <InterwovenKitProvider 
    {...TESTNET} 
    customChain={customChain} 
    customChains={[customChain]}
  >
    <App />
  </InterwovenKitProvider>
  ```
- **Bridge Support**: To ensure the bridge can resolve public chains (like `initiation-2`), ALWAYS spread the `{...TESTNET}` preset (imported from `@initia/interwovenkit-react`) into the `InterwovenKitProvider`: `<InterwovenKitProvider {...TESTNET} ... />`.
- **Address Prefix**: `customChain` MUST include a top-level `bech32_prefix` string (e.g., `bech32_prefix: "init"`). This is **mandatory for all appchain types**.
- **Metadata Completeness**: To avoid "Chain not found" errors, the `customChain` object MUST include `network_type: 'testnet'`, `staking`, `fees` (with `low/average/high_gas_price: 0`), and `native_assets` arrays.
- **API Requirements**: The `apis` object MUST include `rpc`, `rest`, AND `indexer` (use a placeholder if needed) to satisfy the kit's discovery logic.
- **Bridge Support (openBridge)**: When using `openBridge`, ONLY specify `srcChainId` and `srcDenom` (e.g., `initiation-2` and `uinit`). Avoid specifying a local `dstChainId` as it may cause resolution errors if the local chain is not yet indexed.
- **Example `customChain` Structure**:
  ```javascript
  const customChain = {
    chain_id: '<INSERT_APPCHAIN_ID_HERE>',
    chain_name: '<INSERT_APP_NAME_HERE>',
    network_type: 'testnet', // MANDATORY
    bech32_prefix: 'init',
    apis: {
      rpc: [{ address: 'http://localhost:26657' }],
      rest: [{ address: 'http://localhost:1317' }],
      indexer: [{ address: 'http://localhost:8080' }], // MANDATORY
      'json-rpc': [{ address: 'http://localhost:8545' }],
    },
    fees: { fee_tokens: [{ denom: 'umin', fixed_min_gas_price: 0, low_gas_price: 0, average_gas_price: 0, high_gas_price: 0 }] },
    staking: { staking_tokens: [{ denom: 'umin' }] },
    native_assets: [{ denom: 'umin', name: 'Token', symbol: 'TKN', decimals: 6 }],
    metadata: { is_l1: false, minitia: { type: 'minimove' } }
  }
  ```

### Frontend Requirements (CRITICAL)
- **Placeholder Sync**: Immediately after scaffolding a frontend, you MUST update all placeholders in `main.jsx` (like `<INSERT_APPCHAIN_ID_HERE>`, `<INSERT_NATIVE_DENOM_HERE>`, etc.) with the actual values discovered during the Research phase (e.g., `bank-1`, `GAS`, `minievm`).
- **Runtime Config Sync**: If the frontend depends on a deployed contract address, you MUST wire the resolved live address into runtime config (for example, `.env` / `VITE_*`) instead of leaving only placeholders or examples. For Move-specific APIs and code, keep the term `module address` where that distinction matters. If `.env` values are added or changed for a running Vite app, tell the user to restart the dev server.
- **Hook Exports**: `useInterwovenKit` exports `initiaAddress`, `address`, `username`, `openConnect`, `openWallet`, `openBridge`, `requestTxBlock`, `requestTxSync`, and `autoSign`.
- **Transaction Guards**: Before calling `requestTxBlock` or `requestTxSync`, you MUST verify that `initiaAddress` is defined.
- **[ALL-VM] Sender Address**: In Initia, the `sender` field for all message types (`MsgCall`, `MsgExecute`, `MsgExecuteContract`) MUST be the Bech32 address. Use `initiaAddress` for this field to ensure compatibility across EVM, Move, and Wasm appchains. Using the hex `address` on an EVM chain for the `sender` field in a Cosmos-style message will cause an "empty address string" or "decoding bech32 failed" error.

### Security & Key Protection (STRICTLY ENFORCED)
- You MUST NOT export raw private keys from the keyring.
- **[MOVE][DEV] Development (Building for Publish)**: Before publishing, you MUST rebuild the module using the intended deployer's **Hex** address: `minitiad move build --named-addresses <name>=0x<hex_addr>`.
- **[MOVE][DEV][BUILD] Named Address Reassignment**: If `[addresses].<name>` in `Move.toml` is hardcoded (for example `0x42`) and you pass a different `--named-addresses <name>=0x...`, compilation fails with a named-address reassignment error. Prefer `"<name>" = "_"` in `[addresses]` and keep local test defaults in `[dev-addresses]`.
- **[MOVE][DEV] Dependency Resolution**: If `InitiaStdlib` fails to resolve, use: `{ git = "https://github.com/initia-labs/movevm.git", subdir = "precompile/modules/initia_stdlib", rev = "main" }`.
- **[MOVE][DEV] Package Scaffolding**: `minitiad move new <NAME>` can write the package into the current working directory instead of creating a sibling directory. If the user wants a specific folder such as `blockforge/`, create and enter that folder first before running `minitiad move new`.
- **[MOVE][DEV] Clean (Non-Interactive Shells)**: `minitiad move clean` may prompt for confirmation and panic without a TTY. In automated workflows, remove the package `build/` directory directly if a clean rebuild is required.
- **[MOVE][CLI] Deploy Semantics**: Move modules do not have a separate instantiate transaction. "Instantiation" is typically the first state-changing entry call (for example, creating per-player resources on first `mint_shard`).
- **[EVM][CLI] Deployment**: For EVM deployment, use `minitiad tx evm create` with `--from`.
- **[EVM][CLI] Bytecode Extraction**: Extract bytecode from Foundry artifacts using `jq`; ensure NO `0x` prefix and NO trailing newlines in `.bin` files.
- **[EVM][DEV][CLI] `tx evm create` Input Shape**: The positional argument to `minitiad tx evm create` is a **bytecode file path**. If you want to pass raw bytecode directly, use `--input 0x...`. Passing raw hex as the positional argument can fail with `file name too long`.
- **[ALL-VM][SECURITY] Private Key Handling**: If a tool requires a private key, find an alternative workflow using Initia CLI or `InterwovenKit`.

### Frontend Requirements (ADDITIONAL)
- **Polyfills**: Use `vite-plugin-node-polyfills` in `vite.config.js` with `globals: { Buffer: true, process: true }`. Also set `resolve.dedupe` to `['react', 'react-dom', 'wagmi', '@tanstack/react-query', 'viem']` to avoid provider context splits in Vite. If using manual polyfills, define `Buffer` and `process` global polyfills at the TOP of `main.jsx`.
  ```javascript
  import { Buffer } from "buffer";
  window.Buffer = Buffer;
  window.process = { env: {} };
  ```
- **Styles**: 
  - Import the CSS: `import "@initia/interwovenkit-react/styles.css"`.
  - Import the style data: `import InterwovenKitStyles from "@initia/interwovenkit-react/styles.js"`.
  - Import the injector function: `import { injectStyles } from "@initia/interwovenkit-react"`.
  - Inject them: `injectStyles(InterwovenKitStyles)`.
  - **Note**: `InterwovenKitStyles` is a DEFAULT export from the styles subpath, while `injectStyles` is a NAMED export from the main package.
- **Provider Order**: `WagmiProvider` -> `QueryClientProvider` -> `InterwovenKitProvider`.
- **Wallet Modal**: 
  - Use `openConnect` (not `openModal`) to open the connection modal (v2.4.0+).
  - **Connected State (CRITICAL)**: When `initiaAddress` is present, ALWAYS provide a clickable UI element (e.g., a button with a shortened address) that calls `openWallet` to allow the user to manage their connection or disconnect.
- **Auto-Sign Implementation (STRICTLY OPT-IN)**: 
  - You MUST NOT implement auto-sign support in any scaffold, provider, or component unless explicitly requested (e.g., "add auto-sign support").
  - When requested:
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
  - **CRITICAL**: Do NOT attempt to destructure `networks` or `rest` from `useInterwovenKit`. These objects are NOT available in the hook. Always define your REST/RPC endpoints manually or via your own configuration.

### Transaction Message Flow (CRITICAL)
- **[WASM][INTERWOVENKIT] Transaction Envelope**: ALWAYS include `chainId`. Prefer `requestTxSync`.
  - **[WASM][INTERWOVENKIT] Payload Encoding**: `MsgExecuteContract` expects the `msg` field as bytes (**`Uint8Array`**). Use `new TextEncoder().encode(JSON.stringify(msg))`.
- **[ALL-VM][INTERWOVENKIT] Auto-Sign (Headless)**: To ensure auto-signed transactions are "headless" (no fee selection prompt), ALWAYS include an explicit `feeDenom` (e.g., `feeDenom: "umin"`) AND the `autoSign: true` flag in the request:
  ```javascript
  await requestTxSync({ 
    chainId, 
    autoSign: true, // CRITICAL: Required for silent signing flow
    messages: [...] 
  })
  ```
- **[EVM] Sender (MsgCall)**: Use **bech32** address for `sender` in `MsgCall`, but **hex** for `contractAddr`. 
  - **Normalization**: ALWAYS lowercase the bech32 sender address to avoid "decoding bech32 failed" errors.
- **[EVM][INTERWOVENKIT] Payload**: Use plain objects with `typeUrl: "/minievm.evm.v1.MsgCall"`. The actual message fields MUST be wrapped inside a `value` key.
  - **Incorrect**: `{ typeUrl: "...", sender: "...", contractAddr: "..." }`
  - **Correct**: `{ typeUrl: "...", value: { sender: "...", contractAddr: "...", ... } }`
- **[EVM][INTERWOVENKIT] `requestTxBlock` Key**: ALWAYS use `messages` (plural), not `msgs`. Passing `msgs` can fail with `Cannot read properties of undefined (reading 'map')`.
- **[EVM] Field Naming**: Use **camelCase** for fields (`contractAddr`, `accessList`, `authList`) and include empty arrays for lists.
- **[MOVE][INTERWOVENKIT] MsgExecute Field Naming**: Use **camelCase** for fields; `moduleAddress` MUST be **bech32**.
  - **[MOVE][INTERWOVENKIT] Mandatory Arrays**: ALWAYS include `typeArgs: []` and `args: []` even if they are empty. Omitting these fields in a Move execution message will cause a `TypeError` (Cannot read properties of undefined reading 'length') during the Amino conversion process in the frontend.

### Wasm REST Queries (CRITICAL)
- **[WASM][REST] Query Encoding**: When querying Wasm contract state using the `RESTClient` (e.g., `rest.wasm.smartContractState`), the query message MUST be a **Base64-encoded string**.
- The query JSON and execute JSON MUST match the contract's Rust message schema exactly. Do NOT assume names like `all_messages` or specific field names such as `text` or `message`; for example, MemoBoard variants commonly use `get_messages` with `post_message: { message: ... }`, while other contracts may use different field names.
- **Example Implementation**:
  ```javascript
  const queryData = Buffer.from(JSON.stringify({ get_messages: {} })).toString("base64");
  const res = await rest.wasm.smartContractState(CONTRACT_ADDR, queryData);
  ```
- **[WASM][REST] Response Shape**: `smartContractState` commonly returns the decoded payload directly (for example `res.messages`) rather than nesting it under `res.data`. Do not assume a `.data` wrapper unless you have verified the concrete response shape.
- **[WASM][REST] Method Name**: ALWAYS use `smartContractState`. Methods like `queryContractSmart` are NOT available in the Initia `RESTClient`.
- **[WASM][CLI] Fallback**: If `minitiad query wasm contract-state smart <CONTRACT_ADDRESS> ...` fails with a Bech32 checksum error even though the address came from the instantiate event or `list-contract-by-code`, treat the chain-emitted address as the source of truth. Verify it with `minitiad query wasm list-contract-by-code <CODE_ID>` and continue with the REST endpoint path or `RESTClient` instead of blocking on the CLI parser.

### Wasm Rust Testing (CRITICAL)
- **[WASM][TEST] Address Comparison**: When writing unit tests for Wasm contracts, ALWAYS use `.as_str()` when comparing `cosmwasm_std::Addr` with a string literal or `String`. `Addr` does NOT implement `PartialEq<&str>` or `PartialEq<String>` directly.
- **Incorrect**: `assert_eq!("user1", value.sender);`
- **Correct**: `assert_eq!("user1", value.sender.as_str());`

### Token Precision & Funding (EVM SPECIFIC)
- **[EVM] Precision**: Assume standard EVM precision ($10^{18}$ base units) for all native tokens on EVM appchains (e.g., `GAS`).
- **[EVM] Funding Requests**: When a user asks for "N tokens" on an EVM chain:
  - **Frontend**: Multiply by $10^{18}$ (e.g., `parseUnits(amount, 18)`).
  - **CLI**: You MUST manually scale the value. For "100 tokens", use `100000000000000000000GAS` (100 + 18 zeros) in the `bank send` command.
- **[EVM][FRONTEND] Human-Readable UI**: ALWAYS use `formatUnits(balance, 18)` from `viem` to display EVM balances. NEVER display raw base units in the UI.
- **[EVM][FRONTEND][DEV] `parseEther` / `formatEther` Usage**: `parseEther` and `formatEther` are valid shorthand ONLY when the chain token uses exactly 18 decimals. If decimals might vary, use `parseUnits(amount, decimals)` and `formatUnits(balance, decimals)` from runtime config.

### EVM Queries & Transactions (CRITICAL)
- **[EVM][FRONTEND] ABI Sync**: Treat compiled ABI/function names as the source of truth. Do NOT assume names like `getMyBalance`; confirm names/signatures from the generated artifact (for example `out/<Contract>.sol/<Contract>.json`) before wiring frontend `encodeFunctionData` calls.
- **[EVM][RPC] State Queries**: Prefer standard JSON-RPC `eth_call` over `RESTClient` for EVM state queries to avoid property-undefined errors.
- **[EVM][FRONTEND][RPC] Read Path Provider**: For read-only EVM queries (`eth_call`), use a configured JSON-RPC endpoint (for example `VITE_JSON_RPC_URL`) instead of relying on injected wallet providers (`window.ethereum`). This avoids "EVM wallet provider not found" failures when no EVM extension is injected.
- **[EVM][RPC] Address Conversion**: When querying EVM state (e.g., `eth_call`), ALWAYS convert the bech32 address to hex using `AccAddress.toHex(addr)` and ensure the hex address is lowercased.
- **[EVM][CLI] Sender Format**: `minitiad query evm call` expects a **bech32** sender (`init1...`) as the first argument.
- **[EVM][CLI] Query Output Field**: `minitiad query evm call -o json` returns the call result under `.response` (hex string).
- **[EVM][CLI] Tx Lookup Timing**: Immediately after broadcast, `minitiad query tx <hash>` may briefly return `tx not found`; retry briefly before failing.
- **[EVM][CLI] Calldata Encoding**: 
  - **[EVM][FRONTEND] Preferred**: Prefer `viem` (e.g., `encodeFunctionData`) for generating contract `input` hex. 
  - **[EVM][CLI] Preferred**: ALWAYS use `cast calldata` (e.g., `$(cast calldata "func(type)" arg)`) for generating contract `input` hex. Manual encoding (e.g., `printf`) is brittle and MUST be avoided.
  - **[EVM][CLI] Manual Padding**: If manual encoding is unavoidable, ensure `BigInt` values are converted to hex and padded to exactly 64 characters for `uint256` arguments.

### Move REST Queries (CRITICAL)
- **[MOVE][REST] Module Address Format**: When querying Move contract state using the `RESTClient` (e.g., `rest.move.view`), the module address MUST be in **bech32** format.
- **[MOVE][REST] Struct Tag Address Format**: When querying Move resources using `rest.move.resource`, the **resource owner** remains bech32, but the **struct tag module address MUST be hex** (`0x...::module::Struct`). Do NOT build a struct tag with a bech32 module address.
- **[MOVE][REST] Address Arguments**: Address arguments in `args` MUST be converted to hex, stripped of `0x`, **padded to 64 chars** (32 bytes), and then Base64-encoded.
- **Example Implementation**:
  ```javascript
  const b64Addr = Buffer.from(
    AccAddress.toHex(addr).replace('0x', '').padStart(64, '0'), 
    'hex'
  ).toString('base64');
  const res = await rest.move.view(mod_bech32, mod_name, func_name, [], [b64Addr]);
  ```
- **Resource Query Example**:
  ```javascript
  const structTag = `${AccAddress.toHex(moduleBech32)}::items::Inventory`;
  const res = await rest.move.resource(walletBech32, structTag);
  ```
- **[MOVE][REST] Response Parsing**: The response from `rest.move.view` is a `ViewResponse` object; you MUST parse `JSON.parse(res.data)` to access the actual values.
- **[MOVE][REST] Missing Resource Handling**: For first-use state such as inventories, a resource may not exist yet. Treat a "not found" response from `rest.move.resource` as a valid zero/default state instead of surfacing it as a hard failure.
- **[MOVE][REST] Troubleshooting (400 Bad Request)**: If `rest.move.view` returns a 400 error, it is almost ALWAYS because:
  1. The module address is not bech32.
  2. The address arguments in `args` are not correctly hex-padded-base64 encoded.
- **[MOVE][INTERWOVENKIT] Auto-Sign (No message types configured)**: If `autoSign.enable` fails with "No message types configured", ensure:
  1. `metadata.minitia.type` is set correctly (e.g., `minimove`, `minievm`).
  2. `defaultChainId` in `InterwovenKitProvider` matches your `customChain.chain_id`.
  3. `bech32_prefix` is present at the top level of `customChain`.

## Operating Procedure (How To Execute Tasks)

1. **Classify Layer**: Contract, Frontend, Appchain Ops, or Integration.
2. **Environment Check**: Verify tools (`cargo`, `forge`, `minitiad`) are in PATH. Use absolute paths if needed.
3. **Workspace Awareness**: Check for existing `Move.toml` or `package.json` before scaffolding. Use provided scripts for non-interactive scaffolding.
4. **Pre-Deployment Checklist (CLI)**: Before deploying contracts or sending tokens via CLI, verify the actual environment (set `RPC_ENDPOINT` from runtime discovery):
   - **Chain ID**: `curl -s "${RPC_ENDPOINT}/status" | jq -r '.result.node_info.network'`
   - **Native Denom**: `minitiad q bank total --node "${RPC_ENDPOINT}"`
   - **Balance**: Ensure the `from` account has enough of the *actual* native denom.
5. **Scaffolding Cleanup**: Delete placeholder modules/contracts after scaffolding.
6. **Appchain Health**: If RPC is down, attempt `weave rollup start -d` and verify with `scripts/verify-appchain.sh`.
7. **[MOVE][DEV] Acquires Annotation**: Every function that accesses global storage (using `borrow_global`, `borrow_global_mut`, `move_from`, or calling a function that does) MUST include the `acquires` annotation for that resource type.
8. **[MOVE][DEV] Reference Rules**: You MUST NOT return a reference (mutable or immutable) derived from a global resource (e.g., via `borrow_global_mut`) from a function unless it is passed as a parameter. Inline the logic or pass the resource as a parameter if needed.
9. **[MOVE][DEV] Syntax**: Place doc comments (`///`) **AFTER** attributes like `#[view]` or `#[test]`.
10. **[MOVE][CLI] Publish**: The `minitiad tx move publish` command does NOT use a `--path` flag. Pass the path to the compiled `.mv` file as a positional argument: `minitiad tx move publish <path_to_file>.mv ...`.
11. **[MOVE][DEV][CLI] Republish Compatibility**: If republishing from the same account fails with `BACKWARD_INCOMPATIBLE_MODULE_UPDATE`, preserve existing public APIs (for example, keep prior public entry/view functions as compatibility wrappers) or rename the module before publishing.
12. **[ALL-VM][CLI] Broadcast Mode Compatibility**: In current Initia CLIs, broadcast mode supports `sync|async`; do not assume `block` is available.
13. **[MOVE][CLI] Tx Lookup Timing**: Immediately after `minitiad` broadcast, `minitiad query tx <hash>` may briefly return `tx not found`; poll/retry before treating it as failed.
14. **[WASM][BUILD] Optimization**: ALWAYS use the CosmWasm optimizer Docker image for production-ready binaries.
15. **Visual Polish**: Prioritize sticky glassmorphism headers, centered app-card layouts, and clear visual hierarchy.
16. **UX Excellence**: Feed ordering (newest first), input accessibility (above feed), and interactive feedback (hover/focus).
17. **[ALL-VM][INTERWOVENKIT] Bridge Support**: Use `openBridge` from `useInterwovenKit`. Default `srcChainId` to a public testnet (e.g., `initiation-2`) for local demos.
18. **Validation**: Run `scripts/verify-appchain.sh --gas-station --bots` and confirm transaction success before handoff.

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
