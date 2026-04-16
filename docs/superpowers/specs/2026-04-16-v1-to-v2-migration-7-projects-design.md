# Design: v1 → v2 Migration of 7 Projects (Manual, Custom-Preserving)

**Date:** 2026-04-16
**Author:** Claude + @air900 (brainstorming session)
**Status:** Proposed (awaiting user approval before plan-stage)
**Related:** `migration-plan.md`, `analysis-habr-3000hours.md` §8

---

## 1. Context

Orchestration Kit v1 (pipeline-architecture with 11 agents and 9 SubagentStop hooks) was superseded by v2 (lightweight, 7 on-demand agents + Superpowers/Beads delegation) in kit commit `4aa4e90` on 2026-04-12.

At the time of kit-refactor, only **3 projects** were updated to v2:
`web-scripts`, `pvbridge-ru`, `test-orchestration`.

The rest of the portfolio (17 dirs under `/root/projects/`) was left on v1 or in other states. The user now wants to converge **7 specific projects** onto v2 without losing any project-specific customisations accumulated since initial v1 deployment.

Additionally, kit has gained one new feature today (2026-04-16): a Bash audit-log PreToolUse hook (`.claude/hooks/log-commands.sh`) installed by `deploy.sh`. Migrated projects receive this automatically.

## 2. Goal & Success Criteria

**Goal:** Replace v1 orchestration artefacts with v2 in 7 projects while preserving 100% of project-specific customisations (custom skills, custom agents, custom CLAUDE.md content, docs/orchestration/ history, settings.local.json, orchestration-config.json).

**Success criteria (per project):**

1. Exactly 7 kit-agents present in `.claude/agents/` (plus any pre-existing custom agents unchanged)
2. Kit-skills (`012-update-docs`, `arch-review`, `refactor-code`, `security-audit`, `workflow-gate`, `sync-skills`, `knowledge-harvest`, `find-skills`) updated to v2 contents; v1 skills (`orchestrate/`, `implement/`, `code-review/`) physically absent; every other skill dir preserved byte-for-byte
3. `.claude/settings.json` has no `"SubagentStop"` key; has v2 PreToolUse/PostToolUse/SessionStart/PreCompact hooks; `permissions` array preserved
4. `.claude/settings.local.json` unchanged
5. `.claude/orchestration-config.json` unchanged (if was present)
6. `.claude/hooks/log-commands.sh` present and executable
7. `.claude/.gitignore` excludes `command-log.txt`
8. `.beads/` initialised (if project has git)
9. `CLAUDE.md` content outside the "## Claude Automations" section unchanged; section itself replaced with v2 template
10. `docs/orchestration/` file count equal to pre-migration count (exact equality, no file loss)
11. `.agents/skills/` symlinks unchanged

**Success criteria (global):** All 7 projects individually pass. Git-log shows exactly one pre-migration commit and one post-migration commit per project (allowing 1:1 rollback).

## 3. Scope

### In-scope (7 projects, sequential, risk-ordered)

| # | Project | Risk | Rationale |
|---|---------|:---:|---|
| 1 | `mtproxy-telegram` | 🟢 low | Clean v1, few customisations |
| 2 | `check-parameters-sql-server-for-1c` | 🟢 low | Utility project, clean v1 |
| 3 | `frm-client-automatization` | 🟢 low | Clean v1 |
| 4 | `vpn-manager-openwrt-x-ui` | 🟡 medium | Unusual state (10 agents / 0 skills) — inventory required before delete |
| 5 | `hr-bot-project` | 🟡 medium | Production project on vsem-onboard.ru — careful with CLAUDE.md |
| 6 | `text4site-create-modified` | 🔴 high | ~13 custom skills (avers010, afr020, etc.) |
| 7 | `seo-audit` | 🔴 high | ~26 custom skills (searchfit-seo family) |

### Out-of-scope (excluded projects, for the record)

- `orchestration-kit` — the kit itself
- `web-scripts`, `pvbridge-ru`, `test-orchestration` — already migrated
- `paperclip`, `remnawave`, `api-kaiten-n8n-webhook-app`, `memory-lightrag`, `n8n-edit-workflow`, `topdog-monitor`, `test-orch-gh` — excluded by user decision (may be external mirrors, test sandboxes, or no-orchestration dirs)

## 4. Analysis: v1 → v2 delta (what commit `4aa4e90` did)

### 4.1 Removed agents (4 files)

| File | Reason | v2 replacement |
|---|---|---|
| `worker.md` | Generic implementer | Superpowers TDD cycle |
| `test-runner.md` | Test executor | Superpowers verification-before-completion |
| `reviewer.md` | Code reviewer | Superpowers requesting-code-review |
| `debugger.md` | Bug fixer | Superpowers systematic-debugging |

### 4.2 Removed skills (3 directories)

| Skill | Reason | v2 replacement |
|---|---|---|
| `orchestrate/` | Central pipeline orchestrator | Beads (`bd create/ready/close`) + workflow-gate |
| `implement/` | Task implementation | Superpowers `brainstorm → plan → TDD` |
| `code-review/` | PR review workflow | Superpowers `requesting-code-review` |

### 4.3 Removed hooks (entire `SubagentStop` block)

v1 `settings.json` had 9 SubagentStop matchers (`worker`, `test-runner`, `reviewer`, `debugger`, `security-auditor`, `planner`, `documenter`, `doc-keeper`, `observer`), each emitting `additionalContext` JSON to chain the next pipeline stage. This rigid state-machine is replaced by Beads-driven task orchestration and on-demand agent invocation.

### 4.4 Retained & updated (overwrite-in-place)

- **7 agents:** `planner`, `security-auditor`, `documenter`, `doc-keeper`, `observer`, `senior-reviewer`, `refactor`
- **4 skills:** `012-update-docs`, `arch-review`, `refactor-code`, `security-audit`
- **deploy-orchestration skill** (Phase 2 of deploy)
- **Language hooks** (`language-hooks/*.json` for PostToolUse formatters/linters)

### 4.5 Added in v2 (new)

- **4 skills:** `workflow-gate`, `sync-skills`, `knowledge-harvest`, `find-skills`
- **PreToolUse hooks:** destructive-Bash block, audit-log (new 2026-04-16)
- **SessionStart hook:** `bd prime`
- **PreCompact hook:** `bd prime`
- **`templates/references/*.md`:** shared reference docs for cross-agent consumption
- **Beads init** (if `.beads/` missing)
- **`.claude/hooks/log-commands.sh`** + `.claude/.gitignore`

## 5. Preservation rules (whitelist-by-absence)

**The guiding principle:** the removal list is a closed whitelist. Anything whose name is NOT in the removal list is custom, preserved by default.

### 5.1 Never touched

- Any agent file whose name ∉ `{worker, test-runner, reviewer, debugger, planner, security-auditor, documenter, doc-keeper, observer, senior-reviewer, refactor}`
- Any skill directory whose name ∉ `{orchestrate, implement, code-review, 012-update-docs, arch-review, refactor-code, security-audit, workflow-gate, sync-skills, knowledge-harvest, find-skills, deploy-orchestration}`
- `CLAUDE.md` content above and below the "## Claude Automations" section
- `.claude/settings.local.json` (entire file)
- `.claude/orchestration-config.json` (skipped by `deploy.sh` if present)
- `.agents/skills/` (symlinks to external skills)
- `docs/orchestration/` (full tree — drafts, reports, plans, issues, observer-reports)
- All project working files outside `.claude/` and `.beads/`

### 5.2 Enforcement

Preservation is enforced at **two layers**:

1. **Procedural (our discipline):** explicit `rm` commands target exactly the v1 whitelist, nothing else
2. **Structural (deploy.sh):** `deploy.sh` physically cannot delete files whose names are not in `templates/` — it only copies same-name templates over existing files

Even if Layer 1 is skipped by mistake, Layer 2 guarantees custom skills survive.

## 6. Per-project procedure (6 phases)

### Phase 0. Pre-flight (inventory + rollback point)

```
cd /root/projects/$PROJECT
git status
```

If uncommitted work exists that is *not* orchestration-related, create rollback commit:

```
git add -A && git commit -m "pre-migration snapshot"
```

Run **inventory** (read-only): enumerate agents/skills/hooks, classify as v1 / kit-v2 / custom. Count `docs/orchestration/*` files. Present to user. Wait for "ok".

### Phase 1. Delete v1 artefacts (targeted)

```bash
rm -v -f .claude/agents/{worker,test-runner,reviewer,debugger}.md
rm -rv  .claude/skills/{orchestrate,implement,code-review} 2>/dev/null || true
jq 'del(.hooks.SubagentStop)' .claude/settings.json > .tmp && mv .tmp .claude/settings.json
```

### Phase 2. Install v2

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/$PROJECT atomic
```

`deploy.sh` performs 11 steps: plugin check → language detect → dir creation → overwrite 7 agents → overwrite 8 skills → copy references → copy hooks + chmod → create `.claude/.gitignore` → copy orchestration-config.json (skip if exists) → merge settings.json hooks via jq → `bd init` if needed.

### Phase 3. CLAUDE.md surgery

- Read target `CLAUDE.md`
- Locate "## Claude Automations" section (or v1-equivalents: `## Orchestration`, `## Agents`, `## AI Automations`)
- Show diff to user
- After approval, replace section content using `Edit` tool
- Everything else preserved

### Phase 4. Verification (7 checks)

1. `ls .claude/agents/` — 7 kit-agents + custom, no v1 leftovers
2. `cat .claude/settings.json | jq '.hooks | keys'` — no `SubagentStop`
3. `grep -rl "/orchestrate\|/implement\|/code-review" .claude/ CLAUDE.md` — empty
4. `grep Superpowers CLAUDE.md && grep Beads CLAUDE.md` — both present
5. `ls .beads/` — initialised
6. Pre-count vs post-count of `docs/orchestration/*` — equal (skipped for projects lacking `docs/orchestration/`, e.g. `vpn-manager-openwrt-x-ui`)
7. Live test of audit-log hook: `echo payload | .claude/hooks/log-commands.sh && tail -1 .claude/command-log.txt`

### Phase 5. Report + checkpoint

- 7-check pass/fail table
- `git diff --stat` summary
- List of custom artefacts preserved (for visual confirmation)
- Wait for user "ok" → next project

### Rollback (any phase)

```bash
git reset --hard HEAD~1    # if pre-migration commit was created
# or
git reset --hard HEAD      # if working from clean state
```

## 7. Sequence, batching, and top-level rollback

### 7.1 Sequence

Projects processed sequentially in the order in §3. Each is an independent transaction. Failure in project N does not affect already-completed projects [1..N-1] or pending projects [N+1..7].

### 7.2 Progress tracking

Harness TaskList holds 7 tasks (one per project). State transitions:
- `pending` when task is created (before work starts)
- `in_progress` when Phase 0 of that project begins
- `completed` only after user approves the Phase 5 checkpoint report

Harness restart / session break → next session resumes from first `in_progress` or `pending` task.

### 7.3 Three-level rollback

| Level | Scope | Mechanism |
|---|---|---|
| L1 | Single project | `git reset --hard HEAD~1` in project dir |
| L2 | Batch stop | Checkpoint decision: rollback-current / skip-current / pause-all / continue |
| L3 | Mass rollback | On user request: iterate through completed projects, `git reset --hard <pre-migration-commit>` in each. Pre-migration commits remain visible in git log permanently. |

## 8. Post-migration updates

After all 7 projects pass:

- Update `migration-plan.md` status table: 5 Pending → Done; add `vpn-manager-openwrt-x-ui` and `text4site-create-modified` as Done with date 2026-04-16
- Update `analysis-habr-3000hours.md` §8 migration status table
- Write single summary report: aggregate files deleted / added / overwritten, custom artefacts preserved per project, any surprises encountered
- Commit these doc updates to orchestration-kit

## 9. Alternatives considered

### 9.1 Batch script (`migrate-to-v2.sh`)

**Rejected** by user. Would have been faster (~10-15min for all 7) but sacrifices visibility and per-project control. Risk of silent custom-skill loss on a single bug.

### 9.2 Risk-grouped semi-automation (3 groups of 2-3 projects each)

**Rejected** by user in favour of fully-manual per-project flow. Would have reduced checkpoints from 7 to 3 but introduced shared failure modes within a group.

### 9.3 Raw `cp`/`rm` decomposition of `deploy.sh`

**Rejected** as impractical: `deploy.sh`'s `jq --slurpfile` settings.json merge (preserving permissions, deduplicating hooks by matcher, grouping with `map(last)`) is non-trivial to replicate reliably by hand. `deploy.sh` is treated as a proven tool already part of the kit, not a new script.

## 10. Risks & mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| `deploy.sh` overwrites unexpected file | Low | High | Structural: names not in `templates/` cannot be touched |
| Custom skill with name collision against v2 addition (e.g., project has a `find-skills/` that differs from kit's) | Low | Medium | Flagged in Phase 0 inventory — user decides (backup custom / accept overwrite) |
| CLAUDE.md "## Claude Automations" section missing or named differently | Medium | Low | Phase 3 is manual — I show the diff, user approves before Edit |
| `vpn-manager-openwrt-x-ui` (10/0 state) has non-standard agent set | High | Medium | Phase 0 inventory will reveal this before any delete — may require tailored procedure or skip |
| Pre-migration uncommitted work contains secrets | Low | High | `git status` in Phase 0 surfaces uncommitted files before any commit; user reviews list |
| `bd init` fails (bd CLI missing, git missing) | Low | Low | All 7 projects have git; deploy.sh gracefully handles bd-missing case |
| Context exhaustion during long migration | Medium | Medium | TaskList + per-project checkpoint → harness restart resumes cleanly |

## 11. Out of scope (explicit non-goals)

- Migration of the 10 excluded projects (may be done later under separate design)
- Upgrading Superpowers / Beads / Template Bridge plugin versions
- Re-organising `docs/orchestration/` contents
- Changing project-level CLAUDE.md content outside the "## Claude Automations" section
- Cleanup of pre-v1 artefacts (none expected in these projects)

---

**End of design. Awaiting user approval before invoking `superpowers:writing-plans` to produce the implementation plan.**
