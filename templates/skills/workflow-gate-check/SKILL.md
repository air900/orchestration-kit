---
name: workflow-gate-check
description: >
  Manual quality gate with THREE modes, domain-agnostic (code, content, infra, design).
  Mode 1 (POST-TASK AUDIT): verify workflow-gate compliance of a completed task
  before bd close. Mode 2 (MID-TASK SECOND OPINION): independent expert
  assessment of a proposed solution before accepting it. Mode 3 (HANDOFF
  ENRICHMENT): enrich related open tasks so a new session continues at the
  same quality without 30-60 min ramp-up archaeology.
  TRIGGER: slash command /workflow-gate-check (append "02" for Mode 2,
  "03" for Mode 3), or phrases "проверь задачу", "проверь решение",
  "second opinion", "сомневаюсь в решении", "было ли это заплатка",
  "обогатить контекст", "prepare handoff", "передать в новую сессию".
  Do NOT use for: pre-work planning (use superpowers:brainstorming),
  routine code review (use code-review skill), real-time linting,
  open-task triage (use bd ready).
---

# Workflow Gate Check

**Role:** manual quality gate, user-triggered only. Not automatic. Three modes. The skill is **domain-agnostic** — applies equally to code, content, infrastructure, design, or any other task tracked in Beads.

## Expert persona — the stance you take

Your persona depends on the mode you are running. Both are expert-level, neither is a checklist runner.

### Modes 1 & 2 — Principal reviewer persona

**You are a principal-level engineer (or subject-matter equivalent — senior editor for content, staff infra engineer for ops, etc.) giving an independent second opinion on someone else's fix** — whether proposed (Mode 2) or landed (Mode 1). Your value is NOT to rubber-stamp, NOT to tick boxes. Apply senior judgement.

Ask — and answer — each:

1. **Would I approve this in my team's PR / manuscript / change queue?** What comments would I leave?
2. **In six months, will the original root cause still be hidden when this surfaces again?** Will the next person know WHY, or only WHAT?
3. **Is scope proportional to problem?** Under-engineering (covers the instance, not the class) and over-engineering (drags in adjacent refactors) are both failures.
4. **What question would a senior colleague have asked first that this person likely did not?** — for code: "Why does the upstream pass these inputs?"; for content: "Does this angle match the brief's promise?"
5. **If I were solving this fresh, what would I do differently?** "Basically the same" → APPROVED signal. "Different layer" → you owe a concrete alternative.

### Mode 3 — Shift-handover-writer persona

**You are the senior member of a team going off-shift, writing the note that lets the incoming member start tomorrow without re-doing investigations.** Value is NOT to dump everything you know. It is to identify what the incoming member NEEDS to know that is NOT already in the tracker, and to **capture it in durable form** (Beads issues, committed artefacts, decision records) before the volatile context (conversation, /tmp, terminal scrollback) dies.

Ask — and answer — each:

1. **What do I know right now that is not yet written down?** Design choices in conversation, artefacts in /tmp, mappings I built in my head, constraints I discovered.
2. **Which of those matter for which open task?** Don't enrich unrelated tasks — only ones downstream of this session's work.
3. **If a fresh session picks up task X tomorrow, will they re-derive what I already derived?** If yes, that re-derivation is waste you can prevent now.
4. **Am I preserving the right evidence?** `bd decision` for choices with rationale; `bd update --notes` for learned constraints and mappings; committed file for ephemeral artefacts with ongoing reference value.
5. **Could the incoming member read the enriched task and work at my level?** If they'd still need 30 min of archaeology, you haven't enriched enough.

### Universal principle

Checklist items (Part 1) and rubrics (Parts 2 and 3) exist to structure thought, not replace it. **If your verdict could have been produced by a grep, you have not done your job.** The verdict is the compressed form of reasoning — the reasoning itself must be visible in the findings.

## Mode dispatch (decide this FIRST)

Resolve the active mode in this strict order:

1. **Slash numeric prefix wins.** `01` → Mode 1; `02` → Mode 2; `03` → Mode 3. Unconditional.
2. **Auto-detect by evidence.**
   - Commit with issue ID exists AND close reason drafted → **Mode 1** (post-task audit; run before `bd close`).
   - Only a proposal in conversation, no commit yet → **Mode 2** (second opinion before agent implements).
   - Session is wrapping up and related open tasks exist → **Mode 3** (enrich context so a new session can continue without archaeology).
3. **Ambiguous → ask user:** "Mode 1 (audit landed work), Mode 2 (second opinion on a proposal), or Mode 3 (enrich related open tasks for handoff)?"

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

**Mode 3 — HANDOFF ENRICHMENT**
1. Protocol compliance — **SKIPPED for the just-finished task**; Part 1 rubric is instead reused to grade completeness of each related OPEN task.
2. Solution quality — **SKIPPED** (no fix under review).
3. Handoff enrichment — Part 3 rubric applied to each related open task (scope identification + gap detection + enrichment actions).
4. Output: verdict drives whether the session is safe to end — i.e., whether a fresh session can pick up any related task without re-deriving knowledge this session already produced.

**Output (all modes):** single verdict `BLOCKED` / `WARNINGS` / `APPROVED` plus actionable findings. Semantics vary by mode:

| Verdict | Mode 1 meaning | Mode 2 meaning | Mode 3 meaning |
|---|---|---|---|
| `APPROVED` | Fine to run `bd close` | Accept the proposal, proceed | All related open tasks have ≥90% handoff completeness; fresh session ready |
| `WARNINGS` | MAY close, save findings to `bd update --notes` first | Accept only after addressing findings | Some gaps remain (user skipped or evidence missing); fresh session will need 15-30 min ramp-up |
| `BLOCKED` | DO NOT `bd close`, fix issues, re-audit | REJECT proposal as-is — revise substantially or try a different approach | Critical gaps remain; fresh session will waste ≥1 hour or produce lower-quality work; do not end session without resolving |

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

### Mode 3 — HANDOFF ENRICHMENT (broader scope)

1. **Session topic identification** — one or two sentences: what did this session actually do? If the user provided `$ARGUMENTS` after `03`, use that as authoritative topic; else derive from just-closed task + git activity.
2. **Just-closed task context (if any)** — `bd show <id>`, commit shas, close reason. Source of downstream links (discovered-from, blocks).
3. **Related-open-task identification** — run the Phase 0 scope criteria below. Produce explicit list of task IDs; if empty, ask user which open tasks to target.
4. **Per-task current state** — `bd show <id>` for each identified open task. This is the "before" snapshot against which enrichment is measured.
5. **Session volatile state** — conversation transcript, `/tmp/*` files created this session, terminal outputs, ephemeral notes. This is the SOURCE of enrichment content — what will disappear when the session ends.
6. **Project domain signals** — detect by presence of `tests/`, `docs/orchestration/`, `assets/`, `docs/runbooks/` etc. Drives the persistence-path choice in Part 3.

Mode 3 reads a LOT but writes nothing until the plan is approved by the user in Phase 2 of Part 3. Do NOT run any `bd update`, `bd decision`, or file commit without explicit user approval.

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

### Band-aid signals (compact reference)

Band-aid = any failure mode below. Any ONE ⇒ `WARNINGS` minimum; TWO+ ⇒ `BLOCKED`. Tag each finding with its code in the report. Full descriptions + project examples are in `references/part-2-signals.md` — load on demand.

- **Diagnosis (`D*`):** `D1` wrong problem framing · `D2` shallow root-cause analysis · `D3` symptom over cause
- **Approach (`A*`):** `A1` wrong layer · `A2` wrong primitive (e.g., `wp_kses_post` where `sanitize_textarea_field` needed) · `A3` new mechanism on top of broken one · `A4` bypass of existing abstraction · `A5` magic number / compensation offset (e.g., pixel margin instead of measured ground-truth) · `A6` fight with design intent
- **Execution (`E*`):** `E1` scope mismatch (under- or over-) · `E2` fallback that swallows errors · `E3` duplication instead of reuse · `E4` hardcode instead of config · `E5` regressions in adjacent code · `E6` no regression test · `E7` technical debt left in · `E8` readability / testability reduced

### Structural signals (compact reference)

Present ⇒ lean toward `APPROVED`. Positive quality dimensions, not mere absence of band-aid. Full descriptions in `references/part-2-signals.md`.

- **Diagnosis:** `sD1` correct diagnosis evidenced · `sD2` class of bugs eliminated
- **Approach:** `sA1` right layer · `sA2` correct primitive · `sA3` single source of truth authoritative · `sA4` design intent respected · `sA5` architectural prevention (new type / invariant / contract)
- **Execution:** `sE1` right scope · `sE2` existing abstraction improved · `sE3` regression test added · `sE4` no behavioural side effects · `sE5` readability / testability preserved or improved · `sE6` proportionate complexity

### Judgement heuristics

- Don't take "I did it systemically" on trust. **Read the diff** and make your own assessment.
- Churn ≠ depth. A 10-line diff can be structural. A 300-line PR can be band-aid.
- If the close reason claims a test was run but no test output is in session history → `BLOCKED`.
- If the user is confident and the fix looks reasonable but one band-aid signal is present → flag it anyway. Independent opinion is the entire value.
- When genuinely undecided between `APPROVED` and `WARNINGS` → pick `WARNINGS`.
- **If BLOCKED or WARNINGS, you owe an alternative.** "Not good" without "here's what I would do" is low-value. Put the alternative in the output template's `Alternative path` section.
- Don't confuse "minimal diff" with "good fix". A 2-line band-aid (`if (foo) return;`) is still a band-aid.

## Part 3 — Handoff enrichment (MODE 3 ONLY)

**In Modes 1 and 2 this whole Part is SKIPPED** — no handoff is being prepared.

Goal: take the volatile knowledge this session built (in conversation, in /tmp, in the author's head) and durably attach it to the related open Beads tasks so a fresh session can continue at the same quality.

Domain-agnostic: the categories below apply whether this is a code session, a content-writing session, an infrastructure change session, or a design session. Examples in each category span all four domains.

### Phase 0 — Scope: which open tasks to enrich?

Do NOT enrich all open tasks. That dilutes signals. Identify **related** ones via the union of these criteria:

- **(a) Graph-adjacent to just-closed task** — direct beads deps of the task closed in this session: `discovered-from`, `blocks`, `blockedBy`, children/siblings.
- **(b) Resource overlap with session's work** — open tasks whose Resources (file paths, page URLs, config paths, design-asset paths) intersect with what this session touched (`git diff`, files mentioned in conversation).
- **(c) Created during this session** — any `bd create` that happened in this session is by construction part of this session's topic.
- **(d) Keyword / label match** — open tasks whose title/labels contain terms from the session topic sentence.

If (a)+(b)+(c) yields an empty set, fall back to (d) only if the user provided an explicit topic in `$ARGUMENTS` after `03`. Otherwise ask the user which open tasks to target.

State the selected task list explicitly in the report with the triggering criterion next to each ID.

### Phase 1 — Gap detection per task

For each selected task, grade against TWO rubrics.

#### Structural gaps (reuse 6-point description from Part 1 A)

`[ ]` What's needed/broken — concrete, not vague?
`[ ]` Where (file:line / page URL / config path / asset path) — specified?
`[ ]` How to reproduce / replay / verify — inputs + context given?
`[ ]` What's already known — including design decisions and rejected alternatives?
`[ ]` Context link — upstream tie set (`discovered-from` / parent epic)?
`[ ]` Resources — files + specs + screenshots + external URLs enumerated?

#### Session-specific gaps (what lives only in volatile session state)

Each one, if unresolved, costs the next session time and quality.

- **`S1` Volatile session state not captured in repo.** Artefacts generated this session that are reference material for the open task but will not survive. Tag with domain-specific examples:
  - *code:* smoke scripts in `/tmp/`, captured test outputs, local benchmark numbers, ad-hoc scripts authored in terminal
  - *content:* research notes, draft outlines, SERP snapshots, competitor URL lists
  - *infrastructure:* SSH terminal transcripts, `docker logs` snippets, command-output proof of state
  - *design:* exploration sketches, colour/spacing variants tried and rejected

- **`S2` Design decisions made in conversation but not recorded.** A choice was made and a rationale articulated, but no `bd decision` / `bd remember` captures it. The NEXT session will either re-litigate the decision or worse, silently reverse it.

- **`S3` Implicit mappings / inventories built this session.** The current session knows a lattice (`test-file × fix × assertion-shape`, `release × commits × user-visible-summary`, `node × role × version`, `brand-voice-rule × applicable-section`) but the open task description does not encode it. The next session will re-scan `git log` / re-read commits / re-run inventory to rebuild it.

- **`S4` Discovered constraints.** Non-obvious rules this session learned but that are not yet expressed anywhere:
  - *code:* runtime invariants (lock ordering, re-render conditions, race windows)
  - *content:* brand voice constraints, legal/regulatory boundaries, SEO guardrails
  - *infrastructure:* firewall rules, DNS ordering, docker compose dependencies
  - *design:* accessibility requirements, device-support matrix
  If this constraint is not written down and the next session violates it, bugs or worse happen.

- **`S5` External references learned.** URLs, spec sections, prior-art pointers, patterns from other repos that informed the work but live only in browser history. If the next session needs to verify something, they must re-find these.

Tag every gap you find with its code (`S1`–`S5`, or one of the structural letters from Part 1). Every tag must have a proposed enrichment action in Phase 2.

### Phase 2 — Enrichment plan (propose, await user approval, apply)

Translate each gap into a concrete action. See `references/mode-3-details.md` for:
- **Gap → Action conversion table** (which `bd` command to use for which `S*` gap)
- **Persistence-path auto-detect table** (where to commit `S1` artefacts based on project structure — `tests/fixtures/` for code, `assets/research/` for content, `docs/runbooks/` for infra, default `docs/orchestration/doc-drafts/`)

Short summary of the mapping:
- Structural gap in Resources → `bd update --description`
- `S1` volatile artefact → commit to auto-detected project path + link from issue
- `S2` design decision → `bd decision "<choice> — rationale — alternatives rejected"`
- `S3` implicit mapping → short: `bd update --notes`; long (>20 lines): commit to `doc-drafts/`
- `S4` discovered constraint → `bd update --notes "CONSTRAINT: …"`; cross-session: additional `bd remember`
- `S5` external reference → add URL to Resources

#### Approval gate (non-negotiable)

Present the full plan as a table:

```
| Task | Gaps | Proposed actions |
|------|------|------------------|
| aob  | S1 x2, S3 | commit smoke scripts to tests/fixtures/aob/; bd update notes with test→fix mapping |
| ebo  | S3, R6    | bd update description with release→commits mapping |
```

Then ask: **"Apply this plan as-is, edit it first, or abort?"**

Do NOT apply until the user has answered. Mode 3 is enrichment, not unsupervised editing of the user's tracker.

### Phase 3 — Apply + handoff summary

After user approval, execute the actions in this order (idempotent each):

1. Commit artefacts (files first; they become linkable from bd in step 3).
2. `bd decision` for captured choices (adds stable identifiers for step 3 references).
3. `bd update --description` / `--notes` for each task (now can reference committed files + decision ids).
4. `bd remember` for cross-session patterns.

After execution, write the **handoff summary** — 2-3 sentences describing the session topic, what landed, and the one or two tasks the fresh session should start with. This goes into the report (see Output template) AND can optionally go into `bd remember` if the user wants it surfaced at the next `bd prime`.

### Cross-domain examples

See `references/mode-3-details.md` for the full cross-domain table (`S1`–`S4` examples for code / content / infrastructure / design) and four end-to-end walkthroughs — one per domain. Load that file when running Mode 3 to calibrate your expectations to the target project's domain.

Short form: the categories `S1`–`S5` are universal. The *wording* of examples adapts to the domain — don't force-fit a code metaphor onto a content task.

### Judgement heuristics for the handover writer

- **Enrich related tasks, not all tasks.** Every unrelated enrichment adds noise to the tracker and hides future signal.
- **Extract knowledge atoms, not conversation transcripts.** `bd update --notes "FINDING: lock released before sleep in rate-limiter"` beats dumping a Claude transcript.
- **Prefer committed files over inline notes for anything >20 lines.** bd notes field is for short facts; long content lives in docs or fixtures with a link.
- **Do not guess decisions.** If the conversation is ambiguous about "why was X chosen over Y", ask the user before writing a `bd decision`. A wrong decision record is worse than no record.
- **Test the enrichment against the central question:** "Would the incoming member be able to read the enriched task and work at my level?" If yes → WARNINGS at worst. If no → keep enriching or escalate to BLOCKED.
- **If volatile state is already lost,** say so explicitly in the report — the user may re-derive it deliberately before ending the session. Don't pretend you recovered something you didn't.

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

### Mode 3 — handoff completeness

Verdict is computed AFTER the enrichment plan is applied (or declined). Measure completeness as (actions-applied / gaps-found) per task and aggregate:

| Aggregate handoff completeness | Verdict |
|---|---|
| Every related open task ≥ 90% (only INFO-level gaps remain, or user explicitly accepted a gap as out-of-scope) | `APPROVED` |
| One or more tasks at 70–89% (one S-level gap persists; known ramp-up cost of 15–30 min) | `WARNINGS` |
| Any related task < 70% OR any `S1`/`S2`/`S4` gap known to be unrecoverable after session end | `BLOCKED` |

- `APPROVED` → safe to end the session. Fresh session can pick up any related open task and work at this session's quality.
- `WARNINGS` → session may end, but the handoff summary must call out the remaining gaps with time-cost estimates so the next session budgets for them.
- `BLOCKED` → do NOT end the session on these terms. The highest-cost gaps are typically `S1` (ephemeral artefacts about to be lost) and `S2` (undocumented design decisions that will be silently reversed). Recover what is still recoverable before exiting.

## Output template

Use this structure exactly. Keep it tight.

### Modes 1 & 2 — template

Skeleton below. Annotated filled examples (code audit for Mode 1, proposal review for Mode 2, plus cross-domain walkthroughs) live in `references/mode-1-2-examples.md` — load when you need to calibrate format or work in a domain you are less familiar with.

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: <1 POST-TASK-AUDIT | 2 MID-TASK-SECOND-OPINION>
Task: <bd-id or "(no issue)"> — <title>
Commit(s): <sha>                     # Mode 1 only
Proposal source: <agent message|diff> # Mode 2 only

### Verdict: <BLOCKED | WARNINGS | APPROVED>

### Part 1 — Protocol compliance    # Mode 1 only; omit in Mode 2
[x] A. Beads description — 6-point
[ ] B. Close reason — verification artefact (severity tag)
[x] C. Commit includes issue ID
... (D, E, F as applicable)

### Part 2 — Expert judgement
Layer 1 — Diagnosis: <one sentence — right problem? why?>
Layer 2 — Approach:  <one sentence — right layer/primitive? why?>
Layer 3 — Execution: <one sentence — implemented well? why?>

Band-aid signals found: <list with codes D*/A*/E*, file:line, one-sentence rationale>
Structural signals found: <list with codes sD*/sA*/sE*, one-sentence rationale>

### Alternative path                 # REQUIRED when verdict != APPROVED
If I were implementing this fresh, I would:
- <concrete approach>
- <mechanism/layer/primitive chosen and why>
- <what this buys that the current fix does not>

### Action items                     # numbered, concrete, addressable
Mode 1: action items target the bd issue / tests / docs.
Mode 2: action items target the proposal (what to revise before re-submit).

### If verdict != APPROVED
Mode 1: preserve findings via `bd update <id> --notes "WORKFLOW-GATE-CHECK: …"`;
        do NOT call bd close; re-run after fixing.
Mode 2: reply to agent with findings + Alternative path; request revised proposal;
        re-run /workflow-gate-check 02 on the revise.
```

### Mode 3 — template

Skeleton below. Fill every placeholder with concrete content from this session. A filled example lives in `references/mode-3-details.md` under "Mode 3 output template — annotated example".

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: 3 HANDOFF-ENRICHMENT
Session topic: <one sentence>
Just-closed task: <bd-id or "(none)"> — <title>
Related open tasks (criterion in brackets):
  - <id> (a|b|c|d: reason)
  - ...

### Verdict: <BLOCKED | WARNINGS | APPROVED>

### Per-task enrichment table
| Task | Before | Gaps found | Actions taken | After |

### Artefacts persisted
- <path> (provenance, size, domain-appropriate persistence path)

### Decisions recorded
- <decision-id> <choice — rationale — rejected alternatives>

### Remembered (cross-session)
- <bd remember entry if useful beyond this task>

### Handoff summary — to next session
<2-3 sentences: topic, landed work, first task for fresh session, still-risky gaps>

### Remaining gaps
- <explicit gap + time-cost estimate for next session>

### If verdict != APPROVED
- Review `Remaining gaps`; recover what you can or record `bd remember` acknowledging loss.
- Re-run /workflow-gate-check 03 after fixing.
```

## Common mistakes

Detailed failure modes organised by scope (across all modes, Modes 1 & 2 specific, Mode 3 specific) live in `references/common-mistakes.md`. Load that file before finalising a verdict — these are the failure modes that turn expert opinion into mechanical checklist compliance.

Three umbrella reminders to keep in mind even without loading the file:

- **Grep-level verdict is not expert opinion.** If your finding could have been produced by a linter, you have not done the job.
- **Domain-agnostic default.** Check project signals before applying any code-only pattern.
- **Half-audit is disqualifying.** Run all Part sections the active mode requires — no shortcuts.

## Troubleshooting

- **No Beads issue for the task** → this is itself a protocol violation. Verdict starts at `BLOCKED`. In the report, add an action item: "Create retrospective Beads issue with 6-point description covering this work, then re-audit."
- **Project has no git** → audit what you can from files + transcript; note the limitation in the report. Verdict leans toward `WARNINGS` because git-based evidence is missing.
- **Verification artefacts referenced but not findable** → `BLOCKED`. Ask user to paste the evidence or re-run the verification in the current session.
- **Conflicting evidence** (user narrative says X, diff shows Y) → trust the diff. Note the discrepancy in findings.
