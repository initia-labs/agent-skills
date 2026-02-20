# Frontend (EVM Direct RPC)

Use this path by default when VM is `evm` and the app only needs normal EVM wallet/contract interaction.

Do not require InterwovenKit for this baseline path.

## Table of Contents

1. Intake Questions
2. Defaults
3. Quickstart
4. Provider Setup
5. Contract Write Pattern
6. Rollup Value Discovery
7. Gotchas

## Intake Questions

1. Do you have `chainId` and JSON-RPC URL?
2. Is this local Weave rollup or public endpoint?
3. Which wallet target (injected/MetaMask, WalletConnect)?
4. Contract address + ABI + function call details?

If values are missing, run `runtime-discovery.md` and confirm before proceeding.

## Defaults

| Area | Default |
|---|---|
| Stack | `wagmi`, `viem`, `@tanstack/react-query` |
| Wallet | injected connector first |
| Transport | JSON-RPC `http()` |
| Tx path | `writeContract` (or `sendTransaction` for native transfer) |

## Quickstart

```bash
npm install wagmi viem @tanstack/react-query
```

## Provider Setup

```tsx
import type { PropsWithChildren } from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createConfig, http, WagmiProvider } from "wagmi";
import { injected } from "wagmi/connectors";
import { defineChain } from "viem";

const queryClient = new QueryClient();

const rollup = defineChain({
  id: 42069,
  name: "Local Rollup",
  network: "local-rollup",
  nativeCurrency: { name: "Gas", symbol: "GAS", decimals: 18 },
  rpcUrls: { default: { http: ["http://127.0.0.1:8545"] } },
});

const config = createConfig({
  chains: [rollup],
  connectors: [injected()],
  transports: {
    [rollup.id]: http("http://127.0.0.1:8545"),
  },
});

export function Providers({ children }: PropsWithChildren) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={config}>{children}</WagmiProvider>
    </QueryClientProvider>
  );
}
```

## Contract Write Pattern

```tsx
import { useWriteContract } from "wagmi";

const abi = [
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
] as const;

export function MintButton() {
  const { writeContractAsync, isPending } = useWriteContract();

  async function onClick() {
    await writeContractAsync({
      address: "0xContractAddress",
      abi,
      functionName: "mint",
      args: ["0xRecipientAddress", 1n],
      chainId: 42069,
    });
  }

  return (
    <button onClick={onClick} disabled={isPending}>
      {isPending ? "Submitting..." : "Mint"}
    </button>
  );
}
```

## Rollup Value Discovery

When `chainId` or JSON-RPC is unknown, run `runtime-discovery.md`, then confirm with the user before wiring frontend config.

## Gotchas

- Ensure `chainId` in wagmi config matches wallet-selected chain.
- Ensure JSON-RPC endpoint matches the same chain.
- Use `http://localhost:8545`/`http://127.0.0.1:8545` only if your rollup is running locally.
- If wallet rejects chain, add/switch chain in wallet before writing.

Sanity check provider setup:

```bash
scripts/check-provider-setup.sh --mode evm-rpc <providers-file.tsx>
```
