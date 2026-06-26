---
description: Orchestrate a task — self-contained dev-loop (superpowers skills) + our quality standards
---

User's task: $ARGUMENTS

## Orchestration flow (self-contained)

Drive the end-to-end dev loop with the superpowers skills directly — no external
orchestrator plugin required:

1. **Task record** — 6-point description (see `wf-gate` skill § Phase 2) in your
   project tracker, PR body, or a file under `docs/orchestration/issues/`.
2. **Brainstorm** — `superpowers:brainstorming` (design before code).
3. **Plan** — `superpowers:writing-plans` (decompose into 2-5 min tasks).
4. **Sub-tasks** — record concrete sub-tasks in the same place; note blockers inline.
5. **Isolate** — `superpowers:using-git-worktrees` for non-trivial work.
6. **Implement** — for each sub-task: `superpowers:test-driven-development`
   (RED → verify fail → GREEN → verify pass → REFACTOR), commit after each green,
   `superpowers:requesting-code-review`, then close the sub-task.
7. **Verify** — `superpowers:verification-before-completion`.
8. **Finish** — `superpowers:finishing-a-development-branch`.
9. **Close** — 4-point reason (see `wf-gate` skill § Phase 4).

## Our quality standards on top (from wf-gate skill)

1. **Task description** — use the 6-point template (see wf-gate skill § Phase 2):
   what, where in code, how to reproduce, what's found, context, resources.
   Lives wherever your project tracks tasks (issue tracker, PR body, or a file
   under `docs/orchestration/issues/`).

2. **Task close** — use the 4-point reason (see wf-gate skill § Phase 4):
   1) solution, 2) root cause, 3) prevention, 4) **verification evidence**.
   Point 4 MUST include either a fresh test command + its output snippet
   captured in this session, or paths to screenshot/artefact files produced
   during `superpowers:verification-before-completion`.
   "Tested — works" without artefacts is NOT acceptable.

3. **UI changes** — Playwright screenshot at 1920x1080 on affected pages is
   mandatory before close.

## On-demand specialists

When a task needs expertise not covered by installed skills or agents, pull a
specialist from claude-code-templates (413+ agents across 26 categories):

```bash
npx claude-code-templates@latest --agent <category/name> --yes
```

## Fallback

- If Superpowers is not installed: this wf-gate skill still provides the
  task-discipline reference (6-point description, 4-point close); warn the user
  that the dev-loop skills (brainstorming, TDD, verification) are missing.

## Deprecated commands — do NOT use

- `/superpowers:brainstorm` (without `ing`) — deprecated, shows a text telling
  you to use the skill instead. Use skill `superpowers:brainstorming`.
