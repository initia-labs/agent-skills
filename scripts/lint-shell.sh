#!/usr/bin/env bash

set -euo pipefail

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "shellcheck is required but was not found in PATH" >&2
  echo "Install it, then re-run: $0" >&2
  exit 127
fi

shellcheck --version
shellcheck install.sh scripts/ci-check.sh skill/scripts/*.sh
