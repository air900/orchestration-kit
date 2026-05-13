#!/usr/bin/env bash
# Static validator for /delegate-with-context skill.
# Exit 0 -> green. Exit 1 -> at least one check failed (printed to stderr).

set -u
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
ERRORS=0

fail() { echo "FAIL: $*" >&2; ERRORS=$((ERRORS+1)); }
ok()   { echo "ok:   $*"; }

# 1. SKILL.md exists with valid frontmatter
SKILL_MD="$SKILL_DIR/SKILL.md"
if [ ! -f "$SKILL_MD" ]; then
  fail "SKILL.md missing"
else
  if ! head -1 "$SKILL_MD" | grep -q '^---$'; then
    fail "SKILL.md does not start with YAML frontmatter"
  else
    ok "SKILL.md present with frontmatter"
  fi
  for field in name description; do
    if ! grep -q "^$field:" "$SKILL_MD"; then
      fail "SKILL.md frontmatter missing '$field'"
    fi
  done
fi

# 2. Required reference files
REQUIRED_REFS=(
  status-contract.md
  context-bundle.md
  triviality-classifier.md
  doc-manifest.md
  prompt-implementer.md
  prompt-spec-reviewer.md
  prompt-code-reviewer.md
  prompt-doc-proposer.md
  prompt-doc-curator.md
  overlay-schema.md
)
for ref in "${REQUIRED_REFS[@]}"; do
  if [ ! -f "$SKILL_DIR/references/$ref" ]; then
    fail "references/$ref missing"
  else
    ok "references/$ref present"
  fi
done

# 3. Slash-shim
SHIM="$PROJECT_ROOT/.claude/commands/delegate-with-context.md"
if [ ! -f "$SHIM" ]; then
  fail "slash-shim .claude/commands/delegate-with-context.md missing"
else
  ok "slash-shim present"
fi

# 4. SKILL.md links to all required refs
if [ -f "$SKILL_MD" ]; then
  for ref in "${REQUIRED_REFS[@]}"; do
    if ! grep -q "references/$ref" "$SKILL_MD"; then
      fail "SKILL.md does not link to references/$ref"
    fi
  done
fi

# 5. status-contract.md has required YAML keys (Iron Law)
SC="$SKILL_DIR/references/status-contract.md"
if [ -f "$SC" ]; then
  for key in "status:" "verification:" "exit_code:" "stdout_tail:"; do
    if ! grep -q "$key" "$SC"; then
      fail "status-contract.md does not document key '$key'"
    fi
  done
fi

if [ "$ERRORS" -eq 0 ]; then
  echo ""
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo ""
  echo "$ERRORS check(s) failed"
  exit 1
fi
