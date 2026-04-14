# Workflow-Gate D1 — Design

**Date:** 2026-04-14
**Status:** Design approved (sections 1-5), pending spec review.
**Skill used:** `superpowers:brainstorming`
**Next step:** `superpowers:writing-plans` after user approves this spec.

---

## 1. Problem statement

Three concrete failures observed in a real web-scripts session log (2026-04-14):

1. **Broken entry-point contract.** User typed `/workflow-gate /superpowers:brainstorm`. Neither triggered the intended skill. `/workflow-gate` is defined as a skill (`SKILL.md`), not as a slash command (`commands/*.md`), so Claude Code does not resolve it. `/superpowers:brainstorm` is deprecated — its command file literally tells the agent "this command is deprecated, tell the user to use the skill instead". The working form is `/superpowers:brainstorming` (skill).

2. **PreToolUse hook creates plan-mode deadlock.** The hook `test -f .workflow-active || exit 2` on `Edit|Write|MultiEdit` blocks legitimate plan-mode writes to `/root/.claude/plans/*.md` — a path the agent must write to during plan mode. The agent cannot create `.workflow-active` from within plan mode (it's a non-readonly action), producing a deadlock.

3. **Hook CWD bug.** Diagnostic capture confirmed: `cwd` passed to the hook is the agent's current working directory (e.g., `/root/projects/memory-lightrag`), not the project root. `CLAUDE_PROJECT_DIR` is correctly set. `test -f .workflow-active` checks the wrong directory when the agent crosses project boundaries.

**Behavioural symptom:** agent rationalises around the broken contract — in the log, it skipped brainstorm entirely, citing "plan mode forbids creating the marker" (a fabricated constraint). This is the unsolved "agent skips skills under pressure" problem (Marc Bara 650-trial study; obra/superpowers release notes v4.3.0-v5.0.7). No technical approach in 2026 guarantees 100% compliance — this spec does not attempt to.

### Deeper structural issue

Our `orchestration-kit` was reinventing a workflow that **already exists** in the ecosystem:

- `template-bridge:unified-workflow` skill already implements the 9-step flow (beads → brainstorm → plan → sub-tasks → isolate → TDD → verification → finish → close).
- `superpowers:verification-before-completion` already enforces "NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE".
- `superpowers:test-driven-development` enforces RED-GREEN-REFACTOR.
- `superpowers:using-superpowers` injects the 1% rule at SessionStart.

Our `workflow-gate` skill had grown to duplicate brainstorm/plan/TDD phases inline. This creates conflicting signals (agent sees two workflows) and increases maintenance surface.

## 2. Non-goals

- **100% guarantee that agent invokes brainstorm.** Research-level unsolved. Best available is `using-superpowers` + `<HARD-GATE>` in brainstorming — both already in Superpowers.
- **Covering Bash-based file-write bypass.** GitHub issues #29709, #6876 document that PreToolUse hooks on `Edit|Write|MultiEdit` can be routed around via `sed -i`, `cat > file`, `echo >`, heredocs, `perl -e`, etc. Pattern arms-race is out of scope.
- **Deploying the fix.** This spec is orchestration-kit templates only (the canonical source). Rollout to existing projects (`web-scripts`, `hr-bot`, `seo-audit`, `frm-client`, `check-parameters-sql-server`, `mtproxy-telegram`) is a separate task.

## 3. Design — D1 (use Template Bridge as base, layer our additions)

### 3.1. Architecture

Four layers, each with single responsibility:

```
┌─ L1 — BEADS — operational memory
│    Plugin: steveyegge/beads
│    Our contribution: 6-point issue description standard,
│    4-point close-reason standard (incl verification evidence),
│    Playwright-screenshots-for-UI convention via bd remember
│
├─ L2 — TEMPLATE BRIDGE — workflow orchestrator  ★ NEW in our stack
│    Plugin: maslennikov-ig/template-bridge
│    Skill used as-is: unified-workflow (9-step flow)
│    Bonus: template-catalog + /browse-templates (413+ on-demand agents)
│
├─ L3 — SUPERPOWERS — dev-loop skills
│    Plugin: obra/superpowers, used as-is:
│    brainstorming, writing-plans, test-driven-development,
│    verification-before-completion, finishing-a-development-branch,
│    using-superpowers (SessionStart injection with 1% rule)
│
└─ L4 — ORCHESTRATION-KIT — thin glue, project-local
     • .claude/commands/workflow-gate.md   (NEW)
     • .claude/skills/workflow-gate/SKILL.md  (SHRINK — Beads-only)
     • .claude/settings.json  (simplified hooks)
```

Beads is vertical (spans all phases); Template Bridge is horizontal (the dev-loop); Superpowers supplies the skills Template Bridge invokes; our kit contributes a single entry-point slash command and Beads-discipline additions.

### 3.2. Components

#### 3.2.1. `/workflow-gate` slash command — NEW

**Path:** `templates/commands/workflow-gate.md` (deployed to `.claude/commands/workflow-gate.md` per project)

**Contents (exact):**

```markdown
---
description: Orchestrate task — Beads → Template Bridge unified-workflow, with our quality standards layered on top
---

User's task: $ARGUMENTS

Follow `template-bridge:unified-workflow` skill for the overall flow.

Apply these project standards on top (from `workflow-gate` skill):

1. **Beads create** — use 6-point description (see workflow-gate skill § Issue Creation).
2. **Beads close** — use 4-point reason (see workflow-gate skill § Closing). Point 4 (Verification) MUST include either: a fresh test command + its output snippet captured in this session, or paths to screenshot/artefact files produced during `superpowers:verification-before-completion`. "Tested — works" without artefacts is not acceptable.
3. **UI changes** — Playwright screenshot at 1920x1080 on affected pages is mandatory before close (recorded as bd remember convention).

If Template Bridge is not installed in this project, fall back to invoking `superpowers:brainstorming` directly; warn user that unified-workflow is the intended orchestrator.
```

#### 3.2.2. `workflow-gate` skill — SHRINK

**Path:** `templates/skills/workflow-gate/SKILL.md`

**Remove:**
- Phase 1 "Session Start — Activate gate" (`touch .workflow-active` is obsolete).
- Phase 1.3 "Launch unified workflow" (now invoked via slash command, no duplication).
- Phase 5.5 "Снять маркер `rm -f .workflow-active`" (no marker).
- Any prose framing workflow-gate as "unlock mechanism".

**Keep and refine:**
- Phase 2 — **Issue Creation Quality Standard** (6-point description). Unchanged.
- Phase 3 — **During Work** (notes immediately, bd remember, commits with issue ID). Unchanged.
- Phase 4 — **Closing Quality Standard**. Expand from 3-point to 4-point reason:
  1. Решение
  2. Root cause
  3. Prevention
  4. **Verification** — concrete artefacts: test command + output snippet; screenshot paths; before/after for bug fixes. Without point 4, reason is invalid.
- Phase 5 — **Session End (Land the Plane)**. Keep notes/remember/git push. Remove marker-removal step.
- Phase 6 — **Maintenance** (bd doctor, compact, upgrade). Unchanged.

**Add:**
- Preamble clarifying: "This skill is a reference for **Beads discipline**. Overall workflow orchestration lives in the `/workflow-gate` slash command, which invokes `template-bridge:unified-workflow`."

Expected size reduction: ~40-50% of current content.

#### 3.2.3. `.claude/settings.json` hooks — simplify

```json
{
  "permissions": { "allow": [] },
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
          { "type": "command", "command": "bd prime 2>/dev/null || true" },
          { "type": "command", "command": "echo 'Task workflow: /workflow-gate <task>. Beads discipline: see workflow-gate skill. Verification: superpowers:verification-before-completion (Iron Law).'" }
        ]
      }
    ],
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bd prime 2>/dev/null || true" }
        ]
      }
    ]
  }
}
```

**Removed:**
- `Edit|Write|MultiEdit` PreToolUse matcher (source of the deadlock and CWD bug).
- `SessionStart` `rm -f .workflow-active` (no marker).
- "WORKFLOW: Edits BLOCKED" echo (false promise — hook is gone).

**Kept:**
- Destructive Bash matcher (unrelated to workflow-gate; general safety).
- `bd prime` on SessionStart and PreCompact.

### 3.3. Data flow

```
User types: /workflow-gate fix LINE-CARD-CROSSING P1

  ▼ Claude Code resolves slash command (now exists)
  ▼ commands/workflow-gate.md loads with $ARGUMENTS
  ▼ Agent invoked template-bridge:unified-workflow skill + our standards overlay

  ▼ unified-workflow executes:
     1. bd create (our 6-point overlay applied here)
     2. superpowers:brainstorming (agent writes spec to docs/superpowers/specs/)
     3. superpowers:writing-plans (plan file)
     4. sub-task decomposition in bd
     5. superpowers:using-git-worktrees (if non-trivial)
     6. TDD implement via superpowers:test-driven-development
     7. superpowers:verification-before-completion ← Iron Law enforced
     8. superpowers:finishing-a-development-branch
     9. bd close (our 4-point overlay applied here — reason must cite step 7 artefacts)

  ▼ During steps 2-8: bd update --notes at each inflection point
  ▼ Side findings: bd create + bd dep add --type discovered-from
  ▼ Insights: bd remember
  ▼ Commits: message includes bd ID
```

Session resume flow: SessionStart `bd prime` surfaces open issues; agent resumes from `bd show <id>` notes without needing to re-enter `/workflow-gate`.

### 3.4. Testing / Verification guarantee

The user's explicit requirement: **tested output delivered, not "tested" claim**. Guaranteed by two independent layers:

1. **`superpowers:verification-before-completion`** (existing, part of unified-workflow Step 7) — Iron Law: "If you haven't run the verification command in this message, you cannot claim it passes."

2. **Our 4-point close-reason standard** (Phase 4 of workflow-gate skill) — point 4 must cite concrete test output / screenshot paths. Without it, reason is invalid and must be rewritten.

Both are prose-enforced (skills), not hook-enforced. Hook-level verification of test output is out of scope (would require parsing test frameworks, brittle). The user accepts this limit in exchange for simplicity.

### 3.5. Error handling

| Scenario                                        | Behaviour                                                                 |
|-------------------------------------------------|---------------------------------------------------------------------------|
| Template Bridge not installed                   | `/workflow-gate` command text includes fallback: invoke `superpowers:brainstorming` directly; warn user |
| Superpowers not installed                       | workflow-gate skill has minimal inline Beads-discipline reference; workflow degrades to "Beads + ad-hoc" |
| Beads not initialised (`.beads/` missing)       | `/workflow-gate` first step prompts `bd init`; does not proceed until initialised |
| Playwright not installed for UI project         | Agent proposes install; close may proceed without but 4-point reason flagged invalid by skill |
| No tests exist for changed code                 | `verification-before-completion` requires creating them (TDD skill); "no tests" not an acceptable reason |
| Agent attempts `bd close` without evidence      | Close-reason quality standard in workflow-gate skill rejects; agent must rewrite reason with point 4 |

## 4. Migration impact

### 4.1. Orchestration-kit templates (in-scope for this spec)

- `templates/commands/workflow-gate.md` — new file
- `templates/skills/workflow-gate/SKILL.md` — content reduction
- `templates/settings-hooks.json` — hook simplification
- `templates/CLAUDE.md` section — update messaging (no "Edit/Write ЗАБЛОКИРОВАНЫ")
- `README.md` (orchestration-kit) — update architecture diagram and flow description
- `migration-plan.md` — update to reflect D1

### 4.2. Existing projects (out of scope, separate rollout)

`web-scripts` is the immediate candidate (it triggered this redesign). Others: `hr-bot`, `seo-audit`, `frm-client`, `check-parameters-sql-server`, `mtproxy-telegram`. Each requires:
- Create `.claude/commands/workflow-gate.md` (new file)
- Shrink `.claude/skills/workflow-gate/SKILL.md` (remove obsolete phases)
- Patch `.claude/settings.json` (remove Edit/Write matcher and marker lifecycle)
- Update project CLAUDE.md (Automations section)
- Verify Template Bridge plugin is enabled

This rollout is deferred to its own spec/plan.

## 5. Risks and mitigations

| Risk                                                          | Mitigation                                                                    |
|---------------------------------------------------------------|-------------------------------------------------------------------------------|
| Removing Edit/Write hook reduces "physical backstop"           | Log shows the backstop didn't work as intended — agent rationalised around it. We're trading theatrical protection for a functional entry point. |
| Agent still skips brainstorm under pressure                    | Accepted limit. Superpowers' `using-superpowers` 1% rule + `<HARD-GATE>` in brainstorming remain the best available tools. Not solved by any known technique in 2026. |
| Template Bridge changes its unified-workflow contract          | Pin to a known version in README; update when Template Bridge releases a major version. |
| Deprecated `/superpowers:brainstorm` command continues to mislead users | Update all our docs/messages to use skill name `superpowers:brainstorming`. Include a bd remember. |
| User forgets `/workflow-gate` and edits directly               | No hook block; agent can edit. Relies on SessionStart echo + CLAUDE.md guidance. Accepted trade-off. |

## 6. Acceptance criteria

This design is ready for implementation planning when:

1. `/workflow-gate <task>` in a project with Template Bridge installed: Claude Code resolves the slash command, agent reads `commands/workflow-gate.md`, and the agent's next action is to invoke `template-bridge:unified-workflow` skill (not a fabricated workflow).
2. No PreToolUse hook block prevents plan-mode writes to `/root/.claude/plans/*.md`.
3. `.workflow-active` marker does not exist and is never created.
4. SessionStart hook outputs a single coherent message referencing `/workflow-gate` slash command; no "Edits BLOCKED" text.
5. `workflow-gate` SKILL.md is Beads-centric only; references unified-workflow for dev-loop.
6. 4-point close-reason standard (including Verification) is documented in workflow-gate SKILL.md Phase 4.
7. Destructive Bash matcher still blocks `rm -rf`, `git push --force`, `git reset --hard`.

## 7. Out of scope (deferred)

- Rollout to existing projects (separate plan).
- Covering Bash-based file-write bypass (pattern arms-race; hooks can't win).
- Hook-enforced verification of test output (requires test-framework parsing; brittle).
- EnterPlanMode interception (Superpowers v4.3.0 handles it at plugin level; our layer doesn't need to).
- HARD-GATE XML blocks in our skills (no research-backed efficacy; Superpowers uses them because their skill-family needs strong internal gating; our thin-glue skill does not).

## 8. Source evidence

- Log excerpt from web-scripts session (2026-04-14, session `8a353475-9ca7-47b0-b85d-bd7d0f706c58`): agent skipped `/superpowers:brainstorm` (deprecated command) and `/workflow-gate` (non-existent slash command), then hit PreToolUse block on plan-mode write.
- `CLAUDE_FILE_PATHS` env var confirmed empty via diagnostic hook on 2026-04-14; stdin JSON (`tool_input.file_path`) is the documented access path.
- GitHub issues #29709 (Bash bypass), #6876 (SED bypass), #24327 (exit 2 stops agent), #9567 (CLAUDE_FILE_PATHS empty).
- `obra/superpowers/5.0.7/hooks/hooks.json` — SessionStart async:false injection of `using-superpowers`.
- `template-bridge/1.0.0/skills/unified-workflow/SKILL.md` — pre-existing 9-step orchestrator.
- Marc Bara, "Claude Skills Have Two Reliability Problems, Not One" — step-following inside skills remains unsolved.
