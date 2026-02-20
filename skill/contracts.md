# Contracts (MoveVM, WasmVM, EVM)

## Table of Contents

1. Intake Questions
2. Opinionated Defaults
3. Toolchain Prerequisites
4. Implementation Checklist
5. MoveVM
6. WasmVM (CosmWasm)
7. EVM (Solidity)
8. Deployment Output Expectations
9. Gotchas

## Intake Questions

Ask for missing inputs before generating contract code:

1. Which VM (`evm`, `move`, `wasm`)?
2. Is this new contract scaffolding or edits to existing code?
3. Which network and chain IDs are targeted?
4. Which deployment toolchain is expected (Foundry, Move CLI, CosmWasm workflow)?

## Opinionated Defaults

| Area | Default | Notes |
|---|---|---|
| VM | `evm` | Use `move`/`wasm` only when requested |
| EVM toolchain | Foundry | Keep `solc` pinned |
| Move dependency | `InitiaStdlib` | Use official repo path |
| Wasm baseline | `cosmwasm-std` + `cw-storage-plus` | Add deps only when needed |

## Toolchain Prerequisites

Install only the toolchain needed for the target VM.

### Common

```bash
# macOS
brew install git jq

# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y git jq
```

### EVM (Foundry)

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
forge --version
```

### WasmVM (Rust/CosmWasm)

```bash
curl https://sh.rustup.rs -sSf | sh -s -- -y
source "$HOME/.cargo/env"
rustup target add wasm32-unknown-unknown
cargo --version
```

### MoveVM / Appchain CLI

Use the CLI for your Initia environment and confirm it supports Move build/publish for your target chain. For Move 2 support, use `initiad` (v1.2.2+).

```bash
initiad version
initiad config view
```

## Implementation Checklist

1. Confirm VM and select matching section below.
2. Produce a minimal compile-ready starter first (`scripts/scaffold-contract.sh <evm|move|wasm> <target-dir>`).
3. **Cleanup**: Scaffolding creates a boilerplate file (e.g., `sources/<project_name>.move`). Delete or rename this if you are creating a different module.
4. Add feature-specific logic (execute paths, storage).
5. Add placeholders for chain/module-specific values.
6. Provide explicit build/deploy commands for the selected VM.

## MoveVM

### Quick Start (Fast-Path)

Use the provided script to scaffold a project with pre-cloned local dependencies. This avoids slow git resolution and provides a Move 2.1 compatible starter.

```bash
# Usage: scripts/scaffold-contract.sh move <target-dir>
scripts/scaffold-contract.sh move ./my-project
```

### Project Structure

```text
.
├── Move.toml
├── deps/
│   └── movevm/ (Pre-cloned for speed)
└── sources/
    └── <project_name>.move (Boilerplate - delete if creating custom modules)
```

### Baseline Move.toml (Move 2.1)

```toml
[package]
name = "MyProject"
version = "0.0.1"
edition = "2024.alpha" # Triggers a warning in some compilers, but safe to ignore.

[dependencies]
InitiaStdlib = { local = "deps/movevm/precompile/modules/initia_stdlib" }
MoveStdlib = { local = "deps/movevm/precompile/modules/move_stdlib" }

[addresses]
MyProject = "0x2" # Use a concrete hex address (e.g., 0x2) to allow local builds. This will be overridden during deploy.
std = "0x1"
```

### Move 2.1 Features Example

```move
module MyProject::game {
    use std::signer;

    struct Player has key {
        points: u64,
    }

    public entry fun join(account: &signer) {
        move_to(account, Player { points: 0 });
    }

    /// View functions use the #[view] attribute in Move 2.1
    #[view]
    /// NOTE: Place doc comments AFTER attributes to avoid compiler warnings.
    public fun get_points(addr: address): u64 acquires Player {
        if (exists<Player>(addr)) {
            borrow_global<Player>(addr).points
        } else {
            0
        }
    }
}
```

### Abort Code Mapping (Testing)
When writing tests with `#[expected_failure]`, standard error categories map to specific abort code ranges:
- `error::invalid_argument(N)` -> `0x10000 + N` (e.g., `0x10001` for argument 1)
- `error::not_found(N)` -> `0x60000 + N` (e.g., `0x60002` for resource 2)
- `error::permission_denied(N)` -> `0x50000 + N`

Example:
```move
#[test(account = @0x1)]
#[expected_failure(abort_code = 0x60002, location = MyProject::game)]
fun test_failure(account: &signer) {
    // ... logic that calls error::not_found(2)
}
```

### Oracle Integration (Move 2.1)

```move
module MyProject::oracle_consumer {
    use std::string::utf8;
    use initia_std::oracle::get_price;

    #[view]
    public fun btc_price(): (u256, u64, u64) {
        let (price, timestamp, decimals) = get_price(utf8(b"BITCOIN/USD"));
        (price, timestamp, decimals)
    }
}
```

### Build and Test (Move)

```bash
# Build (Always specify version 2.1 for latest features)
# If your Move.toml uses "_" for an address, provide it via --named-addresses
# CRITICAL: --named-addresses MUST use HEX addresses (0x...), NOT bech32 (init1...)
# Ensure the named address matches the package name in Move.toml
minitiad move build --language-version=2.1 --named-addresses MyProject=0x82ac...

# Test
minitiad move test --language-version=2.1 --named-addresses MyProject=0x82ac...
```

### Deploy and Publish (Move)

The automated `deploy` command builds and publishes the entire package in one step.

**CRITICAL: Address Matching**
Initia requires the module address in `Move.toml` to match the sender's address during deployment.
1.  **Get Hex Address**: Convert your bech32 address (e.g., `init1...`) to hex using `scripts/to_hex.py`.
2.  **Update Move.toml**: Replace the placeholder address in `Move.toml` with the **hex** version of your sender address.
    *   Example: `my_module = "0x6698..."`
3.  **Clean Build**: If you encounter `MODULE_ADDRESS_DOES_NOT_MATCH_SENDER`, delete the `build/` directory and rebuild.

```bash
# 1. Automated Deploy (Recommended)
# Run this from your Move project root
# It is recommended to build explicitly first to ensure address resolution
minitiad move build --language-version=2.1 --named-addresses MyProject=0x<SENDER_HEX>
minitiad move deploy \
  --from gas-station \
  --keyring-backend test \
  --chain-id <CHAIN_ID> \
  --gas auto --gas-adjustment 1.4 --yes

# 2. Manual Publish (Specific bytecode files)
# NOTE: publish does NOT support --named-addresses. Build first, then publish the .mv file.
minitiad tx move publish <PATH_TO_BYTECODE> \
  --from gas-station \
  --keyring-backend test \
  --chain-id <CHAIN_ID> \
  --gas auto --gas-adjustment 1.4 --yes --upgrade-policy COMPATIBLE
```

### Execute and Query (Move)

```bash
# 1. Execute a function (entry point)
# Must provide exactly 3 args: [module_address] [module_name] [function_name]
minitiad tx move execute <MODULE_ADDRESS> <MODULE_NAME> <FUNCTION_NAME> \
  --args <JSON_ARGS_ARRAY> \
  --from gas-station \
  --keyring-backend test \
  --chain-id <CHAIN_ID> \
  --gas auto --gas-adjustment 1.4 --yes

# 2. Call a view function
minitiad query move view <MODULE_ADDRESS> <MODULE_NAME> <FUNCTION_NAME> \
  --args <JSON_ARGS_ARRAY>
```

#### Move Argument Formatting (CRITICAL)
When using `--args` in `minitiad`, you MUST prefix values with their Move type to ensure correct BCS serialization.

| Type | Prefix Example |
|---|---|
| Address | `"address:0x1"` or `"address:init1..."` |
| U64 | `"u64:100"` |
| Bool | `"bool:true"` |
| String | `"string:hello"` |
| Vector | `"vector<u8>:1,2,3"` |

Example:
`minitiad query move view <ADDR> <MOD> <FUNC> --args '["address:init1...", "u64:5"]'`

## WasmVM (CosmWasm)

### Project Structure and Filenames

```text
.
├── Cargo.toml
└── src/
    ├── contract.rs
    ├── error.rs
    ├── lib.rs
    ├── msg.rs
    └── state.rs
```

Conventions:
- Core entry points in `src/contract.rs`
- Message types in `src/msg.rs`
- State models in `src/state.rs`

### Baseline Dependencies

```toml
[dependencies]
cosmwasm-schema = "2.1.0"
cosmwasm-std = { version = "2.1.0", features = ["cosmwasm_1_3"] }
cw-storage-plus = "2.0.0"
cw2 = "2.0.0"
schemars = "0.8.16"
serde = { version = "1.0.197", default-features = false, features = ["derive"] }
thiserror = "1.0.58"
```

### Build and Deploy (Wasm)

**AI Strategy: Command Paths**
In many environments, `cargo` is not in the default PATH for shell commands. If `cargo` fails, use `~/.cargo/bin/cargo`.

**AI Strategy: Testing**
In `cosmwasm-std` 2.x, `mock_info` is deprecated. Use `message_info` for new tests to avoid warnings. Use `cosmwasm_std::from_json` and `to_json_binary` for serialization.

**AI Strategy: Dependency Updates**
After pinning dependencies in `Cargo.toml` (e.g., to fix `edition2024` errors), ALWAYS run `cargo update` (or `~/.cargo/bin/cargo update`) to ensure the lock file is synchronized before building.

**CRITICAL: Build Optimization**
Standard `cargo build` often produces Wasm files that are too large or contain incompatible features (like `bulk-memory`). ALWAYS use the CosmWasm optimizer for deployment.

```bash
# 1. Ensure crate-type is set in Cargo.toml
# [lib]
# crate-type = ["cdylib", "rlib"]

# 2. Run the optimizer (Docker required)
# Use arm64 version for Apple Silicon, otherwise use cosmwasm/optimizer:0.16.1
docker run --rm -v "$(pwd)":/code \
  --mount type=volume,source="$(basename "$(pwd)")_cache",target=/code/target \
  --mount type=volume,source=registry_cache,target=/usr/local/cargo/registry \
  cosmwasm/optimizer-arm64:0.16.1

# 3. Artifacts will be in ./artifacts/
```

**Gotcha: Edition 2024 Build Errors**
If you see errors like `feature edition2024 is required` or `bulk memory support is not enabled`, pin these dependencies in `Cargo.toml`:
```toml
rmp = "=0.8.14"
rmp-serde = "=1.3.0"
```

### E2E WasmVM Build & Deploy (Agent Workflow)
Follow this exact sequence to build and deploy a WasmVM contract:

1.  **Store Code**:
    ```bash
    minitiad tx wasm store ./artifacts/<project>.wasm --from gas-station --keyring-backend test --chain-id <L2_CHAIN_ID> --gas auto --gas-adjustment 1.4 --yes
    ```
2.  **Wait & Retrieve Code ID**:
    ```bash
    sleep 5
    minitiad q tx <STORE_TX_HASH> --output json | jq -r '.events[] | select(.type=="store_code") | .attributes[] | select(.key=="code_id") | .value'
    ```
3.  **Instantiate**:
    ```bash
    minitiad tx wasm instantiate <CODE_ID> '{}' --label "memoboard" --from gas-station --keyring-backend test --chain-id <L2_CHAIN_ID> --gas auto --gas-adjustment 1.4 --no-admin --yes
    ```
4.  **Wait & Retrieve Contract Address**:
    ```bash
    sleep 5
    minitiad q tx <INSTANTIATE_TX_HASH> --output json | jq -r '.events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address") | .value'
    ```

### Execute and Query (Wasm CLI)

```bash
# Execute a contract call (State-changing)
minitiad tx wasm execute <CONTRACT_ADDRESS> '<MSG_JSON>' \
  --from gas-station --keyring-backend test --chain-id <CHAIN_ID> \
  --gas auto --gas-adjustment 1.4 --yes

# Query contract state (Read-only)
minitiad query wasm contract-state smart <CONTRACT_ADDRESS> '<QUERY_JSON>'
```

```

## EVM (Solidity)

### Project Structure and Filenames

```text
.
├── foundry.toml
├── src/
│   └── <ContractName>.sol
├── script/
│   └── Deploy.s.sol
└── lib/
```

Conventions:
- Contract filenames use PascalCase (example: `MyContract.sol`)
- Deploy script at `script/Deploy.s.sol`

### Build and Deploy (EVM)

> **CRITICAL (Security):** To protect key material, you MUST prioritize the `minitiad` CLI for deployment as it uses the secure local keyring. Avoid `forge create` or `forge script` in automated workflows as they require raw private keys.

#### Pro Tip: EVM Unit Testing with `msg.sender`
If your Solidity contract uses `msg.sender` in a `view` function (e.g., `mapping(address => uint256) balances; ... return balances[msg.sender];`), remember that in Foundry tests:
1. **State-changing calls**: Use `vm.prank(user)` before the call (e.g., `bank.deposit{value: 1 ether}();`).
2. **View-only calls**: You MUST also use `vm.prank(user)` before calling the `view` function to check that specific user's balance. Without it, `msg.sender` will be the test contract itself, likely returning `0`.
3. **Failure Testing**: `testFail` is deprecated in current Foundry versions. Use `vm.expectRevert("ErrorMessage")` followed by the function call that is expected to fail.

Example:
```solidity
vm.prank(user);
bank.deposit{value: 1 ether}();
vm.prank(user); // REQUIRED to see the user's balance
assertEq(bank.getBalance(), 1 ether);

// Failure test
vm.prank(user);
vm.expectRevert("Insufficient balance");
bank.withdraw(2 ether);
```

#### Option 1: Minitiad CLI (Recommended for Security)

> **Pro Tip**: The `minitiad tx evm create` command expects a **raw hex string** (or a file containing one). It will fail if you pass the full Foundry JSON artifact (e.g., `out/MyContract.json`). Always extract the bytecode first.

```bash
# 1. Build your contract
forge build

# 2. Extract hex bytecode (requires jq)
# Use sed to remove 0x prefix and tr to remove newlines
jq -r '.bytecode.object' out/MyContract.sol/MyContract.json | sed 's/^0x//' | tr -d '\n' > MyContract.bin

# 3. Deploy the binary securely via keyring
minitiad tx evm create MyContract.bin \
  --from gas-station \
  --keyring-backend test \
  --chain-id <CHAIN_ID> \
  --gas-prices 0.15GAS \
  --gas 3000000 \
  -y
```

### Retrieving the Contract Address
The `create` command returns a transaction hash but not the contract address. To find the address, wait for the transaction to be indexed:
```bash
sleep 5
minitiad q tx <TX_HASH> --output json | jq -r '.events[] | select(.type=="contract_created") | .attributes[] | select(.key=="contract") | .value'
```

#### Option 2: Foundry (Manual/Local only)

Use only when the user explicitly provides a private key or for local development where security is not a concern.

```bash
# Deploy (using gas-station private key)
forge script script/Deploy.s.sol:Deploy \
  --rpc-url <EVM_RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

### Handling Token Precision
When users request transactions in "tokens" (e.g., "1 token"):
- **Default**: Assume standard EVM precision ($10^{18}$ wei).
- **Supply Check**: Before transacting, check the total supply with `minitiad q bank total`. 
- **Auto-Scaling**: If the requested amount exceeds the total supply or the account balance, scale the request to a safe value (e.g., use `1000` for "1 token") and explain: *"I've scaled your request to 1,000 units to fit the test environment's supply limits."*

### Finding your Hex Address
To find the hex address of a bech32 account (like `gas-station`) for use in `eth_call`:
```bash
# Note: --address (-a) and --output json are mutually exclusive
# Use python3 or python depending on your environment
minitiad keys show gas-station -a --keyring-backend test | xargs -I {} python3 scripts/to_hex.py {}
```
Alternatively, look for the `sender` address in the logs of a successful transaction.

### Execute and Query (EVM CLI)

```bash
# Execute a contract call (State-changing)
minitiad tx evm call <CONTRACT_ADDRESS> <INPUT_HEX> \
  --from gas-station \
  --keyring-backend test \
  --chain-id <CHAIN_ID> \
  --gas auto --gas-adjustment 1.4 --yes

# Query EVM state (Native CLI - Recommended for agents)
# minitiad query evm call [sender_bech32] [contract_addr] [input_hex]
minitiad query evm call $(minitiad keys show gas-station -a --keyring-backend test) <CONTRACT_ADDRESS> <INPUT_HEX>

# Query EVM state (via JSON-RPC)
# NOTE: "from" is REQUIRED if the function uses msg.sender (like getBalance)
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_call","params":[{"from":"0x...","to":"0x...","data":"0x..."},"latest"],"id":1}' \
  http://localhost:8545

### Encoding Arguments (CLI)
For functions with arguments (e.g., `withdraw(uint256)`), use `cast calldata` to generate the input hex. For functions WITHOUT arguments (e.g., `deposit()`), you can use `cast sig`:

```bash
# Example with arguments
DATA=$(cast calldata "withdraw(uint256)" 1000)

# Example without arguments
SIG=$(cast sig "deposit()")
minitiad tx evm call <CONTRACT_ADDRESS> $SIG --from gas-station ...
```
```

## Deployment Output Expectations

For any deploy flow, return:

1. Deployed contract address.
2. Transaction hash.
3. Network/chain ID used.
4. One working read or write command to verify deployment.

## Gotchas

- **EVM: Hex Prefix Error**: The `minitiad tx evm call` command requires the `0x` prefix for input hex strings.
  - **Fix**: Ensure your data starts with `0x` (e.g., `0xd0e30db0`).

- **EVM: eth_call returns 0 or error**: If your Solidity function uses `msg.sender` (like `getBalance()`), you MUST provide a `from` address in your `eth_call` params.
  - **Fix**: `{"method":"eth_call","params":[{"from":"0x...","to":"0x...","data":"0x..."},"latest"]}`.

- **EVM: Missing Imports (forge-std)**: If `forge build` fails to find `forge-std/Test.sol`, you may need a `remappings.txt` file.
  - **Fix**: Create a `remappings.txt` file in your project root with the following content:
    ```text
    forge-std/=lib/forge-std/src/
    ```
  - **Strategy**: Always use `scripts/scaffold-contract.sh evm <dir>` which now automatically sets this up.

- **Move: Address Mismatch on Deploy**: If you encounter `MODULE_ADDRESS_DOES_NOT_MATCH_SENDER` during `minitiad move deploy`, it means the address defined in your bytecode doesn't match the sender.
  - **Fix**: Use `--named-addresses <package>=0x<HEX_ADDR> --build --force` in your `deploy` command to recompile with the correct address on the fly.

- **Move: Backward Incompatible Update**: If you see `BACKWARD_INCOMPATIBLE_MODULE_UPDATE`, you are trying to publish a module to an account that already has it, but your new code removes or changes existing public functions/structs.
  - **Fix**: The preferred fix is to **rename the module** (e.g., from `items` to `items_v2`) in the source code and `Move.toml`. This allows you to keep using the same account (like `gas-station`) without compatibility issues. Only use a fresh account if renaming is not an option for the project.

- **Move Build Hangs (AI Strategy)**: Building Move packages with git dependencies is extremely slow. 
  - **Action**: ALWAYS use `scripts/scaffold-contract.sh move <dir>` which sets up a local `deps/` folder for the Initia framework to ensure fast builds. 
  - **Manual Fix**: If modifying an existing project, clone the repository into a `deps/` folder at your project root and update `Move.toml` to use `local` paths:
    ```bash
    mkdir -p deps && cd deps
    git clone --depth 1 https://github.com/initia-labs/movevm.git
    ```
    ```toml
    [dependencies]
    InitiaStdlib = { local = "deps/movevm/precompile/modules/initia_stdlib" }
    ```

- **Account Sequence Mismatch**: When sending multiple transactions in rapid succession (e.g., in a loop), you may encounter an `account sequence mismatch` error.
  - **Fix**: Add a small delay (e.g., `sleep 2`) between transactions or ensure the previous transaction is indexed before sending the next one.

- **Transaction Indexing Latency**: Querying a transaction (e.g., `minitiad q tx <HASH>`) immediately after sending it may return a "not found" error because the block hasn't been indexed.
  - **Fix**: Add a small delay (e.g., `sleep 5`) before querying transaction results to retrieve contract addresses or event data.

- Move: module addresses and named addresses must align with deployment config.
- Wasm: keep query/execute/instantiate boundaries explicit and typed.
- EVM: pin compiler version and ensure imported Initia interfaces match deployed chain tooling.
- CLI subcommands/flags can vary by environment; adjust to your chain profile.
- If unsure, re-scaffold from scratch:

```bash
scripts/scaffold-contract.sh <evm|move|wasm> <target-dir>
```
