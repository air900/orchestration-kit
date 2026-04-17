#!/bin/bash
# orch.sh — unified orchestration-kit operations for a deployed project.
#
# After `curl .../install.sh | bash -s -- --update-deploy`, this script lives at
# <project>/.claude/scripts/orch.sh and is the single entry point for
# refreshing both kit content and user-installed external skills.
#
# Usage (run from anywhere inside the project):
#   .claude/scripts/orch.sh --update-skills
#   .claude/scripts/orch.sh --update-external-skills
#   .claude/scripts/orch.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# In a deployed project the layout is <project>/.claude/scripts/orch.sh, so the
# project root is two levels up. Fallback to the cwd if layout differs.
if [ -d "$SCRIPT_DIR/../../.claude" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
else
    PROJECT_ROOT="$(pwd)"
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[orch]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[orch]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[orch]${NC} $1"; }
log_error() { echo -e "${RED}[orch]${NC} $1" >&2; }

usage() {
    cat <<EOF
Usage: $0 --update-skills | --update-external-skills

  --update-skills            Refresh kit-shipped content (agents, skills,
                             commands, hooks, references). Invokes deploy.sh
                             which self-bootstraps templates from GitHub.
                             Auto commits + pushes on real drift.

  --update-external-skills   Refresh user-installed skills.sh skills
                             (tracked in skills-lock.json). Interactive
                             selection + GitHub stats. Auto commits + pushes
                             on real drift.

Environment overrides:
  ORCHESTRATION_KIT_REPO     Default: air900/orchestration-kit
  ORCHESTRATION_KIT_REF      Default: main
  GITHUB_TOKEN               Optional — raises GitHub API anon limit (60/hr)
                             to 5000/hr for --update-external-skills metadata.
EOF
}

MODE="${1:-}"

case "$MODE" in
    --update-skills)
        DEPLOY_SH="$SCRIPT_DIR/deploy.sh"
        if [ ! -x "$DEPLOY_SH" ]; then
            log_error "deploy.sh not found at $DEPLOY_SH."
            log_info "Run: curl -sSL https://raw.githubusercontent.com/\${ORCHESTRATION_KIT_REPO:-air900/orchestration-kit}/\${ORCHESTRATION_KIT_REF:-main}/install.sh | bash -s -- --update-deploy"
            exit 1
        fi
        log_info "→ kit content refresh (deploy.sh --update-skills)"
        exec "$DEPLOY_SH" "$PROJECT_ROOT" --update-skills
        ;;

    --update-external-skills)
        UPDATE_PY="$PROJECT_ROOT/.claude/skills/update-external-skills/scripts/update.py"
        if [ ! -f "$UPDATE_PY" ]; then
            log_error "update.py not found at $UPDATE_PY."
            log_info "Run '$0 --update-skills' first — the script is shipped with the kit."
            exit 1
        fi
        if ! command -v python3 &>/dev/null; then
            log_error "python3 is required for --update-external-skills."
            exit 1
        fi
        log_info "→ external skills refresh (update-external-skills/update.py)"
        cd "$PROJECT_ROOT"
        exec python3 "$UPDATE_PY"
        ;;

    -h|--help|"")
        usage
        exit 0
        ;;

    *)
        log_error "Unknown option: $MODE"
        echo ""
        usage
        exit 1
        ;;
esac
