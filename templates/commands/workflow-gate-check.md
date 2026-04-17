---
description: Quality gate — Mode 1 (post-task audit) or Mode 2 (second opinion on proposal). Pass "02" as first arg to force Mode 2
---

Raw user input: $ARGUMENTS

## Mode dispatch

1. If `$ARGUMENTS` starts with `02` → **Mode 2 (mid-task second opinion)**. Treat the rest of $ARGUMENTS (after the `02` token) as the user's narrative about what they're uncertain about.
2. If `$ARGUMENTS` starts with `01` → **Mode 1 (post-task audit)**. Treat the rest as task context.
3. Otherwise auto-detect per the skill's dispatch rules (commit + close reason present → Mode 1; only proposal, no commit yet → Mode 2; ambiguous → ask user).

## Invoke the audit

Invoke skill `workflow-gate-check`. Follow its procedure end-to-end according to the chosen mode:

- **Mode 1:** gather `bd show` + `git show` + `git diff` + close-reason + verification artefacts; run Part 1 (six compliance checklists) and Part 2 (rubric on the landed diff); emit verdict using the skill's output template.
- **Mode 2:** gather the agent's proposal text + target-code context + preview diff if any + user's specific doubt; SKIP Part 1; run Part 2 on the proposal; emit verdict using the skill's output template.

State the chosen mode explicitly at the top of the report.

## Non-negotiables

- **Give expert opinion, not checklist compliance.** If your verdict could have been produced by a grep or a linter, you have not done the job. The verdict must be the compressed form of real reasoning — the reasoning itself must be visible in the findings and the Alternative path.
- **Start with Diagnosis (Part 2 Layer 1)** — was the right problem addressed? Do not move to Approach / Execution until you have judged this. A technically-clean fix to the wrong problem is a band-aid.
- Do NOT rubber-stamp. The point of this command is an **independent second opinion**.
- Read the diff / proposal code directly. Do not grade the claim "I did it systemically" on trust.
- When the verdict is `BLOCKED` or `WARNINGS`, you **owe an Alternative path** — a concrete description of how you would have approached the problem instead, and why it matters. Without it, a negative verdict is low-value.
- In Mode 1: do NOT call `bd close` from inside this command under any circumstance. The user decides based on the verdict.
- In Mode 2: do NOT start implementing the proposal. The user decides whether to accept.
- If verdict is `BLOCKED`, preserve the findings:
  - Mode 1: `bd update <id> --notes "WORKFLOW-GATE-CHECK: …"`
  - Mode 2: reply to the agent with the findings + Alternative path and request a revised proposal.

## If Beads or git is absent

- No `bd` binary → audit from files + transcript; lower confidence; verdict leans to `WARNINGS` unless a blocking protocol/quality item is found.
- No `.git` → same treatment; note the limitation explicitly in the report.
- No Beads issue for the work being audited (Mode 1) → that IS the first finding. Verdict starts at `BLOCKED`. Action item: create a retrospective Beads issue with 6-point description and re-audit.
