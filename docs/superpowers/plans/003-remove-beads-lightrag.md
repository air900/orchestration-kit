---
name: 003-remove-beads-lightrag
title: Remove Beads & LightRAG implementation plan
date: 2026-05-13
spec: docs/superpowers/specs/003-remove-beads-lightrag-design.md
status: plan-in-progress
---

# Remove Beads & LightRAG Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Beads (operational memory) and LightRAG (KB) from orchestration-kit; preserve discipline (6-pt issue, 4-pt close, expert review, dispatch-with-context) in tracker-agnostic form. Leave `knowledge-harvest` skill untouched.

**Architecture:** Three sequenced stages — (A) deploy.sh + settings-hooks.json mechanical removal, (B) rewrite of `workflow-gate`, `workflow-gate-check` (Mode 3 → file-based handoff), `delegate-with-context` (drop Phase 8 LightRAG harvester), plus their references + `orchestration-config.json` getting a `handoff` path + the two slash-command files, (C) top-level README and deploy-orchestration SKILL.md rewritten to reflect 3-layer model. Each stage is independently reviewable and verifiable.

**Tech Stack:** Bash, JSON (jq merge logic), Markdown skills/commands, no runtime code.

## Contents

- [Conventions](#conventions)
- [File map](#file-map)
- [Stage 1 — Wire layer](#stage-1--wire-layer)
- [Stage 2 — Skills, commands, config](#stage-2--skills-commands-config)
- [Stage 3 — Top-level docs](#stage-3--top-level-docs)
- [Stage 4 — Cross-stage verification](#stage-4--cross-stage-verification)
- [Self-review checklist](#self-review-checklist)

---

## Conventions

**TDD analog for docs/config.** No runtime code in this plan. The TDD discipline maps to:
1. Run a `grep` for the pattern that *should* disappear → record baseline count.
2. Apply the edit.
3. Re-run the same `grep` → expected count after edit (usually zero in the target file, or only allowed contexts like `knowledge-harvest/`).
4. Smoke verification per stage (deploy fixture run, slash-command dry-run, README render).

**Commit cadence.** One commit per logical unit (one file or one tight cluster of related files within a stage). Conventional Commits style:

```
chore(deploy): drop beads plugin install + bd init from deploy.sh
chore(hooks): remove bd prime from SessionStart and PreCompact
refactor(workflow-gate): rewrite skill as tracker-agnostic task-discipline reference
refactor(workflow-gate-check): mode 3 persists handoff to docs/orchestration/handoff/
refactor(delegate-with-context): drop Phase 2 BEADS-RECONCILE and Phase 8 LightRAG harvester
refactor(commands): drop bd phrasing from workflow-gate, workflow-gate-check
chore(config): add handoff path to orchestration-config.json
docs(readme): 4-layer → 3-layer model; remove Beads tracking section
docs(skill): drop Beads block from generated CLAUDE.md template
```

**Baseline grep counts** (recorded at plan-writing time, 2026-05-13):

```
README.md:51         templates/skills/workflow-gate/SKILL.md:35
SKILL.md:14          templates/skills/workflow-gate-check/SKILL.md:49
deploy.sh:31         templates/skills/workflow-gate-check/references/mode-3-details.md:14
                     templates/skills/workflow-gate-check/references/mode-1-2-examples.md:9
                     templates/skills/workflow-gate-check/references/common-mistakes.md:3
                     templates/skills/delegate-with-context/SKILL.md:16
                     templates/skills/delegate-with-context/references/*.md (multiple, ~60 total)
                     templates/commands/workflow-gate.md:7
                     templates/commands/workflow-gate-check.md:6
                     templates/settings-hooks.json:3
```

Each task's verification step references these baselines.

**Branching.** Each stage commits to `main` directly (this repo's convention; no PR workflow per current commit history). If running through subagent-driven-development, use a feature branch per stage and merge after stage verification.

---

## File map

| Stage | File | Action |
|---|---|---|
| 1 | `deploy.sh` | EDIT (5 deletes + 2 rewrites) |
| 1 | `templates/settings-hooks.json` | EDIT (2 deletes + 1 echo rewrite) |
| 2A | `templates/skills/delegate-with-context/references/beads-reconcile.md` | DELETE |
| 2A | `templates/skills/delegate-with-context/references/prompt-knowledge-harvester.md` | DELETE |
| 2B | `templates/skills/workflow-gate/SKILL.md` | REWRITE |
| 2C | `templates/skills/workflow-gate-check/SKILL.md` | REWRITE (Part 1 reframe + Mode 3 file-based) |
| 2C | `templates/skills/workflow-gate-check/references/mode-3-details.md` | REWRITE (Gap→Action file-based) |
| 2C | `templates/skills/workflow-gate-check/references/mode-1-2-examples.md` | EDIT |
| 2C | `templates/skills/workflow-gate-check/references/common-mistakes.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/SKILL.md` | EDIT (Phase 2 + Phase 8 + Refs list) |
| 2D | `templates/skills/delegate-with-context/references/context-bundle.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/triviality-classifier.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/doc-manifest.md` | EDIT (auto-archive trigger schema) |
| 2D | `templates/skills/delegate-with-context/references/status-contract.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/prompt-implementer.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/prompt-spec-reviewer.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/prompt-code-reviewer.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/prompt-doc-proposer.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/prompt-doc-curator.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/references/overlay-schema.md` | EDIT |
| 2D | `templates/skills/delegate-with-context/validate.sh` | EDIT |
| 2E | `templates/commands/workflow-gate.md` | REWRITE |
| 2E | `templates/commands/workflow-gate-check.md` | EDIT |
| 2E | `templates/orchestration-config.json` | EDIT (+handoff path) |
| 3 | `README.md` | REWRITE |
| 3 | `SKILL.md` (top-level, deploy-orchestration) | REWRITE |
| 3 | `README.md` | EDIT (append migration subsection) |

---

## Stage 1 — Wire layer

Mechanical removals. No behavioural rewrites. Reviewer should be able to diff and approve in 5 min.

### Task 1: Drop Beads plugin install from `deploy.sh`

**Files:** Modify `deploy.sh:153-164`

- [ ] **Step 1: Baseline grep**

```bash
grep -nE 'beads|@beads/bd|bd init|bd prime' deploy.sh | wc -l
```

Expected: ~31 matches.

- [ ] **Step 2: Read the block to delete (sanity check)**

Read `deploy.sh:153-164` — confirm it's the "Beads (recommended)" plugin block inside the `if command -v claude &>/dev/null` branch.

- [ ] **Step 3: Apply edit — delete the block**

Replace the 12-line block (L153-164) with a single blank line. The Template Bridge block above and the closing comments below are preserved.

Old:
```bash
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
```

New: (the block is removed entirely — leave a single blank line)

- [ ] **Step 4: Verify post-edit**

```bash
grep -n 'Beads plugin' deploy.sh
```

Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add deploy.sh
git commit -m "chore(deploy): drop beads plugin install block"
```

---

### Task 2: Drop beads hint from "claude CLI not found" branch

**Files:** Modify `deploy.sh:179-184`

- [ ] **Step 1: Locate**

Read `deploy.sh:178-184`. The two lines starting with `echo "  claude plugin marketplace add steveyegge/beads ...` are the targets.

- [ ] **Step 2: Apply edit**

Old:
```bash
  else
    log_warn "claude CLI not found — install plugins manually after setup:"
    echo "  claude plugin install superpowers"
    echo "  claude plugin marketplace add steveyegge/beads && claude plugin install beads"
    echo "  claude plugin marketplace add maslennikov-ig/template-bridge && claude plugin install template-bridge"
    echo ""
  fi
```

New:
```bash
  else
    log_warn "claude CLI not found — install plugins manually after setup:"
    echo "  claude plugin install superpowers"
    echo "  claude plugin marketplace add maslennikov-ig/template-bridge && claude plugin install template-bridge"
    echo ""
  fi
```

- [ ] **Step 3: Verify**

```bash
grep -n 'beads' deploy.sh
```

Expected: no matches in the now-deleted hint line.

- [ ] **Step 4: Commit**

```bash
git add deploy.sh
git commit -m "chore(deploy): drop beads hint from claude-cli-missing branch"
```

---

### Task 3: Drop `bd` CLI install block from `deploy.sh`

**Files:** Modify `deploy.sh:187-202`

- [ ] **Step 1: Locate**

Lines 187-202: `# --- Check & install bd CLI ...` through the closing `fi`. Includes the global state variable `HAS_BD`.

- [ ] **Step 2: Apply edit**

Delete the entire block (16 lines). Also delete every later reference to `HAS_BD` in the file. Confirm references via:

```bash
grep -n 'HAS_BD' deploy.sh
```

Expected (before edit): 5-6 references.

Each reference (`HAS_BD=true`, `[ "$HAS_BD" = true ]`, `[ "$HAS_BD" = false ]`, etc.) is part of the bd init block we will remove in Task 4. Confirm no other code depends on `HAS_BD` before deletion.

- [ ] **Step 3: Verify partial state**

```bash
grep -n 'HAS_BD\|bd CLI' deploy.sh
```

Expected: only matches inside the `bd init` block (lines ~432-444), which Task 4 will remove.

- [ ] **Step 4: Commit**

```bash
git add deploy.sh
git commit -m "chore(deploy): drop bd CLI install block + HAS_BD state variable"
```

---

### Task 4: Drop `bd init` block from `deploy.sh`

**Files:** Modify `deploy.sh:432-444`

- [ ] **Step 1: Locate**

Lines 432-444: `# --- Initialize Beads ... --- end` block, wrapping `(cd "$TARGET" && bd init ...)`.

- [ ] **Step 2: Apply edit**

Delete the entire block (13 lines). Also remove any straggler logging line that references "Beads" earlier in `deploy.sh` summary output.

- [ ] **Step 3: Verify**

```bash
grep -nE '\bbd \b|bd init|bd prime|@beads/bd' deploy.sh
```

Expected: 0 matches.

- [ ] **Step 4: Smoke check**

```bash
bash -n deploy.sh
```

Expected: exit 0 (syntax valid).

- [ ] **Step 5: Commit**

```bash
git add deploy.sh
git commit -m "chore(deploy): drop bd init invocation from post-copy phase"
```

---

### Task 5: Rewrite `deploy.sh` summary block

**Files:** Modify `deploy.sh:602` and surrounding context (around `# --- Summary ---` to end-of-file).

- [ ] **Step 1: Locate**

Find the `# --- Summary ---` section near EOF. There are at least two Beads mentions:
- `"  Beads:        committed ..."` line in UPDATE_MODE summary
- `"  Beads tracks tasks across sessions ..."` line in install-mode summary
- `".beads/ left untouched"` line in what-changed list

- [ ] **Step 2: Apply edits**

Replace `"  Beads tracks tasks across sessions (bd ready, bd create)."` with a blank line or with a new line referencing the task-discipline reference skill.

New:
```bash
echo "  Task discipline reference: see .claude/skills/workflow-gate/SKILL.md"
```

Replace `"    - orchestration-config.json and .beads/ left untouched"` with:
```bash
echo "    - orchestration-config.json left untouched"
```

- [ ] **Step 3: Verify**

```bash
grep -nE 'beads|@beads/bd|bd init|bd prime|bd ready|bd create' deploy.sh
```

Expected: 0 matches.

```bash
bash -n deploy.sh
```

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add deploy.sh
git commit -m "chore(deploy): purge beads references from summary block"
```

---

### Task 6: Strip `bd prime` from `settings-hooks.json`

**Files:** Modify `templates/settings-hooks.json`

- [ ] **Step 1: Baseline**

```bash
grep -nE 'bd prime|PreCompact' templates/settings-hooks.json
```

Expected: 3 matches (SessionStart bd prime, PreCompact section header, PreCompact bd prime).

- [ ] **Step 2: Apply edit — full file replacement**

New content for `templates/settings-hooks.json`:

```json
{
  "permissions": {
    "allow": []
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash(rm -rf*|git push --force*|git reset --hard*)",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Destructive command detected. Verify this is intentional.' >&2; exit 2"
          }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PROJECT_DIR:-.}/.claude/hooks/log-commands.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Workflow: /workflow-gate <task> (delegates to template-bridge:unified-workflow). Task discipline: workflow-gate skill. Verification: superpowers:verification-before-completion (Iron Law).'"
          }
        ]
      }
    ]
  }
}
```

Changes versus baseline:
- SessionStart loses the `bd prime` command (keeps the echo, with "Beads discipline" wording → "Task discipline").
- PreCompact entire section removed.

- [ ] **Step 3: Verify**

```bash
jq . templates/settings-hooks.json
```

Expected: pretty-print succeeds (no JSON syntax errors).

```bash
grep -nE 'bd prime|PreCompact|Beads' templates/settings-hooks.json
```

Expected: 0 matches.

- [ ] **Step 4: Commit**

```bash
git add templates/settings-hooks.json
git commit -m "chore(hooks): remove bd prime from SessionStart; drop PreCompact"
```

---

### Task 7: Audit `deploy.sh` `--update-skills` behaviour for stale hooks (Open Q1 decision)

**Files:** Read `deploy.sh:398-428` (jq merge block).

- [ ] **Step 1: Read the jq merge logic**

The current `jq` block merges hooks by:
```
group_by(.matcher) | map(last)
```
This keeps the LAST entry per matcher. If the kit no longer ships a `PreCompact` hook, the target's existing `PreCompact` hook stays (it's not in the new shipment, so the group is "old only" and persists).

- [ ] **Step 2: Decision**

The plan adopts the **document-only mitigation** per the spec's Open Question #1 recommendation: existing targets keep their stale `bd prime` hooks until users hand-edit `settings.json` or wipe-and-redeploy. Active jq-side removal is out of scope; it requires a non-trivial schema change (e.g., kit-owned marker on each hook entry).

- [ ] **Step 3: Record the decision**

Add a note to README's migration subsection (handled in Stage 3, Task 30): "Existing deployments: `bd prime` lines in `.claude/settings.json` are not auto-removed by `/kit-update --update-skills`; remove them manually if you no longer use Beads."

No file edit in this task. The decision is recorded; documentation lands in Stage 3.

- [ ] **Step 4: No commit (placeholder for migration note)**

---

### Stage 1 verification

- [ ] **Step 1: Fixture deploy**

```bash
rm -rf /tmp/fixture-prj && mkdir -p /tmp/fixture-prj && (cd /tmp/fixture-prj && git init --quiet)
./deploy.sh /tmp/fixture-prj atomic 2>&1 | tee /tmp/deploy-stage1.log
```

Expected in `/tmp/deploy-stage1.log`: NO occurrence of "Beads", "@beads/bd", "bd init". Exit 0.

- [ ] **Step 2: Settings inspect**

```bash
jq '.hooks | keys' /tmp/fixture-prj/.claude/settings.json
```

Expected: `["PreToolUse", "SessionStart"]` (no PreCompact).

```bash
jq '.hooks.SessionStart[0].hooks | map(.command) | .[]' /tmp/fixture-prj/.claude/settings.json
```

Expected: only the echo command (no `bd prime`).

- [ ] **Step 3: Repo grep**

```bash
grep -rnE '\bbd \b|@beads/bd|bd init|bd prime' deploy.sh templates/settings-hooks.json
```

Expected: 0 matches.

- [ ] **Step 4: Mark Stage 1 done**

If all three steps pass, Stage 1 is complete. Move to Stage 2.

---

## Stage 2 — Skills, commands, config

Stage 2 splits into five sub-stages (A → E) for review focus.

### Stage 2A — Pure deletes

#### Task 8: Delete `references/beads-reconcile.md`

**Files:** Delete `templates/skills/delegate-with-context/references/beads-reconcile.md`

- [ ] **Step 1: Confirm no other file references this path**

```bash
grep -rn 'beads-reconcile' templates/ docs/ README.md SKILL.md
```

Expected: only the one reference inside `templates/skills/delegate-with-context/SKILL.md` (which Stage 2D will rewrite).

- [ ] **Step 2: Delete**

```bash
git rm templates/skills/delegate-with-context/references/beads-reconcile.md
```

- [ ] **Step 3: Commit (defer until Task 9 done to keep Stage 2A atomic)**

#### Task 9: Delete `references/prompt-knowledge-harvester.md`

**Files:** Delete `templates/skills/delegate-with-context/references/prompt-knowledge-harvester.md`

- [ ] **Step 1: Confirm no external references**

```bash
grep -rn 'prompt-knowledge-harvester' templates/ docs/ README.md SKILL.md
```

Expected: only `templates/skills/delegate-with-context/SKILL.md` (Stage 2D rewrite).

- [ ] **Step 2: Delete**

```bash
git rm templates/skills/delegate-with-context/references/prompt-knowledge-harvester.md
```

- [ ] **Step 3: Commit (atomic with Task 8)**

```bash
git commit -m "refactor(delegate-with-context): drop beads-reconcile + LightRAG harvester reference files"
```

---

### Stage 2B — `workflow-gate` skill rewrite

#### Task 10: Rewrite `templates/skills/workflow-gate/SKILL.md`

**Files:** Modify `templates/skills/workflow-gate/SKILL.md` (full rewrite)

- [ ] **Step 1: Baseline**

```bash
wc -l templates/skills/workflow-gate/SKILL.md
grep -cE '\bbd \b|beads' templates/skills/workflow-gate/SKILL.md
```

Expected: 226 lines, ~35 matches.

- [ ] **Step 2: Write new content**

Replace the entire file with:

````markdown
---
name: workflow-gate
description: >
  Tracker-agnostic task-discipline reference: 6-point task description, 4-point
  close reason with verification evidence, commit conventions, land-the-plane
  habits. The discipline is independent of any specific tracker (GitHub issues,
  Linear, plain commit messages, project-local task files) — apply the templates
  wherever your project records tasks. Orchestration of the dev loop is the
  responsibility of slash-command `/workflow-gate` (delegates to
  `template-bridge:unified-workflow`); this skill is the reference manual that
  the controller and reviewers consult.
  TRIGGER: Consult this skill whenever creating or closing a task in your
  project's tracker, or whenever uncertain about task-description quality
  standards.
---

# Workflow Gate

**Role:** Reference for task-discipline in any project.
**Orchestration:** handled by slash-command `/workflow-gate` (delegates to
`template-bridge:unified-workflow`). This skill does NOT orchestrate; it
documents the quality standards that apply to any workflow.

**There is no marker file, no unlock mechanism, no Edit/Write hook block.**
Those were removed in the D1 redesign (see spec
`docs/superpowers/specs/2026-04-14-workflow-gate-d1-design.md`).

---

## Phase 2: Issue Creation — Quality Standard

A task description is the project's memory of *why* this work exists. It must
carry enough context that **another session, with no access to the current
conversation,** can pick up the work without re-derivation.

### Where the description lives

The same 6-point template applies wherever your project tracks tasks. Common
homes:

- A dedicated issue tracker (GitHub Issues, Linear, Jira, GitLab, Bitbucket)
- A project-local `docs/orchestration/issues/` file (configurable via
  `orchestration-config.json` → `documentation.paths.issues`)
- A pull-request body when work is small enough that "the PR is the task"
- A commit message body for trivial one-shot changes

Pick the tracker that already exists in the project. **Do not invent a new
tracker just because the kit does not ship one.** The skill is deliberately
tracker-neutral.

### Description — 6 required points — WRITE IN ENGLISH

**Language rule:** task descriptions, notes, and close reasons should be
written in English for token efficiency. The agent communicates with the user
in their language; written tracker artefacts go in English.

1. **What's broken / what's needed** — concrete behaviour, not abstraction
2. **Where in code** — file, function, line range (`tree.js:2420, compact()`)
3. **How to reproduce** — inputs, URL, parameters (`pid=7 tmode=5`)
4. **What's already known** — root cause candidates, approaches rejected
5. **Context link** — why this task emerged, what surfaced the problem
6. **Resources** — everything the next session will need:
   - Code files with line numbers (`src/tree.js:1840-1870`)
   - Specs / docs (`docs/line-spec.md §4.5`)
   - Screenshots (`assets/screenshots/overlap-pid7.png`)
   - Test data, configs
   - External links (GitHub issues, articles, specs)

**Bad:** `"Fix bond-drop crossing"`

**Good:**
```
Bond-drop (grey bio line) crosses ⊔ former connector crossbar.
Root cause: _dropOff() in tree.js:1850 doesn't check ⊔ connectors.
Visible on pid=7 tmode=5, pair 35+34.
Found during GENP=140 testing — was hidden at GENP=100.

Resources:
- Code: src/plugins/drevo-zhizni-web/assets/js/tree.js:1840-1870
- Spec: docs/drevo-zhizni-web/line-spec.md §4.3
- Screenshot: assets/drevo-zhizni-web/images/overlap-pid7-tmode5.png
- Related: prior issue tracking the dynamic-gap parent task
```

### Side findings — link provenance

When you discover a bug while working on a different task:

- If you use a tracker with link types (GitHub issues, Linear) — open a new
  task and link it with whatever the tracker calls `discovered-from`.
- If you use plain commit/PR-body tasks — reference the originating PR or
  commit SHA in the new task's description, in a single line like
  `Discovered during: PR #123 (commit abc1234)`.

The point is a provenance chain so future-you understands *how* the bug
surfaced.

---

## Phase 3: During Work

### Notes — update IMMEDIATELY

Whenever you discover a new fact, write it down in the task's notes/comments
field (or append it to the task file in `docs/orchestration/issues/`). Do
NOT batch findings until the end of the session — context loss between
discovery and recording is a leading cause of forgotten work.

Example note:
```
FINDING: compact() at line 2420 ignores spouse gap. Tested on pid=5,7,213.
```

### Remember — persistent memory

When a pattern, convention, or gotcha emerges that future sessions in this
project must respect, persist it. Two practical homes:

- `CLAUDE.md` in the project root — for project-wide conventions.
- A dedicated `docs/orchestration/conventions.md` (or per-component
  `README.md`) — for narrower scope.

Examples:
```
test-pattern: all tree layout tests use pid=5 tmode=2 as baseline
convention: DREVO_VERSION bumped on every visual change
gotcha: _formerSlot and gOffset go in opposite directions — never mix
```

### Commits — include task ID

Always include the task identifier in the commit message subject line:

```
git commit -m "Fix spacing for 4+ children (issue-123)"
```

This lets reviewers (and the `delegate-with-context` doc-curator) trace each
commit back to its driving task.

---

## Phase 4: Closing — Quality Standard

The close reason is what future maintainers read when revisiting why a
defect was fixed in a particular way. It belongs in:

- The tracker's close comment, OR
- The PR body for the merging change, OR
- The commit message body for direct-to-trunk fixes.

### Reason — 4 required points

1. **Solution** — what was concretely done (1-2 sentences)
2. **Root cause** — why the defect existed
3. **Prevention** — what will stop it from recurring (test, rule, check)
4. **Verification** — concrete artefacts from `superpowers:verification-before-completion`:
   - Test command + snapshot of its output (fresh, run in this session)
   - Screenshot paths (mandatory for UI changes)
   - Before/after evidence for bug fixes
   - "Tested — works" WITHOUT artefacts is an invalid reason. Rewrite.

**Bad:** `"Fixed"` — no points

**Bad:** `"Fix + tested"` — no root cause, prevention, or concrete evidence

**Good:**
```
1. Added expandRowGaps() post-pass after allocateCombSlots().
2. Root cause: GENP was fixed and didn't account for the number of combs in the gap.
3. Prevention: expandRowGaps() now dynamically widens rows — for any new connector,
   confirm its height is accounted for in the deficit calculation.
4. Verification:
   - node tests/channel-integrity-full.js → COMB-COLLISION: 0 (was 30)
   - Playwright pid=5,7,213 tmode=5 at 1920x1080:
     assets/screenshots/2026-04-14-after-comb-*.png (visual OK)
   - Full sweep 261 pids: no regression in LINE-CARD-CROSSING/CARD-OVERLAP.
```

---

## Phase 5: Session End — "Land the Plane"

The session is NOT complete until ALL of these are done:

1. **Open tasks** — update notes/comments with current status:
   ```
   PROGRESS: steps 1-3 done. NEXT: step 4 (refactor drawBond). BLOCKED BY: nothing.
   ```

2. **Side findings** — file them as new tasks with provenance link

3. **Memory** — persist conventions to CLAUDE.md or `docs/orchestration/conventions.md`

4. **Git** — clean state:
   ```bash
   git pull --rebase && git push
   ```

---

## Rules

- ALWAYS write rich descriptions — they are the project's memory
- ALWAYS write task artefacts (descriptions, notes, close reasons, conventions) in English — token efficiency
- ALWAYS update notes immediately — don't batch
- ALWAYS include the task ID in commit messages
- ALWAYS "land the plane" before session end — notes, git push
- NEVER claim "done" without verification artefacts (Iron Law from `superpowers:verification-before-completion`)
````

- [ ] **Step 3: Verify**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate/SKILL.md
```

Expected: 0 matches.

```bash
wc -l templates/skills/workflow-gate/SKILL.md
```

Expected: ~150 lines (down from 226).

- [ ] **Step 4: Commit**

```bash
git add templates/skills/workflow-gate/SKILL.md
git commit -m "refactor(workflow-gate): rewrite as tracker-agnostic task-discipline reference"
```

---

### Stage 2C — `workflow-gate-check` rewrite (Mode 3 file-based)

#### Task 11: Rewrite `templates/skills/workflow-gate-check/SKILL.md`

**Files:** Modify `templates/skills/workflow-gate-check/SKILL.md` (large refactor)

This is the most intricate edit in the plan. The skill has Part 1 (compliance), Part 2 (judgement), Part 3 (handoff). Beads coupling is in:

- Part 1 section A (description quality) — references "Beads issue" → rename "task description"
- Part 1 section B (close reason) — references `bd close` → rename "PR/commit close note"
- Part 1 section D — `bd remember` → "persisted to CLAUDE.md or conventions doc"
- Part 1 section F — bd-related notes → "task tracker notes"
- Part 3 — `bd update/decision/remember` → file persistence (`docs/orchestration/handoff/NNN-<topic>-handoff.md`)
- Verdict tables — "bd close" → "close the task"
- Output templates — `bd-id` placeholders → "task-id"
- Troubleshooting — "No Beads issue" → "No task record"

- [ ] **Step 1: Baseline**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/SKILL.md
```

Expected: ~49 matches.

- [ ] **Step 2: Apply targeted edits**

The edit is too large to write inline; the executor uses sed-style targeted replacements plus structural rewrites. Concrete substitutions (apply each globally inside this file only):

```
Beads issue              → task record
bd show <id>             → read the task record
bd show <id> --json      → read the task record
bd update <id> --notes   → append a note to the task record
bd update <id> --description → update the task record's description
bd close <id> --reason   → write the close note (PR body, commit body, or task tracker close)
bd close                 → close the task
bd decision              → append a decision to docs/orchestration/handoff/NNN-<topic>-handoff.md
bd remember              → persist to CLAUDE.md or docs/orchestration/conventions.md
bd-id / bd ID / <bd-id>  → task-id
discovered-from          → discovered-from (link or "Discovered during:" line in description)
.beads/                  → task tracker state (e.g., GitHub issues, docs/orchestration/issues/)
bd doctor                → run your tracker's hygiene check, or skip if N/A
No Beads issue for the task → No task record for the task
```

For the **Part 3 (Mode 3) rewrite**, replace the entire "Part 3 — Handoff enrichment" section with a file-based version. The new Mode 3 produces:

```
docs/orchestration/handoff/NNN-<session-topic>-handoff.md
```

containing sections:

- **Session topic** (one sentence)
- **Just-closed work** (commit SHAs + brief description)
- **Related open tasks** (list IDs, file paths, or PR numbers — whatever the project's tracker exposes)
- **Volatile state preserved** (S1 artefacts; for each, where it now lives in the repo)
- **Decisions recorded** (S2; rationale + alternatives rejected — persist as committed file in the handoff doc itself)
- **Implicit mappings captured** (S3; tables, lists, lattices)
- **Discovered constraints** (S4; runtime invariants, brand-voice rules, infra ordering)
- **External references** (S5; URLs added to task records or this file)
- **Handoff summary for next session** (2-3 sentences)

The Gap → Action table (Phase 2 in current Mode 3) is replaced by:

| Gap | Action |
|---|---|
| Missing Resources in a related task | Edit the task record's description; if no record exists, create one with the 6-point template |
| `S1` volatile artefact | Commit to project's artefact path (use `orchestration-config.json` paths or auto-detect: `tests/fixtures/` for code, `assets/research/` for content, `docs/runbooks/` for infra). Link from the handoff file. |
| `S2` design decision | Append a `### Decision: <id> — <choice>` block to the handoff file with rationale + rejected alternatives |
| `S3` implicit mapping (short) | Append a `### Mapping: <topic>` block to the handoff file; if mapping is large (>20 lines), commit it as a separate file under `docs/orchestration/handoff/NNN-<topic>-<subtopic>.md` |
| `S4` discovered constraint (per-task) | Append a "CONSTRAINT:" note in the related task record; if cross-session pattern, ALSO append to CLAUDE.md or `docs/orchestration/conventions.md` |
| `S5` external reference | Add the URL to the related task record's Resources list AND to the handoff file's External references section |

The **Phase 3 Apply order** becomes:
1. Commit artefacts (files) — Stage them with `git add` + `git commit`.
2. Write the handoff file itself (`docs/orchestration/handoff/NNN-...-handoff.md`).
3. Edit related task records to add cross-links to the handoff file.
4. Update CLAUDE.md / `conventions.md` for cross-session patterns.

The **Phase 0 scope criterion** stays the same conceptually but adapts:
- (a) Graph-adjacent — for projects using `discovered-from`-style links in their tracker, or `Discovered during: PR #X` lines in descriptions.
- (b) Resource overlap — unchanged.
- (c) Created during this session — adapt to "new task records created this session in the project's tracker or in `docs/orchestration/issues/`".
- (d) Keyword/label match — unchanged.

- [ ] **Step 3: Verify**

```bash
grep -cE '\bbd \b|beads|@beads/bd' templates/skills/workflow-gate-check/SKILL.md
```

Expected: 0 matches.

```bash
grep -c 'task record\|handoff file\|handoff doc' templates/skills/workflow-gate-check/SKILL.md
```

Expected: ≥10 matches (confirms replacements landed).

- [ ] **Step 4: Smoke check section coherence**

Open the file in a viewer. Scan headings — Part 1 → Part 2 → Part 3 → Verdict → Output template. Confirm:
- Mode 1 still references `task record close note`
- Mode 2 unchanged
- Mode 3 path mentions `docs/orchestration/handoff/`
- Verdict table uses `task close` not `bd close`

- [ ] **Step 5: Commit**

```bash
git add templates/skills/workflow-gate-check/SKILL.md
git commit -m "refactor(workflow-gate-check): rewrite Mode 3 to file-based handoff; tracker-agnostic Part 1"
```

#### Task 12: Rewrite `references/mode-3-details.md`

**Files:** Modify `templates/skills/workflow-gate-check/references/mode-3-details.md`

- [ ] **Step 1: Baseline**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/mode-3-details.md
```

Expected: ~14 matches.

- [ ] **Step 2: Apply edits**

Apply the same substitution table as Task 11 Step 2 globally within this file. Additionally:

- Convert the example "Phase 2 plan" snippets (lines 73-75 currently using `bd decision "29j Option C …"`) to new format:
  ```
  - commit smoke fixtures: tests/fixtures/aob/smoke-*.php
  - append to handoff file: ### Decision: aob-option-c — chose C because [rationale]; rejected A (reason), B (reason)
  - edit task record (aob) description to cross-link the handoff file
  ```
- Replace persistence-path table content for `S1` to retain auto-detect logic but reference `orchestration-config.json` `documentation.paths` as a source of truth.

- [ ] **Step 3: Verify**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/mode-3-details.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit**

```bash
git add templates/skills/workflow-gate-check/references/mode-3-details.md
git commit -m "refactor(workflow-gate-check): rewrite mode-3-details for file-based handoff"
```

#### Task 13: Edit `references/mode-1-2-examples.md`

**Files:** Modify `templates/skills/workflow-gate-check/references/mode-1-2-examples.md`

- [ ] **Step 1: Baseline**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/mode-1-2-examples.md
```

Expected: ~9 matches.

- [ ] **Step 2: Targeted edits**

Apply the Task 11 substitution table. Specifically:
- Lines 14, 72, 75-76: `bd close gxu7 --claim-next` → `close the task (e.g., "Closes #gxu7" in commit body)`; `bd update gxu7 --notes` → `append note to task gxu7`.
- Lines 149, 161, 173, 185: `bd show description` → `Task gxu7 description`.

- [ ] **Step 3: Verify**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/mode-1-2-examples.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit**

```bash
git add templates/skills/workflow-gate-check/references/mode-1-2-examples.md
git commit -m "refactor(workflow-gate-check): drop bd phrasing from examples"
```

#### Task 14: Edit `references/common-mistakes.md`

**Files:** Modify `templates/skills/workflow-gate-check/references/common-mistakes.md`

- [ ] **Step 1: Baseline**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/common-mistakes.md
```

Expected: ~3 matches (lines 30, 31, 34).

- [ ] **Step 2: Apply**

- Line 30: `bd notes` → `task notes/comments`
- Line 31: `bd decision` → `decision block in handoff file`
- Line 34: `bd update / bd decision / git commit` → `task edits / handoff-file edits / git commit`

- [ ] **Step 3: Verify**

```bash
grep -cE '\bbd \b|beads' templates/skills/workflow-gate-check/references/common-mistakes.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit**

```bash
git add templates/skills/workflow-gate-check/references/common-mistakes.md
git commit -m "refactor(workflow-gate-check): drop bd phrasing from common-mistakes"
```

---

### Stage 2D — `delegate-with-context` updates

#### Task 15: Edit `templates/skills/delegate-with-context/SKILL.md`

**Files:** Modify `templates/skills/delegate-with-context/SKILL.md`

- [ ] **Step 1: Baseline**

```bash
grep -cE 'beads|BEADS|lightrag|LightRAG' templates/skills/delegate-with-context/SKILL.md
```

Expected: ~16 matches.

- [ ] **Step 2: Apply edits**

Three structural changes:

**A. Phase 2 rename.** Replace the entire `### Phase 2 — BEADS-RECONCILE` section with:

```markdown
### Phase 2 — SPEC-DISTILL

The distilled task spec (Phase 1) is now the single source of truth for the
dispatch. Persist it in the chat context only; do not write it to disk in
this phase. If the project happens to use an external tracker, the architect
may, after Phase 9 completes, add a link to the closed PR or commits — that
is a manual step, not part of this skill.

If the project ships a dedicated `docs/orchestration/issues/` directory
(per `orchestration-config.json`) AND the dispatch results in a non-trivial
multi-commit change, the doc-curator subagent in Phase 8 may propose a new
file there. Do not pre-emptively create one in Phase 2.
```

**B. Phase 8 — drop knowledge-harvester.** Replace the Phase 8 section's three-subagent dispatch with a two-subagent dispatch:

```markdown
### Phase 8 — END-OF-RUN PIPELINE (parallel)

Single tool-call with two concurrent `Agent()` invocations:

- doc-proposer subagent — [`references/prompt-doc-proposer.md`](references/prompt-doc-proposer.md) — edits to existing doc CONTENT
- doc-curator subagent — [`references/prompt-doc-curator.md`](references/prompt-doc-curator.md) — edits to manifest STRUCTURE (add/archive/restructure entries; bootstrap if missing)

Both return summaries (no raw diffs). Proposer and curator proposals are stored for architect review in Phase 9.

The two subagents are independent: proposer touches `*.md` content, curator touches `docs/MANIFEST.md` structure. No shared state.
```

**C. References list.** Remove the lines referring to `beads-reconcile.md` and `prompt-knowledge-harvester.md` from the References section near EOF. Adjust ordering of remaining entries.

**D. Other bd mentions.** Apply the substitution table from Task 11 to remaining occurrences (e.g., "If `.beads/` is not present" in Phase 2 disappears entirely with the rename; "the controller pulls bd context" → "the controller pulls task context").

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|BEADS|lightrag|LightRAG|knowledge-harvester' templates/skills/delegate-with-context/SKILL.md
```

Expected: 0 matches.

```bash
grep -c 'SPEC-DISTILL\|doc-proposer\|doc-curator' templates/skills/delegate-with-context/SKILL.md
```

Expected: ≥3 each.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 16: Edit `references/context-bundle.md`

**Files:** Modify `templates/skills/delegate-with-context/references/context-bundle.md`

- [ ] **Step 1: Baseline**

```bash
grep -nE 'beads|\bbd ' templates/skills/delegate-with-context/references/context-bundle.md
```

Expected: 3 matches (lines 30, 65, 73).

- [ ] **Step 2: Apply edits**

- Line 30: `from \`bd show\`` → `from the task spec / linked task record`
- Line 65: `\`bd close <id> --reason="..."\`` → `Close the task: commit message body OR PR description OR tracker close-comment carrying the 4-point reason`
- Line 73: `full \`bd list\` dumps` → `full tracker-state dumps`

Also remove the "Beads issue body" template variable (if present in any subsection) — replace with "Task spec body". Verify by reading the full file post-edit.

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/context-bundle.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 17: Edit `references/triviality-classifier.md`

**Files:** Modify `templates/skills/delegate-with-context/references/triviality-classifier.md:14`

- [ ] **Step 1: Locate**

Line 14 contains: `| Beads issue is \`--type epic\` OR \`priority ≤ 1\` | \`bd show\` | by policy — gate required |`

- [ ] **Step 2: Apply edit**

Delete that table row. The "Generic signals" table loses one entry. The non-trivial classification can still be driven by the remaining signals (file count, public API, doc touches, etc.).

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/triviality-classifier.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 18: Edit `references/doc-manifest.md`

**Files:** Modify `templates/skills/delegate-with-context/references/doc-manifest.md:133-140`

- [ ] **Step 1: Locate**

Lines 133-140 describe the `spec-in-progress` / `plan-in-progress` schema referencing a bd ID for auto-archive.

- [ ] **Step 2: Apply edit**

Old:
```
For `spec-in-progress` and `plan-in-progress`, the next indented line carries the bd ID it belongs to (so the curator can detect when to auto-archive):

[example with bd ID]

When that bd is closed AND a result artifact appears (runbook / research / new doc cross-referenced from commits), the curator proposes:
```

New:
```
For `spec-in-progress` and `plan-in-progress`, the linked spec/plan file's own front-matter carries a `status:` field (`spec-in-progress`, `plan-in-progress`, `done`). When the curator runs and the front-matter is `done` AND a result artifact appears (runbook / research / new doc cross-referenced from commits), the curator proposes:
```

Adjust the indented example accordingly (replace bd ID with a relative path to the spec file).

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/doc-manifest.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 19: Edit `references/status-contract.md`

**Files:** Modify `templates/skills/delegate-with-context/references/status-contract.md:117`

- [ ] **Step 1: Apply edit**

Old:
```
detail: spec asks to refactor anamnesis pipeline + add new endpoint + migrate DB schema in one pass; recommend split into 3 sub-tasks via bd dep add ... --type discovered-from
```

New:
```
detail: spec asks to refactor anamnesis pipeline + add new endpoint + migrate DB schema in one pass; recommend split into 3 sub-tasks tracked separately (in your tracker or as new files under docs/orchestration/issues/)
```

- [ ] **Step 2: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/status-contract.md
```

Expected: 0 matches.

- [ ] **Step 3: Commit (defer to Task 22)**

#### Task 20: Edit small reference files

**Files:** Modify `prompt-implementer.md`, `prompt-spec-reviewer.md`, `prompt-code-reviewer.md`, `prompt-doc-proposer.md`, `overlay-schema.md`

- [ ] **Step 1: Batch grep**

```bash
grep -nE 'beads|\bbd ' templates/skills/delegate-with-context/references/prompt-implementer.md templates/skills/delegate-with-context/references/prompt-spec-reviewer.md templates/skills/delegate-with-context/references/prompt-code-reviewer.md templates/skills/delegate-with-context/references/prompt-doc-proposer.md templates/skills/delegate-with-context/references/overlay-schema.md
```

Expected total: ~10 matches (mostly placeholder template variables like `{{BEADS_ISSUE_BODY}}` and one-line `bd dep add` mentions).

- [ ] **Step 2: Apply edits**

For each file, rename template variables:
- `{{BEADS_ISSUE_BODY}}` → `{{TASK_SPEC_BODY}}`
- `{{BEADS_ISSUE_ID}}` → `{{TASK_ID}}` (if present)

Remove any `bd dep add` / `bd notes` example lines, replacing with "(record in your tracker / task file)" placeholder.

For `overlay-schema.md`: remove any `bd_type_epic` / `bd_priority_le_1` signal keys if present (per spec Stage 2 plan). Their associated rows in any example overlay YAML should also be removed.

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/prompt-implementer.md templates/skills/delegate-with-context/references/prompt-spec-reviewer.md templates/skills/delegate-with-context/references/prompt-code-reviewer.md templates/skills/delegate-with-context/references/prompt-doc-proposer.md templates/skills/delegate-with-context/references/overlay-schema.md
```

Expected: 0 across all five files.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 21: Edit `references/prompt-doc-curator.md`

**Files:** Modify `templates/skills/delegate-with-context/references/prompt-doc-curator.md:78`

- [ ] **Step 1: Locate**

Around line 78: instructions reference `"bd close <id>"` as a signal for detecting completed work.

- [ ] **Step 2: Apply edit**

Old:
```
in this run (check Beads body / commit messages for "bd close <id>"
```

New:
```
in this run (check commit messages and PR bodies for closing references — e.g., "Closes #N", "Fixes <task-id>", or status changes in linked spec/plan front-matter to `status: done`)
```

Also adjust nearby logic that auto-archives a spec-in-progress entry on "bd close" event — change to "on commit subject including a closing reference for the spec OR on spec/plan front-matter `status: done`".

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/skills/delegate-with-context/references/prompt-doc-curator.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 22)**

#### Task 21.5: Edit `validate.sh`

**Files:** Modify `templates/skills/delegate-with-context/validate.sh`

- [ ] **Step 1: Inspect**

```bash
grep -n 'bd' templates/skills/delegate-with-context/validate.sh
```

Expected: 1 match.

- [ ] **Step 2: Apply edit**

If the line is a validation step like `command -v bd >/dev/null && echo "bd present"`, delete it. If it's a comment, delete the comment.

- [ ] **Step 3: Verify**

```bash
grep -c 'bd' templates/skills/delegate-with-context/validate.sh
```

Expected: 0 matches.

```bash
bash -n templates/skills/delegate-with-context/validate.sh
```

Expected: exit 0.

- [ ] **Step 4: Commit (combined with Task 22)**

#### Task 22: Commit Stage 2D atomically

- [ ] **Step 1: Confirm cumulative state**

```bash
grep -rnE 'beads|BEADS|lightrag|LightRAG|\bbd ' templates/skills/delegate-with-context/
```

Expected: 0 matches.

- [ ] **Step 2: Commit**

```bash
git add templates/skills/delegate-with-context/
git commit -m "refactor(delegate-with-context): drop Phase 2 BEADS-RECONCILE + Phase 8 LightRAG harvester; tracker-agnostic refs"
```

---

### Stage 2E — Commands and config

#### Task 23: Rewrite `templates/commands/workflow-gate.md`

**Files:** Modify `templates/commands/workflow-gate.md`

- [ ] **Step 1: Baseline**

```bash
wc -l templates/commands/workflow-gate.md
grep -cE 'beads|\bbd ' templates/commands/workflow-gate.md
```

Expected: 42 lines, ~7 matches.

- [ ] **Step 2: Replace file content**

New content:

````markdown
---
description: Orchestrate task — Template Bridge unified-workflow + our quality standards
---

User's task: $ARGUMENTS

## Base orchestrator

Follow `template-bridge:unified-workflow` skill. It defines the end-to-end flow:
task setup → brainstorm → plan → sub-tasks → (worktrees) → TDD implement →
verification-before-completion → finishing-a-development-branch → task close.

## Our quality standards on top (from workflow-gate skill)

1. **Task description** — use the 6-point template (see workflow-gate skill § Phase 2):
   what, where in code, how to reproduce, what's found, context, resources.
   Lives wherever your project tracks tasks (issue tracker, PR body, or a file
   under `docs/orchestration/issues/`).

2. **Task close** — use the 4-point reason (see workflow-gate skill § Phase 4):
   1) solution, 2) root cause, 3) prevention, 4) **verification evidence**.
   Point 4 MUST include either a fresh test command + its output snippet
   captured in this session, or paths to screenshot/artefact files produced
   during `superpowers:verification-before-completion`.
   "Tested — works" without artefacts is NOT acceptable.

3. **UI changes** — Playwright screenshot at 1920x1080 on affected pages is
   mandatory before close.

## Fallbacks

- If Template Bridge is not installed: invoke `superpowers:brainstorming` directly
  and inform the user that `template-bridge:unified-workflow` is the intended
  orchestrator and should be installed.
- If Superpowers is not installed: the workflow-gate skill still provides the
  task-discipline reference; warn the user that the dev-loop skills
  (brainstorming, TDD, verification) are missing.

## Deprecated commands — do NOT use

- `/superpowers:brainstorm` (without `ing`) — deprecated, shows a text telling
  you to use the skill instead. Use skill `superpowers:brainstorming`.
````

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/commands/workflow-gate.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 25)**

#### Task 24: Edit `templates/commands/workflow-gate-check.md`

**Files:** Modify `templates/commands/workflow-gate-check.md`

- [ ] **Step 1: Baseline**

```bash
grep -cE 'beads|\bbd ' templates/commands/workflow-gate-check.md
```

Expected: ~6 matches.

- [ ] **Step 2: Apply edits**

Apply the substitution table from Task 11 across the file. Key replacements:
- `gather \`bd show\` + \`git show\` + \`git diff\` + close-reason` → `gather the task record + \`git show\` + \`git diff\` + close-reason`
- `Run \`bd update <id> --notes "WORKFLOW-GATE-CHECK: …"\`` → `Append a "WORKFLOW-GATE-CHECK: …" note to the task record`
- `do NOT call \`bd close\`` → `do NOT close the task`
- `No \`bd\` binary → audit from files + transcript` → `No issue tracker integration → audit from task spec + transcript + git`
- `No Beads issue for the work being audited` → `No task record for the work being audited`
- `(Mode 3) or no related open tasks` — unchanged conceptually; remove only the bd terminology.

- [ ] **Step 3: Verify**

```bash
grep -cE 'beads|\bbd ' templates/commands/workflow-gate-check.md
```

Expected: 0 matches.

- [ ] **Step 4: Commit (defer to Task 25)**

#### Task 24.5: Edit `templates/orchestration-config.json` — add `handoff` path

**Files:** Modify `templates/orchestration-config.json`

- [ ] **Step 1: Read current**

```bash
cat templates/orchestration-config.json
```

- [ ] **Step 2: Apply edit**

New content:

```json
{
  "documentation": {
    "paths": {
      "root": "docs",
      "plans": "docs/orchestration/plans",
      "reports": "docs/orchestration/reports",
      "issues": "docs/orchestration/issues",
      "doc_drafts": "docs/orchestration/doc-drafts",
      "observer_reports": "docs/orchestration/observer-reports",
      "handoff": "docs/orchestration/handoff"
    },
    "enabled": {
      "plans": true,
      "reports": true,
      "issues": true,
      "doc_drafts": true,
      "observer_reports": true,
      "handoff": true
    }
  }
}
```

- [ ] **Step 3: Verify JSON validity**

```bash
jq '.documentation.paths.handoff' templates/orchestration-config.json
```

Expected output: `"docs/orchestration/handoff"`.

```bash
jq '.documentation.enabled.handoff' templates/orchestration-config.json
```

Expected output: `true`.

- [ ] **Step 4: Update `deploy.sh` to create the directory on install**

Find the `mkdir -p` block in `deploy.sh` (around line 237-241) that creates `docs/orchestration/*` directories. Add one line:

```bash
mkdir -p "$TARGET/docs/orchestration/handoff"
```

- [ ] **Step 5: Verify**

```bash
grep -n 'mkdir -p .*/handoff' deploy.sh
```

Expected: 1 match.

- [ ] **Step 6: Commit (combined with Task 25)**

#### Task 25: Commit Stage 2E

- [ ] **Step 1: Confirm cumulative state**

```bash
grep -rnE 'beads|BEADS|lightrag|LightRAG|\bbd ' templates/commands/ templates/orchestration-config.json
```

Expected: 0 matches.

- [ ] **Step 2: Commit**

```bash
git add templates/commands/ templates/orchestration-config.json deploy.sh
git commit -m "refactor(commands,config): drop bd phrasing; add handoff path to orchestration-config"
```

---

### Stage 2 verification

- [ ] **Step 1: Cross-skill grep sweep**

```bash
grep -rnE 'beads|BEADS|lightrag|LightRAG|\bbd ' templates/skills/workflow-gate templates/skills/workflow-gate-check templates/skills/delegate-with-context templates/commands templates/orchestration-config.json
```

Expected: 0 matches.

```bash
grep -rnE 'beads|BEADS|lightrag|LightRAG|\bbd ' templates/skills/knowledge-harvest
```

Expected: matches present (the skill is intentionally preserved).

- [ ] **Step 2: Smoke — fixture deploy**

```bash
rm -rf /tmp/fixture-prj && mkdir -p /tmp/fixture-prj && (cd /tmp/fixture-prj && git init --quiet)
./deploy.sh /tmp/fixture-prj atomic 2>&1 | tee /tmp/deploy-stage2.log
ls /tmp/fixture-prj/docs/orchestration/handoff
```

Expected: `handoff/` directory exists (created from the orchestration-config + deploy.sh edit).

- [ ] **Step 3: Skill renders**

```bash
head -20 /tmp/fixture-prj/.claude/skills/workflow-gate/SKILL.md
head -20 /tmp/fixture-prj/.claude/skills/workflow-gate-check/SKILL.md
head -20 /tmp/fixture-prj/.claude/skills/delegate-with-context/SKILL.md
```

Expected: each starts with proper frontmatter (`---`), no bd/beads in heads.

- [ ] **Step 4: Mark Stage 2 done**

If all three steps pass, Stage 2 is complete.

---

## Stage 3 — Top-level docs

### Task 26: Rewrite `README.md`

**Files:** Modify `README.md`

This is the largest single file change. The rewrite touches:

- ASCII architecture diagram (lines ~17-41): 4-layer → 3-layer
- Prerequisites (lines ~46-62): drop beads plugin + npm bd lines
- Section "Кто что делает" table (lines ~204-213): drop Beads row
- Flow examples (lines ~215-256): drop `bd create/close` invocations
- Entire section "Task tracking with Beads" (lines ~389-475): delete
- Section "Три источника памяти проекта" table (~477-484): delete (the LightRAG row + Beads row leave nothing useful)
- Closing sentence about "Beads tracks tasks across sessions" — remove

- [ ] **Step 1: Baseline**

```bash
grep -cE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' README.md
wc -l README.md
```

Expected: ~51 matches, ~507 lines.

- [ ] **Step 2: Replace the ASCII diagram (~L17-41)**

Old (lines 17-41):
```
┌─────────────────────────────────────────────────────────────┐
│ L1 — BEADS (operational memory, vertical)                   │
│   Plugin: steveyegge/beads                                  │
│   Our overlay: 6-point issue desc, 4-point close reason     │
├─────────────────────────────────────────────────────────────┤
│ L2 — TEMPLATE BRIDGE (workflow orchestrator, horizontal)    │
│   Plugin: maslennikov-ig/template-bridge                    │
│   Skill: unified-workflow (9-step flow)                     │
│   Bonus: template-catalog + /browse-templates               │
├─────────────────────────────────────────────────────────────┤
│ L3 — SUPERPOWERS (dev-loop skills, used as-is)              │
│   Plugin: obra/superpowers                                  │
│   Skills: brainstorming, writing-plans,                     │
│           test-driven-development,                          │
│           verification-before-completion (Iron Law),        │
│           finishing-a-development-branch,                   │
│           using-superpowers (SessionStart 1% rule)          │
├─────────────────────────────────────────────────────────────┤
│ L4 — ORCHESTRATION-KIT (thin glue, project-local)           │
│   • .claude/commands/workflow-gate.md — NEW slash command   │
│   • .claude/skills/workflow-gate/ — Beads-discipline ref    │
│   • .claude/settings.json — simplified hooks                │
└─────────────────────────────────────────────────────────────┘
```

New:
```
┌─────────────────────────────────────────────────────────────┐
│ L1 — TEMPLATE BRIDGE (workflow orchestrator)                │
│   Plugin: maslennikov-ig/template-bridge                    │
│   Skill: unified-workflow (end-to-end flow)                 │
│   Bonus: template-catalog + /browse-templates               │
├─────────────────────────────────────────────────────────────┤
│ L2 — SUPERPOWERS (dev-loop skills, used as-is)              │
│   Plugin: obra/superpowers                                  │
│   Skills: brainstorming, writing-plans,                     │
│           test-driven-development,                          │
│           verification-before-completion (Iron Law),        │
│           finishing-a-development-branch,                   │
│           using-superpowers (SessionStart 1% rule)          │
├─────────────────────────────────────────────────────────────┤
│ L3 — ORCHESTRATION-KIT (thin glue, project-local)           │
│   • .claude/commands/workflow-gate.md — slash command       │
│   • .claude/skills/workflow-gate/ — task-discipline ref     │
│   • .claude/settings.json — simplified hooks                │
└─────────────────────────────────────────────────────────────┘
```

Also rewrite the surrounding paragraph (line 43): drop the sentence "Beads keeps persistent memory across sessions." and adjust adjoining prose.

- [ ] **Step 3: Update Prerequisites (~L46-62)**

Old:
```bash
# Required — development methodology (dev-loop skills)
claude plugin install superpowers

# Required — workflow orchestrator (unified-workflow skill + template-catalog)
claude plugin marketplace add maslennikov-ig/template-bridge
claude plugin install template-bridge

# Recommended — persistent task tracking (operational memory)
claude plugin marketplace add steveyegge/beads
claude plugin install beads
npm install -g @beads/bd
```

New:
```bash
# Required — development methodology (dev-loop skills)
claude plugin install superpowers

# Required — workflow orchestrator (unified-workflow skill + template-catalog)
claude plugin marketplace add maslennikov-ig/template-bridge
claude plugin install template-bridge
```

- [ ] **Step 4: Drop "Кто что делает" Beads row (~L204-213)**

The row to drop is:
```
| **Beads** | Задачи, зависимости, история, межсессионный контекст | Всегда — operational memory |
```

The flow examples below (~L215-256) reference `bd create`, `bd ready`, `bd close`. Rewrite each example to instead reference whatever tracker is in use (e.g., GitHub issue create/close, or commit message conventions). Concretely:

Replace `→ beads: создаёт задачу` with `→ create task record (issue tracker / PR body / docs/orchestration/issues/)`. Replace `→ beads: закрывает задачу` with `→ close task with 4-point reason in commit body or tracker close-comment`. Drop multi-session examples sub-bullet about `bd prime` since it no longer exists.

- [ ] **Step 5: Delete "Task tracking with Beads" section entirely**

Delete from heading `### Task tracking with Beads` through the next top-level (`---` or `###`) heading. Roughly lines 389-475 (~85 lines).

- [ ] **Step 6: Delete "Три источника памяти проекта" table**

Delete this table around lines 477-484:
```
| Источник | Что хранит | Пример |
|----------|-----------|--------|
| **Git** | Изменения в коде | `git log` — что менялось |
| **LightRAG** | Решения и причины | "Выбрали D3 потому что нужна интерактивность" |
| **Beads** | Задачи, прогресс, контекст | "Epic: рефакторинг. 3 задачи, 2 closed, 1 ready" |
| **bd remember** | Конвенции и паттерны | "test-pattern: baseline pid=5 tmode=2" |
```

If the surrounding paragraph mentions "три источника" or similar, reword to "two sources: git history and `docs/orchestration/conventions.md` (or CLAUDE.md) for cross-session patterns".

- [ ] **Step 7: Verify**

```bash
grep -cE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' README.md
```

Expected: 0 matches.

```bash
wc -l README.md
```

Expected: ~390 lines (down from 507).

- [ ] **Step 8: Commit**

```bash
git add README.md
git commit -m "docs(readme): 4-layer → 3-layer model; drop Beads tracking section"
```

---

### Task 27: Rewrite `SKILL.md` (top-level deploy-orchestration)

**Files:** Modify `SKILL.md`

The generated CLAUDE.md template inside this file contains Beads-heavy sections.

- [ ] **Step 1: Baseline**

```bash
grep -cE 'beads|Beads|\bbd \b' SKILL.md
```

Expected: ~14 matches.

- [ ] **Step 2: Delete Step 1 bd init detection (lines 43-55)**

Delete the entire block:
```
Also check Beads status:
\`\`\`
5. Check if .beads/ exists (bd init already run by deploy.sh)
6. If not — check if bd command is available, offer to run bd init
7. If bd not available — note in summary, recommend installing
\`\`\`

Combine user input + detected info. Output a brief summary:
\`\`\`
Got it — "{user's description}".
Detected: {language/framework if found, or "fresh project, no code yet"}
Beads: {initialized | not installed — run: npm install -g @beads/bd && bd init}
\`\`\`
```

Replace with:
```
Combine user input + detected info. Output a brief summary:
\`\`\`
Got it — "{user's description}".
Detected: {language/framework if found, or "fresh project, no code yet"}
\`\`\`
```

- [ ] **Step 3: Rewrite generated CLAUDE.md template — Development Methodology section (lines ~202-227)**

Old (Step 5's generated CLAUDE.md content for Development Methodology):
```
### Development Methodology (D1)

**Entry point:** `/workflow-gate <task>` — slash command. Delegates to `template-bridge:unified-workflow` and layers our Beads quality overlay on top.

Flow (9 steps from unified-workflow):
1. `bd create` (6-point description — see `workflow-gate` skill § Phase 2)
2. Skill `superpowers:brainstorming`
...
9. `bd close` (4-point reason incl Verification — `workflow-gate` skill § Phase 4)

**Beads artefacts (descriptions, notes, reasons, remember) are written in English** for token efficiency. User-facing communication stays in the user's language.

Manual commands:
- `/beads:create`, `/beads:ready`, `/beads:close` — direct Beads operations
- Skill `superpowers:brainstorming` — brainstorm without full `/workflow-gate`
- `/browse-templates` — 413+ on-demand specialist agents (Template Bridge)

**DO NOT use:** `/superpowers:brainstorm` (no `ing`) — deprecated, just prints a notice. Always invoke the skill `superpowers:brainstorming`.

**Workflow summary:** epic → sub-tasks with deps → `bd ready` → claim → work → verify → close → next ready task.
```

New:
```
### Development Methodology (D1)

**Entry point:** `/workflow-gate <task>` — slash command. Delegates to `template-bridge:unified-workflow` and layers our task-discipline reference (`workflow-gate` skill) on top.

Flow (from unified-workflow):
1. Task record (6-point description — see `workflow-gate` skill § Phase 2 — lives in your tracker or `docs/orchestration/issues/`)
2. Skill `superpowers:brainstorming`
3. Skill `superpowers:writing-plans`
4. Sub-tasks (track in same place as parent)
5. `superpowers:using-git-worktrees` (if non-trivial)
6. TDD via `superpowers:test-driven-development`
7. `superpowers:verification-before-completion` — **Iron Law:** no fresh test output → no "tested" claim
8. `superpowers:finishing-a-development-branch`
9. Task close (4-point reason in commit body, PR description, or tracker close — see `workflow-gate` skill § Phase 4)

**Task artefacts (descriptions, notes, close reasons) are written in English** for token efficiency. User-facing communication stays in the user's language.

Manual commands:
- Skill `superpowers:brainstorming` — brainstorm without full `/workflow-gate`
- `/browse-templates` — 413+ on-demand specialist agents (Template Bridge)

**DO NOT use:** `/superpowers:brainstorm` (no `ing`) — deprecated, just prints a notice. Always invoke the skill `superpowers:brainstorming`.

**Workflow summary:** plan → sub-tasks → work → verify → close → next task.
```

- [ ] **Step 4: Edit Step 7 output summary (around line 351)**

Old block:
```
Development approach:
  Superpowers  — dev loop (brainstorm → plan → TDD → review → verify)
  Beads        — task tracking (bd ready → claim → work → close)
  Templates    — on-demand specialists (npx claude-code-templates@latest --agent ...)
```

New:
```
Development approach:
  Superpowers  — dev loop (brainstorm → plan → TDD → review → verify)
  Templates    — on-demand specialists (npx claude-code-templates@latest --agent ...)
```

- [ ] **Step 5: Verify**

```bash
grep -cE 'beads|Beads|\bbd \b' SKILL.md
```

Expected: 0 matches.

- [ ] **Step 6: Commit**

```bash
git add SKILL.md
git commit -m "docs(skill): drop Beads from generated CLAUDE.md template + deploy-orchestration flow"
```

---

### Task 28: Append migration subsection to `README.md`

**Files:** Modify `README.md` (add a new subsection near the top, after "Quick Start")

- [ ] **Step 1: Locate insertion point**

Find the end of the "Quick Start" section (after step 4 "Start working" but before "Supported Languages").

- [ ] **Step 2: Append**

Insert this new subsection:

````markdown
### Migrating an existing deployment

If you previously installed orchestration-kit when it shipped with Beads / LightRAG integration, your project still carries some legacy state. Run these one-time steps:

```bash
# 1. Refresh the kit-shipped content (skills, commands, hooks)
/kit-update --update-skills

# 2. (If you no longer want Beads) Remove the local Beads state and plugin
rm -rf .beads/
claude plugin uninstall beads

# 3. Hand-edit .claude/settings.json — remove any leftover hook entry that runs `bd prime`
#    Check: jq '.hooks.SessionStart, .hooks.PreCompact' .claude/settings.json
#    The kit no longer ships those entries; `/kit-update` only ADDS hooks, it does not
#    remove stale ones.

# 4. Regenerate CLAUDE.md to drop Beads-flavoured sections
/deploy-orchestration <your project description>
# When prompted about overwriting Claude Automations block, accept.
```

The `knowledge-harvest` skill currently still requires LightRAG MCP; it remains in the deployed roster but is scheduled for a rewrite that persists findings into project files. If your project does not have LightRAG MCP installed, the skill will return a `SKIPPED — no LightRAG MCP` notice when invoked.
````

- [ ] **Step 3: Verify**

```bash
grep -n 'Migrating an existing deployment' README.md
```

Expected: 1 match.

```bash
grep -cE 'beads|Beads|\bbd \b' README.md
```

Expected: matches present, but all inside the new migration subsection (intentional — instructions for users migrating *away* from Beads).

To confirm only the migration block contains those terms:
```bash
awk '/^### Migrating an existing deployment/,/^### /' README.md | grep -cE 'beads|Beads|\bbd \b'
```

Should match the same number as the global count → confirms no stray Beads references outside the migration block.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs(readme): add migration subsection for projects with legacy Beads/LightRAG"
```

---

### Stage 3 verification

- [ ] **Step 1: Re-run /deploy-orchestration in fixture**

```bash
rm -rf /tmp/fixture-prj && mkdir -p /tmp/fixture-prj && (cd /tmp/fixture-prj && git init --quiet)
./deploy.sh /tmp/fixture-prj atomic
```

Open `/tmp/fixture-prj` in Claude Code (manual step) and run:
```
/deploy-orchestration build a simple test project
```

Inspect the generated `CLAUDE.md` — confirm no Beads section, no `bd` commands in Manual commands list.

- [ ] **Step 2: Repo-wide sweep**

```bash
grep -rnE '\bbeads\b|\bBeads\b|\bbd \b|LightRAG' README.md SKILL.md deploy.sh templates/ | grep -v 'knowledge-harvest' | grep -v 'docs/superpowers/specs/2026-04' | grep -v 'docs/superpowers/plans/2026-04' | grep -v 'migration-plan' | grep -v 'analysis-habr'
```

Filter out: knowledge-harvest skill (preserved), frozen specs/plans (historical), migration-plan.md / analysis-habr (historical).

Expected: matches only inside the README "Migrating an existing deployment" subsection.

- [ ] **Step 3: Render sanity**

Open `README.md` and `SKILL.md` in a markdown viewer (or `glow`, `mdcat`). Confirm:
- README architecture diagram now shows L1-L3 (Template Bridge → Superpowers → Orchestration-kit).
- "Кто что делает" table no longer has Beads row.
- "Three sources of memory" table is gone.
- Migration subsection sits between Quick Start and Supported Languages.

- [ ] **Step 4: Mark Stage 3 done**

---

## Stage 4 — Cross-stage verification

### Task 29: Manual smoke of the rewritten workflow

- [ ] **Step 1: Fresh fixture**

```bash
rm -rf /tmp/wgc-fixture && mkdir -p /tmp/wgc-fixture && (cd /tmp/wgc-fixture && git init --quiet && echo "# test" > README.md && git add . && git commit --quiet -m "init")
./deploy.sh /tmp/wgc-fixture atomic
```

- [ ] **Step 2: Trigger `/workflow-gate` in Claude Code**

Manual: open `/tmp/wgc-fixture` in Claude Code, run:
```
/workflow-gate fix some typo
```

Expected behavior:
- The slash command invokes `template-bridge:unified-workflow` (or warns if not installed).
- No `bd create` / `bd close` instructions appear.
- The 6-point + 4-point templates reference "task record" or "PR body" / "commit body".

- [ ] **Step 3: Trigger `/workflow-gate-check 03` after a fake session**

Manual: make some commits in the fixture, then:
```
/workflow-gate-check 03
```

Expected:
- Mode 3 proposes a handoff file at `docs/orchestration/handoff/NNN-<topic>-handoff.md`.
- No `bd update` / `bd decision` / `bd remember` invocations.
- User-approval gate present.

- [ ] **Step 4: Trigger `/delegate-with-context --dry-run`**

Manual: in the fixture, with a small chat task, run:
```
/delegate-with-context --dry-run "add a hello world function"
```

Expected:
- Phase 1 distils the task.
- Phase 2 is SPEC-DISTILL (not BEADS-RECONCILE).
- Phase 8 plans 2 subagents (doc-proposer + doc-curator), not 3.
- No mention of LightRAG / knowledge-harvester in the dry-run output.

- [ ] **Step 5: Record outcomes**

If any expectation fails, file the failure as a follow-up task (in your tracker or `docs/orchestration/issues/`) with `Discovered during: 003-remove-beads-lightrag plan, Task 29`.

---

### Task 30: Update spec status to "done"

**Files:** Modify `docs/superpowers/specs/003-remove-beads-lightrag-design.md`

- [ ] **Step 1: Update front-matter**

Change `status: spec-in-progress` → `status: done`.

- [ ] **Step 2: Update plan status**

Change this plan's own front-matter `status: plan-in-progress` → `status: done`.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/003-remove-beads-lightrag-design.md docs/superpowers/plans/003-remove-beads-lightrag.md
git commit -m "chore(docs): mark spec & plan 003 as done"
```

---

## Self-review checklist

(Reviewer runs this checklist after the plan is written, before handing off.)

- [ ] **Spec coverage:** every Stage in the spec (A wire, B skills, C top docs) maps to a task in this plan. Risks #1-9 each have a referenced mitigation either in a task or in Task 28 (migration subsection). Open questions #1-5 each have a recorded decision (Task 7 for Q1, Task 28 for Q2, Task 27 for Q3, Task 18 for Q4, Task 24.5 for Q5).
- [ ] **Placeholder scan:** no "TBD", "TODO", "implement later", "add appropriate" — every task contains concrete code or text.
- [ ] **Type consistency:** path `docs/orchestration/handoff/NNN-<topic>-handoff.md` used uniformly across Task 11, Task 12, Task 24, Task 24.5. The substitution table in Task 11 is consistent with all later application points (Tasks 12-14, 16-21, 24).
- [ ] **Grep baselines:** baseline counts in Conventions match `grep` outputs taken at plan-write time (2026-05-13). If counts have drifted by the time the plan executes, re-baseline before starting Stage 1.
