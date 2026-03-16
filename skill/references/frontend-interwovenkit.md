# Frontend (InterwovenKit)

Tagging: Follow the [VM][CONTEXT] standard from ../SKILL.md (Tagging Standard).

## Table of Contents

1. Intake Questions
2. When To Use This Path
3. Opinionated Defaults
4. Quickstart
5. Dependency Tiers
6. Version Alignment
7. Implementation Checklist
8. Provider Setup (Current Baseline)
9. Custom Chain IDs Not In Initia Registry
10. Wallet Button Pattern
11. Transaction Patterns
12. Optional Advanced Path: Direct SDK Contract Calls
13. Gotchas
14. Install Recovery

## Intake Questions

Ask for missing context before writing code:

1. Framework and runtime (`next`, `react-vite`, other)?
2. Is provider wiring already present?
3. Which network is targeted (testnet/mainnet/custom appchain)?
4. Is user-confirmed tx UX required (`requestTxBlock`) or direct submit acceptable?
5. Are chain endpoints and deployed contract addresses known?

If VM is `evm` and user only needs normal contract interaction over JSON-RPC, use `frontend-evm-rpc.md` as default instead of this file.

## When To Use This Path

Use this file when at least one is true:

- App requires InterwovenKit wallet/bridge/portfolio UI.
- App is Move/Wasm oriented with `requestTxBlock` message flow.
- User explicitly requests InterwovenKit.

For pure EVM dApp frontend work (wallet + contract calls), default to `frontend-evm-rpc.md`.

## Opinionated Defaults

| Area | Default | Notes |
|---|---|---|
| Frontend wallet stack | `@initia/interwovenkit-react` | Primary integration path |
| Tx UX | `requestTxBlock` | Prefer explicit user confirmation |
| Local Tx UX | `requestTxSync` | Use sync submission for better robustness in local dev |
| Provider order | Wagmi -> Query -> InterwovenKit | Stable provider path |
| Connector | `initiaPrivyWalletConnector` | Default connector in kit docs |
| SDK path | InterwovenKit first | Use direct SDK only when required |

## Quickstart

### React + Vite (TypeScript)

```bash
# Use --template react or react-ts
npm create vite@latest initia-frontend -- --template react-ts
cd initia-frontend
npm install
npm install @initia/interwovenkit-react wagmi viem @tanstack/react-query @initia/initia.js @initia/initia.proto
npm install --save-dev vite-plugin-node-polyfills
npm install buffer util
```

## Dependency Tiers

### Required

- `@initia/interwovenkit-react`
- `@tanstack/react-query`
- `wagmi`
- `viem`
- `buffer` (Required polyfill for browser compatibility)
- `util` (Required polyfill for browser compatibility)

### Optional (common)

- `@initia/utils` for helpers like address truncation.

### Advanced

- `@initia/initia.js` and `@initia/initia.proto` for direct REST/protobuf workflows.
- `vite-plugin-node-polyfills` (Highly recommended for Vite users to avoid "Buffer is not defined" errors).

## Version Alignment

Avoid hard-coded version matrices in this skill.

- Install latest compatible package versions unless the user asks to pin.
- Keep `@initia/interwovenkit-react`, `wagmi`, and `viem` aligned to peer dependency expectations.
- **IMPORTANT**: If using Vite, you MUST install `vite-plugin-node-polyfills` and add it to `vite.config.js` to ensure `@initia/initia.js` works in the browser. Also add `resolve.dedupe` for `react`, `react-dom`, `wagmi`, `@tanstack/react-query`, and `viem`.

## Implementation Checklist

1. Install required dependencies + polyfills (`buffer`, `util`, `vite-plugin-node-polyfills`).
2. Configure Vite polyfills and `resolve.dedupe` (`react`, `react-dom`, `wagmi`, `@tanstack/react-query`, `viem`) if applicable.
3. Set up `window.Buffer` and `window.process` in `main.jsx` before other imports.
4. Set up providers in order: `WagmiProvider` -> `QueryClientProvider` -> `InterwovenKitProvider`.
5. For custom appchains, provide a complete `customChain` object including `rpc`, `rest`, and a placeholder `indexer`. Pass BOTH `customChain={customChain}` AND `customChains={[customChain]}` to the provider.
6. Use `RESTClient` (from `@initia/initia.js`) for querying resources or view functions. **Note: `LCDClient` is deprecated.**
7. Prefer `rest.move.resource` for state queries as it is more robust than view functions.
8. **IMPORTANT (v2.4.0)**: Use `openConnect` (not `openModal`) to open the wallet connection modal. Extract it from the `useInterwovenKit` hook.
9. **IMPORTANT (v2.4.0)**: `useInterwovenKit` does NOT export a `rest` client. You MUST instantiate `RESTClient` from `@initia/initia.js` manually for queries.
10. If the app depends on a deployed contract address, store the resolved live address in runtime config (for example, `.env` / `VITE_*`) instead of leaving placeholder constants in component code. Keep VM-specific names precise in code: `moduleAddress` for Move, `contractAddress` for EVM/Wasm.
11. If `.env` values are added or changed in a running Vite app, restart the dev server so the new values are loaded.
12. **Auto-Sign API (STRICTLY OPT-IN)**:
    - **Setup Requirement**: If (and only if) auto-sign support is requested, `enableAutoSign={true}` must be passed to the `InterwovenKitProvider` in `main.jsx`.
    - **Usage**: The `useInterwovenKit` hook returns an `autoSign` object (not individual functions).
    - Status: `autoSign.isEnabledByChain[chainId]`
    - Enable: `await autoSign.enable(chainId)`
    - Disable: `await autoSign.disable(chainId)`
    - **Session Wallet Fix**: You MUST include `bech32_prefix` (e.g., `bech32_prefix: "init"`) as a top-level field in your `customChain` object to avoid derivation `TypeError`.
    - **Headless Flow**: To ensure auto-signed transactions are "headless" (no fee selection prompt), ALWAYS include `autoSign: true` and an explicit `feeDenom` (e.g., `feeDenom: "umin"`) in the transaction request.
13. **Chain Stability (CRITICAL)**: To avoid "Chain not found" or "URL not found" errors, the `customChain.apis` object MUST include `rpc`, `rest`, AND `indexer` (even if indexer is a placeholder).

## Provider Setup (Current Baseline)

```tsx
// main.jsx
import { Buffer } from 'buffer'
window.Buffer = Buffer
window.process = { env: { NODE_ENV: 'development' } }

import React from 'react'
import ReactDOM from 'react-dom/client'
import "@initia/interwovenkit-react/styles.css";
import { injectStyles, InterwovenKitProvider, TESTNET } from "@initia/interwovenkit-react";
import InterwovenKitStyles from "@initia/interwovenkit-react/styles.js";
import { WagmiProvider, createConfig, http } from "wagmi";
import { mainnet } from "wagmi/chains";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import App from './App.jsx'

// Inject styles for the widget
injectStyles(InterwovenKitStyles);

const queryClient = new QueryClient();
const wagmiConfig = createConfig({
  chains: [mainnet],
  transports: { [mainnet.id]: http() },
});

const customChain = {
  chain_id: "my-appchain-1",
  chain_name: "myapp",
  pretty_name: "My Appchain",
  network_type: "testnet",
  bech32_prefix: "init",
  logo_URIs: {
    png: "https://raw.githubusercontent.com/initia-labs/initia-registry/main/testnets/initia/images/initia.png",
    svg: "https://raw.githubusercontent.com/initia-labs/initia-registry/main/testnets/initia/images/initia.svg"
  },
  apis: {
    rpc: [{ address: "http://localhost:26657" }],
    rest: [{ address: "http://localhost:1317" }],
    indexer: [{ address: "http://localhost:8080" }], // Placeholder REQUIRED
    "json-rpc": [{ address: "http://localhost:8545" }] // REQUIRED for EVM appchains
  },
  fees: {
    fee_tokens: [{
      denom: "GAS",
      fixed_min_gas_price: 0,
      low_gas_price: 0,
      average_gas_price: 0,
      high_gas_price: 0
    }]
  },
  staking: {
    staking_tokens: [{ denom: "GAS" }]
  },
  metadata: {
    minitia: { type: "minievm" },
    is_l1: false
  },
  native_assets: [
    {
      denom: "GAS",
      name: "Native Token",
      symbol: "GAS",
      decimals: 18
    },
    {
      denom: "uinit",
      name: "Initia",
      symbol: "INIT",
      decimals: 6
    }
  ]
};

ReactDOM.createRoot(document.getElementById('root')).render(
  <WagmiProvider config={wagmiConfig}>
    <QueryClientProvider client={queryClient}>
      <InterwovenKitProvider
        {...TESTNET}
        defaultChainId="my-appchain-1"
        customChain={customChain}
        customChains={[customChain]}
      >
        <App />
      </InterwovenKitProvider>
    </QueryClientProvider>
  </WagmiProvider>
);
```

## Custom Chain IDs Not In Initia Registry

InterwovenKit supports non-registry chains via `customChain` (singular) or `customChains` (array) on `InterwovenKitProvider`.

Important behavior:

- `customChain` is the preferred property for a single local appchain.
- `apis` MUST use the array-of-objects format: `rpc: [{ address: "..." }]`.
- For `minievm` chains, you MUST include `"json-rpc"` in the `apis` object for internal balance and state queries to resolve.
- `apis` MUST include `rpc`, `rest`, AND `indexer` (even if indexer is a placeholder).
- `metadata` MUST include `is_l1: false` for appchains to be correctly registered in local environments.
- `logo_URIs` and `staking` fields improve stability during chain discovery.
- `defaultChainId` must match the `chain_id` you want active.
- If omitted or incomplete, runtime can fail with `Chain not found: <CHAIN_ID>`.

## Wallet Button Pattern (Account Pill)

The "Account Pill" is the recommended pattern for wallet connectivity. It provides a clean, professional UI by showing the truncated address with a connectivity indicator, while delegating account management (and disconnecting) to the InterwovenKit Wallet Drawer.

> **Compliance Note**: Per the "Initia Usernames" mandate, you MUST NOT include `username` in this component unless explicitly requested. If requested, use the pattern below.

```tsx
import { useInterwovenKit } from "@initia/interwovenkit-react";

function shortenAddress(value: string) {
  if (value.length < 14) return value;
  return `${value.slice(0, 8)}...${value.slice(-4)}`;
}

export function WalletPill() {
  const { initiaAddress, username, openConnect, openWallet } = useInterwovenKit();

  // Standard username resolution pattern
  const label = username ? username : shortenAddress(initiaAddress);

  if (!initiaAddress) return (
    <button onClick={openConnect} className="btn-connect">
      Connect Wallet
    </button>
  );

  return (
    <button onClick={openWallet} className="account-pill">
      <span className="status-dot"></span>
      {label}
    </button>
  );
}
```

**Recommended CSS (Vanilla):**
```css
.account-pill {
  display: flex;
  align-items: center;
  background-color: #ffffff;
  border: 1px solid #e2e8f0;
  padding: 6px 16px;
  borderRadius: 100px;
  cursor: pointer;
  fontWeight: 600;
  fontSize: 14px;
  transition: all 0.2s ease;
}

.status-dot {
  width: 8px;
  height: 8px;
  background-color: #10b981;
  border-radius: 50%;
  margin-right: 10px;
}
```

### Auto-Sign Toggle Pattern

For games or high-frequency apps, providing an "Auto-Sign" toggle is essential for a "headless" UX. This allows users to delegate signing to a session wallet for the current chain.

```tsx
export function AutoSignToggle({ chainId }) {
  const { autoSign } = useInterwovenKit();
  const isEnabled = autoSign?.isEnabledByChain[chainId];

  const handleToggle = async () => {
    if (isEnabled) {
      await autoSign.disable(chainId);
    } else {
      await autoSign.enable(chainId);
    }
  };

  return (
    <button onClick={handleToggle} className={`auto-sign-btn ${isEnabled ? 'active' : ''}`}>
      <span className="dot"></span>
      {isEnabled ? 'AUTO-SIGN ON' : 'AUTO-SIGN OFF'}
    </button>
  );
}
```

## Standard Username Pattern

When username support is requested for feeds or message boards, use:
- `useInterwovenKit().username` for the connected wallet identity.
- `useUsernameQuery(address?)` for resolving any other wallet address.
- For rendered message lists, move the sender label into a child component and call `useUsernameQuery(address)` there so the React hooks usage remains valid.

```tsx
import { useInterwovenKit, useUsernameQuery } from "@initia/interwovenkit-react";

export function MessageRow({ message }) {
  const { initiaAddress, username } = useInterwovenKit();
  const { data: senderUsername } = useUsernameQuery(message.sender);

  return (
    <div className="message">
      <span className="sender">
        {message.sender === initiaAddress
          ? (username ? username : shortenAddress(message.sender))
          : (senderUsername ? senderUsername : shortenAddress(message.sender))}
      </span>
      <p>{message.text}</p>
    </div>
  );
}

export function MessageList({ messages }) {
  return messages.map((message, index) => (
    <MessageRow key={`${message.sender}-${index}`} message={message} />
  ));
}
```

`useUsernameQuery` API:
- `useUsernameQuery()` -> connected wallet address
- `useUsernameQuery(address)` -> explicit address resolution

## Reference UI Patterns (Optional)

Use these patterns to satisfy the "beautiful and polished" mandate for centered appcard layouts.

### Centered Card & Balance Styles
```javascript
const styles = {
  // ... (existing styles)
};
```

### High-Fidelity Hero Layout (Vanilla CSS)

Use this structure for a professional, centered landing page.

**CSS (index.css):**
```css
.app-container { min-height: 100vh; display: flex; flex-direction: column; }
.header { position: sticky; top: 0; z-index: 50; background: rgba(255, 255, 255, 0.8); backdrop-filter: blur(12px); border-bottom: 1px solid #e2e8f0; padding: 1rem 1.5rem; }
.main-content { max-width: 1100px; margin: 0 auto; padding: 4rem 1.5rem; width: 100%; flex: 1; display: grid; grid-template-columns: 1fr 1fr; gap: 4rem; align-items: center; }
@media (max-width: 900px) { .main-content { grid-template-columns: 1fr; text-align: center; } }
.hero-section h2 { font-size: 4rem; font-weight: 900; line-height: 1.1; letter-spacing: -0.04em; }
.hero-accent { background: linear-gradient(to right, #2563eb, #6366f1); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
.bank-card { background: white; border-radius: 32px; box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.1); border: 1px solid #e2e8f0; overflow: hidden; width: 100%; max-width: 440px; margin: 0 auto; }
```

**JSX Structure:**
```jsx
<div className="app-container">
  <header className="header">
    <div className="header-content">
      {/* Logo & Wallet Connect */}
    </div>
  </header>
  <main className="main-content">
    <div className="hero-section">
      <h2>The Future of <span className="hero-accent">Savings</span> is Native.</h2>
      <p className="hero-description">Experience ultra-low latency banking.</p>
    </div>
    <div className="app-section">
      <Bank /> {/* Interaction Card */}
    </div>
  </main>
</div>
```

## Transaction Patterns

### Move Contract Execution (`requestTxSync` flow for local appchains)

```tsx
import { useInterwovenKit } from "@initia/interwovenkit-react";
import { MsgExecute } from "@initia/initia.proto/initia/move/v1/tx";

export function useGameActions() {
  const { initiaAddress, requestTxSync } = useInterwovenKit();

  const mintShard = async (moduleAddress: string) => {
    if (!initiaAddress) return;

    const messages = [{
      typeUrl: "/initia.move.v1.MsgExecute",
      value: MsgExecute.fromPartial({
        sender: initiaAddress,
        moduleAddress, // bech32
        moduleName: "items",
        functionName: "mint_shard",
        args: [],
        typeArgs: [],
      }),
    }];

    return requestTxSync({
      chainId: "game-1",
      messages,
    });
  };

  return { mintShard };
}
```

### EVM Contract Execution (`requestTxBlock` flow)

```tsx
import { useInterwovenKit } from "@initia/interwovenkit-react";
import { encodeFunctionData } from "viem";
import { MsgCall } from "@initia/initia.proto/minievm/evm/v1/tx";

const ABI = [ /* ... */ ];

export function useBankActions(contractAddress: string) {
  const { initiaAddress, requestTxBlock } = useInterwovenKit();

  const deposit = async (amount: string) => {
    if (!initiaAddress) return;

    const data = encodeFunctionData({
      abi: ABI,
      functionName: "deposit",
    });

    const messages = [{
      typeUrl: "/minievm.evm.v1.MsgCall",
      value: {
        sender: initiaAddress, // bech32
        contractAddr: contractAddress, // hex (0x...)
        input: data.startsWith("0x") ? data : `0x${data}`,
        value: amount, // Amount in base units (string)
        accessList: [], // MANDATORY to avoid Amino error
        authList: [],   // MANDATORY to avoid Amino error
      },
    }];

    return requestTxBlock({
      chainId: "<INSERT_APPCHAIN_ID_HERE>", // Strongly recommended for appchains
      messages
    });
  };

  return { deposit };
}
```

### Wasm Contract Execution (`requestTxSync` flow)

```tsx
import { useInterwovenKit } from "@initia/interwovenkit-react";

export function useBoardActions(contractAddress: string) {
  const { initiaAddress, requestTxSync } = useInterwovenKit();

  const postMessage = async (message: string) => {
    if (!initiaAddress) return;

    // MsgExecuteContract expects 'msg' as bytes (Uint8Array).
    // The JSON shape must match the contract's ExecuteMsg exactly.
    const msg = new TextEncoder().encode(JSON.stringify({ post_message: { message } }));

    return requestTxSync({
      chainId: "social-1",
      messages: [
        {
          typeUrl: "/cosmwasm.wasm.v1.MsgExecuteContract",
          value: {
            sender: initiaAddress,
            contract: contractAddress,
            msg,
            funds: [],
          },
        },
      ],
    });
  };

  return { postMessage };
}
```

## Liquidity Management (Bridge)

InterwovenKit provides specialized UI modals for moving funds between chains. Use `openBridge` for a simplified entry point.

**Local Dev Support**: In local environments, the modal may be blank if using local `chainId`. Use a public testnet ID (e.g., `initiation-2`) as the source to move funds *onto* the appchain.

```tsx
import { useInterwovenKit } from "@initia/interwovenkit-react";

export function BridgeButton() {
  const { initiaAddress, openBridge } = useInterwovenKit();

  const handleBridge = () => {
    if (!initiaAddress) return;
    openBridge({
      srcChainId: "initiation-2",
      srcDenom: "uinit"
    });
  };

  return (
    <div className="bridge-ui">
      <button onClick={handleBridge}>Bridge Assets</button>
    </div>
  );
}
```

#### Pro Tip: EVM Dual-Address Requirements
When interacting with an EVM appchain:
1. **Querying (`eth_call` / `ethers`)**: Use the **hex address** (`0x...`) for the `from` or contract view parameters. You MUST convert a bech32 address using `AccAddress.toHex(address)` from `@initia/initia.js`.
2. **Transacting (`MsgCall`)**: Use the **bech32 address** (`init1...`) for the `sender` field in the message payload. The `contractAddr` MUST be **hex** (`0x...`).

- **[EVM][RPC] Address Conversion (Hex)**:
  ```javascript
  import { AccAddress } from "@initia/initia.js";
  import { ethers } from "ethers";

  const toHexAddress = (bech32Addr) => {
    try {
      const hex = AccAddress.toHex(bech32Addr);
      const cleanHex = hex.startsWith("0x") ? hex : `0x${hex}`;
      return ethers.getAddress(cleanHex); // Normalizes checksum
    } catch (e) {
      return null;
    }
  };
  ```

- **[EVM][INTERWOVENKIT] MsgCall Requirements**: When passing a raw object (not using `MsgCall.fromPartial`), you MUST use **camelCase** for the fields (e.g., `contractAddr`, `accessList`, `authList`) and ensure **both** the address and input have the `0x` prefix. You MUST also include `accessList: []` and `authList: []` as empty arrays to avoid Amino conversion errors.

- **Note**: If `contractAddr` is passed as hex but still fails with "empty address string", try explicitly casting it: `AccAddress.fromHex(CONTRACT_ADDRESS.replace('0x', ''))`. However, the standard `0x...` hex string is usually preferred for `minievm`.

## [MOVE][REST] View Function Argument Encoding

When calling Move view functions using `rest.move.view`, address arguments MUST be formatted as 32-byte padded hex strings and then Base64 encoded. Failure to do so will result in `400 Bad Request` errors.

```javascript
import { AccAddress } from "@initia/initia.js";

const fetchMoveState = async (address) => {
  try {
    // 1. Convert bech32 to Hex
    // 2. Remove '0x' prefix and pad to EXACTLY 64 chars (32 bytes)
    // 3. Convert to Buffer and then Base64 string
    const hexAddr = AccAddress.toHex(address).replace('0x', '').padStart(64, '0');
    const b64Addr = Buffer.from(hexAddr, 'hex').toString('base64');

    const res = await rest.move.view(
      MODULE_ADDR,
      MODULE_NAME,
      'your_view_function',
      [], // Type arguments
      [b64Addr] // Encoded arguments
    );

    return JSON.parse(res.data);
  } catch (err) {
    console.error("View function failed:", err);
    return null; // or default state
  }
};
```

## Optional Advanced Path: Direct SDK Contract Calls

```tsx
import { RESTClient, bcs, AccAddress } from "@initia/initia.js";
import { MsgExecute } from "@initia/initia.proto/initia/move/v1/tx";

// Use RESTClient for SDK v1.0+
const rest = new RESTClient("http://localhost:1317", { chainId: "mygame-1" });

// Prefer querying resources directly for state
export async function queryInventory(moduleAddressBech32: string, walletAddress: string) {
  const structTag = `${AccAddress.toHex(moduleAddressBech32)}::items::Inventory`;

  try {
    return await rest.move.resource(walletAddress, structTag);
  } catch (error) {
    const message = String(error?.response?.data?.message || error?.message || "");
    if (message.includes("not found")) {
      return { type: structTag, data: { shards: "0", relics: "0" } };
    }
    throw error;
  }
}

// CosmWasm query via REST
export async function queryWasm(contractAddress: string, queryMsg: any) {
  // Query must be base64 encoded because it's part of the REST URL path
  const queryData = Buffer.from(JSON.stringify(queryMsg)).toString("base64");
  return rest.wasm.smartContractState(contractAddress, queryData);
}

// Convert bech32 to hex for EVM calls
export function getHexAddress(address: string) {
  return address.startsWith("0x") ? address : AccAddress.toHex(address);
}
```

## Gotchas

- **[EVM][INTERWOVENKIT] Incorrect typeUrl**: For EVM contract calls via `requestTxBlock`, the `typeUrl` usually follows the pattern `/minievm.evm.v1.MsgCall` or `/initia.evm.v1.MsgCall`.
  - **Fix**: Check your appchain's module name (often `minievm` on rollups) or use `../scripts/verify-appchain.sh` to see the module registry.

- **[EVM][INTERWOVENKIT] MsgCall Value Type**: The `value` field in `MsgCall` (for sending native tokens) MUST be a string representing the amount in base units (wei).
  - **Fix**: Use `parseEther(amount).toString()` to ensure it's a string.
- **[EVM][INTERWOVENKIT] `requestTxBlock` `.map` TypeError**: If you see `Cannot read properties of undefined (reading 'map')`, you likely passed `msgs` instead of `messages`.
  - **Fix**: Always call `requestTxBlock({ chainId, messages: [...] })`.

- **[EVM][INTERWOVENKIT] URL not found error**: This error in the frontend usually occurs when the `customChain` config is missing the `json-rpc` entry in `apis`.
  - **Fix**: Add `"json-rpc": [{ address: "http://localhost:8545" }]` to your `customChain.apis`.

- **[EVM][FRONTEND] Ethers v6 Syntax**: Many modern InterwovenKit projects pull in `ethers` v6, which has breaking changes from v5.
  - **Fix**: Use `new ethers.Interface()` instead of `ethers.utils.Interface`, and `ethers.parseEther()` instead of `ethers.utils.parseEther()`.

- **[WASM][REST] Query 400 Bad Request**: `smartContractState` expects the query to be a Base64-encoded string.
  - **Fix**: `const queryData = Buffer.from(JSON.stringify(query)).toString("base64"); rest.wasm.smartContractState(addr, queryData);`
- **[WASM][REST] Query response shape is unexpected**: `smartContractState` often returns the decoded payload directly, not under `res.data`.
  - **Fix**: Inspect the returned object first and prefer direct access like `res.messages` when the contract query returns `{ messages: [...] }`.

- **[WASM][INTERWOVENKIT] Transaction "invalid payload" / map error**: `MsgExecuteContract` expects the `msg` field as bytes (`Uint8Array`). If `requestTxBlock` fails with a `.map()` error, try using `requestTxSync` with the `messages` (plural) field.
  - **Fix**: Use `new TextEncoder().encode(JSON.stringify(msg))` for the `msg` field.
- **[WASM][REST] Query still shows old state right after post**: local REST/indexer visibility can lag briefly behind a successful `requestTxSync`.
  - **Fix**: wait a short delay before refreshing, or poll until the new state appears.

- **Buffer is not defined**: Initia.js uses Node.js globals. Use `vite-plugin-node-polyfills` or manual global assignment.
- **WagmiProviderNotFoundError / Invalid hook call in Vite**: This usually means duplicated provider modules in the Vite dependency graph.
  - **Fix**: In `vite.config.js`, add `resolve.dedupe: ["react", "react-dom", "wagmi", "@tanstack/react-query", "viem"]`, then restart the dev server (clearing `node_modules/.vite*` if needed).
- **switchChain is not a function**: `switchChain` is NOT exported from `useInterwovenKit`. Change chain context by setting the `defaultChainId` in `InterwovenKitProvider` or by using `openBridge` to move assets between specific chains.
- **Chain not found**: Ensure `customChain` AND `customChains: [customChain]` are passed to `InterwovenKitProvider`. Ensure `rpc`, `rest`, AND `indexer` are present in `customChain.apis`.
- **URL not found**: Ensure `rpc`, `rest`, AND `indexer` are present in `customChain.apis`.
- **LCDClient or useRest is not an export**: These hooks are not currently exported in `@initia/interwovenkit-react` v2.4.0. Use `RESTClient` from `@initia/initia.js` instead.
- **View function 400/500 errors**: Ensure arguments are correctly typed strings (e.g., `address:init1...`) and parameters match Move signature exactly. Prefer `resource()` queries for simple state.
  - **[MOVE][REST] view 400 Fix**: Address arguments MUST be hex strings padded to exactly **64 characters** (32 bytes) before Base64 encoding.
  - **[MOVE][REST] view 500 Fix**: If a view function fails with 500 because a resource doesn't exist yet, ALWAYS wrap the call in a `.catch()` to return default values (e.g., `["0", "0"]`).
- **[MOVE][REST] resource struct tags**: `rest.move.resource(wallet, structTag)` requires the wallet address in bech32, but the struct tag itself must use the module's hex address (`0x...::items::Inventory`). Using `init1...::items::Inventory` will fail with `invalid struct tag`.
  - **[MOVE][REST] state update delay**: After a transaction, there is a short delay before the REST API reflects the new state. ALWAYS include a 2-second delay (`setTimeout`) before refreshing the inventory or state.
- **Unstyled Modal**: Ensure `styles.css` is imported AND `injectStyles(InterwovenKitStyles)` is called in `main.jsx`.

- **Error: must contain at least one message**: This often occurs if `requestTxBlock` is called without a `chainId` or with a `chainId` that the node doesn't recognize (e.g., trying to send an L2-only message to L1).
  - **Fix**: Ensure `InterwovenKitProvider` is configured with your `customChain` and `defaultChainId`. Also, explicitly pass `chainId` in the `requestTxBlock` options.
  - **Note**: When passing a raw object (not using `MsgCall.fromPartial`), ALWAYS use **camelCase** for the fields (e.g., `contractAddr`, `accessList`) to ensure correct processing by the InterwovenKit provider.

## Install Recovery

If dependency install was interrupted and subsequent installs fail unexpectedly, use the recovery commands in `troubleshooting.md` ("NPM install interrupted / dependency state corrupted").
