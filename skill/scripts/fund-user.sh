#!/bin/bash

# Simple script to fund a user address from the gas-station account.
# Supports both L1 (initiad) and L2 (minitiad).

set -e

# Default values
KEY_NAME="gas-station"
KEYRING="test"
AMOUNT="10000000" # 10 tokens default (10^7)

usage() {
  echo "Usage: $0 --address <addr> [--layer <l1|l2>] [--amount <amount_with_denom>] [--chain-id <id>]"
  echo ""
  echo "Options:"
  echo "  --address   The recipient address (init1...)"
  echo "  --layer     Target layer: 'l1' for Initia, 'l2' for Appchain (default: auto-detect by address)"
  echo "  --amount    Amount and denom (e.g., 5000000uinit or 1000000uapp)"
  echo "  --chain-id  Explicitly set the chain ID"
  exit 1
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --address) ADDR="$2"; shift ;;
    --layer) LAYER="$2"; shift ;;
    --amount) USER_AMOUNT="$2"; shift ;;
    --chain-id) CHAIN_ID="$2"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown parameter: $1"; usage ;;
  esac
  shift
done

if [ -z "$ADDR" ]; then
  echo "Error: --address is required."
  usage
fi

# Auto-convert hex address if needed
if [[ "$ADDR" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
  echo "Detected EVM address, converting to bech32..."
  ADDR=$(python3 "$(dirname "$0")/convert-address.py" "$ADDR")
  echo "Bech32 address: $ADDR"
fi

# Determine Layer and Binary
BINARY="initiad"
if [ "$LAYER" == "l2" ]; then
  BINARY="minitiad"
elif [ "$LAYER" == "l1" ]; then
  BINARY="initiad"
else
  # Auto-detection or fallback
  BINARY="minitiad" # Default to minitiad for most hackathon tasks
fi

# Determine Denom and Chain ID if not provided
if [ "$BINARY" == "initiad" ]; then
  DEFAULT_DENOM="uinit"
  [ -z "$CHAIN_ID" ] && CHAIN_ID="initiation-2"
  EXTRA_FLAGS="--node https://rpc.testnet.initia.xyz:443 --gas-prices 0.015uinit"
else
  # For L2, try to read from minitia.config.json or ~/.minitia/config/config.json
  if [ -f "minitia.config.json" ]; then
    DEFAULT_DENOM=$(jq -r '.l2_config.denom' minitia.config.json)
    [ -z "$CHAIN_ID" ] && CHAIN_ID=$(jq -r '.l2_config.chain_id' minitia.config.json)
  elif [ -f "$HOME/.minitia/config/config.toml" ]; then
    # Fallback to local node info if available
    [ -z "$CHAIN_ID" ] && CHAIN_ID=$(grep "chain-id" "$HOME/.minitia/config/genesis.json" | cut -d '"' -f 4 || echo "")
    # Try to find denom from artifacts
    if [ -f "minitia.config.json" ]; then
       DEFAULT_DENOM=$(jq -r '.l2_config.denom' minitia.config.json)
    else
       DEFAULT_DENOM="GAS" # Common default for EVM appchains
    fi
  else
    DEFAULT_DENOM="uapp"
  fi
  EXTRA_FLAGS=""
fi

# Final Amount string - check if USER_AMOUNT already has a denom (case insensitive)
if [[ "$USER_AMOUNT" =~ ^[0-9]+[a-zA-Z]+$ ]]; then
  FINAL_AMOUNT="$USER_AMOUNT"
else
  FINAL_AMOUNT="${USER_AMOUNT:-${AMOUNT}}${DEFAULT_DENOM}"
fi

# Verify Chain ID
if [ -z "$CHAIN_ID" ] && [ "$BINARY" == "minitiad" ]; then
  echo "Error: Could not detect L2 chain-id. Please provide it with --chain-id."
  exit 1
fi

echo "--- Funding User ---"
echo "Recipient: $ADDR"
echo "Binary:    $BINARY"
echo "Amount:    $FINAL_AMOUNT"
echo "Chain ID:  $CHAIN_ID"
echo "--------------------"

# Execute transfer
$BINARY tx bank send "$KEY_NAME" "$ADDR" "$FINAL_AMOUNT" \
  --from "$KEY_NAME" \
  --keyring-backend "$KEYRING" \
  --chain-id "$CHAIN_ID" \
  --gas auto --gas-adjustment 1.4 \
  $EXTRA_FLAGS \
  --yes

echo ""
echo "Success! Sent $FINAL_AMOUNT to $ADDR"
