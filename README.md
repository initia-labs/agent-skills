# Initia Appchain Dev Skill

Single-skill package for end-to-end Initia development:
- Appchain deployment with Weave CLI
- Smart contracts development across all supported VMs  (Move / Wasm / EVM)
- Frontend integration for both direct EVM JSON-RPC (`wagmi` + `viem`) and `@initia/interwovenkit-react`

## Install (skills.sh)

```bash
npx skills add initia-labs/agent-skills
```

## Install (manual script)

```bash
git clone https://github.com/initia-labs/agent-skills
cd agent-skills
./install.sh
```

Project-local install:

```bash
./install.sh --project
```

Project-local install (overwrite non-interactively):

```bash
./install.sh --project --force
```

Custom destination:

```bash
./install.sh --path /custom/path/initia-appchain-dev
```

## Local check

```bash
npx skills add . --list
```

Expected output: one skill named `initia-appchain-dev`.

Default install destination for `install.sh`: `${CODEX_HOME:-~/.codex}/skills/initia-appchain-dev`

## Migration

This repo replaced three legacy skills with one consolidated skill:

- `contract-guide` -> `initia-appchain-dev`
- `frontend-kit` -> `initia-appchain-dev`
- `weave` -> `initia-appchain-dev`

Behavior changes:

- Frontend guidance now has two explicit paths:
  - EVM direct JSON-RPC (`frontend-evm-rpc.md`)
  - InterwovenKit (`frontend-interwovenkit.md`)
- Runtime discovery is centralized in `runtime-discovery.md`.
- Quality checks and CI are now built in (`scripts/ci-check.sh`, GitHub workflow).

## Example prompts

- "Scaffold an EVM contract on Initia and add an oracle read function."
- "Set up InterwovenKit providers in my Next.js app and implement wallet connect."
- "Create a `weave` launch config for a testnet EVM rollup."
- "My rollup is not producing blocks. Help me debug it step by step."
- "Convert this `0x...` address to Initia bech32 and add it to genesis accounts."

## Quality checks

Run all local checks:

```bash
./scripts/ci-check.sh
```

Script dependencies (for key generation checks):

```bash
pip install -r skill/scripts/requirements.txt
```

`generate-system-keys.py` does not hard-require a specific Python version, but if `bip_utils` fails to install/import on your runtime, use Python 3.11 or 3.12.

Safe key generation examples:

```bash
# Safe stdout output (mnemonics redacted)
python3 skill/scripts/generate-system-keys.py --vm evm

# Include mnemonics only when writing to a protected file (0600 perms)
python3 skill/scripts/generate-system-keys.py --vm move --include-mnemonics --output ./system-keys.json
```

Optional CI fallback for network-restricted environments:

```bash
SKIP_SKILLS_CLI_CHECK=1 ./scripts/ci-check.sh
```
