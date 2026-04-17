---
name: workflow-gate-check
description: >
  Manual post-task audit — verifies workflow-gate protocol compliance AND judges
  whether the solution was a band-aid or a structural/systemic fix that keeps
  the rest of the code as predictable as before. Independent second opinion
  before closing the Beads issue.
  TRIGGER via slash command /workflow-gate-check, or when user says
  "проверь задачу", "audit this task", "second opinion", "check workflow-gate",
  "было ли это заплатка", "system vs patch", "systemic or band-aid",
  "проверь workflow-gate", or requests a post-task quality review.
  Do NOT use for: pre-work planning (use superpowers:brainstorming),
  routine code review (use code-review skill), real-time linting, or
  open-task triage (use bd ready).
---

# Workflow Gate Check

**Role:** manual, post-task auditor. Two jobs:

1. **Protocol compliance** — mechanical check of workflow-gate discipline (6-point Beads description, 4-point close reason with verification evidence, commit conventions).
2. **Solution quality second opinion** — central question: was this a band-aid that hides the symptom, or a structural/systemic fix that keeps the rest of the code as predictable as before?

**Output:** single verdict `BLOCKED` / `WARNINGS` / `APPROVED` plus actionable findings.

**Invocation:** user-triggered only. Not automatic. Runs AFTER the task is done, BEFORE `bd close`.

---

## Input gathering

Before auditing, collect (in this order):

1. **Task identity**
   ```bash
   bd show <id> --json
   ```
   If user did not give an ID, ask. If no Beads issue exists at all, that IS the first finding.

2. **Git evidence of the change**
   ```bash
   git log --oneline -10
   git show <commit>            # the change commit
   git diff <commit>^..<commit> # what actually landed
   ```

3. **User narrative** — one or two sentences from the user: what did you change and why did you think it was the right fix.

4. **Verification artefacts** — if the close reason references a test run or screenshot, locate the actual file or terminal output in session history.

Skip nothing. An audit with incomplete evidence defaults to `BLOCKED` — the user can always re-run after supplying what was missing.

---

## Part 1 — Protocol compliance (mechanical)

Tick each item. Each miss has a severity tag.

### A. Beads issue quality

- `[ ]` Title is descriptive (not "fix bug", not "update") → miss = **WARNING**
- `[ ]` `--type` and `--priority` set → miss = **WARNING**
- `[ ]` Description has all 6 points: (1) what's broken, (2) where in code with file:line, (3) how to reproduce, (4) what's already known, (5) context link, (6) resources — miss of 3+ points = **BLOCKED**, miss of 1-2 = **WARNING**
- `[ ]` Written in English → miss = **WARNING** (token-budget rule)
- `[ ]` `discovered-from` link set if this task emerged from a different one → miss = **WARNING**

### B. Close reason (bd close --reason "…")

- `[ ]` Point 1 — **solution**: 1–2 sentences on what was concretely done
- `[ ]` Point 2 — **root cause**: why the defect existed
- `[ ]` Point 3 — **prevention**: test/rule/invariant that stops recurrence
- `[ ]` Point 4 — **verification with concrete artefacts**:
    - fresh test command + its output snippet (run in THIS session)
    - screenshot path for UI changes (Playwright @ 1920×1080)
    - before/after evidence for bug fixes
- Any of 1–3 missing → **BLOCKED**. Point 4 missing or just "tested, works" → **BLOCKED**.

### C. Commit conventions

- `[ ]` Commit message includes issue ID (e.g., `fix: X (project-a3f2)`) → miss = **WARNING**
- `[ ]` Conventional-commit prefix (`feat` / `fix` / `chore` / `docs` / `refactor` / `test`) → miss = **WARNING**
- `[ ]` Multi-line body for non-trivial changes → miss = **INFO**

### D. Notes & `bd remember`

- `[ ]` Notes updated during work, not batched at the end → miss = **INFO**
- `[ ]` `bd remember` entries added for any pattern/gotcha/convention worth future sessions → miss = **WARNING**

### E. README / docs synchronisation

- `[ ]` If code under `src/` (or equivalent project sources) changed, the local `README.md` in the same scope is updated in the SAME commit — "pvbridge feedback rule". Miss = **BLOCKED** (classified as hygiene bug).
- `[ ]` If public API or external contract changed, docs reflect it. Miss = **WARNING**.

### F. Land the plane

- `[ ]` `git pull --rebase && git push` done → miss = **WARNING** if remote exists
- `[ ]` Open sibling tasks have `bd update --notes` with current status → miss = **INFO**

---

## Part 2 — Band-aid vs structural (judgment)

**Central question:** Was this a quality, structural, systemic fix — the rest of the code works as predictably as before, and the class of bugs the task represents is gone — or a band-aid that hides the symptom?

Apply the rubric. Flag every matching signal. Band-aid signals combine; structural signals do not "cancel" them.

### Band-aid signals (any ONE ⇒ `WARNINGS` at minimum; TWO+ ⇒ `BLOCKED`)

1. **Magic number or compensation offset** — arbitrary margin/timeout/delay/retry added to paper over a calculation or flow error. *Example from this project: adding a fixed pixel offset to the layout prediction instead of using measured data as ground truth — see drevo LINE-CARD-CROSSING fix where `measureCardBBoxes` was moved post-render.*
2. **Fallback that swallows errors** — `try { ... } catch { /* log and continue */ }`, `?? defaultValue` on data that should never be null, silent retries that mask upstream brokenness.
3. **Symptom over root cause** — user-visible message changed; CSS hack for JS bug; DB query tuned instead of fixing the N+1 upstream.
4. **Duplication instead of reuse** — new helper/component/class whose logic already exists elsewhere. DRY violated.
5. **Technical debt left in code** — `TODO`, `FIXME`, `// temporary`, commented-out old implementation, "will fix later".
6. **Hardcode instead of config** — values that belong in settings/env/CLAUDE.md/database baked into code.
7. **Bypass of existing abstraction** — direct DB call instead of repository; direct `fetch` instead of API client; new global state instead of using the existing context.
8. **Wrong primitive** — using a right-sounding function that does the wrong thing. *Example from this project: using `wp_kses_post()` to sanitize template text where `sanitize_textarea_field()` was correct — ail-prompt-sanitizer-fix.*
9. **New mechanism on top of broken one** — adding a correction/compensation layer instead of replacing the broken mechanism it papers over.
10. **Regressions in adjacent code** — any previously-green test fails after the change, even if "unrelated". *Example from this project: drevo stagger-unification was rejected because it caused regressions elsewhere.*
11. **No test for the regressed class** — the bug could recur tomorrow and CI would not catch it.
12. **Unjustified scope creep inside the fix** — unrelated refactors bundled into a "targeted bug fix", inflating blast radius.

### Structural signals (present ⇒ lean toward `APPROVED`)

1. **Single source of truth made authoritative** — when two representations diverge, one is promoted to ground truth and the other is derived from it (the layout/measurement pattern).
2. **Correct primitive adopted** — the right function/type/tool for the job, not a workalike.
3. **Class of bugs fixed** — the fix is at the layer where the problem originates; instances beyond the reported one are now impossible.
4. **Existing abstraction improved** — DRY preserved or strengthened; shared code upgraded rather than forked.
5. **Regression test added** — a concrete test that fails without the fix and passes with it, located in the right suite.
6. **Minimal, narrow diff** — the change is as small as correctness allows, guards are narrow, blast radius contained.
7. **No behavioural side effects** — all existing callers see identical behaviour except the fixed case; verified by full test sweep / Playwright run.
8. **Architectural prevention** — new type, invariant, contract, or schema prevents the shape of the bug rather than relying on developer discipline.
9. **Post-change predictability** — re-running representative flows produces the same visible behaviour as before (for everything except the fix target).
10. **Documentation & memory updated** — `README.md` updated if `src/` changed (pvbridge feedback rule); `bd remember` captures the lesson for future sessions.

### Judgment heuristics for the auditor

- Don't take the user's claim "I did it systemically" at face value. **Read the diff.** A minimal structural fix is often 5 lines; a band-aid can be 200 lines of wrapper.
- Lots of code churn does NOT imply structural work. Tiny diff ≠ band-aid either.
- If the close reason claims a test was run but no test output is in session history — **BLOCKED**.
- If user seems confident and the fix seems reasonable but one band-aid signal is present — still flag it. The whole point is independent second opinion.
- When genuinely unsure between `APPROVED` and `WARNINGS` — pick `WARNINGS`.

---

## Verdict

Combine Parts 1 and 2.

| Combined findings | Verdict |
|---|---|
| Protocol all ticked AND zero band-aid signals | `APPROVED` |
| Protocol has `INFO`/`WARNING`s only AND 0–1 band-aid signal with mitigation documented | `WARNINGS` |
| Any protocol item tagged `BLOCKED` OR 2+ band-aid signals OR known regression OR missing verification evidence | `BLOCKED` |

- `APPROVED` → user is free to run `bd close --reason "…" --claim-next`.
- `WARNINGS` → user MAY close, but should first write findings into `bd update <id> --notes` so they are preserved for future maintainers.
- `BLOCKED` → DO NOT run `bd close`. Write findings into `bd update <id> --notes`, fix the issues, re-run this audit.

---

## Output template

Use this structure exactly. Keep it tight.

```
=== WORKFLOW-GATE-CHECK REPORT ===
Task: <bd-id> — <title>
Commit(s): <sha>[, <sha2>]

### Verdict: <BLOCKED | WARNINGS | APPROVED>

### Part 1 — Protocol compliance
[x] A. Beads description — 6-point
[ ] B. Close reason — verification artefact ← MISSING (severity: BLOCKED)
[x] C. Commit includes issue ID
...

### Part 2 — Solution quality
Answer to central question: <BAND-AID | STRUCTURAL | MIXED>

Band-aid signals found:
- #8 Wrong primitive: wp_kses_post used for template content at src/x.php:42.
  Should be sanitize_textarea_field (see ail-prompt-sanitizer-fix).
- #1 Magic number: retry count 5 added in src/y.js:20 with no justification.

Structural signals found:
- #2 Correct primitive: replaced custom parser with lib's official one.

### Action items
1. Add test output to bd close reason point 4 (fresh session, snippet).
2. Replace wp_kses_post with sanitize_textarea_field.
3. Justify or remove magic retry count.

### If verdict ≠ APPROVED
- Do NOT call bd close yet.
- Preserve findings: bd update <id> --notes "WORKFLOW-GATE-CHECK: <summary>".
- Re-run /workflow-gate-check after fixing the items above.
```

---

## Common mistakes (by the auditor itself)

- **Taking the user's word for "systemic"** — always check the diff. Structural work is visible in code, not in prose.
- **Confusing churn with depth** — a 10-line diff can be structural; a 300-line PR can be band-aid.
- **Leniency on verification** — "tested, works" without artefacts is not verification. It is a claim. `BLOCKED`.
- **Confirmation bias** — if the user is senior / confident / just got done explaining the fix, the temptation to rubber-stamp is maximal. Resist it. Independent second opinion is the entire value of this skill.
- **Half-audit** — all six protocol sections run, the rubric runs. No shortcuts.
- **Off-topic depth** — don't redesign the feature. Audit only what landed.

---

## Troubleshooting

- **No Beads issue for the task** → this is itself a protocol violation. Verdict starts at `BLOCKED`. In the report, add an action item: "Create retrospective Beads issue with 6-point description covering this work, then re-audit."
- **Project has no git** → audit what you can from files + transcript; note the limitation in the report. Verdict leans toward `WARNINGS` because git-based evidence is missing.
- **Verification artefacts referenced but not findable** → `BLOCKED`. Ask user to paste the evidence or re-run the verification in the current session.
- **Conflicting evidence** (user narrative says X, diff shows Y) → trust the diff. Note the discrepancy in findings.
