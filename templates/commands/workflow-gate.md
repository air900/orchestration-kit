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
