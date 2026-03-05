#!/usr/bin/env bash
set -euo pipefail

CHAIN_ID=""
RPC_URL="http://localhost:26657"
KEY_NAME=""
CHECK_GAS_STATION=false
ADDRESS=""

usage() {
  cat <<'USAGE'
Usage: verify-appchain.sh [--chain-id <chain-id>] [--rpc-url <url>] [--key-name <key-name>] [--gas-station] [--bots] [--address <addr>]

Options:
  --chain-id     Chain ID (auto-detected from ~/.minitia/artifacts/config.json if omitted)
  --rpc-url      RPC URL (default: http://localhost:26657)
  --key-name     Check balance for a local key name
  --address      Check balance for a specific address
  --gas-station  Check Gas Station status and balances
  --bots         Check status of OPinit Executor and IBC Relayer

Examples:
  verify-appchain.sh
  verify-appchain.sh --gas-station --bots
  verify-appchain.sh --chain-id myrollup-1 --key-name mykey
USAGE
}

CHECK_BOTS=false
APPCHAIN_STATUS="NOT CHECKED"
EXECUTOR_STATUS="NOT CHECKED"
RELAYER_STATUS="NOT CHECKED"
GAS_STATION_STATUS="NOT CHECKED"
RELAYER_WARNING=""

iso_to_epoch() {
  local ts="$1"
  local ts_clean="${ts%%.*}Z"

  if date -u -d "$ts_clean" +%s >/dev/null 2>&1; then
    date -u -d "$ts_clean" +%s
    return
  fi

  if date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts_clean" +%s >/dev/null 2>&1; then
    date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts_clean" +%s
    return
  fi

  echo ""
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chain-id)
      CHAIN_ID="$2"
      shift 2
      ;;
    --rpc-url)
      RPC_URL="$2"
      shift 2
      ;;
    --key-name)
      KEY_NAME="$2"
      shift 2
      ;;
    --address)
      ADDRESS="$2"
      shift 2
      ;;
    --gas-station)
      CHECK_GAS_STATION=true
      shift
      ;;
    --bots)
      CHECK_BOTS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Auto-detect Chain ID if not provided
if [[ -z "$CHAIN_ID" && -f "$HOME/.minitia/artifacts/config.json" ]]; then
  CHAIN_ID=$(jq -r '.l2_config.chain_id' "$HOME/.minitia/artifacts/config.json")
  echo "Auto-detected Chain ID: $CHAIN_ID"
fi

for cmd in minitiad jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd"
    exit 1
  fi
done

status_json="$(minitiad status --node "$RPC_URL" 2>/dev/null || echo "{}")"
if [[ "$status_json" == "{}" ]]; then
  echo "Error: Could not connect to RPC at $RPC_URL. Is the appchain running?"
  exit 1
fi

height="$(printf "%s\n" "$status_json" | jq -r '.SyncInfo.latest_block_height // .sync_info.latest_block_height')"
network="$(printf "%s\n" "$status_json" | jq -r '.NodeInfo.network // .node_info.network // empty')"
latest_block_time="$(printf "%s\n" "$status_json" | jq -r '.SyncInfo.latest_block_time // .sync_info.latest_block_time // empty')"

if [[ -z "$height" || "$height" == "null" ]]; then
  echo "Failed to read latest block height"
  exit 1
fi

if ! [[ "$height" =~ ^[0-9]+$ ]]; then
  echo "Unexpected latest block height: $height"
  exit 1
fi

if [[ "$height" -le 0 ]]; then
  echo "Appchain appears unhealthy (latest_block_height=$height)"
  exit 1
fi

if [[ -n "$CHAIN_ID" && -n "$network" && "$network" != "$CHAIN_ID" ]]; then
  echo "Chain ID mismatch: expected '$CHAIN_ID', got '$network'"
  exit 1
fi

height2="$height"
status_json_2="$(minitiad status --node "$RPC_URL" 2>/dev/null || echo "{}")"
if [[ "$status_json_2" != "{}" ]]; then
  parsed_height2="$(printf "%s\n" "$status_json_2" | jq -r '.SyncInfo.latest_block_height // .sync_info.latest_block_height // empty')"
  if [[ "$parsed_height2" =~ ^[0-9]+$ ]]; then
    height2="$parsed_height2"
  fi
fi

now_epoch="$(date -u +%s)"
latest_epoch="$(iso_to_epoch "$latest_block_time")"
block_age=""
if [[ -n "$latest_epoch" ]]; then
  block_age=$((now_epoch - latest_epoch))
fi

if [[ "$height2" -gt "$height" ]]; then
  echo "Appchain ($network) is producing blocks (height $height -> $height2)"
  APPCHAIN_STATUS="RUNNING"
elif [[ -n "$block_age" && "$block_age" -le 180 ]]; then
  echo "Appchain ($network) is reachable and recent (latest_block_height=$height2, latest_block_age=${block_age}s)"
  APPCHAIN_STATUS="RUNNING"
else
  echo "Appchain ($network) is reachable but may be stale (latest_block_height=$height2, latest_block_time=$latest_block_time)"
  APPCHAIN_STATUS="STALE"
fi

if [[ -n "$KEY_NAME" ]]; then
  addr="$(minitiad keys show "$KEY_NAME" -a)"
  echo "Balance for key '$KEY_NAME' ($addr):"
  minitiad query bank balances "$addr" --node "$RPC_URL"
fi

if [[ -n "$ADDRESS" ]]; then
  echo "Balance for address $ADDRESS:"
  minitiad query bank balances "$ADDRESS" --node "$RPC_URL"
fi

if [ "$CHECK_GAS_STATION" = true ]; then
  if command -v weave >/dev/null 2>&1; then
    echo "--- Gas Station Status ---"
    gs_show_output="$(weave gas-station show 2>/dev/null || true)"
    if [[ -z "$gs_show_output" ]]; then
      echo "Unable to read gas-station info from weave."
      GAS_STATION_STATUS="UNKNOWN (weave query failed)"
    else
      printf "%s\n" "$gs_show_output"
    fi

    # Try to extract address and check L2 balance
    gs_addr="$(printf "%s\n" "$gs_show_output" | awk '/Initia Address:/{print $4; exit}')"
    if [[ -n "$gs_addr" ]]; then
      echo "Gas Station L2 Balance ($gs_addr):"
      gs_balances_json="$(minitiad query bank balances "$gs_addr" --node "$RPC_URL" -o json 2>/dev/null || echo "{}")"
      if [[ "$gs_balances_json" == "{}" ]]; then
        echo "Failed to query Gas Station balance from appchain."
        GAS_STATION_STATUS="UNKNOWN (balance query failed)"
      else
        printf "%s\n" "$gs_balances_json" | jq .
        non_zero_balances="$(printf "%s\n" "$gs_balances_json" | jq -r '[.balances[]? | select((.amount | tostring | test("^[0]+$")) | not)] | length')"
        if [[ "$non_zero_balances" =~ ^[0-9]+$ ]] && [[ "$non_zero_balances" -gt 0 ]]; then
          GAS_STATION_STATUS="FUNDED"
        else
          GAS_STATION_STATUS="EMPTY"
        fi
      fi
    else
      GAS_STATION_STATUS="ADDRESS NOT FOUND"
    fi
  else
    echo "weave CLI not found, skipping gas station check."
    GAS_STATION_STATUS="SKIPPED (weave missing)"
  fi
fi

if [ "$CHECK_BOTS" = true ]; then
  echo "--- Interwoven Bots Status ---"

  # Check Executor
  executor_running=false
  if [[ "$OSTYPE" == "darwin"* ]]; then
    launchd_out="$(launchctl print "gui/$(id -u)/com.opinitd.executor.daemon" 2>/dev/null || true)"
    if [[ -n "$launchd_out" ]] && printf "%s\n" "$launchd_out" | grep -q "state = running"; then
      executor_running=true
    fi
  else
    if systemctl is-active --quiet opinitd.executor >/dev/null 2>&1; then
      executor_running=true
    fi
  fi

  if [ "$executor_running" = true ]; then
    echo "✅ OPinit Executor: Running"
    EXECUTOR_STATUS="RUNNING"
  else
    echo "❌ OPinit Executor: Not running"
    EXECUTOR_STATUS="NOT RUNNING"
  fi

  # Check Relayer
  if command -v docker >/dev/null 2>&1; then
    if [ "$(docker ps -q -f name=weave-relayer)" ]; then
      echo "✅ IBC Relayer: Running (Docker)"
      RELAYER_STATUS="RUNNING"
      if docker logs --tail 120 weave-relayer 2>&1 | grep -q "Failed to request to http://localhost:26657"; then
        RELAYER_WARNING="Recent relayer logs contain localhost:26657 RPC failures."
        echo "⚠️ IBC Relayer warning: $RELAYER_WARNING"
        RELAYER_STATUS="DEGRADED"
      fi
    else
      echo "❌ IBC Relayer: Not running"
      RELAYER_STATUS="NOT RUNNING"
    fi
  else
    echo "⚠️ Docker not found, cannot check Relayer status."
    RELAYER_STATUS="UNKNOWN (docker missing)"
  fi
fi

echo "--- Verification Summary ---"
echo "Appchain: $APPCHAIN_STATUS"
if [ "$CHECK_GAS_STATION" = true ]; then
  echo "Gas Station: $GAS_STATION_STATUS"
fi
if [ "$CHECK_BOTS" = true ]; then
  echo "Executor: $EXECUTOR_STATUS"
  echo "Relayer: $RELAYER_STATUS"
fi
