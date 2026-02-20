#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export PYTHONDONTWRITEBYTECODE=1

SKILL_FILE="skill/SKILL.md"
SKILL_NAME="initia-appchain-dev"
SKILLS_CLI_VERSION="1.3.7"

fail() {
  echo "[FAIL] $1"
  exit 1
}

ok() {
  echo "[OK] $1"
}

warn() {
  echo "[WARN] $1"
}

[[ -f "$SKILL_FILE" ]] || fail "$SKILL_FILE missing"

for cmd in rg python3 npx; do
  command -v "$cmd" >/dev/null 2>&1 || fail "required command not found: $cmd"
done

if find skill/scripts -type d -name "__pycache__" | rg -q .; then
  fail "__pycache__ directories are not allowed under skill/scripts"
fi

skill_count="$(find . -name SKILL.md -type f | wc -l | tr -d ' ')"
[[ "$skill_count" -eq 1 ]] || fail "expected exactly one SKILL.md, found $skill_count"
ok "single SKILL.md present"

frontmatter="$(awk 'BEGIN{n=0} /^---$/{n++; next} n==1 {print} n==2 {exit}' "$SKILL_FILE")"
[[ -n "$frontmatter" ]] || fail "frontmatter missing in $SKILL_FILE"

name_count="$(printf "%s\n" "$frontmatter" | rg -c '^name:[[:space:]]' || true)"
desc_count="$(printf "%s\n" "$frontmatter" | rg -c '^description:[[:space:]]' || true)"
other_count="$(printf "%s\n" "$frontmatter" | rg -vc '^(name|description):|^[[:space:]]*$' || true)"

[[ "$name_count" -eq 1 ]] || fail "frontmatter must contain exactly one name field"
[[ "$desc_count" -eq 1 ]] || fail "frontmatter must contain exactly one description field"
[[ "$other_count" -eq 0 ]] || fail "frontmatter must only contain name/description fields"
ok "frontmatter schema valid"

ref_docs="$(
  {
    rg --no-filename -o '`[A-Za-z0-9._/-]+\.md`' skill/*.md || true
    rg --no-filename -o '\([A-Za-z0-9._/-]+\.md(#[A-Za-z0-9._/-]+)?\)' skill/*.md || true
  } | tr -d '`()' | sed 's/#.*$//' | sort -u
)"
if [[ -n "$ref_docs" ]]; then
  while IFS= read -r ref; do
    [[ -f "skill/$ref" ]] || fail "missing referenced doc: skill/$ref"
  done <<< "$ref_docs"
fi

ref_scripts="$(
  {
    rg --no-filename -o '`scripts/[A-Za-z0-9._/-]+\.(sh|py)`' skill/*.md || true
    rg --no-filename -o '\(scripts/[A-Za-z0-9._/-]+\.(sh|py)(#[A-Za-z0-9._/-]+)?\)' skill/*.md || true
  } | tr -d '`()' | sed 's/#.*$//' | sort -u
)"
if [[ -n "$ref_scripts" ]]; then
  while IFS= read -r ref; do
    [[ -f "skill/$ref" ]] || fail "missing referenced script: skill/$ref"
  done <<< "$ref_scripts"
fi
ok "skill doc references resolve (backticks + markdown links)"

if [[ "${SKIP_SKILLS_CLI_CHECK:-0}" == "1" ]]; then
  warn "SKIP_SKILLS_CLI_CHECK=1 set; skipping skills.sh discovery check"
else
  if skills_output="$(npx -y "skills@${SKILLS_CLI_VERSION}" add . --list 2>&1)"; then
    printf "%s\n" "$skills_output" | rg -q "Found 1 skill" || fail "skills.sh did not detect one skill"
    printf "%s\n" "$skills_output" | rg -q "$SKILL_NAME" || fail "skills.sh output missing skill name '$SKILL_NAME'"
    ok "skills.sh discovery valid"
  else
    if printf "%s\n" "$skills_output" | rg -qi "(ENOTFOUND|EAI_AGAIN|ECONN|ETIMEDOUT|network|offline)"; then
      warn "skills.sh discovery skipped due to network error"
    else
      fail "skills.sh discovery check failed: $skills_output"
    fi
  fi
fi

python3 -B skill/scripts/convert-address.py 0x1234567890abcdef1234567890abcdef12345678 --prefix init >/dev/null
ok "convert-address.py smoke test"

scratch="$(mktemp -d)"
python_cleanup() {
  rm -rf "$scratch"
}
trap python_cleanup EXIT

skill/scripts/scaffold-contract.sh move "$scratch/move"
[[ -f "$scratch/move/Move.toml" ]] || fail "scaffold-contract.sh did not create Move.toml"
ok "scaffold-contract.sh smoke test"

skill/scripts/scaffold-contract.sh wasm "$scratch/wasm"
[[ -f "$scratch/wasm/Cargo.toml" ]] || fail "scaffold-contract.sh did not create Cargo.toml for wasm"
[[ -f "$scratch/wasm/src/msg.rs" ]] || fail "scaffold-contract.sh did not create src/msg.rs for wasm"
ok "scaffold-contract.sh wasm smoke test"

skill/scripts/scaffold-contract.sh evm "$scratch/evm"
[[ -f "$scratch/evm/foundry.toml" ]] || fail "scaffold-contract.sh did not create foundry.toml for evm"
[[ -f "$scratch/evm/script/Deploy.s.sol" ]] || fail "scaffold-contract.sh did not create Deploy.s.sol for evm"
ok "scaffold-contract.sh evm smoke test"

cat > "$scratch/providers-modern-good.tsx" <<'TSX'
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig}>
        <InterwovenKitProvider
          {...TESTNET}
          defaultChainId={TESTNET.defaultChainId}
        >
          {children}
        </InterwovenKitProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
}
TSX

cat > "$scratch/providers-legacy-good.tsx" <<'TSX'
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <PrivyProvider>
      <QueryClientProvider client={queryClient}>
        <WagmiProvider config={wagmiConfig}>
          <InterwovenKitProvider>{children}</InterwovenKitProvider>
        </WagmiProvider>
      </QueryClientProvider>
    </PrivyProvider>
  );
}
TSX

cat > "$scratch/providers-bad.tsx" <<'TSX'
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig} />
      <InterwovenKitProvider>{children}</InterwovenKitProvider>
    </QueryClientProvider>
  );
}
TSX

cat > "$scratch/providers-evm-good.tsx" <<'TSX'
export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig}>{children}</WagmiProvider>
    </QueryClientProvider>
  );
}
TSX

skill/scripts/check-provider-setup.sh "$scratch/providers-modern-good.tsx" >/dev/null
skill/scripts/check-provider-setup.sh "$scratch/providers-legacy-good.tsx" >/dev/null
skill/scripts/check-provider-setup.sh --mode evm-rpc "$scratch/providers-evm-good.tsx" >/dev/null
if skill/scripts/check-provider-setup.sh "$scratch/providers-bad.tsx" >/dev/null 2>&1; then
  fail "check-provider-setup.sh false-positive: invalid nesting passed"
fi
ok "check-provider-setup.sh smoke test"

skill/scripts/verify-appchain.sh --help >/dev/null
ok "verify-appchain.sh smoke test"

if python3 -B -c "import bip_utils" >/dev/null 2>&1; then
  python3 -B skill/scripts/generate-system-keys.py --vm evm --da initia >/dev/null
  if python3 -B skill/scripts/generate-system-keys.py --vm evm --include-mnemonics >/dev/null 2>&1; then
    fail "generate-system-keys.py should require --output when --include-mnemonics is set"
  fi
  ok "generate-system-keys.py smoke test"
else
  echo "[WARN] bip_utils not installed; skipping generate-system-keys.py smoke test"
fi

ok "all checks passed"
