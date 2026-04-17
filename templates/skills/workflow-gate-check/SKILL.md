---
name: workflow-gate-check
description: >
  Manual quality gate with TWO modes. Mode 1 (POST-TASK AUDIT): verifies
  workflow-gate protocol compliance after task completion, before bd close.
  Mode 2 (MID-TASK SECOND OPINION): independent assessment of an agent's
  proposed solution before accepting it. Both modes apply the same
  band-aid vs structural/systemic rubric — does the fix keep the rest of
  the code as predictable as before, or does it hide a symptom?
  TRIGGER via slash command /workflow-gate-check (add "02" for Mode 2,
  e.g. "/workflow-gate-check 02"), by skill name, or when user says
  "проверь задачу", "проверь решение", "audit this task", "second opinion",
  "независимая оценка", "сомневаюсь в решении", "было ли это заплатка",
  "systemic or band-aid", "check workflow-gate", "проверь прежде чем принимать".
  Do NOT use for: pre-work planning (use superpowers:brainstorming),
  routine code review (use code-review skill), real-time linting,
  open-task triage (use bd ready).
---

# Workflow Gate Check

**Role:** manual quality gate, user-triggered only. Not automatic. Two modes share one rubric.

## Expert persona — the stance you take

**You are a principal-level engineer giving an independent second opinion on someone else's fix** (proposed or landed). Your value is NOT to rubber-stamp, NOT to tick boxes. It is to apply senior judgement.

Adopt this mindset. Ask yourself — and answer — each of these:

1. **If this arrived in my team's PR queue, would I merge it?** What comments would I leave?
2. **In six months, when this code surfaces in a new bug report, will the original root cause still be hidden?** Will the next engineer know WHY this was done, or just WHAT was done?
3. **Is the scope of the fix proportional to the scope of the problem?** Both under-engineering (covers only the reported instance, not the class) and over-engineering (refactors three adjacent systems on the way) are failures.
4. **What question would a senior colleague have asked first that this engineer likely did not?** (e.g., "Why is the caller passing these inputs?" "Does the existing abstraction already handle this?" "What assumption broke?")
5. **If I had to solve this same problem fresh, what would I do differently?** If your answer is "basically the same" → strong signal for APPROVED. If it's "I'd attack it at a different layer" → you owe the user a concrete alternative.

Checklist items (Part 1) exist to prevent oversights. The rubric (Part 2) exists to structure judgement. **If your verdict could have been produced by a grep, you have not done your job.** The verdict is the compressed form of your reasoning — the reasoning itself must be visible in the findings.

## Mode dispatch (decide this FIRST)

| Mode | When to use | Signals |
|---|---|---|
| **1. POST-TASK AUDIT** | Task is done, code committed, about to `bd close` | Slash has no arg or arg starts with `01`; commit exists with issue ID; close reason drafted |
| **2. MID-TASK SECOND OPINION** | Agent just proposed a solution; user is unsure or sceptical; nothing committed yet | Slash arg starts with `02`; user said "сомневаюсь"/"проверь решение"/"не уверен"; no commit yet for the proposal |

**Decision rule:**

1. If slash argument starts with `02` → Mode 2 unconditionally.
2. If slash argument starts with `01` → Mode 1 unconditionally.
3. Otherwise auto-detect:
   - Commit with issue ID exists for current task AND close reason drafted → Mode 1
   - Only a proposal in conversation, no commit yet → Mode 2
   - Ambiguous → ask user: "Mode 1 (post-task audit of landed code) or Mode 2 (second opinion on proposed solution)?"

State the chosen mode explicitly at the top of the output — the user must see which audit they got.

## What each mode does

**Mode 1 — POST-TASK AUDIT**
1. Protocol compliance — full Part 1 checklist (6-point Beads issue, 4-point close reason with verification artefacts, commit conventions, docs sync, land-the-plane).
2. Solution quality — Part 2 rubric applied to the **landed diff**.
3. Output: verdict drives `bd close` decision.

**Mode 2 — MID-TASK SECOND OPINION**
1. Protocol compliance — **SKIPPED** (the task is not finished — there is nothing to audit compliance against yet).
2. Solution quality — Part 2 rubric applied to the **proposal** (conversation text + preview diff if shared).
3. Output: verdict drives whether the user accepts, revises, or rejects the agent's proposed fix.

**Output:** single verdict `BLOCKED` / `WARNINGS` / `APPROVED` plus actionable findings. Verdict semantics depend on mode:

| Verdict | Mode 1 meaning | Mode 2 meaning |
|---|---|---|
| `APPROVED` | Fine to run `bd close` | Accept the proposal, proceed |
| `WARNINGS` | MAY close, save findings to `bd update --notes` first | Accept only after addressing findings |
| `BLOCKED` | DO NOT `bd close`, fix issues, re-audit | REJECT the proposal as-is — revise substantially or try a different approach |

---

## Input gathering

Collect in this order. Which items are required depends on mode.

### Mode 1 — POST-TASK AUDIT (all required)

1. **Task identity** — `bd show <id> --json`. If no ID from user, ask. If no Beads issue exists at all, that IS the first finding.
2. **Git evidence** — `git log --oneline -10`, `git show <commit>`, `git diff <commit>^..<commit>`.
3. **Close reason (draft or saved)** — read it; it is what Part 1 evaluates against.
4. **Verification artefacts** — if the close reason references a test run or screenshot, locate the actual file or terminal output in session history.
5. **User narrative** — one or two sentences: what changed and why it is the right fix.

Skip nothing. An audit with incomplete evidence defaults to `BLOCKED` — the user can re-run after supplying what was missing.

### Mode 2 — MID-TASK SECOND OPINION (lighter)

1. **The proposal itself** — the agent's message(s) proposing the fix. If the proposal is vague ("I'll fix X by adding a check"), ask for specifics before auditing.
2. **Target code context** — which files/functions the proposal would touch. Read them now to ground the rubric.
3. **Preview diff if available** — if the agent produced a draft patch, apply the rubric to the patch directly. If not, apply it to the *plan* as written.
4. **Current Beads issue (if any)** — `bd show <id>` gives context for what the fix is supposed to solve. Used only for framing, not for compliance grading.
5. **User's specific doubt** — one sentence: what makes you uncertain about this proposal? Named doubts are strong input to the rubric.

Mode 2 has no `git show <commit>` step — nothing has landed yet. Do NOT fabricate or assume code changes: apply the rubric to what is actually on the table.

---

## Part 1 — Protocol compliance (mechanical) — MODE 1 ONLY

**In Mode 2 this whole Part is SKIPPED** — there is nothing to grade compliance against until work lands. Jump to Part 2.

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

## Part 2 — Expert judgement (diagnosis → approach → execution)

An expert second opinion works top-down: correct problem first, correct approach second, correct execution third. A fix can be technically clean (execution ✓) and still fail because it solved the wrong problem (diagnosis ✗). Grade all three layers.

### Layer 1 — Diagnosis: was the right problem addressed?

- Does the work target the actual cause of the reported behaviour, or a plausible-looking downstream effect?
- Would a senior engineer, reading the bug report cold, have framed the problem the same way?
- Was the investigation deep enough to distinguish root cause from surface symptom?

**Red flags at this layer** (each is a band-aid signal — see list below):
- `WP1` **Wrong problem framing** — task was scoped to "make X not error", but the real question was "why is X called with these inputs". Upstream investigation was skipped.
- `WP2` **Shallow diagnosis** — first plausible cause was accepted without ruling out alternatives; the one-line explanation in the close reason is suspiciously tidy.

### Layer 2 — Approach: was the right layer / primitive chosen?

- Is the fix placed where the invariant should live (the layer that owns the concept), or where it happened to be easiest to touch?
- Does the chosen approach respect the codebase's existing design intent, or fight it?
- Is the chosen primitive / API / pattern the correct one for this job?

### Layer 3 — Execution: was the chosen approach implemented well?

- Diff minimal for correctness (not minimal for its own sake; not inflated either)?
- Tests added or updated to lock in the class?
- Readability and maintainability preserved or improved?
- No collateral damage to adjacent code or contracts?

---

### Band-aid signals

Band-aid = any of the failure modes below. Any ONE ⇒ `WARNINGS` minimum; TWO+ ⇒ `BLOCKED`. Tag each finding with its code (`D1`, `A3`, `E2`, etc.) so the report is traceable.

**Diagnosis-level (`D*`):**
- `D1` **Wrong problem framing** — fix addresses a symptom or a mis-scoped version of the real question. The proper question is upstream. *Classic: "make X not error" instead of "why is X called with garbage inputs".*
- `D2` **Shallow root-cause analysis** — the first plausible cause was accepted; no evidence that alternatives were considered or ruled out.
- `D3` **Symptom over cause** — user-visible message changed; CSS hack for a JS bug; DB query tuned instead of fixing the N+1 upstream.

**Approach-level (`A*`):**
- `A1` **Wrong layer** — fix sits in the consumer when the invariant belongs in the producer (or vice versa). Leaves the bug reachable via other code paths.
- `A2` **Wrong primitive** — right-sounding function that does the wrong thing. *Project example: `wp_kses_post()` used for template text where `sanitize_textarea_field()` was correct — `ail-prompt-sanitizer-fix`.*
- `A3` **New mechanism on top of broken one** — correction / compensation layer added instead of replacing the broken mechanism it papers over.
- `A4` **Bypass of existing abstraction** — direct DB call skipping the repository; direct `fetch` skipping the API client; new global state instead of using the existing context.
- `A5` **Magic number or compensation offset** — arbitrary margin / timeout / delay / retry that papers over a calculation or flow error. *Project example: adding a fixed pixel offset to layout prediction instead of using measured data as ground truth — `drevo` LINE-CARD-CROSSING, where `measureCardBBoxes` was moved post-render.*
- `A6` **Fight with design intent** — fix works against the prevailing architectural direction of the codebase (e.g., sprinkles global state in a codebase that has been moving toward explicit DI).

**Execution-level (`E*`):**
- `E1` **Scope mismatch** — fix too narrow (solves only the reported instance, not the class) OR too broad (unrelated refactors bundled in, inflating blast radius).
- `E2` **Fallback that swallows errors** — `try { ... } catch { /* log and continue */ }`, `?? defaultValue` on data that should never be null, silent retries that mask upstream brokenness.
- `E3` **Duplication instead of reuse** — new helper / component / class whose logic already exists elsewhere. DRY violated.
- `E4` **Hardcode instead of config** — values that belong in settings / env / CLAUDE.md / DB baked into code.
- `E5` **Regressions in adjacent code** — any previously-green test fails after the change, even if "unrelated". *Project example: `drevo` stagger-unification was rejected because it regressed elsewhere.*
- `E6` **No regression test** — the exact bug could recur tomorrow and CI would not catch it.
- `E7` **Technical debt left in** — `TODO`, `FIXME`, `// temporary`, commented-out old implementation, "will fix later" with no follow-up issue filed (`discovered-from`).
- `E8` **Readability/testability reduced** — code harder to read or harder to test than what it replaces. Future maintainers pay the tax.

---

### Structural signals

Present in the fix ⇒ lean toward `APPROVED`. These are **positive quality dimensions**, not just "absence of band-aid".

**Diagnosis-level:**
- `sD1` **Correct diagnosis evidenced** — the close reason / proposal articulates the root cause at a level where the fix addresses it; alternatives were considered and ruled out explicitly.
- `sD2` **Class of bugs identified and eliminated** — not just this instance; the change closes the shape of the bug at its source.

**Approach-level:**
- `sA1` **Right layer** — invariant placed where it belongs (producer, not every consumer).
- `sA2` **Correct primitive adopted** — the right function / type / tool for the job, not a workalike.
- `sA3` **Single source of truth made authoritative** — when two representations diverge, one is promoted to ground truth and the other derived from it (the `drevo` layout/measurement pattern).
- `sA4` **Design intent respected** — the fix extends the codebase's existing direction rather than working around it.
- `sA5` **Architectural prevention** — new type, invariant, contract, or schema prevents the shape of the bug rather than relying on developer discipline.

**Execution-level:**
- `sE1` **Right scope** — diff as small as correctness allows, as large as correctness demands. Neither under- nor over-engineered for the problem.
- `sE2` **Existing abstraction improved** — DRY preserved or strengthened; shared code upgraded rather than forked.
- `sE3` **Regression test added** — concrete test that fails without the fix and passes with it, in the right suite.
- `sE4` **No behavioural side effects** — all existing callers see identical behaviour except the fixed case; verified by full test sweep / Playwright run.
- `sE5` **Readability / testability preserved or improved** — a maintainer in six months understands both WHAT changed and WHY; the code is not harder to test than before.
- `sE6` **Proportionate complexity** — complexity of the fix matches complexity of the problem. A 5-line guard for a 5-line bug. A new subsystem only when a new subsystem is required.

---

### Judgement heuristics

- Don't take "I did it systemically" on trust. **Read the diff** and make your own assessment.
- Churn ≠ depth. A 10-line diff can be structural. A 300-line PR can be band-aid.
- If the close reason claims a test was run but no test output is in session history → `BLOCKED`.
- If the user is confident and the fix looks reasonable but one band-aid signal is present → flag it anyway. Independent opinion is the entire value.
- When genuinely undecided between `APPROVED` and `WARNINGS` → pick `WARNINGS`.
- **If BLOCKED or WARNINGS, you owe an alternative.** "Not good" without "here's what I would do" is low-value. Put the alternative in the output template's `Alternative path` section.
- Don't confuse "minimal diff" with "good fix". A 2-line band-aid (`if (foo) return;`) is still a band-aid.

---

## Verdict

### Mode 1 — combined Part 1 + Part 2

| Combined findings | Verdict |
|---|---|
| Protocol all ticked AND zero band-aid signals | `APPROVED` |
| Protocol has `INFO`/`WARNING`s only AND 0–1 band-aid signal with mitigation documented | `WARNINGS` |
| Any protocol item tagged `BLOCKED` OR 2+ band-aid signals OR known regression OR missing verification evidence | `BLOCKED` |

- `APPROVED` → user is free to run `bd close --reason "…" --claim-next`.
- `WARNINGS` → user MAY close, but should first write findings into `bd update <id> --notes` so they are preserved for future maintainers.
- `BLOCKED` → DO NOT run `bd close`. Write findings into `bd update <id> --notes`, fix the issues, re-run this audit.

### Mode 2 — Part 2 only

| Findings on the proposal | Verdict |
|---|---|
| Zero band-aid signals AND 2+ structural signals present | `APPROVED` |
| 1 band-aid signal OR few/no structural signals (weak-but-workable proposal) | `WARNINGS` |
| 2+ band-aid signals OR a likely regression OR proposal does not address root cause | `BLOCKED` |

- `APPROVED` → accept the proposal, proceed with implementation.
- `WARNINGS` → accept only after the agent addresses the listed findings. Ask the agent to revise before writing code.
- `BLOCKED` → reject the proposal as-is. Ask the agent to reconsider — different layer, different primitive, or deeper root-cause analysis. Do NOT let the agent start implementing until the revise lands.

---

## Output template

Use this structure exactly. Keep it tight.

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: <1 POST-TASK-AUDIT | 2 MID-TASK-SECOND-OPINION>
Task: <bd-id or "(no issue)"> — <title>
Commit(s): <sha>[, <sha2>]          # Mode 1 only
Proposal source: <agent message or draft diff>   # Mode 2 only

### Verdict: <BLOCKED | WARNINGS | APPROVED>

### Part 1 — Protocol compliance               # Mode 1 only; omit section in Mode 2
[x] A. Beads description — 6-point
[ ] B. Close reason — verification artefact ← MISSING (severity: BLOCKED)
[x] C. Commit includes issue ID
...

### Part 2 — Expert judgement

Layer 1 — Diagnosis: <one sentence — right problem addressed? Why or why not?>
Layer 2 — Approach: <one sentence — right layer/primitive chosen? Why or why not?>
Layer 3 — Execution: <one sentence — chosen approach implemented well? Why or why not?>

Band-aid signals found:
- A2 Wrong primitive: wp_kses_post used for template content at src/x.php:42.
  sanitize_textarea_field would be correct (cf. ail-prompt-sanitizer-fix).
- A5 Magic number: retry count 5 added in src/y.js:20 with no justification
  — masks an upstream flakiness rather than diagnosing it.

Structural signals found:
- sE2 Existing abstraction improved: repository method now handles the edge
  case in one place instead of three.

### Alternative path                 # REQUIRED when verdict != APPROVED; optional but welcome when APPROVED
If I were implementing this from scratch, I would:
- <concrete alternative approach, one or two sentences>
- <the mechanism / layer / primitive I would have chosen and why>
- <what this buys us that the current fix does not>

This is the expert's deliverable, not optional prose. Without it the user
cannot act on a negative verdict.

### Action items
Mode 1:
1. Add test output to bd close reason point 4 (fresh session, snippet).
2. Replace wp_kses_post with sanitize_textarea_field at src/x.php:42.
3. Investigate upstream flakiness or justify the magic retry count with evidence.
Mode 2:
1. Revise proposal: move the invariant to the producer layer.
2. Use sanitize_textarea_field; drop the retry until the flakiness is understood.
3. Re-submit proposal for /workflow-gate-check 02.

### If verdict != APPROVED
Mode 1:
- Do NOT call bd close yet.
- Preserve findings: bd update <id> --notes "WORKFLOW-GATE-CHECK: <summary>".
- Re-run /workflow-gate-check after fixing the items above.
Mode 2:
- Do NOT let the agent start implementing.
- Reply to the agent with the findings + Alternative path and ask for a
  revised proposal.
- Re-run /workflow-gate-check 02 on the revised proposal.
```

---

## Common mistakes (by the auditor itself)

- **Grep-level verdict** — if your conclusion could have been produced by a checklist runner or a linter, you did not give expert opinion. The verdict is the compressed form of reasoning — the reasoning itself must be visible in the findings and in the Alternative path.
- **Skipping Layer 1 (Diagnosis)** — most tempting failure. Code looks clean → pronounce APPROVED → but the fix solved the wrong problem. Always ask first: "was the right question answered?"
- **Taking "I did it systemically" on trust** — always check the diff. Structural work is visible in code, not in prose.
- **Confusing churn with depth** — a 10-line diff can be structural; a 300-line PR can be band-aid. "Minimal diff" is not a structural signal on its own — a 2-line `if (foo) return;` is still a band-aid.
- **Leniency on verification** — "tested, works" without artefacts is not verification. It is a claim. → `BLOCKED`.
- **Confirmation bias** — when the user is senior / confident / just explained the fix at length, the temptation to rubber-stamp is maximal. Resist it. Independent second opinion is the entire value of this skill.
- **Withholding an Alternative** — saying `BLOCKED` without "here is what I would do instead" is low-value. Expert judgement is actionable; the alternative is part of the product.
- **Redesigning the feature** — the opposite failure. Audit what landed; don't scope-creep into a product redesign. If the real issue is product-level, say so in one sentence and defer.
- **Half-audit** — all six Part 1 sections run in Mode 1; all three Part 2 layers run in both modes. No shortcuts.

---

## Troubleshooting

- **No Beads issue for the task** → this is itself a protocol violation. Verdict starts at `BLOCKED`. In the report, add an action item: "Create retrospective Beads issue with 6-point description covering this work, then re-audit."
- **Project has no git** → audit what you can from files + transcript; note the limitation in the report. Verdict leans toward `WARNINGS` because git-based evidence is missing.
- **Verification artefacts referenced but not findable** → `BLOCKED`. Ask user to paste the evidence or re-run the verification in the current session.
- **Conflicting evidence** (user narrative says X, diff shows Y) → trust the diff. Note the discrepancy in findings.
