#!/bin/bash
# deploy.sh — Deploy orchestration system to a target project
# Usage: ./deploy.sh /path/to/target-project [atomic|multi]
#
# Phase 1 of hybrid deployment:
#   - Copies agents, skills, config, hooks
#   - Detects language and applies appropriate PostToolUse hooks
#   - Merges with existing settings.json if present
#
# Phase 2 (interactive) is handled by the deploy-orchestration skill
# which discovers task-specific skills and generates CLAUDE.md

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$SCRIPT_DIR/templates"
LANG_HOOKS="$SCRIPT_DIR/language-hooks"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Usage ---
usage() {
    echo "Usage: $0 <target-project-path> [atomic|multi]"
    echo ""
    echo "  target-project-path  Path to the project to deploy orchestration into"
    echo "  atomic               Single-purpose project (default)"
    echo "  multi                Multi-purpose project with sub-projects in src/"
    echo ""
    echo "After running this script, use /deploy-orchestration in Claude Code"
    echo "to discover task-specific skills and generate CLAUDE.md."
    exit 1
}

# --- Validate inputs ---
if [ $# -lt 1 ]; then
    usage
fi

TARGET="$(cd "$1" 2>/dev/null && pwd)" || {
    log_error "Target path does not exist: $1"
    exit 1
}

PROJECT_TYPE="${2:-atomic}"
if [[ "$PROJECT_TYPE" != "atomic" && "$PROJECT_TYPE" != "multi" ]]; then
    log_error "Project type must be 'atomic' or 'multi', got: $PROJECT_TYPE"
    exit 1
fi

# --- Check prerequisites ---
if ! command -v jq &>/dev/null; then
    log_error "jq is required for settings.json merging. Install: apt install jq"
    exit 1
fi

if [ ! -d "$TARGET/.git" ]; then
    log_warn "Target is not a git repository. Orchestration works best with git."
fi

# Helper: prompt user or auto-accept if no TTY (pipe mode)
ask_yes() {
    local prompt="$1"
    if [ -e /dev/tty ]; then
        read -r -p "  $prompt [Y/n] " ans < /dev/tty
    else
        ans="y"  # auto-accept in non-interactive (CI, Docker)
    fi
    [[ "${ans:-y}" =~ ^[Yy]$ ]]
}

# --- Check & install plugin prerequisites ---
if command -v claude &>/dev/null; then
    PLUGIN_LIST=$(claude plugin list 2>/dev/null || echo "")

    # Superpowers (required)
    if ! echo "$PLUGIN_LIST" | grep -q "superpowers"; then
        log_warn "Superpowers plugin not found (required for dev methodology)"
        if ask_yes "Install superpowers?"; then
            log_info "Installing superpowers..."
            claude plugin install superpowers 2>&1 && log_ok "Superpowers installed" || log_warn "Failed — install manually: claude plugin install superpowers"
        fi
    else
        log_ok "Superpowers plugin found"
    fi

    # Beads (recommended)
    if ! echo "$PLUGIN_LIST" | grep -q "beads"; then
        log_warn "Beads plugin not found (recommended for task tracking)"
        if ask_yes "Install beads?"; then
            log_info "Adding beads marketplace..."
            claude plugin marketplace add steveyegge/beads 2>&1 || true
            log_info "Installing beads plugin..."
            claude plugin install beads 2>&1 && log_ok "Beads plugin installed" || log_warn "Failed — install manually: claude plugin marketplace add steveyegge/beads && claude plugin install beads"
        fi
    else
        log_ok "Beads plugin found"
    fi
else
    log_warn "claude CLI not found — install plugins manually after setup:"
    echo "  claude plugin install superpowers"
    echo "  claude plugin marketplace add steveyegge/beads && claude plugin install beads"
    echo ""
fi

# --- Check & install bd CLI ---
HAS_BD=false
if command -v bd &>/dev/null; then
    HAS_BD=true
    log_ok "bd CLI found"
else
    log_warn "bd CLI not found (needed for Beads task tracking)"
    if command -v npm &>/dev/null; then
        if ask_yes "Install bd globally via npm?"; then
            log_info "Installing @beads/bd..."
            npm install -g @beads/bd 2>&1 && { HAS_BD=true; log_ok "bd CLI installed"; } || log_warn "Failed — install manually: npm install -g @beads/bd"
        fi
    else
        log_info "Install manually: npm install -g @beads/bd"
    fi
fi

log_info "Deploying orchestration to: $TARGET"
log_info "Project type: $PROJECT_TYPE"

# --- Detect language ---
detect_language() {
    local target="$1"
    if [ -f "$target/package.json" ]; then
        # Check if TypeScript
        if [ -f "$target/tsconfig.json" ] || grep -q '"typescript"' "$target/package.json" 2>/dev/null; then
            echo "typescript"
        else
            echo "javascript"
        fi
    elif [ -f "$target/pyproject.toml" ] || [ -f "$target/requirements.txt" ] || [ -f "$target/setup.py" ]; then
        echo "python"
    elif [ -f "$target/go.mod" ]; then
        echo "go"
    elif [ -f "$target/Cargo.toml" ]; then
        echo "rust"
    else
        echo "generic"
    fi
}

LANG=$(detect_language "$TARGET")
log_info "Detected language: $LANG"

# --- Create directories ---
log_info "Creating directory structure..."

mkdir -p "$TARGET/.claude/agents"
mkdir -p "$TARGET/.claude/skills"
mkdir -p "$TARGET/.agents/skills"
mkdir -p "$TARGET/docs/orchestration/plans"
mkdir -p "$TARGET/docs/orchestration/reports"
mkdir -p "$TARGET/docs/orchestration/issues"
mkdir -p "$TARGET/docs/orchestration/doc-drafts"
mkdir -p "$TARGET/docs/orchestration/observer-reports"

log_ok "Directories created"

# --- Copy agents ---
log_info "Copying agents..."
AGENTS_COPIED=0
for agent_file in "$TEMPLATES/agents/"*.md; do
    agent_name=$(basename "$agent_file")
    dest="$TARGET/.claude/agents/$agent_name"
    if [ -f "$dest" ]; then
        log_warn "Agent already exists, overwriting: $agent_name"
    fi
    cp "$agent_file" "$dest"
    AGENTS_COPIED=$((AGENTS_COPIED + 1))
done
log_ok "Copied $AGENTS_COPIED agents"

# --- Copy skills ---
log_info "Copying skills..."
SKILLS_COPIED=0
for skill_dir in "$TEMPLATES/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    dest="$TARGET/.claude/skills/$skill_name"
    if [ -d "$dest" ]; then
        log_warn "Skill already exists, overwriting: $skill_name"
    fi
    cp -r "$skill_dir" "$dest"
    SKILLS_COPIED=$((SKILLS_COPIED + 1))
done
log_ok "Copied $SKILLS_COPIED skills"

# --- Copy shared references ---
log_info "Copying shared references..."
if [ -d "$TEMPLATES/references" ]; then
    mkdir -p "$TARGET/.claude/references"
    cp "$TEMPLATES/references/"*.md "$TARGET/.claude/references/"
    REFS_COPIED=$(ls -1 "$TEMPLATES/references/"*.md 2>/dev/null | wc -l)
    log_ok "Copied $REFS_COPIED reference docs"
fi

# --- Copy deploy-orchestration skill for Phase 2 ---
log_info "Installing deploy-orchestration skill..."
mkdir -p "$TARGET/.claude/skills/deploy-orchestration"
cp "$SCRIPT_DIR/SKILL.md" "$TARGET/.claude/skills/deploy-orchestration/SKILL.md"
log_ok "Deploy-orchestration skill installed"

# find-skills is now included in templates/skills/ and deployed with other skills above

# --- Copy orchestration config ---
log_info "Setting up orchestration config..."
if [ -f "$TARGET/.claude/orchestration-config.json" ]; then
    log_warn ".claude/orchestration-config.json already exists, skipping"
else
    cp "$TEMPLATES/orchestration-config.json" "$TARGET/.claude/orchestration-config.json"
    log_ok ".claude/orchestration-config.json created"
fi

# --- Generate settings.json with hooks ---
log_info "Configuring hooks..."

generate_settings() {
    local target="$1"
    local lang="$2"
    local target_path="$target"

    # Start with base hooks (PreToolUse safety guard)
    local base_hooks
    base_hooks=$(cat "$TEMPLATES/settings-hooks.json")

    # Add language-specific PostToolUse hooks if available
    local lang_file="$LANG_HOOKS/${lang}.json"
    if [ -f "$lang_file" ]; then
        # Read language hooks and replace {{PROJECT_PATH}} placeholder
        local lang_hooks_file
        lang_hooks_file=$(mktemp)
        sed "s|{{PROJECT_PATH}}|$target_path|g" "$lang_file" > "$lang_hooks_file"

        # Merge PostToolUse from language hooks into base hooks
        base_hooks=$(jq --slurpfile lang_hooks "$lang_hooks_file" '
            .hooks.PostToolUse = ($lang_hooks[0].PostToolUse // [])
        ' <<< "$base_hooks")
        rm -f "$lang_hooks_file"
        log_ok "Applied $lang language hooks" >&2
    else
        log_info "No language-specific hooks for: $lang" >&2
    fi

    echo "$base_hooks"
}

GENERATED_SETTINGS=$(generate_settings "$TARGET" "$LANG")

NEW_SETTINGS_FILE=$(mktemp)
echo "$GENERATED_SETTINGS" > "$NEW_SETTINGS_FILE"

if [ -f "$TARGET/.claude/settings.json" ]; then
    log_info "Existing settings.json found, merging..."

    # Merge: preserve existing permissions, add new hooks (deduplicate by matcher)
    jq --slurpfile new "$NEW_SETTINGS_FILE" '
        .hooks = (
            ($new[0].hooks // {}) as $new_hooks |
            (.hooks // {}) as $old_hooks |
            reduce ($new_hooks | keys[]) as $key (
                $old_hooks;
                # For array hook types, deduplicate by matcher field
                if ($new_hooks[$key] | type) == "array" then
                    .[$key] = (
                        ((.[$key] // []) + ($new_hooks[$key] // [])) |
                        # Keep last occurrence of each matcher (new wins)
                        group_by(.matcher) | map(last)
                    )
                else
                    .[$key] = ($new_hooks[$key] // .[$key])
                end
            )
        ) |
        .permissions = (.permissions // {})
    ' "$TARGET/.claude/settings.json" > "$TARGET/.claude/settings.json.tmp"

    mv "$TARGET/.claude/settings.json.tmp" "$TARGET/.claude/settings.json"
    log_ok "Merged into existing settings.json"
else
    jq '.' "$NEW_SETTINGS_FILE" > "$TARGET/.claude/settings.json"
    log_ok "Created settings.json"
fi

rm -f "$NEW_SETTINGS_FILE"

# --- Initialize Beads (if bd is available) ---
if [ "$HAS_BD" = true ] && [ -d "$TARGET/.git" ]; then
    if [ ! -d "$TARGET/.beads" ]; then
        log_info "Initializing Beads issue tracker..."
        (cd "$TARGET" && bd init 2>/dev/null) && log_ok "Beads initialized (.beads/)" || log_warn "Beads init failed — you can run 'bd init' manually"
    else
        log_info "Beads already initialized, skipping"
    fi
elif [ "$HAS_BD" = false ]; then
    log_info "bd CLI not found. Install: npm install -g @beads/bd"
fi

# --- Multi-project structure ---
if [ "$PROJECT_TYPE" = "multi" ]; then
    log_info "Setting up multi-project structure..."
    mkdir -p "$TARGET/src"
    log_ok "Created src/ for sub-projects"
    log_info "Use /deploy-orchestration to define sub-projects and generate CLAUDE.md sections"
fi

# --- Summary ---
echo ""
echo -e "${GREEN}================================================================${NC}"
echo -e "${GREEN}  Orchestration deployed successfully!${NC}"
echo -e "${GREEN}================================================================${NC}"
echo ""
echo "  Target:     $TARGET"
echo "  Type:       $PROJECT_TYPE"
echo "  Language:   $LANG"
echo "  Agents:     $AGENTS_COPIED"
echo "  Skills:     $SKILLS_COPIED + deploy-orchestration"
echo ""
echo "  Next steps:"
echo "    1. cd $TARGET"
echo "    2. Open Claude Code"
echo "    3. Run /deploy-orchestration with your task description:"
echo ""
echo "       Examples:"
echo "         /deploy-orchestration develop REST API with FastAPI and PostgreSQL"
echo "         /deploy-orchestration build React dashboard with auth and charts"
echo "         /deploy-orchestration create WordPress plugin for SEO"
if [ "$PROJECT_TYPE" = "multi" ]; then
echo "         /deploy-orchestration web-scripts: form validators, browser plugins, CLI tools"
fi
echo ""
echo "       This discovers relevant skills and generates CLAUDE.md."
echo ""
echo "  After setup, Superpowers handles the dev loop."
echo "  Beads tracks tasks across sessions (bd ready, bd create)."
echo ""
echo "  Specialist skills:"
echo "    /arch-review     — Architecture health check"
echo "    /security-audit  — OWASP vulnerability scan"
echo "    /refactor-code   — Guided refactoring"
echo "    /012-update-docs — Verify docs match code"
echo ""
echo "  On-demand agents from template catalog:"
echo "    npx claude-code-templates@latest --agent <category/name> --yes"
echo ""
echo -e "${GREEN}================================================================${NC}"
