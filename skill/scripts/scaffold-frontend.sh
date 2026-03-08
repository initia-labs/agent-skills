#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scaffold-frontend.sh <target-dir>

Example:
  scaffold-frontend.sh ./my-react-app
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

target="$1"
pkg_name=$(basename "$target")
sanitized_pkg_name="$(printf '%s' "$pkg_name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/[-._]{2,}/-/g; s/^[-._]+//; s/[-._]+$//')"
if [[ -z "$sanitized_pkg_name" ]]; then
  sanitized_pkg_name="initia-frontend"
fi

mkdir -p "$target/src"
cd "$target"

# Step 1: Create package.json directly with all dependencies (Avoids npm init + jq overhead)
echo "Creating package.json..."
cat > package.json <<JSON
{
  "name": "$sanitized_pkg_name",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@initia/initia.js": "*",
    "@initia/interwovenkit-react": "*",
    "@tanstack/react-query": "*",
    "buffer": "*",
    "lucide-react": "*",
    "react": "*",
    "react-dom": "*",
    "util": "*",
    "viem": "*",
    "wagmi": "*"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "*",
    "vite": "*",
    "vite-plugin-node-polyfills": "*"
  }
}
JSON

# Step 2: Create Vite config with polyfills
cat > vite.config.js <<EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { nodePolyfills } from 'vite-plugin-node-polyfills'

export default defineConfig({
  resolve: {
    dedupe: ['react', 'react-dom', 'wagmi', '@tanstack/react-query', 'viem'],
  },
  optimizeDeps: {
    include: ['wagmi', '@tanstack/react-query', 'viem'],
  },
  plugins: [
    react(),
    nodePolyfills({
      globals: {
        Buffer: true,
        process: true,
      },
    }),
  ],
})
EOF

# Step 3: Create index.css with Design Tokens and Base Components
cat > src/index.css <<EOF
:root {
  --bg: #050505;
  --fg: #ffffff;
  --fg-muted: rgba(255, 255, 255, 0.6);
  --accent: #6366f1;
  --accent-hover: #4f46e5;
  --surface: rgba(255, 255, 255, 0.05);
  --border: rgba(255, 255, 255, 0.1);
  --radius: 20px;
}

body {
  margin: 0;
  padding: 0;
  background-color: var(--bg);
  color: var(--fg);
  font-family: 'Inter', system-ui, -apple-system, sans-serif;
  -webkit-font-smoothing: antialiased;
}

* { box-sizing: border-box; }

.card {
  background: var(--surface);
  backdrop-filter: blur(16px);
  -webkit-backdrop-filter: blur(16px);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  padding: 2rem;
}

.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.75rem 1.5rem;
  border-radius: 100px;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s ease;
  border: none;
}

.btn-primary { background: var(--accent); color: white; }
.btn-primary:hover { background: var(--accent-hover); transform: translateY(-1px); }

.btn-secondary {
  background: var(--surface);
  color: white;
  border: 1px solid var(--border);
}
.btn-secondary:hover { background: rgba(255, 255, 255, 0.1); }
EOF

# Step 4: Create index.html
cat > index.html <<EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$pkg_name</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# Step 5: Create main.jsx with Provider setup
cat > src/main.jsx <<EOF
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
import './index.css'

// Inject styles for the widget
injectStyles(InterwovenKitStyles);

const queryClient = new QueryClient();
const wagmiConfig = createConfig({
  chains: [mainnet],
  transports: { [mainnet.id]: http() },
});

// Custom Appchain Configuration
// This is REQUIRED for local rollups to be recognized by InterwovenKit.
// Set VITE_NATIVE_DECIMALS in .env (for example: VITE_NATIVE_DECIMALS=6) when your chain is not 18 decimals.
const customChain = {
  chain_id: '<INSERT_APPCHAIN_ID_HERE>', // Update to match your rollup
  chain_name: '<INSERT_APP_NAME_HERE>',
  pretty_name: '<INSERT_PRETTY_NAME_HERE>',
  network_type: 'testnet',
  bech32_prefix: 'init',
  logo_URIs: {
    png: 'https://raw.githubusercontent.com/initia-labs/initia-registry/main/testnets/initia/images/initia.png',
    svg: 'https://raw.githubusercontent.com/initia-labs/initia-registry/main/testnets/initia/images/initia.svg',
  },
  apis: {
    rpc: [{ address: 'http://localhost:26657' }],
    rest: [{ address: 'http://localhost:1317' }],
    indexer: [{ address: 'http://localhost:8080' }],
    "json-rpc": [{ address: 'http://localhost:8545' }], // REQUIRED for EVM rollups
  },
  fees: {
    fee_tokens: [{ 
      denom: '<INSERT_NATIVE_DENOM_HERE>', 
      fixed_min_gas_price: 0,
      low_gas_price: 0,
      average_gas_price: 0,
      high_gas_price: 0
    }],
  },
  staking: {
    staking_tokens: [{ denom: '<INSERT_NATIVE_DENOM_HERE>' }]
  },
  metadata: {
    is_l1: false,
    minitia: {
      type: '<INSERT_MINITIA_TYPE_HERE>', // Use 'minimove', 'miniwasm', or 'minievm'
    },
  },
  native_assets: [
    {
      denom: '<INSERT_NATIVE_DENOM_HERE>',
      name: 'Native Token',
      symbol: '<INSERT_NATIVE_SYMBOL_HERE>',
      decimals: Number(import.meta.env.VITE_NATIVE_DECIMALS ?? 18)
    }
  ]
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <InterwovenKitProvider
          {...TESTNET}
          defaultChainId={customChain.chain_id}
          customChain={customChain}
          customChains={[customChain]}
        >
          <App />
        </InterwovenKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
)
EOF

# Step 6: Create App.jsx
cat > src/App.jsx <<EOF
import React from 'react'
import { useInterwovenKit } from "@initia/interwovenkit-react";

function App() {
  const { initiaAddress, openConnect, openWallet } = useInterwovenKit();

  const shortenAddress = (addr) => {
    if (!addr) return "";
    return \`\${addr.slice(0, 8)}...\${addr.slice(-4)}\`;
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
      <header style={{ 
        width: '100%', 
        maxWidth: '1200px', 
        display: 'flex', 
        justifyContent: 'space-between', 
        alignItems: 'center', 
        padding: '2rem' 
      }}>
        <h1 style={{ fontSize: '1.25rem', fontWeight: 800, margin: 0 }}>$pkg_name</h1>
        
        {!initiaAddress ? (
          <button onClick={openConnect} className="btn btn-primary">Connect Wallet</button>
        ) : (
          <button onClick={openWallet} className="btn btn-secondary">
            {shortenAddress(initiaAddress)}
          </button>
        )}
      </header>

      <main style={{ flex: 1, width: '100%', maxWidth: '640px', padding: '2rem' }}>
        <div className="card" style={{ textAlign: 'center' }}>
          <h2 style={{ fontSize: '1.5rem', marginBottom: '1rem' }}>Welcome to Initia</h2>
          <p style={{ color: 'rgba(255,255,255,0.6)', marginBottom: '2rem' }}>
            Your appchain frontend is ready. Modify <code>src/App.jsx</code> to start building your application.
          </p>
          <div style={{ display: 'flex', gap: '1rem', justifyContent: 'center' }}>
            <a href="https://docs.initia.xyz" target="_blank" rel="noopener noreferrer" className="btn btn-primary">Documentation</a>
            <button className="btn btn-secondary">Learn More</button>
          </div>
        </div>
      </main>

      <footer style={{ padding: '4rem 2rem', color: 'rgba(255,255,255,0.2)', fontSize: '0.75rem', fontWeight: 700 }}>
        POWERED BY INITIA
      </footer>
    </div>
  )
}

export default App
EOF

# Step 7: Perform a single, optimized npm install
echo "Installing React, Vite, and Initia dependencies (single pass)..."
npm install --quiet --no-progress --no-audit --no-fund --prefer-offline

echo "Scaffolded React + Vite project at $target"
