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

mkdir -p "$target/src"

# Initialize npm non-interactively
cd "$target"
npm init -y > /dev/null

# Set type to module and add vite scripts
jq '. + {type: "module", scripts: {dev: "vite", build: "vite build", preview: "vite preview"}}' package.json > package.json.tmp && mv package.json.tmp package.json

# Install dependencies silently
echo "Installing React, Vite, and Initia dependencies..."
npm install vite @vitejs/plugin-react react react-dom --save-dev --quiet --no-progress > /dev/null
npm install @initia/interwovenkit-react wagmi viem @tanstack/react-query @initia/initia.js @initia/initia.proto --quiet --no-progress > /dev/null
npm install --save-dev vite-plugin-node-polyfills --quiet --no-progress > /dev/null
npm install buffer util --quiet --no-progress > /dev/null

# Create Vite config with polyfills
cat > vite.config.js <<EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { nodePolyfills } from 'vite-plugin-node-polyfills'

export default defineConfig({
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

# Create index.css
cat > src/index.css <<EOF
body {
  margin: 0;
  padding: 0;
  background-color: #fafafa;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

* {
  box-sizing: border-box;
}
EOF

# Create index.html
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

# Create main.jsx with Provider setup
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
const customChain = {
  chain_id: 'your-appchain-id', // Update to match your rollup
  chain_name: 'myapp',
  pretty_name: 'My Appchain',
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
    // "json-rpc": [{ address: 'http://localhost:8545' }], // REQUIRED for EVM rollups
  },
  fees: {
    fee_tokens: [{ denom: 'umin', fixed_min_gas_price: 0 }],
  },
  metadata: {
    is_l1: false,
    minitia: { 
      type: 'minimove', // Use 'minimove', 'miniwasm', or 'minievm'
    },
  },
}

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <InterwovenKitProvider 
          {...TESTNET}
          defaultChainId="your-appchain-id" // Update to match your rollup
          customChain={customChain}
        >
          <App />
        </InterwovenKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
)
EOF

# Create App.jsx
cat > src/App.jsx <<EOF
import React from 'react'
import { useInterwovenKit } from "@initia/interwovenkit-react";

function App() {
  const { initiaAddress, openConnect, openWallet } = useInterwovenKit();

  const shortenAddress = (addr) => {
    if (!addr) return "";
    return \`\${addr.slice(0, 8)}...\${addr.slice(-4)}\`;
  };

  const containerStyle = {
    fontFamily: '"Inter", system-ui, -apple-system, sans-serif',
    minHeight: '100vh',
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    color: '#1e293b',
    padding: '20px'
  };

  const headerStyle = {
    width: '100%',
    maxWidth: '800px',
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: '20px 0',
    marginBottom: '40px',
    borderBottom: '1px solid #e2e8f0'
  };

  const pillButtonStyle = {
    display: 'flex',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    border: '1px solid #e2e8f0',
    padding: '6px 16px',
    borderRadius: '100px',
    cursor: 'pointer',
    fontWeight: '600',
    fontSize: '14px',
    color: '#0f172a',
    transition: 'all 0.2s ease',
    boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
  };

  const connectButtonStyle = {
    backgroundColor: '#3b82f6',
    color: 'white',
    border: 'none',
    padding: '10px 24px',
    borderRadius: '100px',
    fontSize: '14px',
    fontWeight: '700',
    cursor: 'pointer',
    transition: 'all 0.2s ease',
    boxShadow: '0 4px 6px -1px rgba(59, 130, 246, 0.3)'
  };

  return (
    <div style={containerStyle}>
      <header style={headerStyle}>
        <h1 style={{ 
          margin: 0, 
          fontSize: '20px', 
          fontWeight: '900', 
          letterSpacing: '-0.5px',
          color: '#0f172a',
          textTransform: 'uppercase'
        }}>
          $pkg_name
        </h1>
        
        <div>
          {!initiaAddress ? (
            <button 
              onClick={openConnect} 
              style={connectButtonStyle}
            >
              Connect Wallet
            </button>
          ) : (
            <button 
              onClick={openWallet} 
              style={pillButtonStyle}
            >
              <span style={{
                width: '8px',
                height: '8px',
                backgroundColor: '#10b981',
                borderRadius: '50%',
                marginRight: '10px'
              }}></span>
              {shortenAddress(initiaAddress)}
            </button>
          )}
        </div>
      </header>

      <main style={{ 
        width: '100%', 
        maxWidth: '800px',
        backgroundColor: '#ffffff',
        borderRadius: '24px',
        padding: '40px',
        boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.06)',
        border: '1px solid #f1f5f9',
        textAlign: 'center'
      }}>
        <h2 style={{ fontSize: '24px', marginBottom: '16px', color: '#0f172a' }}>
          Welcome to your new Initia appchain frontend!
        </h2>
        <p style={{ color: '#64748b', fontSize: '16px', lineHeight: '1.5' }}>
          Your frontend is now connected to your local appchain. Start building your next great idea!
        </p>
      </main>
    </div>
  )
}

export default App
EOF

echo "Scaffolded React + Vite project at $target"
