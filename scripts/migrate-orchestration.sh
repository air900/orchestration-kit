#!/bin/bash
# migrate-orchestration.sh — Move a project deployed with the old (Beads/LightRAG)
# orchestration-kit onto the current (tracker-agnostic) version.
#
# Steps performed per target:
#   1. Run local deploy.sh --update-skills (refreshes agents/skills/commands/hooks)
#   2. Drop hooks.PreCompact + any leftover `bd prime` commands from settings.json
#   3. Add documentation.paths.handoff + documentation.enabled.handoff to
#      orchestration-config.json (idempotent — preserves existing fields)
#   4. mkdir -p docs/orchestration/handoff/
#   5. Patch CLAUDE.md "Claude Automations" section in place (templated subs)
#   6. Optionally: rm -rf .beads/ and uninstall the beads plugin (only with --purge-beads)
#
# Usage:
#   migrate-orchestration.sh <project-path> [--purge-beads] [--dry-run]
#
# Exit codes:
#   0 — migration completed (or already up-to-date)
#   1 — invalid arguments
#   2 — project does not look like an orchestration-kit install
#   3 — a sub-step failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    cat <<EOF >&2
Usage: $0 <project-path> [--purge-beads] [--dry-run]

  --purge-beads   rm -rf .beads/ and attempt to uninstall the beads plugin
                  via 'claude plugin uninstall beads'. Off by default; the
                  state is left in place so the user can choose what to keep.

  --dry-run       Print actions without applying. Implies no commits, no
                  file edits, no settings.json mutation.
EOF
    exit 1
}

# --- Parse args ---
[ $# -lt 1 ] && usage
TARGET=""
PURGE_BEADS=false
DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --purge-beads) PURGE_BEADS=true ;;
        --dry-run) DRY_RUN=true ;;
        -h|--help) usage ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$arg"
            else
                log_error "unexpected argument: $arg"
                usage
            fi
            ;;
    esac
done

# --- Validate target ---
TARGET="$(cd "$TARGET" 2>/dev/null && pwd)" || {
    log_error "target path does not exist: $1"
    exit 1
}

if [ ! -d "$TARGET/.claude" ]; then
    log_error "$TARGET has no .claude/ — not an orchestration-kit install"
    exit 2
fi

log_info "Migrating: $TARGET"
[ "$DRY_RUN" = true ] && log_warn "DRY RUN — no files will change"

# --- Dependencies ---
command -v jq >/dev/null  || { log_error "jq is required"; exit 3; }
command -v python3 >/dev/null || { log_error "python3 is required"; exit 3; }

# === Step 1: deploy.sh --update-skills ===
log_info "Step 1: Refresh kit content via local deploy.sh --update-skills"
if [ "$DRY_RUN" = true ]; then
    log_info "  (dry-run) would run: $KIT_ROOT/deploy.sh $TARGET --update-skills"
else
    set +e
    "$KIT_ROOT/deploy.sh" "$TARGET" --update-skills >/tmp/migrate-deploy.log 2>&1
    DEPLOY_RC=$?
    set -e
    # Exit codes from deploy.sh in --update-skills mode:
    #   0  — committed + pushed; 10 — no drift (clean idempotent re-run);
    #   11 — committed but push failed; 12 — commit failed
    # Treat 0, 10, 11 as success for migration purposes (commit/push is optional).
    case "$DEPLOY_RC" in
        0|10|11) log_ok "Step 1 done (deploy.sh rc=$DEPLOY_RC)" ;;
        *) log_error "Step 1 failed (deploy.sh rc=$DEPLOY_RC) — see /tmp/migrate-deploy.log"
           exit 3 ;;
    esac
fi

# === Step 2: settings.json — drop PreCompact + bd prime ===
SETTINGS="$TARGET/.claude/settings.json"
if [ -f "$SETTINGS" ]; then
    log_info "Step 2: Clean stale hooks in settings.json"
    if [ "$DRY_RUN" = true ]; then
        PRECOMPACT_EXISTS=$(jq 'has("hooks") and (.hooks | has("PreCompact"))' "$SETTINGS" 2>/dev/null || echo "false")
        BD_PRIME_COUNT=$(grep -c 'bd prime' "$SETTINGS" 2>/dev/null || echo 0)
        log_info "  (dry-run) PreCompact present: $PRECOMPACT_EXISTS; bd prime commands: $BD_PRIME_COUNT"
    else
        # Delete PreCompact entirely
        jq 'if (.hooks | has("PreCompact")) then del(.hooks.PreCompact) else . end' "$SETTINGS" > /tmp/migrate-settings.json
        # Strip any hook entry whose command starts with `bd prime`
        # (defensive: shouldn't be any after dropping PreCompact, but cover the case)
        jq '
            walk(
                if type == "object" and has("command") and (.command | tostring | startswith("bd prime"))
                then empty
                else .
                end
            )
        ' /tmp/migrate-settings.json > /tmp/migrate-settings.2.json 2>/dev/null \
            || cp /tmp/migrate-settings.json /tmp/migrate-settings.2.json
        mv /tmp/migrate-settings.2.json "$SETTINGS"
        rm -f /tmp/migrate-settings.json
        log_ok "Step 2 done — settings.json hooks: $(jq -c '.hooks | keys' "$SETTINGS")"
    fi
else
    log_warn "Step 2 skipped — no .claude/settings.json"
fi

# === Step 3: orchestration-config.json — add handoff path ===
ORCH_CFG="$TARGET/.claude/orchestration-config.json"
if [ -f "$ORCH_CFG" ]; then
    log_info "Step 3: Ensure handoff path in orchestration-config.json"
    if [ "$DRY_RUN" = true ]; then
        HANDOFF_PATH=$(jq -r '.documentation.paths.handoff // "missing"' "$ORCH_CFG")
        HANDOFF_ENABLED=$(jq -r '.documentation.enabled.handoff // "missing"' "$ORCH_CFG")
        log_info "  (dry-run) current: paths.handoff=$HANDOFF_PATH, enabled.handoff=$HANDOFF_ENABLED"
    else
        jq '
            .documentation.paths.handoff = (.documentation.paths.handoff // "docs/orchestration/handoff")
            | .documentation.enabled.handoff = (.documentation.enabled.handoff // true)
        ' "$ORCH_CFG" > /tmp/migrate-orch-cfg.json
        mv /tmp/migrate-orch-cfg.json "$ORCH_CFG"
        log_ok "Step 3 done — handoff path = $(jq -r '.documentation.paths.handoff' "$ORCH_CFG")"
    fi
else
    log_warn "Step 3 skipped — no .claude/orchestration-config.json"
fi

# === Step 4: mkdir -p docs/orchestration/handoff/ ===
log_info "Step 4: Ensure docs/orchestration/handoff/ exists"
if [ "$DRY_RUN" = true ]; then
    [ -d "$TARGET/docs/orchestration/handoff" ] && log_info "  (dry-run) already present" || log_info "  (dry-run) would mkdir"
else
    mkdir -p "$TARGET/docs/orchestration/handoff"
    log_ok "Step 4 done"
fi

# === Step 5: patch CLAUDE.md ===
CLAUDE_MD="$TARGET/CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    log_info "Step 5: Patch CLAUDE.md (templated substitutions)"
    if [ "$DRY_RUN" = true ]; then
        BEADS_HITS=$(grep -cE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' "$CLAUDE_MD" || true)
        log_info "  (dry-run) current beads/bd/LightRAG matches: $BEADS_HITS"
    else
        python3 "$SCRIPT_DIR/migrate-claude-md.py" "$CLAUDE_MD" || true
        RESIDUAL=$(grep -cE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' "$CLAUDE_MD" || true)
        if [ "$RESIDUAL" -eq 0 ]; then
            log_ok "Step 5 done — CLAUDE.md clean of bd/beads/LightRAG"
        else
            log_warn "Step 5 done with $RESIDUAL residual mention(s); review $CLAUDE_MD manually"
        fi
    fi
else
    log_warn "Step 5 skipped — no CLAUDE.md"
fi

# === Step 6: optional purge .beads/ + plugin ===
if [ "$PURGE_BEADS" = true ]; then
    log_info "Step 6: Purge .beads/ state and uninstall plugin (per --purge-beads)"
    if [ -d "$TARGET/.beads" ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "  (dry-run) would rm -rf $TARGET/.beads"
        else
            rm -rf "$TARGET/.beads"
            log_ok "  removed $TARGET/.beads"
        fi
    else
        log_info "  no .beads/ to remove"
    fi
    if command -v claude >/dev/null; then
        if [ "$DRY_RUN" = true ]; then
            log_info "  (dry-run) would: claude plugin uninstall beads"
        else
            claude plugin uninstall beads >/dev/null 2>&1 && log_ok "  beads plugin uninstalled" || log_info "  beads plugin not installed (or uninstall failed; ignored)"
        fi
    fi
else
    if [ -d "$TARGET/.beads" ]; then
        log_info "Step 6: .beads/ retained (pass --purge-beads to remove)"
    fi
fi

# === Final state summary ===
echo
echo -e "${GREEN}================================================================${NC}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${GREEN}  Migration dry-run finished: $TARGET${NC}"
else
    echo -e "${GREEN}  Migration finished: $TARGET${NC}"
fi
echo -e "${GREEN}================================================================${NC}"

if [ "$DRY_RUN" = false ]; then
    echo
    EXCLUDE='knowledge-harvest|Migrating an existing deployment|command-log\.txt|\.claude/worktrees/|\.beads/|settings\.local\.json'
    BEADS_FINAL=$(grep -rnE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' "$TARGET/.claude" "$TARGET/CLAUDE.md" 2>/dev/null \
        | grep -vE "$EXCLUDE" \
        | wc -l)
    echo "  Residual beads/bd/LightRAG mentions (excluding knowledge-harvest skill,"
    echo "  README migration block, command-log.txt, ephemeral .claude/worktrees/,"
    echo "  .beads/ internal data, and settings.local.json local MCP allow-list): $BEADS_FINAL"
    if [ "$BEADS_FINAL" -gt 0 ]; then
        echo
        echo "  Locations needing manual review:"
        grep -rnE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' "$TARGET/.claude" "$TARGET/CLAUDE.md" 2>/dev/null \
            | grep -vE "$EXCLUDE" \
            | head -10
    fi
fi
echo
