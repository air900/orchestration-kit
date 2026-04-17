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

# --- Mode: --update-deploy (light refresh of deploy.sh + /kit-update command) ---
if [ "${1:-}" = "--update-deploy" ]; then
    log_info "Refreshing .claude/scripts/deploy.sh + .claude/commands/kit-update.md from ${REPO}@${REF}..."
    mkdir -p "$TARGET/.claude/scripts" "$TARGET/.claude/commands"

    # Fetch backend deploy.sh
    curl -sSLf "https://raw.githubusercontent.com/${REPO}/${REF}/deploy.sh" \
        -o "$TARGET/.claude/scripts/deploy.sh" || {
        log_err "Failed to download deploy.sh from ${REPO}@${REF}"
        exit 1
    }
    chmod +x "$TARGET/.claude/scripts/deploy.sh"

    # Fetch unified slash command
    curl -sSLf "https://raw.githubusercontent.com/${REPO}/${REF}/templates/commands/kit-update.md" \
        -o "$TARGET/.claude/commands/kit-update.md" || {
        log_err "Failed to download kit-update.md from ${REPO}@${REF}"
        exit 1
    }

    # Clean up stale orch.sh wrapper from earlier revision, if present
    rm -f "$TARGET/.claude/scripts/orch.sh"

    log_ok "Updated .claude/scripts/deploy.sh + .claude/commands/kit-update.md"

    # Auto commit + push if in a git repo and files actually changed
    if [ -d "$TARGET/.git" ]; then
        (
            cd "$TARGET" || exit 1
            git add .claude/scripts/deploy.sh .claude/commands/kit-update.md 2>/dev/null || true
            # Stage any pending orch.sh removal (from earlier revision)
            if [ -f .claude/scripts/orch.sh ] || git ls-files --error-unmatch .claude/scripts/orch.sh &>/dev/null; then
                git rm -f .claude/scripts/orch.sh 2>/dev/null || true
            fi
            if git diff --cached --quiet; then
                log_info "No drift in deploy.sh or kit-update.md — skipping commit."
                exit 10
            fi
            REMOTE_SHA=$(git ls-remote "https://github.com/${REPO}.git" "${REF}" 2>/dev/null | awk '{print $1}' | cut -c1-7 || echo "unknown")
            git commit --quiet -m "chore(orchestration): refresh deploy.sh + /kit-update from kit ${REMOTE_SHA}

Updated via: curl -sSL .../install.sh | bash -s -- --update-deploy
Source: ${REPO}@${REF}

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>" || exit 12
            log_ok "Committed: $(git rev-parse --short HEAD)"
            if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' &>/dev/null; then
                git push --quiet 2>/dev/null && log_ok "Pushed to $(git rev-parse --abbrev-ref '@{u}')" || log_info "git push failed — run manually later"
            else
                log_info "No upstream branch set — run 'git push' manually."
            fi
        )
    else
        log_info "Not a git repo — skipping auto commit/push."
    fi

    log_info "Next: use slash command '/kit-update --update-skills' or '/kit-update --update-external-skills' in Claude Code."
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
