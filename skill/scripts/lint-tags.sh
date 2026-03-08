#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS=("$ROOT_DIR/SKILL.md" "$ROOT_DIR/references")

echo "Running tag lint in: $ROOT_DIR"

status=0

# Disallow legacy combined/mixed patterns.
if rg -n "\[(EVM CLI|MOVE CLI|WASM CLI|ALL VMs|EVM\]\[InterwovenKit|MOVE\]\[InterwovenKit|WASM\]\[InterwovenKit)\]" "${TARGETS[@]}" | rg -v "avoid .*EVM CLI"; then
  echo "Found non-standard tag style. Use [VM][CONTEXT] with uppercase context tags."
  status=1
fi

# Disallow common untagged VM bullet labels that drift over time.
if rg -n "^- \*\*(EVM:|Move:|Wasm:|EVM [A-Z]|Move [A-Z]|Wasm [A-Z]|Sender Address \(ALL VMs\))" "${TARGETS[@]}"; then
  echo "Found VM-specific bullet labels without standardized tags."
  status=1
fi

if [[ "$status" -eq 0 ]]; then
  echo "Tag lint passed."
fi

exit "$status"
