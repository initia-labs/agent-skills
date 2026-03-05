# Common Tasks (Funding, Addresses, Precision)

Tagging: Follow the [VM][CONTEXT] standard from ../SKILL.md (Tagging Standard).

## Table of Contents

1. Account & Key Management
2. Funding User Wallets
3. Address Conversion
4. Token Precision & Denoms

## Account & Key Management (CRITICAL)

- **Primary Account:** Use the `gas-station` account for ALL transactions (L1 and L2) unless the user explicitly provides another.
- **Key Discovery:** Before running transactions, verify the `gas-station` key exists in the local keychain:
  ```bash
  initiad keys show gas-station --keyring-backend test
  minitiad keys show gas-station --keyring-backend test
  ```
- **Auto-Import Flow:** If the `gas-station` key is missing from the keychains, run the following to import it from the Weave configuration.
  > **SECURITY NOTE:** This flow is for **Hackathon/Testnet use only**. NEVER auto-import keys from a JSON config if the target network is `mainnet`.
  ```bash
  MNEMONIC=$(jq -r '.common.gas_station.mnemonic' ~/.weave/config.json)
  if [ -z "$MNEMONIC" ] || [ "$MNEMONIC" = "null" ]; then
    echo "Error: gas-station mnemonic missing in ~/.weave/config.json" >&2
    exit 1
  fi
  # Use this mnemonic to import the key to initiad and minitiad keyrings
  ```

## Funding User Wallets

Developers need tokens in their browser wallets (e.g., Keplr or Leap) to interact with their appchain and the Initia L1.

When a user provides an address and asks for funding, you should ideally fund them on **both layers**:

- **L2 Funding (Appchain):** Essential for gas on their rollup. (`../scripts/fund-user.sh --address <init1...> --layer l2 --chain-id <l2_chain_id>`)
- **L1 Funding (Initia):** Needed for bridging and L1 features. (`../scripts/fund-user.sh --address <init1...> --layer l1`)

**Note:** `../scripts/fund-user.sh` may fail to auto-detect the L2 `chain-id`. Always use `../scripts/verify-appchain.sh` first to retrieve it and provide it explicitly if needed.

### Account Existence (CRITICAL)
Transactions via `requestTxSync` or `requestTxBlock` will fail with "Account does not exist" if the sender has no balance. ALWAYS ensure a user is funded on L2 before they attempt their first transaction.

Always verify the balance of the gas-station account before attempting to fund a user.

## Address Conversion

Initia uses different address formats depending on the layer and VM:
- **L1/L2 (Bech32):** `init1...` (Primary format for CLI and Move/Wasm)
- **[EVM][RPC] (Hex):** `0x...` (Primary format for Solidity and JSON-RPC)

### CLI Conversion
Use these scripts to convert between formats:
- **Hex to Bech32**: `../scripts/convert-address.py <0x...>`
- **Bech32 to Hex**: `../scripts/convert-address.py <init1...> --to-hex`

### Code Conversion (JS/TS)
Use `@initia/initia.js`:
```javascript
import { AccAddress } from "@initia/initia.js";

// Bech32 -> Hex
const hex = AccAddress.toHex("init1...");

// Hex -> Bech32
const bech32 = AccAddress.fromHex("0x...");

// Move VM View Call Encoding (Hex-Padded-Base64)
// CRITICAL: Required for address arguments in rest.move.view
const encodeMoveViewAddr = (bech32Addr) => {
  const hex = AccAddress.toHex(bech32Addr).replace('0x', '').padStart(64, '0');
  const bytes = Uint8Array.from(hex.match(/.{1,2}/g).map((byte) => parseInt(byte, 16)));
  const binary = Array.from(bytes, (byte) => String.fromCharCode(byte)).join('');
  return btoa(binary);
};
```

## Token Precision & Denoms

Handling precision correctly is critical for transactions and funding.

### Native Denoms
- **L1 (INIT)**: The base unit is `uinit` ($10^{-6}$). When a user asks for "1 INIT", you MUST send `1000000uinit`.
- **L2 (Appchain)**: Denoms vary (e.g., `GAS`, `umin`, `uinit`). ALWAYS check `minitiad q bank total` to verify the native denom before funding.

### Whole Tokens vs. Base Units
If a user asks for "X tokens" and the denom is a micro-unit (e.g., `umin`), assume they mean whole tokens and multiply by $10^6$ (Move/Wasm) or $10^{18}$ (EVM) unless they explicitly specify "base units" or "u-amount".

### Multipliers (VM Specific)
| VM | Decimals | Base Unit Example | 1 Token = |
|---|---|---|---|
| Move/Wasm | 6 | `uinit` / `umin` | $10^6$ |
| EVM | 18 | `GAS` / `wei` | $10^{18}$ |

### Avoid Script Defaults
Do not rely on `../scripts/fund-user.sh` to handle precision or denoms automatically. Explicitly calculate the base unit amount and specify the correct denom in your commands.
