---
description: Audit just-completed task — workflow-gate protocol compliance + band-aid vs structural rubric, independent second opinion before bd close
---

User's context on what was just done: $ARGUMENTS

## Invoke the audit

Invoke skill `workflow-gate-check`. Follow its procedure end-to-end:

1. **Gather inputs** — `bd show <id>`, `git log --oneline -10`, `git show <commit>`, `git diff <commit>^..<commit>`, user narrative, verification artefacts.
2. **Part 1** — run the six protocol-compliance checklists (A through F), tag each miss with severity.
3. **Part 2** — run the band-aid vs structural rubric. Read the actual diff, not just the user's description.
4. **Verdict** — combine findings into `BLOCKED` / `WARNINGS` / `APPROVED`.
5. **Output** — use the skill's exact output template.

## Non-negotiables

- Do NOT rubber-stamp. The point of this command is an **independent second opinion**.
- Do NOT grade the claim "I did it systemically" on trust — read the diff and apply the rubric.
- Do NOT call `bd close` from inside this command under any circumstance. The user decides whether to close based on the verdict.
- If verdict is `BLOCKED`, preserve the findings via `bd update <id> --notes "WORKFLOW-GATE-CHECK: …"` so they survive the session.

## If Beads or git is absent

- No `bd` binary → audit from files + transcript, lower confidence, verdict leans to `WARNINGS` unless a blocking protocol/quality item is found.
- No `.git` → same treatment; note the limitation explicitly in the report.
- No Beads issue for this work → this IS the first finding. Verdict starts at `BLOCKED`. Action item: create a retrospective Beads issue with 6-point description and re-audit.
