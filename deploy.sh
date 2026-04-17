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
    echo "Usage: $0 <target-project-path> [atomic|multi|--update-skills]"
    echo ""
    echo "  target-project-path  Path to the project to deploy orchestration into"
    echo "  atomic               Fresh install — single-purpose project (default)"
    echo "  multi                Fresh install — multi-purpose project (sub-projects in src/)"
    echo "  --update-skills      Refresh kit content ONLY on an already-deployed project:"
    echo "                       re-copies agents, skills (with refs/), commands, hooks,"
    echo "                       references, and merges settings.json. Skips plugin checks,"
    echo "                       bd init, orchestration-config. Requires .claude/ to exist."
    echo ""
    echo "After fresh install, run /deploy-orchestration in Claude Code to"
    echo "discover task-specific skills and generate CLAUDE.md."
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
UPDATE_MODE=false
if [[ "$PROJECT_TYPE" == "--update-skills" ]]; then
    UPDATE_MODE=true
    # Safety: --update-skills only makes sense on an already-deployed project.
    # Fresh install should use atomic/multi to trigger plugin checks + bd init.
    if [ ! -d "$TARGET/.claude" ]; then
        log_error "--update-skills requires an existing deployment (.claude/ not found at $TARGET)"
        log_info "For fresh install, use: $0 $TARGET atomic"
        exit 1
    fi
    log_info "UPDATE-SKILLS mode: refreshing kit content only (no plugin checks, no bd init)"
elif [[ "$PROJECT_TYPE" != "atomic" && "$PROJECT_TYPE" != "multi" ]]; then
    log_error "Second argument must be one of: atomic | multi | --update-skills (got: $PROJECT_TYPE)"
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

# --- Check & install plugin prerequisites (skipped in --update-skills mode) ---
if [ "$UPDATE_MODE" = false ]; then
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

    # Template Bridge (recommended — connects Superpowers + Beads)
    if ! echo "$PLUGIN_LIST" | grep -q "template-bridge"; then
        log_warn "Template Bridge plugin not found (connects Superpowers + Beads into unified flow)"
        if ask_yes "Install template-bridge?"; then
            log_info "Adding template-bridge marketplace..."
            claude plugin marketplace add maslennikov-ig/template-bridge 2>&1 || true
            log_info "Installing template-bridge plugin..."
            claude plugin install template-bridge 2>&1 && log_ok "Template Bridge installed" || log_warn "Failed — install manually: claude plugin marketplace add maslennikov-ig/template-bridge && claude plugin install template-bridge"
        fi
    else
        log_ok "Template Bridge plugin found"
    fi
  else
    log_warn "claude CLI not found — install plugins manually after setup:"
    echo "  claude plugin install superpowers"
    echo "  claude plugin marketplace add steveyegge/beads && claude plugin install beads"
    echo "  claude plugin marketplace add maslennikov-ig/template-bridge && claude plugin install template-bridge"
    echo ""
  fi
fi

# --- Check & install bd CLI (skipped in --update-skills mode) ---
HAS_BD=false
if command -v bd &>/dev/null; then
    HAS_BD=true
    [ "$UPDATE_MODE" = false ] && log_ok "bd CLI found"
elif [ "$UPDATE_MODE" = false ]; then
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
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        # Remove existing dest (dir, file, or symlink) before copy.
        # cp -r src/ dest creates dest/src/ when dest pre-exists, causing
        # nested-dir artefacts. Safe here: loop only iterates kit skill
        # names from templates/, so custom skills (not in that list) are
        # never targeted. Kit skills are by definition owned by the kit,
        # so overwriting them — including symlinks — is intentional.
        log_warn "Skill already exists, overwriting: $skill_name"
        rm -rf "$dest"
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

# --- Copy slash commands ---
# Kit-owned slash commands (e.g., /workflow-gate, /workflow-gate-check).
# Only kit-template names are copied — any pre-existing command files in the
# target project with other names are left untouched.
log_info "Copying slash commands..."
if [ -d "$TEMPLATES/commands" ]; then
    mkdir -p "$TARGET/.claude/commands"
    CMDS_COPIED=0
    for cmd_file in "$TEMPLATES/commands/"*.md; do
        [ -e "$cmd_file" ] || continue
        cmd_name=$(basename "$cmd_file")
        dest="$TARGET/.claude/commands/$cmd_name"
        if [ -f "$dest" ]; then
            log_warn "Command already exists, overwriting: $cmd_name"
        fi
        cp "$cmd_file" "$dest"
        CMDS_COPIED=$((CMDS_COPIED + 1))
    done
    log_ok "Copied $CMDS_COPIED slash commands"
fi

# --- Copy hook scripts ---
log_info "Installing hook scripts..."
if [ -d "$TEMPLATES/hooks" ]; then
    mkdir -p "$TARGET/.claude/hooks"
    HOOKS_COPIED=0
    for hook_file in "$TEMPLATES/hooks/"*.sh; do
        [ -e "$hook_file" ] || continue
        hook_name=$(basename "$hook_file")
        dest="$TARGET/.claude/hooks/$hook_name"
        cp "$hook_file" "$dest"
        chmod +x "$dest"
        HOOKS_COPIED=$((HOOKS_COPIED + 1))
    done
    log_ok "Installed $HOOKS_COPIED hook scripts"
fi

# --- Ensure .claude/.gitignore excludes runtime artefacts ---
CLAUDE_GITIGNORE="$TARGET/.claude/.gitignore"
if [ -f "$TEMPLATES/claude-gitignore" ]; then
    if [ -f "$CLAUDE_GITIGNORE" ]; then
        if ! grep -qxF "command-log.txt" "$CLAUDE_GITIGNORE"; then
            echo "command-log.txt" >> "$CLAUDE_GITIGNORE"
            log_ok "Appended command-log.txt to existing .claude/.gitignore"
        else
            log_info ".claude/.gitignore already ignores command-log.txt"
        fi
    else
        cp "$TEMPLATES/claude-gitignore" "$CLAUDE_GITIGNORE"
        log_ok "Created .claude/.gitignore"
    fi
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

# --- Initialize Beads (skipped in --update-skills mode — already initialised) ---
if [ "$UPDATE_MODE" = false ]; then
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
fi

# --- Multi-project structure ---
if [ "$PROJECT_TYPE" = "multi" ]; then
    log_info "Setting up multi-project structure..."
    mkdir -p "$TARGET/src"
    log_ok "Created src/ for sub-projects"
    log_info "Use /deploy-orchestration to define sub-projects and generate CLAUDE.md sections"
fi

# --- Auto commit + push (only in --update-skills mode on git repos) ---
UPDATE_PUSHED=false
UPDATE_COMMIT_SHA=""
if [ "$UPDATE_MODE" = true ] && [ -d "$TARGET/.git" ]; then
    KIT_SHA=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    (
        cd "$TARGET" || exit 1
        # Stage only kit-owned paths (never git add -A — user may have unrelated
        # uncommitted work that should not land in our auto-commit).
        git add .claude/agents .claude/skills .claude/references .claude/commands \
                .claude/hooks .claude/.gitignore .claude/settings.json 2>/dev/null || true

        if git diff --cached --quiet; then
            log_info "No kit-content drift; nothing to commit."
            exit 10
        fi

        COMMIT_MSG="chore(orchestration): refresh kit content (kit ${KIT_SHA})

Auto-synced by: deploy.sh --update-skills from orchestration-kit ${KIT_SHA}

Paths refreshed:
- .claude/agents/             kit agent roster
- .claude/skills/             kit skills (directories with references/)
- .claude/commands/           kit slash commands
- .claude/references/         kit shared references
- .claude/hooks/              kit hooks (log-commands.sh etc.)
- .claude/.gitignore          audit-log exclusion
- .claude/settings.json       merged hooks

Custom files with non-kit names are preserved. settings.local.json,
orchestration-config.json, .beads/, docs/orchestration/ untouched.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"

        if git commit -m "$COMMIT_MSG" --quiet; then
            COMMIT_SHA=$(git rev-parse --short HEAD)
            log_ok "Committed: $COMMIT_SHA"
            echo "$COMMIT_SHA" > /tmp/.wgc_commit_sha

            if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' &>/dev/null; then
                if git push --quiet 2>/dev/null; then
                    log_ok "Pushed to $(git rev-parse --abbrev-ref '@{u}')"
                    exit 0
                else
                    log_warn "git push failed — run 'git push' manually in $TARGET"
                    exit 11
                fi
            else
                log_warn "No upstream branch set — run 'git push -u origin <branch>' manually"
                exit 11
            fi
        else
            log_error "git commit failed"
            exit 12
        fi
    )
    rc=$?
    case $rc in
        0)  UPDATE_PUSHED=true
            UPDATE_COMMIT_SHA=$(cat /tmp/.wgc_commit_sha 2>/dev/null || echo "")
            rm -f /tmp/.wgc_commit_sha ;;
        10) : ;; # no changes
        11) UPDATE_COMMIT_SHA=$(cat /tmp/.wgc_commit_sha 2>/dev/null || echo "")
            rm -f /tmp/.wgc_commit_sha ;;
        *)  log_warn "Auto-commit subshell exited with code $rc" ;;
    esac
elif [ "$UPDATE_MODE" = true ]; then
    log_warn "Target is not a git repo — skipping auto-commit/push"
fi

# --- Summary ---
echo ""
echo -e "${GREEN}================================================================${NC}"
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${GREEN}  Kit content refreshed successfully!${NC}"
else
    echo -e "${GREEN}  Orchestration deployed successfully!${NC}"
fi
echo -e "${GREEN}================================================================${NC}"
echo ""
echo "  Target:     $TARGET"
echo "  Type:       $PROJECT_TYPE"
echo "  Language:   $LANG"
echo "  Agents:     $AGENTS_COPIED"
echo "  Skills:     $SKILLS_COPIED + deploy-orchestration"
echo ""

if [ "$UPDATE_MODE" = true ]; then
echo "  What changed in this run:"
echo "    - agents/, skills/ (with references/), commands/, hooks/, shared references/"
echo "    - settings.json hooks merged with kit's latest"
echo "    - orchestration-config.json and .beads/ left untouched"
echo ""
if [ "$UPDATE_PUSHED" = true ]; then
echo "  Git:        committed ($UPDATE_COMMIT_SHA) and pushed to remote."
elif [ -n "$UPDATE_COMMIT_SHA" ]; then
echo "  Git:        committed ($UPDATE_COMMIT_SHA) but push failed — run 'git push' in $TARGET."
elif [ -d "$TARGET/.git" ]; then
echo "  Git:        no drift detected; no commit created."
else
echo "  Git:        target is not a git repo; manual tracking required."
fi
else
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
fi
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
