#!/usr/bin/env bash

# Initia Appchain Dev Skill Installer
# Usage: ./install.sh [--project | --path <path> | --force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="initia-appchain-dev"
SOURCE_DIR="$SCRIPT_DIR/skill"

# Default to personal installation for Codex.
INSTALL_PATH="${CODEX_HOME:-$HOME/.codex}/skills/$SKILL_NAME"
FORCE=0

is_unsafe_path() {
  local path="$1"

  if [[ -z "$path" ]]; then
    return 0
  fi

  case "$path" in
    "/"|"/."|"."|".."|"~"|"$HOME"|"$HOME/"|"$HOME/.codex"|"$HOME/.codex/" )
      return 0
      ;;
  esac

  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      INSTALL_PATH=".codex/skills/$SKILL_NAME"
      shift
      ;;
    --path)
      if [[ $# -lt 2 ]]; then
        echo "Error: --path requires a value"
        exit 1
      fi
      INSTALL_PATH="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      echo "Initia Appchain Dev Skill Installer"
      echo ""
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --project     Install to current project (.codex/skills/$SKILL_NAME)"
      echo "  --path PATH   Install to custom path"
      echo "  --force       Overwrite existing install without prompt"
      echo "  -h, --help    Show this help message"
      echo ""
      echo "Default: Install to \${CODEX_HOME:-~/.codex}/skills/$SKILL_NAME"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

if is_unsafe_path "$INSTALL_PATH"; then
  echo "Error: Refusing unsafe install path '$INSTALL_PATH'"
  exit 1
fi

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR' not found"
  exit 1
fi

if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
  echo "Error: SKILL.md not found in '$SOURCE_DIR'"
  exit 1
fi

mkdir -p "$(dirname "$INSTALL_PATH")"

if [ -d "$INSTALL_PATH" ]; then
  echo "Warning: '$INSTALL_PATH' already exists"
  if [[ "$FORCE" -eq 1 ]]; then
    rm -rf "$INSTALL_PATH"
  elif [[ -t 0 ]]; then
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Installation cancelled"
      exit 0
    fi
    rm -rf "$INSTALL_PATH"
  else
    echo "Non-interactive shell detected. Re-run with --force to overwrite."
    exit 1
  fi
fi

echo "Installing Initia Appchain Dev Skill..."
cp -r "$SOURCE_DIR" "$INSTALL_PATH"

echo ""
echo "Successfully installed to: $INSTALL_PATH"
echo ""
echo "Installed files:"
find "$INSTALL_PATH" -type f | while read -r file; do
  echo "  - ${file#$INSTALL_PATH/}"
done
echo ""
echo "The skill is now available in Codex."
