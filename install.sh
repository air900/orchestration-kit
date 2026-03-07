#!/bin/bash
# install.sh — One-liner orchestration deployment from GitHub
#
# Usage (run from your target project directory):
#   curl -sSL https://raw.githubusercontent.com/USERNAME/orchestration-kit/main/install.sh | bash
#   curl -sSL https://raw.githubusercontent.com/USERNAME/orchestration-kit/main/install.sh | bash -s -- multi
#
# Or with explicit repo:
#   curl -sSL https://raw.githubusercontent.com/USERNAME/orchestration-kit/main/install.sh | REPO=USERNAME/orchestration-kit bash

set -euo pipefail

REPO="${REPO:-USERNAME/orchestration-kit}"
PROJECT_TYPE="${1:-atomic}"
TARGET="$(pwd)"
TMP_DIR=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

echo -e "${BLUE}[INFO]${NC} Downloading orchestration-kit from GitHub..."

if command -v git &>/dev/null; then
    git clone --depth 1 "https://github.com/${REPO}.git" "$TMP_DIR/orchestration-kit" 2>/dev/null
else
    echo -e "${BLUE}[INFO]${NC} git not found, using curl..."
    mkdir -p "$TMP_DIR/orchestration-kit"
    curl -sSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" | \
        tar -xz -C "$TMP_DIR/orchestration-kit" --strip-components=1
fi

echo -e "${GREEN}[OK]${NC} Downloaded"

# Run deploy.sh
chmod +x "$TMP_DIR/orchestration-kit/deploy.sh"
"$TMP_DIR/orchestration-kit/deploy.sh" "$TARGET" "$PROJECT_TYPE"

echo ""
echo -e "${GREEN}Temp files cleaned up automatically.${NC}"
