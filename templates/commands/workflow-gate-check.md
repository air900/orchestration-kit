---
description: Quality gate — Mode 1 (post-task audit), Mode 2 (second opinion on proposal), or Mode 3 (handoff enrichment for open tasks). First arg 01/02/03 forces a mode; topic text may follow.
---

Raw user input: $ARGUMENTS

## Mode dispatch

1. If `$ARGUMENTS` starts with `02` → **Mode 2 (mid-task second opinion)**. Treat the rest of `$ARGUMENTS` (after the `02` token) as the user's narrative about what they're uncertain about.
2. If `$ARGUMENTS` starts with `03` → **Mode 3 (handoff enrichment)**. Treat the rest as the session topic sentence (optional — otherwise derive from just-closed task + git activity).
3. If `$ARGUMENTS` starts with `01` → **Mode 1 (post-task audit)**. Treat the rest as task context.
4. Otherwise auto-detect per the skill's dispatch rules:
   - commit + close reason present → Mode 1
   - only proposal, no commit → Mode 2
   - session wrap-up with related open tasks → Mode 3
   - ambiguous → ask user to pick

## Invoke the audit

Invoke skill `workflow-gate-check`. Follow its procedure end-to-end according to the chosen mode:

- **Mode 1:** gather `bd show` + `git show` + `git diff` + close-reason + verification artefacts; run Part 1 (six compliance checklists) and Part 2 (rubric on the landed diff); emit verdict using the skill's Modes 1 & 2 output template.
- **Mode 2:** gather the agent's proposal text + target-code context + preview diff if any + user's specific doubt; SKIP Part 1; run Part 2 on the proposal; emit verdict using the skill's Modes 1 & 2 output template.
- **Mode 3:** identify session topic + related open tasks (Part 3 Phase 0 scope criteria); for each task, run Phase 1 gap detection (structural + `S1`–`S5` session-specific); propose Phase 2 enrichment plan; **wait for user approval**; apply Phase 3 actions; emit verdict using the skill's Mode 3 output template.

State the chosen mode explicitly at the top of the report.

## Non-negotiables

- **Give expert opinion, not checklist compliance.** If your verdict could have been produced by a grep or a linter, you have not done the job. The verdict must be the compressed form of real reasoning — the reasoning itself must be visible in the findings.
- **Domain-agnostic.** This project could be code, content, infrastructure, design, or something else. Detect the project's nature from its structure (`tests/`, `assets/`, `docs/runbooks/`, etc.) and apply the domain-appropriate persona, examples, and persistence paths.
- **Modes 1-2: start with Diagnosis (Part 2 Layer 1)** — was the right problem addressed? Do not move to Approach / Execution until you have judged this. A technically-clean fix to the wrong problem is a band-aid.
- **Modes 1-2: when `BLOCKED`/`WARNINGS`, you owe an Alternative path** — a concrete description of how you would have approached the problem instead, and why it matters.
- **Mode 3: wait for user approval before applying enrichment actions.** Phase 2 produces a plan; Phase 3 applies it only after explicit user sign-off. Running `bd update` / `bd decision` / `git commit` before approval is a trust violation.
- Do NOT rubber-stamp. The point of this command is an **independent second opinion** (Modes 1-2) or an **independent handoff quality gate** (Mode 3).
- Read the diff / proposal code / open-task descriptions directly. Do not grade on trust.
- In Mode 1: do NOT call `bd close` from inside this command. The user decides based on the verdict.
- In Mode 2: do NOT start implementing the proposal. The user decides whether to accept.
- In Mode 3: do NOT close the current session even on `APPROVED` — the user ends the session themselves.
- If verdict is `BLOCKED`, preserve the findings:
  - Mode 1: `bd update <id> --notes "WORKFLOW-GATE-CHECK: …"`
  - Mode 2: reply with findings + Alternative path, request revised proposal.
  - Mode 3: surface the list of unrecoverable gaps so the user can decide whether to extend the session.

## If Beads or git is absent

- No `bd` binary → audit from files + transcript; lower confidence; verdict leans to `WARNINGS` unless a blocking item is found.
- No `.git` → same treatment; note the limitation in the report.
- No Beads issue for the work being audited (Mode 1) or no related open tasks (Mode 3) → first finding. Mode 1 verdict starts at `BLOCKED`; Mode 3 asks the user which open tasks to target, or exits with an observation that enrichment is not applicable.
