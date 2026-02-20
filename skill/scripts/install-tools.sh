#!/usr/bin/env bash

# Initia Hackathon Tool Installer
# Installs: jq, weave, initiad

set -e

# Versions
INITIAD_VERSION="v1.3.0"
WEAVE_VERSION="v0.3.5"

# Paths
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[Initia Installer]${NC} $1"
}

error() {
    echo -e "${RED}[Error]${NC} $1"
}

# OS/Arch Detection
OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux)
        OS_TYPE="linux"
        ;;
    Darwin)
        OS_TYPE="darwin"
        ;;
    *)
        error "Unsupported OS: $OS"
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64)
        ARCH_TYPE="amd64"
        ;;
    arm64|aarch64)
        ARCH_TYPE="arm64"
        ;;
    *)
        error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

log "Detected system: $OS_TYPE/$ARCH_TYPE"
log "Installing tools to: $INSTALL_DIR"

# 1. Check Docker
if ! command -v docker &> /dev/null; then
    error "Docker is not installed. Please install Docker Desktop (macOS) or Docker Engine (Linux) manually."
    error "  - macOS: https://docs.docker.com/desktop/install/mac-install/"
    error "  - Linux: https://docs.docker.com/engine/install/"
else
    log "Docker is installed."
fi

# 2. Install jq
if ! command -v jq &> /dev/null; then
    log "Installing jq..."
    if [[ "$OS_TYPE" == "darwin" ]]; then
        if command -v brew &> /dev/null; then
            brew install jq
        else
            error "Homebrew not found. Please install jq manually or install Homebrew."
        fi
    else
        # Try apt/yum/apk if possible, otherwise warn
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        else
            error "Please install 'jq' using your package manager (apt, yum, etc)."
        fi
    fi
else
    log "jq is already installed."
fi

# 3. Install Weave
log "Checking Weave ($WEAVE_VERSION)..."
if command -v weave &> /dev/null; then
    log "Weave is already installed: $(weave version)"
else
    if [[ "$OS_TYPE" == "darwin" ]]; then
        if command -v brew &> /dev/null; then
            log "Installing Weave via Homebrew..."
            brew install initia-labs/tap/weave || true
        fi
    fi

    if ! command -v weave &> /dev/null; then
        # Fallback to direct download if brew fails or on Linux
        WEAVE_URL="https://github.com/initia-labs/weave/releases/download/${WEAVE_VERSION}/weave-${WEAVE_VERSION:1}-${OS_TYPE}-${ARCH_TYPE}.tar.gz"
        log "Downloading Weave from $WEAVE_URL..."
        curl -L -o /tmp/weave.tar.gz "$WEAVE_URL"
        if tar -tzf /tmp/weave.tar.gz &>/dev/null; then
            tar -xzf /tmp/weave.tar.gz -C "$INSTALL_DIR"
            chmod +x "$INSTALL_DIR/weave"
        else
            # Try direct binary download
            WEAVE_BIN_URL="https://github.com/initia-labs/weave/releases/download/${WEAVE_VERSION}/weave-${WEAVE_VERSION:1}-${OS_TYPE}-${ARCH_TYPE}"
            curl -L -o "$INSTALL_DIR/weave" "$WEAVE_BIN_URL"
            chmod +x "$INSTALL_DIR/weave"
        fi
    fi
fi

# 4. Install initiad
log "Checking initiad ($INITIAD_VERSION)..."
if command -v initiad &> /dev/null; then
    log "initiad is already installed: $(initiad version)"
else
    # Check if we can build from source first as it's more reliable in this repo
    # Prioritize root initia directory if it exists as it might be more up to date
    if [[ -f "../initia/Makefile" ]]; then
        log "Source found for initia at ../initia. Building from source..."
        (cd ../initia && make install)
    elif [[ -f "initia/Makefile" ]]; then
        log "Source found for initia. Building from source..."
        (cd initia && make install)
    else
        OS_TITLE="$(tr '[:lower:]' '[:upper:]' <<< ${OS_TYPE:0:1})${OS_TYPE:1}"
        INITIAD_ASSET="initia_${INITIAD_VERSION}_${OS_TITLE}_${ARCH_TYPE}.tar.gz"
        INITIAD_URL="https://github.com/initia-labs/initia/releases/download/${INITIAD_VERSION}/${INITIAD_ASSET}"

        log "Downloading $INITIAD_URL ..."
        curl -L -o /tmp/initiad.tar.gz "$INITIAD_URL"
        if tar -tzf /tmp/initiad.tar.gz &>/dev/null; then
            tar -xzf /tmp/initiad.tar.gz -C "$INSTALL_DIR" initiad
            rm /tmp/initiad.tar.gz
            chmod +x "$INSTALL_DIR/initiad"
        else
            error "Failed to download/extract initiad. Please install manually or build from source."
        fi
    fi
fi

# Final PATH check
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    log "WARNING: $INSTALL_DIR is not in your PATH."
    log "Add it by running: export PATH=\$PATH:$INSTALL_DIR"
fi

log "Installation complete! Verifying..."

if command -v weave &> /dev/null; then
    log "weave installed!"
    echo "  Version: $(weave version)"
    echo "  Location: $(command -v weave)"
else
    error "weave not found in PATH"
fi

if command -v initiad &> /dev/null; then
    log "initiad installed!"
    echo "  Version: $(initiad version)"
    echo "  Location: $(command -v initiad)"
else
    error "initiad not found in PATH"
fi
