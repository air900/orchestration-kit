---
name: 003-remove-beads-lightrag-design
title: Remove Beads & LightRAG from orchestration-kit
date: 2026-05-13
status: spec-in-progress
---

# Remove Beads & LightRAG from orchestration-kit

## Contents

- [TL;DR](#tldr)
- [Diagnosis](#diagnosis)
- [Current state](#current-state)
- [Target state](#target-state)
- [What changes](#what-changes)
- [What does NOT change](#what-does-not-change)
- [File scope](#file-scope)
- [Risks](#risks)
- [Open questions / decisions](#open-questions--decisions)
- [Out of scope](#out-of-scope)
- [Verification plan](#verification-plan)

## TL;DR

Beads (operational memory) and LightRAG (knowledge base) are removed from the orchestration-kit core. The four-layer D1 model collapses to three layers (Template Bridge + Superpowers + orchestration-kit glue). Discipline (6-point issue, 4-point close, expert review, dispatch-with-context) is preserved but becomes tracker-agnostic — `bd` calls disappear from skills and commands; Mode 3 of `workflow-gate-check` rewrites volatile-session-state persistence onto files under `docs/orchestration/handoff/`. `deploy.sh` stops installing the beads plugin / bd CLI / running `bd init`; `settings-hooks.json` drops `bd prime` from SessionStart and PreCompact. The `knowledge-harvest` skill is **untouched** (explicit user instruction — will be rewritten in a later cycle to persist findings into project files). The `delegate-with-context` Phase 8 LightRAG subagent is dropped (knowledge-harvester invocation + its prompt-template file deleted). Approximately 23 files touched: 21 edits, 2 deletes; 7 historical/excluded files left as-is. Estimated diff: -700 / +375 lines. Delivered in 3 sequenced stages so each can be reviewed and tested independently.

## Diagnosis

Beads and LightRAG are deeply woven into four skills (`workflow-gate`, `workflow-gate-check`, `delegate-with-context`, `knowledge-harvest`), two commands (`workflow-gate`, `workflow-gate-check`), `deploy.sh`, `settings-hooks.json`, the README architecture diagram, and the generated CLAUDE.md template inside the top-level `SKILL.md`. The dependency is unidirectional: orchestration-kit calls into Beads/LightRAG, never the reverse. A clean removal is therefore possible without breaking external consumers, provided the *discipline* embedded in the skills (6-point issue, 4-point close reason with verification evidence, expert second-opinion rubric, dispatch-with-bundle workflow) is preserved in tracker-agnostic form.

Why now: the user wants the orchestration-kit to be lighter, with fewer mandatory external dependencies. Beads adds an installable plugin + a global npm binary + a `.beads/` directory + a SessionStart/PreCompact hook. LightRAG adds an MCP-server dependency that not every project will have. Removing both narrows the prerequisite list to `superpowers` + `template-bridge`, both already required for the core dev loop.

## Current state

```
orchestration-kit (4-layer D1 model)
│
├── L1 BEADS (operational memory)                        ← TO BE REMOVED
│   • plugin steveyegge/beads (claude plugin install)
│   • bd CLI (npm install -g @beads/bd)
│   • bd init, bd create/close/update/remember/decision
│   • 6-pt description + 4-pt close reason are bd-bound
│
├── L2 Template Bridge :: unified-workflow (orchestrator)
├── L3 Superpowers :: brainstorming / writing-plans / TDD
│                     / verification-before-completion
│                     / finishing-a-development-branch
└── L4 ORCHESTRATION-KIT (project-local glue)
    │
    ├── deploy.sh ────────────► installs beads plugin, bd CLI, runs bd init
    ├── settings-hooks.json ──► bd prime on SessionStart + PreCompact
    ├── SKILL.md (deploy-orch) ► generates CLAUDE.md with Beads block
    ├── README.md ───────────► L1 diagram + Task tracking with Beads section
    │
    ├── skills/
    │   ├── workflow-gate ★ entire skill = Beads discipline reference
    │   ├── workflow-gate-check ★ Mode 1 audits bd close; Mode 3 enriches bd
    │   ├── delegate-with-context ★ Phase 2 BEADS-RECONCILE; Phase 8 → LightRAG
    │   ├── knowledge-harvest ★ LightRAG only            ← LEAVE UNTOUCHED
    │   └── [arch-review, security-audit, refactor-code, 012-update-docs,
    │        find-skills-my, sync-skills, update-external-skills] (clean)
    │
    └── commands/
        ├── workflow-gate.md ──────► `bd create` + `bd close` steps
        ├── workflow-gate-check.md ► `bd close` phraseology
        └── delegate-with-context.md (clean)
```

Counted beads/lightrag mentions across the touched surface: ~395 lines across 22 files (`grep -rni -c -E 'beads|lightrag|\bbd \b'`).

## Target state

```
orchestration-kit (3-layer model)
│
├── L1 Template Bridge :: unified-workflow               (was L2)
├── L2 Superpowers :: brainstorming/plans/TDD/verification (was L3)
└── L3 ORCHESTRATION-KIT (project-local glue)            (was L4)
    │
    ├── deploy.sh ────────────► no plugin/CLI install; no bd init
    ├── settings-hooks.json ──► PreToolUse safety + log-commands; no bd prime
    ├── SKILL.md (deploy-orch) ► generates CLAUDE.md without Beads
    ├── README.md ───────────► 3-layer diagram; no Beads section
    │
    ├── skills/
    │   ├── workflow-gate ★ tracker-agnostic task-discipline reference
    │   │       (6-point template + 4-point close template usable in
    │   │        any issue tracker, PR body, or commit message)
    │   ├── workflow-gate-check ★ Mode 1/2 tracker-agnostic;
    │   │       Mode 3 persists handoff to docs/orchestration/handoff/
    │   │       NNN-<topic>-handoff.md (file-based, not bd update/decision)
    │   ├── delegate-with-context ★ Phase 2 → SPEC-DISTILL (task-spec is
    │   │       single source of truth); Phase 8 → 2 subagents
    │   │       (doc-proposer + doc-curator; no LightRAG)
    │   ├── knowledge-harvest ★ untouched (parked LightRAG; future rewrite)
    │   └── [others unchanged]
    │
    └── commands/
        ├── workflow-gate.md ──────► no bd; quality reference language only
        ├── workflow-gate-check.md ► no bd; file-based Mode 3
        └── delegate-with-context.md (unchanged)
```

## What changes

The work is staged for review/test isolation. Each stage is one PR or one commit batch.

### Stage 1 — Wire (deploy / hooks)

| File | Action | Lines (~) |
|---|---|---|
| `deploy.sh` | DELETE blocks: beads plugin install (~L153-164), bd CLI npm install (~L187-202), `bd init` block (~L432-444), beads hint in "claude CLI not found" (~L181); REWRITE summary lines (~L573, L602) | -65 / +5 |
| `templates/settings-hooks.json` | DELETE `bd prime` from SessionStart (L31-34); DELETE entire PreCompact block (L41-51); REWRITE SessionStart echo message | -20 / +3 |

### Stage 2 — Skills + commands rewrite

| File | Action | Lines (~) |
|---|---|---|
| `templates/skills/workflow-gate/SKILL.md` | REWRITE: frontmatter description → "tracker-agnostic task-discipline reference"; "Phase 2/3/4/5/6" → unified "Task discipline" section with 6-point + 4-point templates, no `bd` commands; Rules section purged of `bd` | -100 / +80 |
| `templates/skills/workflow-gate-check/SKILL.md` | REWRITE: Part 1 reframed (6-point in task description across *any* tracker; 4-point in commit body or close-comment); Mode 3 rewritten to persist handoff to file (`docs/orchestration/handoff/NNN-<topic>-handoff.md`) instead of `bd update/decision/remember`; Troubleshooting purged of bd | -120 / +90 |
| `templates/skills/workflow-gate-check/references/mode-3-details.md` | REWRITE: Gap→Action mapping table → file-based actions (commit handoff doc + append session log); cross-domain examples updated | -40 / +35 |
| `templates/skills/workflow-gate-check/references/mode-1-2-examples.md` | EDIT: `bd show description` → "task description"; `bd close` → "commit/PR close" | -15 / +15 |
| `templates/skills/workflow-gate-check/references/common-mistakes.md` | EDIT: bullets about `bd notes/decision/update` → file-based equivalents | -5 / +5 |
| `templates/skills/delegate-with-context/SKILL.md` | EDIT: Phase 2 BEADS-RECONCILE → SPEC-DISTILL; Phase 8 — 3→2 subagents (drop knowledge-harvester); References list updated | -20 / +10 |
| `templates/skills/delegate-with-context/references/beads-reconcile.md` | DELETE | -73 |
| `templates/skills/delegate-with-context/references/prompt-knowledge-harvester.md` | DELETE | -122 |
| `templates/skills/delegate-with-context/references/context-bundle.md` | EDIT: remove "Beads issue body" and `bd close` → "task spec body" | -10 / +5 |
| `templates/skills/delegate-with-context/references/triviality-classifier.md` | EDIT: remove "Beads issue type=epic OR priority ≤ 1" row | -3 |
| `templates/skills/delegate-with-context/references/doc-manifest.md` | EDIT: replace "bd ID" in spec-in-progress/plan-in-progress with "owning spec ID OR handoff filename"; redefine auto-archive trigger as `status: done` in spec front-matter | -8 / +8 |
| `templates/skills/delegate-with-context/references/status-contract.md` | EDIT: example `bd dep add` → neutral wording | -2 / +2 |
| `templates/skills/delegate-with-context/references/prompt-implementer.md` | EDIT: drop `bd` mentions | -3 / +3 |
| `templates/skills/delegate-with-context/references/prompt-spec-reviewer.md` | EDIT: drop `bd` mentions | -2 / +2 |
| `templates/skills/delegate-with-context/references/prompt-code-reviewer.md` | EDIT: drop `bd` mention | -1 / +1 |
| `templates/skills/delegate-with-context/references/prompt-doc-proposer.md` | EDIT: drop `bd` mentions | -3 / +3 |
| `templates/skills/delegate-with-context/references/prompt-doc-curator.md` | EDIT: drop "bd close <id>" in Phase 8 detection rules | -7 / +5 |
| `templates/skills/delegate-with-context/references/overlay-schema.md` | EDIT: drop bd-specific signals if present | -2 / +2 |
| `templates/skills/delegate-with-context/validate.sh` | EDIT: drop `bd` checks | -1 |
| `templates/commands/workflow-gate.md` | REWRITE: remove "Beads create/close" sections; restate "Quality standards on top" tracker-agnostic; drop `bd init` fallback | -20 / +15 |
| `templates/commands/workflow-gate-check.md` | EDIT: remove "do NOT call bd close", "bd update notes", "no bd binary" → file-based persistence | -15 / +12 |
| `templates/orchestration-config.json` | EDIT: add `documentation.paths.handoff = "docs/orchestration/handoff"` and `documentation.enabled.handoff = true` so Mode 3 of `workflow-gate-check` has a configured target | +4 |

### Stage 3 — Top-level docs

| File | Action | Lines (~) |
|---|---|---|
| `README.md` | REWRITE: ASCII diagram from 4-layer to 3-layer; DELETE entire "Task tracking with Beads" section (~L389-475); DELETE "Три источника памяти проекта" table; update Prerequisites (remove `claude plugin install beads`, remove `npm install -g @beads/bd`); update "Кто что делает" table (drop Beads row); update flow examples (drop `bd create/close` lines); fixes in Quick Start | -120 / +50 |
| `SKILL.md` (deploy-orchestration) | EDIT: Step 1 bd init detection block (L43-55) → DELETE; Step 5 generated CLAUDE.md template — drop Beads artefacts block, simplify Development Methodology section, drop `/beads:*` manual commands; Step 7 summary — drop "Beads — task tracking" line | -50 / +20 |

## What does NOT change

- `templates/skills/knowledge-harvest/` — explicit user instruction. Skill keeps its LightRAG dependency; a future cycle will rewrite it to persist findings into project files. The skill remains in the deployed roster.
- `templates/agents/*.md` — no beads/lightrag references (`planner`, `security-auditor`, `senior-reviewer`, `refactor`, `documenter`, `doc-keeper`, `observer`).
- `templates/skills/{arch-review, security-audit, refactor-code, 012-update-docs, find-skills-my, sync-skills, update-external-skills}/` — already clean.
- `templates/orchestration-config.json` — no beads logic; one path entry is added (`handoff`) but no existing behaviour is removed.
- `language-hooks/*.json` — clean.
- `install.sh` — clean (curl wrapper into deploy.sh).
- `templates/claude-gitignore` — clean.
- `.claude/settings.local.json` — local-only file (LightRAG MCP permission entries); not deployed by the kit.
- Historical / frozen artefacts: `analysis-habr-3000hours.md`, `migration-plan.md`, `docs/superpowers/specs/2026-04-14-*`, `docs/superpowers/specs/2026-04-16-*`, `docs/superpowers/plans/2026-04-14-*`, `docs/superpowers/plans/2026-04-16-*`, `docs/001-lightrag-memory-system.md`. These are frozen records of past design states. The new spec links to them for context but does not rewrite them.
- The Iron Law (verification-before-completion) remains central: every `DONE` claim still requires fresh test output / screenshots / artefacts. Only the *persistence target* (formerly `bd close --reason`) changes — the evidence itself is unchanged.
- The 6-point issue template + 4-point close template — the *concepts* remain; they become tracker-agnostic templates the user pastes into whichever tracker (or PR body, or commit message) the project uses.
- `/delegate-with-context` mechanics (DISTILL → CLASSIFY → DISPATCH → SPEC-REVIEW → CODE-QUALITY-REVIEW → DOC-PROPOSE/CURATE → SUMMARY) — preserved. Only Phase 2 and Phase 8 are slimmed.
- `/workflow-gate` entry point remains a slash command that delegates to `template-bridge:unified-workflow`. It no longer prescribes `bd create` / `bd close` — those steps in unified-workflow become "task-tracker steps (project-specific)".

## File scope

| Layer | Files edited | Files deleted | Untouched (by design) | Total touched |
|---|---|---|---|---|
| A — deploy/hooks | 2 | 0 | 0 | 2 |
| B — skills + commands + config | 17 | 2 | 1 (knowledge-harvest) | 19 |
| C — top docs | 2 | 0 | 6 (historical) | 2 |
| **Total** | **21** | **2** | **7** | **23** |

Approximate diff: −700 / +375 lines.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Existing projects already deployed with beads will keep their `.beads/` and beads-flavoured CLAUDE.md; users see drift between updated skills and stale CLAUDE.md | High | Medium | README "Migrating existing deployments" subsection with explicit steps: `rm -rf .beads/`, `claude plugin uninstall beads`, re-run `/deploy-orchestration` to regenerate CLAUDE.md |
| `/kit-update --update-skills` will refresh kit-shipped skills but a project's existing `settings.json` still merges via jq dedupe-by-matcher. SessionStart matcher `""` already exists in the target so a *removed* bd-prime hook will NOT be deleted from the target settings.json — only added. | High | Medium | Audit deploy.sh jq logic: confirm/extend the merge to remove kit-owned hook entries that no longer exist in the kit (currently it only adds); OR document that users must hand-edit settings.json. **Decision needed during Stage 1.** |
| `delegate-with-context/references/doc-manifest.md` auto-archive logic uses "bd closed" as a trigger; without bd this signal is missing | Medium | Medium | Replace trigger with `status: done` in the spec/plan file's own front-matter. Schema change documented in this spec; doc-manifest.md gets a small redesign as part of Stage 2. |
| Mode 3 file-based handoff may collide with existing `docs/orchestration/handoff/` if a project already uses that directory | Low | Low | Skill checks existence and follows global NNN- prefix rule; collision improbable since orchestration-config.json today doesn't ship a `handoff` path |
| Existing projects with active Beads will lose context-recovery via `bd prime` at session start / pre-compact | Medium | Low | Intentional — user explicitly requested removal. Documented in migration notes. Projects that *want* to keep Beads can roll back the hooks in their own settings.json. |
| `workflow-gate-check/references/mode-1-2-examples.md` contains literal `bd-id` strings (e.g., `gxu7`) embedded in narrative examples; partial edits may leave references that confuse readers | Medium | Low | Spec self-review checklist includes a final `grep -nE '\bbd-?[a-z0-9]+\b'` sweep of the touched files. |
| No automated regression tests for skills — manual verification only | Medium | Medium | After Stage 2, run a manual smoke: `/workflow-gate <test-task>` in a clean fixture project, `/workflow-gate-check 01`, `/delegate-with-context --dry-run`. Document results in the implementation plan. |
| `knowledge-harvest` skill remains LightRAG-coupled and stays in deployed roster — users may try to use it and get errors | Low | Low | Add a one-line "Known limitations" subsection in README explaining that `/knowledge-harvest` currently requires LightRAG MCP and will be rewritten. Skill description itself remains accurate (it already says `mcp__lightrag__*`). |
| Diff is large (~22 files, -700/+370) — review fatigue | Medium | Low | Three-stage delivery (A → B → C) gives reviewers focused windows. Stage A is mechanical removal (~70 lines), Stage B is the rewrite-heavy chunk, Stage C is documentation. |

## Open questions / decisions

1. **deploy.sh `--update-skills` hook removal semantics.** jq merge currently only *adds* hook entries (group_by matcher, keep last). After this change, the kit no longer ships `bd prime` in SessionStart, but a previously-deployed target's settings.json still contains it. Should `--update-skills` actively *remove* kit-owned hook entries that disappeared from the kit, or only document the manual cleanup? **Recommendation:** Stage 1 adds a small jq-based "remove kit-owned hooks that are no longer in the kit shipped settings" step, gated by a marker in the kit-owned hooks (e.g., `kit_owned: true`). If that requires reworking the matcher logic, push to a separate follow-up spec and document the manual step here.

2. **Migration helper for projects with active `.beads/`.** Ship `cleanup-beads.sh` script in the kit, or document the manual cleanup in README? **Recommendation:** README-only — the cleanup is two commands (`rm -rf .beads/`, `claude plugin uninstall beads`). A script adds maintenance surface for a one-time op.

3. **Regenerating CLAUDE.md in existing projects.** Three options: (a) `/deploy-orchestration` re-run wipes the `Claude Automations` block; (b) add a `--migrate-claude-md` flag to deploy.sh; (c) users edit manually. **Recommendation:** (a) — `/deploy-orchestration` already prompts before overwriting an existing `Claude Automations` block. Document the workflow in the migration subsection.

4. **doc-manifest auto-archive schema.** Replace bd-id link with `status: done` in spec/plan front-matter? **Recommendation:** Yes — this spec already defines its own `status: spec-in-progress` front-matter; we adopt the same convention across all specs/plans the curator tracks. Schema documented in `doc-manifest.md` during Stage 2.

5. **Mode 3 handoff path.** `docs/orchestration/handoff/NNN-<topic>-handoff.md` directly, or under `docs/orchestration/reports/handoff/`? **Recommendation:** top-level `docs/orchestration/handoff/`; this is the rationale for the `orchestration-config.json` edit in Stage 2. Projects that want to disable the handoff output set `documentation.enabled.handoff = false`.

These five recommendations are the working defaults the implementation plan will adopt unless the user overrides during plan review.

## Out of scope

- Rewriting `knowledge-harvest` skill to persist into project files (separate cycle).
- Retroactive NNN- renaming of the two existing specs in `docs/superpowers/specs/` (separate cleanup commit).
- Updating downstream projects (web-scripts, hr-bot, frm-client, text4site-create-modified, mtproxy-telegram, check-parameters-sql-server-for-1c, seo-audit) that have already consumed the kit. They follow via `/kit-update --update-skills` + the documented migration steps.
- Rewriting frozen historical specs and plans in `docs/superpowers/specs/2026-04-*` and `docs/superpowers/plans/2026-04-*`. They remain as design history.
- Touching `.claude/settings.local.json` — local user permissions, out of repo scope.

## Verification plan

After each stage:

**Stage 1 verification.** On a clean fixture target (no prior `.claude/`):
- `./deploy.sh /tmp/fixture-project atomic` — observe summary contains no Beads lines, no `bd init` invocation, no plugin install attempts.
- Inspect generated `.claude/settings.json` — `hooks.PreCompact` absent; `hooks.SessionStart` contains no `bd prime` command.
- Re-run on an already-deployed project (`./deploy.sh /path --update-skills`) — settings.json updated correctly per the decision on open-question #1.

**Stage 2 verification.** Manual smoke in a representative project:
- `/workflow-gate "test task"` — flow proceeds without `bd` mentions.
- `/workflow-gate-check 01` against a fresh commit — Part 1 (compliance) and Part 2 (rubric) produce a verdict; no `bd close` instructions.
- `/workflow-gate-check 03` after a session — produces a handoff file at `docs/orchestration/handoff/NNN-<topic>-handoff.md`, awaits user approval, then commits.
- `/delegate-with-context --dry-run` on a small task — Phase 1/2 distil produces a task spec; Phase 8 plans 2 subagents (doc-proposer + doc-curator), not 3.
- `grep -rni -E 'beads|lightrag|\bbd \b' templates/ deploy.sh README.md SKILL.md` — only `knowledge-harvest/` LightRAG calls remain.

**Stage 3 verification.**
- `README.md` renders correctly (visual diff vs current).
- `SKILL.md` (deploy-orchestration) — re-run `/deploy-orchestration <task>` in a fresh fixture — generated CLAUDE.md contains no Beads section.

**Cross-stage Iron Law evidence.** For every claim of "done" on each stage, attach: command run + exit code + last lines of stdout (or "no output" if empty), and any screenshots if a UI surface is affected (none expected here — this is a docs/config change).
