#!/bin/bash
# install.sh — One-liner orchestration deployment from GitHub
#
# Usage (run from your target project directory):
#
#   Initial install (full):
#     curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash
#     curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
#
#   Refresh ONLY the local deploy.sh at .claude/scripts/deploy.sh
#   (after initial install, when you want the newest deploy.sh without full redeploy):
#     curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- --update-deploy

set -euo pipefail

REPO="${REPO:-air900/orchestration-kit}"
REF="${REF:-main}"
TARGET="$(pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Mode: --update-deploy (light refresh of local deploy.sh only) ---
if [ "${1:-}" = "--update-deploy" ]; then
    log_info "Refreshing local .claude/scripts/deploy.sh from ${REPO}@${REF}..."
    mkdir -p "$TARGET/.claude/scripts"
    curl -sSLf "https://raw.githubusercontent.com/${REPO}/${REF}/deploy.sh" \
        -o "$TARGET/.claude/scripts/deploy.sh" || {
        log_err "Failed to download deploy.sh from ${REPO}@${REF}"
        exit 1
    }
    chmod +x "$TARGET/.claude/scripts/deploy.sh"
    log_ok "deploy.sh updated at $TARGET/.claude/scripts/deploy.sh"
    log_info "Next: run '.claude/scripts/deploy.sh . --update-skills' to refresh kit content."
    exit 0
fi

# --- Mode: full install (atomic or multi) ---
PROJECT_TYPE="${1:-atomic}"
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log_info "Downloading orchestration-kit from GitHub (${REPO}@${REF})..."

if command -v git &>/dev/null; then
    git clone --quiet --depth 1 --branch "$REF" \
        "https://github.com/${REPO}.git" "$TMP_DIR/orchestration-kit"
else
    log_info "git not found, using curl + tarball..."
    mkdir -p "$TMP_DIR/orchestration-kit"
    curl -sSL "https://github.com/${REPO}/archive/refs/heads/${REF}.tar.gz" | \
        tar -xz -C "$TMP_DIR/orchestration-kit" --strip-components=1
fi

log_ok "Downloaded"

chmod +x "$TMP_DIR/orchestration-kit/deploy.sh"
"$TMP_DIR/orchestration-kit/deploy.sh" "$TARGET" "$PROJECT_TYPE"

echo ""
log_ok "Temp files cleaned up automatically."
log_info "deploy.sh available at $TARGET/.claude/scripts/deploy.sh for future updates."
