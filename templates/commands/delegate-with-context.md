---
description: Delegate the current chat decision to subagents with full context bundle, mandatory verification evidence, two-stage review, end-of-run doc-proposer + knowledge-harvest. Skill is portable — uses CLAUDE.md and optional overlay.md for project-specific rules.
---

Invoke skill `delegate-with-context`.

Optional ARGUMENTS:

- `--dry-run` — print planned subagent prompts without dispatching (debugging)
- one-line intent string — used as a hint for Phase 1 (DISTILL); if absent,
  controller distills the chosen option from the current chat context

Phase 1 (DISTILL) self-introspects whatever context is in the session and
adapts. Valid sources of the task:

- A prior options discussion ending with a pick
- A short pick (e.g., the architect typed `1` or `B`) referring to a list you
  just offered, then the skill name
- A handoff blob pasted from another session
- The architect's invocation message itself describing what to delegate

The triviality classifier (Phase 3) decides complexity — simple task gets one
agent, complex gets more. You do NOT need a prior discussion to invoke this skill.

Refuse only when there is **no actionable task content anywhere** in the loaded
context:

> "I don't see a task to delegate in this session. Either describe the task
> in your message, paste handoff context from another session, or have a
> quick discussion first, then re-invoke."

Otherwise: enter Phase 1 (DISTILL) of the skill flow as documented in
`.claude/skills/delegate-with-context/SKILL.md`.
