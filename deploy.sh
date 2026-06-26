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

# --- Self-bootstrap: if templates/ is not alongside, clone kit to /tmp ---
# This lets a project keep only .claude/scripts/deploy.sh and still run
# --update-skills — the script fetches its own templates at runtime.
KIT_REPO="${ORCHESTRATION_KIT_REPO:-air900/orchestration-kit}"
KIT_REF="${ORCHESTRATION_KIT_REF:-main}"
BOOTSTRAP_DIR=""
cleanup_bootstrap() {
    [ -n "$BOOTSTRAP_DIR" ] && [ -d "$BOOTSTRAP_DIR" ] && rm -rf "$BOOTSTRAP_DIR"
}

if [ -d "$SCRIPT_DIR/templates" ]; then
    # Dev mode: running deploy.sh from cloned orchestration-kit repo
    TEMPLATES="$SCRIPT_DIR/templates"
    LANG_HOOKS="$SCRIPT_DIR/language-hooks"
    KIT_SKILL_MD="$SCRIPT_DIR/SKILL.md"
else
    # Project-local mode: deploy.sh lives in a project (e.g., .claude/scripts/);
    # fetch templates from GitHub into a tmp dir for this invocation.
    log_info "No local templates/ next to deploy.sh; bootstrapping from ${KIT_REPO}@${KIT_REF}..."
    BOOTSTRAP_DIR=$(mktemp -d)
    trap cleanup_bootstrap EXIT
    if command -v git &>/dev/null; then
        git clone --quiet --depth 1 --branch "$KIT_REF" \
            "https://github.com/${KIT_REPO}.git" "$BOOTSTRAP_DIR/kit" 2>/dev/null || {
            log_error "git clone failed for https://github.com/${KIT_REPO}.git@${KIT_REF}"
            exit 1
        }
    else
        curl -sL "https://codeload.github.com/${KIT_REPO}/tar.gz/${KIT_REF}" | \
            tar -xz -C "$BOOTSTRAP_DIR" --strip-components=1 \
                --wildcards '*/templates/*' '*/language-hooks/*' '*/SKILL.md' 2>/dev/null || {
            log_error "tarball fetch failed for ${KIT_REPO}@${KIT_REF}"
            exit 1
        }
    fi
    KIT_ROOT="$BOOTSTRAP_DIR/kit"
    [ -d "$KIT_ROOT" ] || KIT_ROOT="$BOOTSTRAP_DIR"
    TEMPLATES="$KIT_ROOT/templates"
    LANG_HOOKS="$KIT_ROOT/language-hooks"
    KIT_SKILL_MD="$KIT_ROOT/SKILL.md"
    log_ok "Kit bootstrapped to $KIT_ROOT"
fi

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
    echo "                       orchestration-config. Requires .claude/ to exist."
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
    # Fresh install should use atomic/multi to trigger plugin checks.
    if [ ! -d "$TARGET/.claude" ]; then
        log_error "--update-skills requires an existing deployment (.claude/ not found at $TARGET)"
        log_info "For fresh install, use: $0 $TARGET atomic"
        exit 1
    fi
    log_info "UPDATE-SKILLS mode: refreshing kit content only (no plugin checks)"
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

    # Note: /wf-gate is self-contained (drives superpowers skills directly) —
    # no template-bridge / unified-workflow plugin is required.
  else
    log_warn "claude CLI not found — install the one prerequisite manually after setup:"
    echo "  claude plugin install superpowers"
    echo ""
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
mkdir -p "$TARGET/docs/orchestration/handoff"

log_ok "Directories created"

# --- Global (user-level) skill/command config ---
# The wf-gate pair lives globally in ~/.claude so a single canonical copy
# serves every project. deploy.sh installs them to ~/.claude and never copies
# them project-local; stale local copies (incl. legacy workflow-gate names)
# are removed on every run.
GLOBAL_SKILLS=("wf-gate" "wf-gate-check")
GLOBAL_CMDS=("wf-gate.md" "wf-gate-check.md")
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
GLOBAL_CMDS_DIR="$HOME/.claude/commands"
LEGACY_LOCAL_SKILLS=("workflow-gate" "workflow-gate-check")
LEGACY_LOCAL_CMDS=("workflow-gate.md" "workflow-gate-check.md")

# Codex agents are user-level by design: one canonical worker roster for all projects.
CODEX_GLOBAL_AGENTS=(
    "backend-engineer"
    "code-reviewer"
    "code-scout"
    "debugger"
    "frontend-engineer"
    "infra-engineer"
    "test-engineer"
)
CODEX_AGENTS_DIR="$HOME/.codex/agents"
CODEX_CONFIG_FILE="$HOME/.codex/config.toml"

in_list() {
    local needle="$1"; shift
    local x
    for x in "$@"; do [ "$x" = "$needle" ] && return 0; done
    return 1
}

ensure_codex_agents_config() {
    mkdir -p "$(dirname "$CODEX_CONFIG_FILE")"
    if command -v python3 &>/dev/null; then
        CODEX_CONFIG_FILE="$CODEX_CONFIG_FILE" python3 - <<'PY'
from pathlib import Path
import os

path = Path(os.environ["CODEX_CONFIG_FILE"])
text = path.read_text() if path.exists() else ""
lines = text.splitlines()

if not lines:
    lines = ["[agents]", "max_threads = 16", "max_depth = 5"]
elif "[agents]" not in lines:
    if lines[-1].strip():
        lines.append("")
    lines.extend(["[agents]", "max_threads = 16", "max_depth = 5"])
else:
    out = []
    in_agents = False
    saw_threads = False
    saw_depth = False
    inserted = False
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            if in_agents and not inserted:
                if not saw_threads:
                    out.append("max_threads = 16")
                if not saw_depth:
                    out.append("max_depth = 5")
                inserted = True
            in_agents = stripped == "[agents]"
        if in_agents and stripped.startswith("max_threads"):
            out.append("max_threads = 16")
            saw_threads = True
            continue
        if in_agents and stripped.startswith("max_depth"):
            out.append("max_depth = 5")
            saw_depth = True
            continue
        out.append(line)
    if in_agents and not inserted:
        if not saw_threads:
            out.append("max_threads = 16")
        if not saw_depth:
            out.append("max_depth = 5")
    lines = out

path.write_text("\n".join(lines) + "\n")
PY
    else
        log_warn "python3 not found; cannot safely merge ~/.codex/config.toml [agents] settings"
        if [ ! -f "$CODEX_CONFIG_FILE" ] || ! grep -qxF "[agents]" "$CODEX_CONFIG_FILE"; then
            { echo ""; echo "[agents]"; echo "max_threads = 16"; echo "max_depth = 5"; } >> "$CODEX_CONFIG_FILE"
            log_ok "Appended Codex [agents] settings to $CODEX_CONFIG_FILE"
        fi
    fi
}

install_codex_global_agents() {
    local src_dir="$TEMPLATES/codex-agents"
    if [ ! -d "$src_dir" ]; then
        log_warn "Codex agent templates not found: $src_dir"
        return 0
    fi

    log_info "Installing global Codex agents (~/.codex/agents)..."
    mkdir -p "$CODEX_AGENTS_DIR"
    local installed=0
    local agent
    for agent in "${CODEX_GLOBAL_AGENTS[@]}"; do
        local src="$src_dir/$agent.toml"
        local dest="$CODEX_AGENTS_DIR/$agent.toml"
        if [ ! -f "$src" ]; then
            log_warn "Missing Codex agent template: $agent.toml"
            continue
        fi
        cp "$src" "$dest"
        installed=$((installed + 1))
    done


    ensure_codex_agents_config
    log_ok "Installed/updated $installed global Codex agents"
}

ensure_agents_md_symlink() {
    local claude_md="$TARGET/CLAUDE.md"
    local agents_md="$TARGET/AGENTS.md"

    if [ ! -e "$claude_md" ] && [ ! -L "$claude_md" ]; then
        log_info "CLAUDE.md not found; AGENTS.md symlink will be created after CLAUDE.md generation"
        return 0
    fi

    if [ -L "$agents_md" ] && [ "$(readlink "$agents_md")" = "CLAUDE.md" ]; then
        log_info "AGENTS.md already points to CLAUDE.md"
        return 0
    fi

    rm -f "$agents_md"
    ln -s "CLAUDE.md" "$agents_md"
    log_ok "Ensured AGENTS.md -> CLAUDE.md"
}

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

# --- Install global Codex agents ---
install_codex_global_agents

# --- Copy skills ---
log_info "Copying skills..."
SKILLS_COPIED=0
for skill_dir in "$TEMPLATES/skills/"*/; do
    skill_name=$(basename "$skill_dir")
    # wf-gate pair is installed globally (below), never project-local.
    if in_list "$skill_name" "${GLOBAL_SKILLS[@]}"; then
        continue
    fi
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

# --- Install global skills (wf-gate pair) ---
log_info "Installing global skills (~/.claude/skills)..."
mkdir -p "$GLOBAL_SKILLS_DIR"
GLOBAL_SKILLS_INSTALLED=0
for gs in "${GLOBAL_SKILLS[@]}"; do
    src="$TEMPLATES/skills/$gs"
    [ -d "$src" ] || continue
    dest="$GLOBAL_SKILLS_DIR/$gs"
    rm -rf "$dest"          # idempotent: overwrite any prior global copy
    cp -r "$src" "$dest"
    GLOBAL_SKILLS_INSTALLED=$((GLOBAL_SKILLS_INSTALLED + 1))
done
log_ok "Installed $GLOBAL_SKILLS_INSTALLED global skills"

# Remove stale project-local copies (current + legacy workflow-gate names).
for stale in "${GLOBAL_SKILLS[@]}" "${LEGACY_LOCAL_SKILLS[@]}"; do
    if [ -e "$TARGET/.claude/skills/$stale" ] || [ -L "$TARGET/.claude/skills/$stale" ]; then
        log_warn "Removing stale project-local skill (now global): $stale"
        rm -rf "$TARGET/.claude/skills/$stale"
    fi
done

# --- Copy shared references ---
log_info "Copying shared references..."
if [ -d "$TEMPLATES/references" ]; then
    mkdir -p "$TARGET/.claude/references"
    cp "$TEMPLATES/references/"*.md "$TARGET/.claude/references/"
    REFS_COPIED=$(ls -1 "$TEMPLATES/references/"*.md 2>/dev/null | wc -l)
    log_ok "Copied $REFS_COPIED reference docs"
fi

# --- Copy slash commands ---
# Kit-owned slash commands (e.g., /wf-gate, /wf-gate-check).
# Only kit-template names are copied — any pre-existing command files in the
# target project with other names are left untouched.
log_info "Copying slash commands..."
if [ -d "$TEMPLATES/commands" ]; then
    mkdir -p "$TARGET/.claude/commands"
    CMDS_COPIED=0
    for cmd_file in "$TEMPLATES/commands/"*.md; do
        [ -e "$cmd_file" ] || continue
        cmd_name=$(basename "$cmd_file")
        # wf-gate pair commands are installed globally (below), never project-local.
        if in_list "$cmd_name" "${GLOBAL_CMDS[@]}"; then
            continue
        fi
        dest="$TARGET/.claude/commands/$cmd_name"
        if [ -f "$dest" ]; then
            log_warn "Command already exists, overwriting: $cmd_name"
        fi
        cp "$cmd_file" "$dest"
        CMDS_COPIED=$((CMDS_COPIED + 1))
    done
    log_ok "Copied $CMDS_COPIED slash commands"
fi

# --- Install global slash commands (wf-gate pair) ---
log_info "Installing global slash commands (~/.claude/commands)..."
mkdir -p "$GLOBAL_CMDS_DIR"
GLOBAL_CMDS_INSTALLED=0
for gc in "${GLOBAL_CMDS[@]}"; do
    src="$TEMPLATES/commands/$gc"
    [ -f "$src" ] || continue
    cp "$src" "$GLOBAL_CMDS_DIR/$gc"
    GLOBAL_CMDS_INSTALLED=$((GLOBAL_CMDS_INSTALLED + 1))
done
log_ok "Installed $GLOBAL_CMDS_INSTALLED global slash commands"

# Remove stale project-local command copies (current + legacy workflow-gate names).
for stale in "${GLOBAL_CMDS[@]}" "${LEGACY_LOCAL_CMDS[@]}"; do
    if [ -e "$TARGET/.claude/commands/$stale" ]; then
        log_warn "Removing stale project-local command (now global): $stale"
        rm -f "$TARGET/.claude/commands/$stale"
    fi
done

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
cp "$KIT_SKILL_MD" "$TARGET/.claude/skills/deploy-orchestration/SKILL.md"
log_ok "Deploy-orchestration skill installed"

# find-skills-my is now included in templates/skills/ and deployed with other skills above
# (renamed from find-skills to avoid collision with vercel-labs/skills' find-skills)

# --- Ensure Codex reads the same project rules as Claude ---
ensure_agents_md_symlink

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

# --- Multi-project structure ---
if [ "$PROJECT_TYPE" = "multi" ]; then
    log_info "Setting up multi-project structure..."
    mkdir -p "$TARGET/src"
    log_ok "Created src/ for sub-projects"
    log_info "Use /deploy-orchestration to define sub-projects and generate CLAUDE.md sections"
fi

# --- Install deploy.sh into project for future self-service updates ---
# After any install/update, leave a fresh copy of deploy.sh at
# .claude/scripts/deploy.sh so the /kit-update slash command (shipped via
# templates/commands/kit-update.md) can invoke it without requiring the
# orchestration-kit repo to be cloned locally. deploy.sh self-bootstraps
# templates from GitHub when templates/ is not next to it.
SOURCE_DIR="$SCRIPT_DIR"
if [ -n "${BOOTSTRAP_DIR:-}" ] && [ -d "${KIT_ROOT:-$BOOTSTRAP_DIR}" ] && [ -f "${KIT_ROOT:-$BOOTSTRAP_DIR}/deploy.sh" ]; then
    SOURCE_DIR="${KIT_ROOT:-$BOOTSTRAP_DIR}"
fi
if [ -f "$SOURCE_DIR/deploy.sh" ]; then
    mkdir -p "$TARGET/.claude/scripts"
    cp "$SOURCE_DIR/deploy.sh" "$TARGET/.claude/scripts/deploy.sh"
    chmod +x "$TARGET/.claude/scripts/deploy.sh"
    # Remove stale orch.sh wrapper if it was ever installed
    rm -f "$TARGET/.claude/scripts/orch.sh"
    log_ok "Installed .claude/scripts/deploy.sh (backend for /kit-update)"
fi

# --- Auto commit + push (only in --update-skills mode on git repos) ---
UPDATE_PUSHED=false
UPDATE_COMMIT_SHA=""
if [ "$UPDATE_MODE" = true ] && [ -d "$TARGET/.git" ]; then
    # KIT_SHA: from local repo if running from kit; else from remote ls-remote.
    if [ -d "$SCRIPT_DIR/.git" ]; then
        KIT_SHA=$(cd "$SCRIPT_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    elif [ -n "$BOOTSTRAP_DIR" ] && [ -d "${KIT_ROOT:-$BOOTSTRAP_DIR}/.git" ]; then
        KIT_SHA=$(cd "${KIT_ROOT:-$BOOTSTRAP_DIR}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        KIT_SHA=$(git ls-remote "https://github.com/${KIT_REPO}.git" "${KIT_REF}" 2>/dev/null | awk '{print $1}' | cut -c1-7 || echo "unknown")
    fi
    [ -z "$KIT_SHA" ] && KIT_SHA="unknown"
    (
        cd "$TARGET" || exit 1
        # Stage only kit-owned paths (never git add -A — user may have unrelated
        # uncommitted work that should not land in our auto-commit).
        git add .claude/agents .claude/skills .claude/references .claude/commands \
                .claude/hooks .claude/scripts .claude/.gitignore .claude/settings.json \
                AGENTS.md 2>/dev/null || true

        if git diff --cached --quiet; then
            log_info "No kit-content drift; nothing to commit."
            exit 10
        fi

        COMMIT_MSG="chore(orchestration): refresh kit content (kit ${KIT_SHA})

Auto-synced by: deploy.sh --update-skills from orchestration-kit ${KIT_SHA}

Paths refreshed:
- .claude/agents/             kit Claude agent roster
- ~/.codex/agents/            kit Codex worker roster (global)
- .claude/skills/             kit skills (directories with references/)
- .claude/commands/           kit slash commands
- .claude/references/         kit shared references
- .claude/hooks/              kit hooks (log-commands.sh etc.)
- .claude/.gitignore          audit-log exclusion
- .claude/settings.json       merged hooks
- AGENTS.md                   symlink to CLAUDE.md when CLAUDE.md exists

Custom files with non-kit names are preserved. settings.local.json,
orchestration-config.json, docs/orchestration/ untouched.

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
echo "  Claude agents: $AGENTS_COPIED"
echo "  Codex agents:  ${#CODEX_GLOBAL_AGENTS[@]} global"
echo "  Skills:        $SKILLS_COPIED + deploy-orchestration"
echo ""

if [ "$UPDATE_MODE" = true ]; then
echo "  What changed in this run:"
echo "    - .claude agents/, skills/ (with references/), commands/, hooks/, shared references/"
echo "    - ~/.codex/agents refreshed from kit's Codex worker roster"
echo "    - AGENTS.md points to CLAUDE.md when CLAUDE.md exists"
echo "    - settings.json hooks merged with kit's latest"
echo "    - orchestration-config.json left untouched"
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
echo "  Task discipline reference: see ~/.claude/skills/wf-gate/SKILL.md (global)"
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
