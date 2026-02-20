#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: check-provider-setup.sh [--mode auto|evm-rpc|interwovenkit] <path-to-tsx-or-ts-file>"
}

MODE="auto"
FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      if [[ $# -lt 2 ]]; then
        usage
        exit 1
      fi
      MODE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$FILE" ]]; then
        FILE="$1"
        shift
      else
        usage
        exit 1
      fi
      ;;
  esac
done

if [[ -z "$FILE" ]]; then
  usage
  exit 1
fi

if [[ "$MODE" != "auto" && "$MODE" != "evm-rpc" && "$MODE" != "interwovenkit" ]]; then
  echo "Invalid mode: $MODE"
  usage
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "File not found: $FILE"
  exit 1
fi

HAS_RG=0
if command -v rg >/dev/null 2>&1; then
  HAS_RG=1
fi

search_exists() {
  local pattern="$1"
  if [[ $HAS_RG -eq 1 ]]; then
    rg -q "$pattern" "$FILE"
  else
    grep -Eq "$pattern" "$FILE"
  fi
}

search_first_line() {
  local pattern="$1"
  if [[ $HAS_RG -eq 1 ]]; then
    rg -n "$pattern" "$FILE" | head -n1 | cut -d: -f1 || true
  else
    grep -nE "$pattern" "$FILE" | head -n1 | cut -d: -f1 || true
  fi
}

search_last_line() {
  local pattern="$1"
  if [[ $HAS_RG -eq 1 ]]; then
    rg -n "$pattern" "$FILE" | tail -n1 | cut -d: -f1 || true
  else
    grep -nE "$pattern" "$FILE" | tail -n1 | cut -d: -f1 || true
  fi
}

if [[ "$MODE" == "auto" ]]; then
  if search_exists "InterwovenKitProvider"; then
    MODE="interwovenkit"
  else
    MODE="evm-rpc"
  fi
fi

required=("QueryClientProvider" "WagmiProvider")
if [[ "$MODE" == "interwovenkit" ]]; then
  required+=("InterwovenKitProvider")
fi

missing=0
for token in "${required[@]}"; do
  if ! search_exists "$token"; then
    echo "Missing token: $token"
    missing=1
  fi
done

if [[ $missing -ne 0 ]]; then
  echo "Provider check failed"
  exit 1
fi

open_query="$(search_first_line "<QueryClientProvider(\\s|>|$)")"
open_wagmi="$(search_first_line "<WagmiProvider(\\s|>|$)")"

if [[ -z "$open_query" ]]; then
  open_query="$(search_first_line "\\bQueryClientProvider\\b")"
fi
if [[ -z "$open_wagmi" ]]; then
  open_wagmi="$(search_first_line "\\bWagmiProvider\\b")"
fi

for value in "$open_query" "$open_wagmi"; do
  if [[ -z "$value" ]]; then
    echo "Failed to locate required provider declarations"
    exit 1
  fi
done

if ! (( open_query < open_wagmi )); then
  echo "Provider opening order is incorrect. Expected: QueryClientProvider -> WagmiProvider"
  exit 1
fi

if search_exists "<QueryClientProvider[^>]*\\/>"; then
  echo "QueryClientProvider must wrap children; self-closing usage detected"
  exit 1
fi

if search_exists "<WagmiProvider[^>]*\\/>"; then
  echo "WagmiProvider must wrap children; self-closing usage detected"
  exit 1
fi

if [[ "$MODE" == "interwovenkit" ]]; then
  open_kit="$(search_first_line "<InterwovenKitProvider(\\s|>|$)")"
  if [[ -z "$open_kit" ]]; then
    open_kit="$(search_first_line "\\bInterwovenKitProvider\\b")"
  fi

  if [[ -z "$open_kit" ]]; then
    echo "InterwovenKit mode requires InterwovenKitProvider"
    exit 1
  fi

  if ! (( open_wagmi < open_kit )); then
    echo "Provider opening order is incorrect. Expected: QueryClientProvider -> WagmiProvider -> InterwovenKitProvider"
    exit 1
  fi

  if search_exists "<InterwovenKitProvider[^>]*\\/>"; then
    echo "InterwovenKitProvider must wrap children; self-closing usage detected"
    exit 1
  fi
fi

close_query="$(search_last_line "</QueryClientProvider>")"
close_wagmi="$(search_last_line "</WagmiProvider>")"

if [[ -n "$close_query" && -n "$close_wagmi" ]]; then
  if ! (( open_query < open_wagmi && open_wagmi <= close_wagmi && close_wagmi < close_query )); then
    echo "WagmiProvider must be nested inside QueryClientProvider"
    exit 1
  fi
else
  echo "Warning: could not verify full Query/Wagmi nesting from closing tags; check manually."
fi

if [[ "$MODE" == "interwovenkit" ]]; then
  close_kit="$(search_last_line "</InterwovenKitProvider>")"
  close_wagmi="$(search_last_line "</WagmiProvider>")"
  if [[ -n "$close_kit" && -n "$close_wagmi" ]]; then
    if ! (( open_wagmi < open_kit && open_kit <= close_kit && close_kit < close_wagmi )); then
      echo "InterwovenKitProvider must be nested inside WagmiProvider"
      exit 1
    fi
  else
    echo "Warning: could not verify full InterwovenKit/Wagmi nesting from closing tags; check manually."
  fi
fi

if [[ "$MODE" == "evm-rpc" ]] && search_exists "InterwovenKitProvider"; then
  echo "Mode 'evm-rpc' selected but InterwovenKitProvider detected. Use --mode interwovenkit or --mode auto."
  exit 1
fi

has_privy=0
if search_exists "PrivyProvider"; then
  has_privy=1
fi

if [[ $has_privy -eq 1 ]]; then
  open_privy="$(search_first_line "<PrivyProvider(\\s|>|$)")"
  if [[ -z "$open_privy" ]]; then
    open_privy="$(search_first_line "\\bPrivyProvider\\b")"
  fi

  if [[ -n "$open_privy" ]] && ! (( open_privy < open_query )); then
    echo "Warning: PrivyProvider appears after QueryClientProvider; verify wrapper order manually."
  fi
fi

if search_exists "initiaPrivyWalletConnector"; then
  echo "Provider check passed (modern connector-based stack, mode=$MODE)"
else
  echo "Provider check passed (custom connector stack, mode=$MODE)"
fi
