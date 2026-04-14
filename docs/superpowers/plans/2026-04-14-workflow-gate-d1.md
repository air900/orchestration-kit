# Workflow-Gate D1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch `orchestration-kit` templates from a reinvented workflow to `template-bridge:unified-workflow` as orchestrator, with our `workflow-gate` skill shrunk to Beads-discipline only (incl 4-point close reason with mandatory verification evidence). Remove the broken PreToolUse `Edit|Write|MultiEdit` hook and the `.workflow-active` marker lifecycle.

**Architecture:** Thin `/workflow-gate` slash command (new `templates/commands/workflow-gate.md`) delegates to `template-bridge:unified-workflow` and layers our Beads quality overlay on top. The workflow-gate skill becomes a Beads-discipline reference (6-point issue description + 4-point close reason + notes/remember/commits with ID). Hooks simplified to destructive-Bash matcher + `bd prime` on SessionStart/PreCompact.

**Tech Stack:** Claude Code slash-commands (`.md` with YAML frontmatter), Claude Code hooks (`.json`), markdown documentation. No executable code changes.

**Scope:** This plan modifies `orchestration-kit` templates only. Rollout to existing projects (`web-scripts`, `hr-bot`, etc.) is deferred to a separate plan per spec §4.2.

**Testing approach:** Since all changes are configuration/docs, "verification" means grep/read assertions that content matches spec. Each task ends with verification step(s) before commit.

---

## File Structure

**New files:**
- `templates/commands/workflow-gate.md` — slash-command entry point

**Modified files:**
- `templates/skills/workflow-gate/SKILL.md` — shrink Phases 1 and 5; add 4th point to Phase 4 close reason; rewrite preamble
- `templates/settings-hooks.json` — remove Edit/Write matcher; remove marker lifecycle; update SessionStart echo
- `README.md` — update architecture diagram and flow description
- `migration-plan.md` — reflect D1

**Removed concepts everywhere (grep-sweep):** `.workflow-active`, `touch .workflow-active`, `rm -f .workflow-active`, "Edit/Write ЗАБЛОКИРОВАНЫ", "edits are blocked", "unlock code editing".

---

## Task 1: Create `/workflow-gate` slash command

**Files:**
- Create: `templates/commands/workflow-gate.md`

- [ ] **Step 1: Verify file does not exist (baseline)**

Run: `ls /root/projects/orchestration-kit/templates/commands/workflow-gate.md 2>&1`
Expected: `ls: cannot access ...: No such file or directory`

- [ ] **Step 2: Create the commands directory**

Run: `mkdir -p /root/projects/orchestration-kit/templates/commands`

- [ ] **Step 3: Write the slash-command file**

Path: `/root/projects/orchestration-kit/templates/commands/workflow-gate.md`

Full content:

````markdown
---
description: Orchestrate task — Beads + Template Bridge unified-workflow + our quality standards
---

User's task: $ARGUMENTS

## Base orchestrator

Follow `template-bridge:unified-workflow` skill. It defines the 9-step flow:
beads task → brainstorm → plan → sub-tasks → (worktrees) → TDD implement →
verification-before-completion → finishing-a-development-branch → bd close.

## Our quality standards on top (from workflow-gate skill)

1. **Beads create** — use 6-point description (see workflow-gate skill § Phase 2):
   what, where in code, how to reproduce, what's found, context, resources.

2. **Beads close** — use 4-point reason (see workflow-gate skill § Phase 4):
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
- If Beads is not initialised: run `bd init` before any other step.
- If Superpowers is not installed: the workflow-gate skill still provides the
  Beads quality reference; warn the user that the dev-loop skills
  (brainstorming, TDD, verification) are missing.

## Deprecated commands — do NOT use

- `/superpowers:brainstorm` (without `ing`) — deprecated, shows a text telling
  you to use the skill instead. Use skill `superpowers:brainstorming`.
````

- [ ] **Step 4: Verify content**

Run: `head -5 /root/projects/orchestration-kit/templates/commands/workflow-gate.md && echo '---' && grep -c 'unified-workflow\|4-point\|6-point\|$ARGUMENTS' /root/projects/orchestration-kit/templates/commands/workflow-gate.md`
Expected: frontmatter with `description:` line, `#` headings, grep count `>= 4`.

- [ ] **Step 5: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/commands/workflow-gate.md
git commit -m "feat: add /workflow-gate slash command (delegates to template-bridge:unified-workflow)"
```

---

## Task 2: Rewrite `workflow-gate` skill preamble and description

**Files:**
- Modify: `templates/skills/workflow-gate/SKILL.md` (lines 1-16)

- [ ] **Step 1: Read current preamble (baseline)**

Run: `sed -n '1,16p' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: current description mentions "Creates .workflow-active marker" and "edits are blocked".

- [ ] **Step 2: Replace frontmatter and first heading block**

Use Edit tool. Replace:

```markdown
---
name: workflow-gate
description: >
  Entry point for all development work. Creates .workflow-active marker (unlocks Edit/Write),
  then invokes template-bridge:unified-workflow. Use BEFORE any task — edits are blocked without this.
  TRIGGER: Always use this instead of unified-workflow directly.
---

# Workflow Gate

**This skill is the ONLY way to unlock code editing in this session.**

A PreToolUse hook blocks Edit/Write/MultiEdit until `.workflow-active` exists.
This skill creates that marker and launches the full development workflow.

---
```

With:

```markdown
---
name: workflow-gate
description: >
  Beads-discipline reference for all development work: issue quality standards,
  notes/remember/commits policy, 4-point close reason with verification evidence.
  Dev-loop orchestration lives in slash-command /workflow-gate, which delegates
  to template-bridge:unified-workflow.
  TRIGGER: Consult this skill whenever creating/closing Beads issues or
  uncertain about project conventions.
---

# Workflow Gate

**Role:** Reference for Beads-discipline in this project.
**Orchestration:** handled by slash-command `/workflow-gate` (delegates to
`template-bridge:unified-workflow`). This skill does NOT orchestrate; it
documents the quality standards that apply to any workflow.

**There is no marker file, no unlock mechanism, no Edit/Write hook block.**
Those were removed in the D1 redesign (see spec
`docs/superpowers/specs/2026-04-14-workflow-gate-d1-design.md`).

---
```

- [ ] **Step 3: Verify new preamble**

Run: `sed -n '1,20p' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md && echo --- && grep -c 'workflow-active\|unlock' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: new content visible; `grep -c` = 0 for those keywords in the preamble's new form (may still appear in later sections — fixed in Task 3).

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/skills/workflow-gate/SKILL.md
git commit -m "refactor(workflow-gate): rewrite preamble — skill becomes Beads-discipline reference"
```

---

## Task 3: Delete Phase 1 (Activate gate / Launch unified-workflow)

**Files:**
- Modify: `templates/skills/workflow-gate/SKILL.md` — remove current Phase 1 block

**Rationale:** Phase 1 hosted marker creation (`touch .workflow-active`) and skill delegation to unified-workflow. Both become obsolete: marker is gone; unified-workflow invocation moves to slash command.

- [ ] **Step 1: Identify current Phase 1 range**

Run: `grep -n '^## Phase\|^### [0-9]\.' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: list of Phase/section headings; Phase 1 starts at "## Phase 1: Session Start" and ends before "## Phase 2: Issue Creation — Quality Standard".

- [ ] **Step 2: Delete the Phase 1 block via Edit**

Use Edit tool. Remove the entire block from `## Phase 1: Session Start` through `### 1.3 Launch unified workflow` and its body, up to (but not including) `## Phase 2: Issue Creation — Quality Standard`. Replace with nothing (blank line).

The removed block looks approximately like:

```markdown
## Phase 1: Session Start

### 1.1 Activate gate

```bash
touch .workflow-active
```

Run IMMEDIATELY. Without it, all edits are blocked.

### 1.2 Load context

```bash
bd prime          # Workflow context: open issues, priorities, blockers
bd recall         # Persistent memory: conventions, patterns, past decisions
bd ready --json   # Structured list of claimable work
```

If resuming work from a previous session — check what's in progress before starting anything new.

### 1.3 Launch unified workflow

Invoke `template-bridge:unified-workflow` skill for the full flow.

---
```

**Note on Phase 1.2 (Load context):** We are NOT losing the `bd prime` / `bd recall` / `bd ready` guidance — that moves to Phase 3 (During Work) in Task 6 to keep it with other Beads-operational commands.

- [ ] **Step 3: Verify Phase 1 gone**

Run: `grep -n 'workflow-active\|Phase 1\|Activate gate\|Launch unified workflow' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: no matches in the skill file (there will be matches in spec file; that's fine).

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/skills/workflow-gate/SKILL.md
git commit -m "refactor(workflow-gate): remove Phase 1 (marker + unified-workflow delegation)"
```

---

## Task 4: Remove marker cleanup from Phase 5 (Session End)

**Files:**
- Modify: `templates/skills/workflow-gate/SKILL.md`, Phase 5 "Land the Plane" section

- [ ] **Step 1: Locate marker-removal step in Phase 5**

Run: `grep -n 'Маркер\|workflow-active\|rm -f' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: a step like:

```markdown
5. **Маркер** — снять:
   ```bash
   rm -f .workflow-active
   ```
```

- [ ] **Step 2: Remove that step via Edit**

Use Edit. Remove exactly the block:

```markdown

5. **Маркер** — снять:
   ```bash
   rm -f .workflow-active
   ```
```

Renumber any subsequent steps if present (likely none — this was the last step).

- [ ] **Step 3: Verify**

Run: `grep -c 'workflow-active' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: `0`

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/skills/workflow-gate/SKILL.md
git commit -m "refactor(workflow-gate): remove marker cleanup from Session End"
```

---

## Task 5: Move `bd prime` / `bd recall` context-loading to Phase 3

**Files:**
- Modify: `templates/skills/workflow-gate/SKILL.md`, top of Phase 3 "During Work"

**Rationale:** Phase 1 (deleted in Task 3) had `bd prime` / `bd recall` / `bd ready`. These are still valuable — they belong with other Beads-operational commands in Phase 3.

- [ ] **Step 1: Locate Phase 3 heading**

Run: `grep -n '^## Phase 3' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: single line like `## Phase 3: During Work`.

- [ ] **Step 2: Insert new sub-section 3.0 at the top of Phase 3**

Use Edit. Insert immediately after the `## Phase 3: During Work` line:

```markdown
## Phase 3: During Work

### 3.0 Session start — load Beads context

**Note:** SessionStart hook already runs `bd prime` automatically. Below is
for manual re-loading mid-session or after switching projects.

```bash
bd prime          # Workflow context: open issues, priorities, blockers
bd recall         # Persistent memory: conventions, patterns, past decisions
bd ready --json   # Structured list of claimable work
```

If resuming work from a previous session — check what's in progress via
`bd show <id>` before starting anything new.

---

```

(Keep the subsequent sub-sections like `### Notes — обновляй СРАЗУ` unchanged.)

- [ ] **Step 3: Verify**

Run: `sed -n '/## Phase 3/,/## Phase 4/p' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md | head -30`
Expected: Phase 3 now leads with `### 3.0 Session start — load Beads context` followed by original Notes section.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/skills/workflow-gate/SKILL.md
git commit -m "refactor(workflow-gate): move bd prime/recall/ready into Phase 3 as 3.0"
```

---

## Task 6: Expand Phase 4 close-reason from 3-point to 4-point (add Verification)

**Files:**
- Modify: `templates/skills/workflow-gate/SKILL.md`, Phase 4 "Closing — Quality Standard"

- [ ] **Step 1: Locate current 3-point structure**

Run: `sed -n '/## Phase 4/,/^## Phase 5/p' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md | head -50`
Expected: shows `### Reason — 3 обязательных пункта` with 3 numbered items (Суть решения / Root cause / Prevention) and Хорошо/Плохо example.

- [ ] **Step 2: Replace the 3-point block with 4-point block**

Use Edit. Replace:

```markdown
### Reason — 3 обязательных пункта

1. **Суть решения** — что конкретно сделано (1-2 предложения)
2. **Root cause** — почему ошибка возникла
3. **Prevention** — что сделать чтобы не повторилось (тест, правило, проверка)

**Плохо:** `--reason "Fixed"`
**Хорошо:**
```
--reason "Добавлен expandRowGaps() post-pass после allocateCombSlots().
Root cause: GENP фиксированный — не учитывал количество гребней в промежутке.
Prevention: expandRowGaps() динамически раздвигает ряды — при новых коннекторах
проверять что их высота учтена в дефиците."
```
```

With:

```markdown
### Reason — 4 обязательных пункта

1. **Суть решения** — что конкретно сделано (1-2 предложения)
2. **Root cause** — почему ошибка возникла
3. **Prevention** — что сделать чтобы не повторилось (тест, правило, проверка)
4. **Verification** — конкретные артефакты из `superpowers:verification-before-completion`:
   - Команда теста + снимок её output'а (свежий, запущенный в этой сессии)
   - Пути к screenshot'ам (для UI-изменений — обязательны)
   - Before/after evidence для багфиксов
   - «Tested — works» БЕЗ артефактов — невалидный reason. Переписать.

**Плохо:** `--reason "Fixed"` — нет ни одного пункта
**Плохо:** `--reason "Fix + tested"` — нет root cause, prevention, конкретного evidence
**Хорошо:**
```
--reason "1. Добавлен expandRowGaps() post-pass после allocateCombSlots().
2. Root cause: GENP фиксированный — не учитывал количество гребней в промежутке.
3. Prevention: expandRowGaps() динамически раздвигает ряды — при новых коннекторах
   проверять что их высота учтена в дефиците.
4. Verification:
   - node tests/channel-integrity-full.js → COMB-COLLISION: 0 (было 30)
   - Playwright pid=5,7,213 tmode=5 at 1920x1080:
     assets/screenshots/2026-04-14-after-comb-*.png (visual OK)
   - Full sweep 261 pids: no regression in LINE-CARD-CROSSING/CARD-OVERLAP."
```
```

- [ ] **Step 3: Verify**

Run: `grep -c '4 обязательных\|Verification\|verification-before-completion' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: `>= 3` (heading + point 4 name + skill reference).

Also: `grep -n '3 обязательных' /root/projects/orchestration-kit/templates/skills/workflow-gate/SKILL.md`
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/skills/workflow-gate/SKILL.md
git commit -m "feat(workflow-gate): expand close-reason to 4-point with mandatory Verification evidence"
```

---

## Task 7: Simplify `templates/settings-hooks.json`

**Files:**
- Modify: `templates/settings-hooks.json` (overwrite)

- [ ] **Step 1: Capture current file for diff reference**

Run: `cat /root/projects/orchestration-kit/templates/settings-hooks.json`
Expected: current JSON with `Edit|Write|MultiEdit` matcher, `rm -f .workflow-active` SessionStart command, `Edits BLOCKED` echo.

- [ ] **Step 2: Overwrite with new content**

Use Write tool. Full new content:

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
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime 2>/dev/null || true"
          },
          {
            "type": "command",
            "command": "echo 'Workflow: /workflow-gate <task> (delegates to template-bridge:unified-workflow). Beads discipline: workflow-gate skill. Verification: superpowers:verification-before-completion (Iron Law).'"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bd prime 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Verify JSON validity and absence of old constructs**

Run:
```bash
python3 -m json.tool /root/projects/orchestration-kit/templates/settings-hooks.json > /dev/null && echo 'JSON OK'
grep -E 'Edit\|Write\|MultiEdit|workflow-active|Edits BLOCKED' /root/projects/orchestration-kit/templates/settings-hooks.json
```
Expected: `JSON OK`; grep returns no matches (exit code 1, empty output).

Also: `grep -c 'rm -rf\|git push --force\|git reset --hard\|bd prime' /root/projects/orchestration-kit/templates/settings-hooks.json`
Expected: `>= 4` (destructive matchers + two bd prime calls).

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add templates/settings-hooks.json
git commit -m "refactor(hooks): remove Edit/Write matcher and marker lifecycle; keep destructive Bash + bd prime"
```

---

## Task 8: Update `README.md` — architecture and flow

**Files:**
- Modify: `/root/projects/orchestration-kit/README.md`

- [ ] **Step 1: Find the architecture / workflow sections**

Run:
```bash
grep -n '^## \|^### \|workflow-active\|Edit/Write ЗАБЛОКИРОВАНЫ\|unified-workflow' /root/projects/orchestration-kit/README.md | head -40
```
Expected: section headings + lines referencing marker/unified-workflow. Note all line numbers that reference `.workflow-active` or "edits are blocked" style messages — these must go.

- [ ] **Step 2: Remove all references to `.workflow-active`, "Edits blocked" / "ЗАБЛОКИРОВАНЫ", and the marker lifecycle**

Use Edit (possibly multiple). For each occurrence:
- If the line is purely about marker/blocking, remove the line or paragraph.
- If the surrounding flow describes orchestration, replace with reference to slash-command `/workflow-gate` → unified-workflow.

Specifically:
- Any block like `touch .workflow-active` → delete
- Any diagram arrow like `├─ touch .workflow-active (разблокирует Edit/Write)` → delete
- Any sentence like "Edit/Write заблокированы пока не вызван..." → replace with: "`/workflow-gate <task>` — slash-команда, делегирует `template-bridge:unified-workflow` и добавляет наши Beads-стандарты (6-point description, 4-point close reason с verification evidence)."
- Any flow diagram with `unified-workflow (Template Bridge)` as a sub-step of marker creation → replace with `/workflow-gate` as the entry point.

- [ ] **Step 3: Add (or update) the D1 architecture diagram**

Find the existing architecture section (look for `PLUGINS (глобальные)` or similar). Ensure it reads (update in place if already exists):

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

- [ ] **Step 4: Update the "flow" example**

Replace any existing flow that starts with `touch .workflow-active`. Use this canonical example:

```
User: /workflow-gate fix LINE-CARD-CROSSING P1
  │
  ▼ Claude Code resolves the slash command.
  ▼ commands/workflow-gate.md injects task text + quality overlays.
  │
  ▼ template-bridge:unified-workflow runs:
     1. bd create      (6-point description — our overlay)
     2. superpowers:brainstorming
     3. superpowers:writing-plans
     4. sub-tasks (bd create + dep add)
     5. superpowers:using-git-worktrees (if non-trivial)
     6. TDD via superpowers:test-driven-development
     7. superpowers:verification-before-completion (Iron Law)
     8. superpowers:finishing-a-development-branch
     9. bd close       (4-point reason incl Verification — our overlay)
```

- [ ] **Step 5: Verify**

Run:
```bash
grep -c 'workflow-active\|ЗАБЛОКИРОВАНЫ\|unlock code editing' /root/projects/orchestration-kit/README.md
grep -c 'unified-workflow\|4-point\|6-point\|verification-before-completion' /root/projects/orchestration-kit/README.md
```
Expected: first grep = `0`; second grep >= `4`.

- [ ] **Step 6: Commit**

```bash
cd /root/projects/orchestration-kit
git add README.md
git commit -m "docs(readme): update architecture and flow to D1 (template-bridge + Beads overlay)"
```

---

## Task 9: Update `migration-plan.md`

**Files:**
- Modify: `/root/projects/orchestration-kit/migration-plan.md`

- [ ] **Step 1: Scan current content**

Run:
```bash
grep -n 'workflow-active\|touch .workflow\|Edit/Write\|unified-workflow' /root/projects/orchestration-kit/migration-plan.md
```

- [ ] **Step 2: Replace marker-based phases**

Use Edit. For every step that references `touch .workflow-active`, `rm -f .workflow-active`, or "Edit/Write заблокированы":
- Replace with equivalent D1 phrasing referencing the slash command + Template Bridge.

Add (or update) an explicit migration step near the top of the plan:

```markdown
## D1 Changes (2026-04-14)

For any existing project that has the old workflow-gate setup:

1. **Create** `.claude/commands/workflow-gate.md` — copy from
   `orchestration-kit/templates/commands/workflow-gate.md`.
2. **Shrink** `.claude/skills/workflow-gate/SKILL.md` — copy from updated
   `orchestration-kit/templates/skills/workflow-gate/SKILL.md` (Phases
   2, 3, 3.0, 4, 5, 6 only; no Phase 1 marker content).
3. **Replace** `.claude/settings.json` hooks section — copy from
   `orchestration-kit/templates/settings-hooks.json` (destructive Bash
   matcher + `bd prime` only).
4. **Delete** any existing `.workflow-active` marker file in the project
   root: `rm -f .workflow-active`.
5. **Update** project `CLAUDE.md` — remove any paragraph describing
   "Edit/Write заблокированы" or the marker lifecycle. Reference the
   slash command `/workflow-gate` as the entry point and the
   `workflow-gate` skill as the Beads-discipline reference.
6. **Verify** Template Bridge plugin is enabled in the user's global
   settings. If not, the agent falls back to `superpowers:brainstorming`
   directly (graceful degradation per design § 3.5).
```

- [ ] **Step 3: Verify**

Run:
```bash
grep -c 'touch .workflow-active\|ЗАБЛОКИРОВАНЫ' /root/projects/orchestration-kit/migration-plan.md
grep -c 'D1 Changes\|template-bridge\|slash command' /root/projects/orchestration-kit/migration-plan.md
```
Expected: first = `0`; second >= `3`.

- [ ] **Step 4: Commit**

```bash
cd /root/projects/orchestration-kit
git add migration-plan.md
git commit -m "docs(migration): add D1 migration steps; remove marker-based procedures"
```

---

## Task 10: Final sweep — verify no lingering old concepts

**Files:** All `orchestration-kit/` except `docs/superpowers/specs/` (the spec itself legitimately describes removed concepts).

- [ ] **Step 1: Full-tree grep for forbidden strings**

Run:
```bash
cd /root/projects/orchestration-kit
grep -rn 'workflow-active\|ЗАБЛОКИРОВАНЫ\|unlock code editing\|touch .workflow' \
  --include='*.md' --include='*.json' --include='*.sh' \
  --exclude-dir='docs/superpowers/specs' \
  --exclude-dir='.git' \
  --exclude-dir='docs/superpowers/plans' \
  .
```
Expected: zero matches (apart from spec/plan directories which legitimately describe what was removed).

- [ ] **Step 2: If matches appear — fix them**

For each hit:
- If in a SKILL.md, command.md, or README — edit out as per Task 2-9 patterns.
- If in a settings-hooks.json — should have been caught in Task 7; re-check.
- If in a CLAUDE.md (template) — rewrite paragraph to reference slash command instead.

Commit each fix with `fix: remove stale reference to <concept> in <file>`.

- [ ] **Step 3: Verify acceptance criteria from spec § 6**

For each of 7 acceptance criteria, run the corresponding check:

```bash
# AC1: /workflow-gate exists as command
test -f templates/commands/workflow-gate.md && echo 'AC1 ✓'

# AC2: no Edit|Write|MultiEdit matcher in settings-hooks
grep -c 'Edit|Write|MultiEdit' templates/settings-hooks.json  # expect 0
grep -q 'Edit|Write|MultiEdit' templates/settings-hooks.json || echo 'AC2 ✓'

# AC3: no workflow-active references
! grep -rq 'workflow-active' templates/ && echo 'AC3 ✓'

# AC4: SessionStart echo has /workflow-gate
grep -q '/workflow-gate' templates/settings-hooks.json && echo 'AC4 ✓'

# AC5: skill is Beads-centric
grep -q 'Beads-discipline reference' templates/skills/workflow-gate/SKILL.md && echo 'AC5 ✓'

# AC6: 4-point close reason
grep -q '4 обязательных' templates/skills/workflow-gate/SKILL.md && echo 'AC6 ✓'

# AC7: destructive Bash matcher kept
grep -q 'rm -rf\*\|git push --force' templates/settings-hooks.json && echo 'AC7 ✓'
```

Expected: all 7 lines print `AC<n> ✓`.

- [ ] **Step 4: Final commit (only if fixes were made in Step 2)**

```bash
cd /root/projects/orchestration-kit
git status
# Commit any outstanding fixes with descriptive messages
```

If no changes remain, skip the commit.

- [ ] **Step 5: Push**

```bash
cd /root/projects/orchestration-kit
git log --oneline -15
git push
```
Expected: all D1 commits pushed to origin.

---

## Self-Review notes

**Spec coverage:** All 7 acceptance criteria from spec § 6 map to tasks:
- AC1 → Task 1
- AC2, AC4, AC7 → Task 7
- AC3 → Tasks 3, 4, 8, 9, 10
- AC5 → Tasks 2, 3, 4, 5
- AC6 → Task 6

Non-goals from spec § 2 are honoured — no tasks attempt Bash-bypass coverage, no hook-based verification enforcement.

**Placeholder scan:** No TBDs, no "similar to Task N", all code blocks and commands are concrete.

**Type / name consistency:** Slash command path, skill path, and hook field names are spelled identically across all tasks. `4 обязательных` (Russian) used consistently where `3 обязательных` currently exists in the skill; Heading text is "4 обязательных пункта".

**Potential risk noticed during review:** Task 3 deletes Phase 1.2 content (`bd prime` / `bd recall` / `bd ready`), and Task 5 re-adds it as Phase 3.0. Order matters — if an executor runs Task 3 and then stops, Beads context-loading commands are lost. Mitigation: Task 3's commit message warns; Task 5 is a direct follow-up. In practice, tasks are executed sequentially.

**One concern remaining:** Task 8 (README) is the largest edit and may have multiple small occurrences. The grep sweep in Task 10 catches anything missed.
