#!/usr/bin/env bash
# PreToolUse hook for Bash: append every shell command Claude Code runs to a
# per-project audit log. Non-blocking (always exits 0) — pure observability.
#
# Log location: $CLAUDE_PROJECT_DIR/.claude/command-log.txt (gitignored).
# Rotate manually if it grows large; no automatic rotation by design.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
LOG_DIR="$PROJECT_DIR/.claude"
LOG_FILE="$LOG_DIR/command-log.txt"

mkdir -p "$LOG_DIR"

cmd=$(jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Collapse newlines in multi-line commands to keep one line per entry.
cmd_single=$(printf '%s' "$cmd" | tr '\n' ' ')

printf '%s\t%s\n' "$(date -Is)" "$cmd_single" >> "$LOG_FILE"

exit 0
