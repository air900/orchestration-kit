---
name: delegate-with-context
description: Use when the architect/product owner has finished discussing options in the current session, picked one, and wants to dispatch implementation to subagents WITHOUT polluting the main session context. Distills the chat decision, reconciles Beads issues, builds a full context bundle, dispatches implementer + spec-reviewer + code-quality-reviewer subagents (each with mandatory verification-evidence in status reports), runs end-of-run doc-proposer and knowledge-harvester, and returns a compact summary. Project-portable — picks up conventions from CLAUDE.md and optional overlay.md. Trigger via slash command /delegate-with-context.
---

# delegate-with-context

A chat-to-subagents dispatch gateway. The architect chat stays clean; subagents do the work with full context.

## Trigger

Slash command `/delegate-with-context` (defined in `.claude/commands/delegate-with-context.md`).

You (the controller) self-introspect your *current loaded context* — there is no separate "read chat" tool. You ARE the conversation memory. Whatever context exists in this session is what you have to work with.

The skill works with any of these context shapes — Phase 1 (DISTILL) figures out which one applies and adapts:

- **Long options discussion + a pick** — extract chosen option + rejected alternatives.
- **Short context + a pick** — e.g., the architect typed `1` or `B` to pick from a list you just offered, then invoked the skill. Use that pick as the chosen option; alternatives may or may not be in context.
- **Primary task spec** — the architect's recent message itself describes the task to delegate (handoff text from another session, fresh-session kickoff, "build X" instruction). Use that text as the task spec.
- **Pure handoff blob** — paste of context from another session, ending with "delegate this". Treat the blob as the task spec.

The skill refuses only when there is **no actionable task content anywhere** in the loaded context — neither a discussion-with-pick, nor a recent directive, nor a handoff blob. In that case:

> "I don't see a task to delegate in this session. Either describe the task in your message, paste handoff context from another session, or have a quick discussion first, then re-invoke."

For everything else, run Phase 1 and adapt to whatever shape the context has.

## Concurrency (Q3)

Before Phase 1, check for `.claude/skills/delegate-with-context/.lock`:

- If file exists and was created less than 1 hour ago: refuse with "Previous /delegate-with-context run still in progress. If you believe the run is stale, delete `.claude/skills/delegate-with-context/.lock` and re-invoke."
- Else: create the lock file with current PID + ISO8601 timestamp; remove it on Phase 9 completion or on any abort path.

## Phases

### Phase 0 — PROJECT-DOCS-LOAD

Discover manifests using the lookup priority from [`references/doc-manifest.md`](references/doc-manifest.md):

1. **Sub-project manifest** at `<sub-project>/MANIFEST.md` — primary if task zone is in or related to a sub-project (e.g., `scripts/<kit>/`)
2. **Project-wide manifest** at `<project root>/docs/MANIFEST.md` — primary for project-wide tasks; optional secondary for cross-cutting sub-project tasks
3. **Fallback scan** of `docs/` — if no manifest at either scope, collect candidate paths and flag for Phase 8 doc-curator to bootstrap one at the right scope

The architect's distilled task spec (Phase 1) determines whether to read sub-project manifest, project-wide manifest, or both.

Output: structured list of doc paths that Phase 4 will inline into the bundle's "Architecture refs" section, governed by the size budget. Manifest entries with state `archived` are NEVER loaded.

### Phase 1 — DISTILL (self-introspect, adaptive)

Examine your current loaded session context. Find the task to delegate from whatever is there. Apply this priority order:

1. **Architect's most recent directive** — if the latest architect message clearly says "delegate X" / "build Y" / "do this" (with or without a number/letter referring back to an offered list), use it. If it references a list you offered (e.g., architect wrote `1` or `B`), resolve the number/letter to the corresponding item from your immediate prior offer.
2. **Options + pick** — if the recent context has a discussion of alternatives followed by a pick, use the picked option as the chosen task; record alternatives as rejected variants in the bundle's Decision distilled.
3. **Handoff blob** — if the architect pasted a chunk of context from another session and asked to delegate it, treat the blob as the task spec.
4. **First-message task** — if the session is fresh and the invocation message itself describes the task, use it.

For each, also extract whatever IS available (don't fabricate what isn't):

- **Constraints** surfaced anywhere in context (must-not-do rules, performance limits, compatibility, language requirements)
- **Special invariants** the architect emphasized
- **Rejected alternatives** if a discussion happened — use the **rejection inference rule**: when the architect picked X out of {A, B, X, C}, A/B/C are rejected by default with reason `user picked X from set {A,B,X,C}` unless an explicit reason was given. **If no alternatives were discussed, this section of the bundle is just absent — do not fabricate rejected options.**

If the context is genuinely empty (no directive, no discussion, no handoff, no task in invocation message), refuse per the Trigger section's refusal text.

If the directive is present but ambiguous (e.g., `1` but no clear "1" in your immediate prior context), ask:

> "I see this looks like a pick — what does <token> refer to? Or paste/restate the task."

Do NOT proceed until the task is unambiguous. Triviality-classifier (Phase 3) will decide complexity — including "simple → 1 agent". Phase 1 just identifies WHAT.

**User-provided link analysis** (when the architect's invocation message contains paths/URLs to docs): apply the decision tree from [`references/doc-manifest.md`](references/doc-manifest.md) → "How Phase 1 user-link analysis interacts". Each link is classified as already-in-manifest / one-shot / permanent / irrelevant. Permanent links are flagged for Phase 8 doc-curator. Bundle inclusion happens for everything except `irrelevant`.

### Phase 2 — BEADS-RECONCILE

Follow [`references/beads-reconcile.md`](references/beads-reconcile.md):

- `bd search` by keywords from the distilled task
- If a relevant open issue exists → refine its description / notes / design
- Otherwise → `bd create` using the inlined 6-point template
- If `.beads/` is not present in the project → follow the no-Beads fallback documented in beads-reconcile.md

### Phase 3 — CLASSIFY

Apply [`references/triviality-classifier.md`](references/triviality-classifier.md):

- Generic signals first (file count, public API, doc/CLAUDE.md touch, SQL DDL, `.claude/`, epic/p1, parallel)
- Load `.claude/skills/delegate-with-context/overlay.md` (per [`references/overlay-schema.md`](references/overlay-schema.md)) if present; merge signals (additive)
- Decide mode: `trivial` / `non-trivial single` / `non-trivial + arch-tag` / `parallel-decomposable`

### Phase 3.5 — GATE (only for non-trivial modes)

For `non-trivial single` / `non-trivial + arch-tag` / `parallel-decomposable` modes, print mini-plan to architect chat:

```markdown
**Mode:** <mode>; reasoning: <which signals fired>
**Beads:** <create new id-XX with title "..."> OR <refine existing bd-YY>
**Implementer agents:** <N> (<parallel|sequential>)
**Reviewer:** <pr-review-toolkit:code-reviewer | senior-reviewer | general-purpose-fallback>
OK to proceed? (yes/edit/cancel)
```

Wait for architect "yes" before proceeding. For `trivial` mode, skip this phase.

### Phase 4 — BUILD CONTEXT BUNDLE

Follow [`references/context-bundle.md`](references/context-bundle.md). Single artifact, identical for all implementer subagents in this run (each gets the same bundle plus task-specific addendum).

Apply size budget. If hard cap (50–60K tokens) is exceeded with all category 5–7 trimming applied, the task is too large for one dispatch — return to Phase 3 and propose `parallel-decomposable` decomposition.

### Phase 5 — DISPATCH

For each implementer task:

- Use the template from [`references/prompt-implementer.md`](references/prompt-implementer.md)
- Subagent type: `general-purpose` (specialized agents lack required skill access — see prompt-implementer.md "Subagent type")
- **Model**: pass the `model` parameter automatically based on the mode from Phase 3 (see [`references/triviality-classifier.md`](references/triviality-classifier.md) → "Model selection"). Trivial → Haiku, non-trivial → Sonnet, arch-tag → Opus. Same logic applies to spec-reviewer (Phase 6) and code-quality reviewer (Phase 7) — match the implementer's mode. Doc-proposer (Phase 8) is always Sonnet; knowledge-harvester (Phase 8) is always Haiku.
- For `parallel-decomposable` mode: **cross-reference check first**. Pseudo-logic:
  ```bash
  for f in zone1_files; do
    grep -l "$(basename $f .ext)" zone2_files
  done
  # Any matches → degrade to sequential single-zone mode
  ```
  If files in different parallel zones reference each other (imports, includes), degrade to `non-trivial single` and merge the zones — the work is not parallelizable safely.
- Parallel dispatch: single tool-call with N concurrent `Agent()` invocations.
- On `NEEDS_CONTEXT`: greedy bundle extension per [`references/context-bundle.md`](references/context-bundle.md) "Adaptive deepening", then **fresh** Agent dispatch (every Agent call is a new subagent — there is no "redispatch the same agent").
- Dispatch budget: ≤4 Agent calls per task. After that, escalate to architect: "subagent could not converge in 4 dispatches; recommend architect review."

### Phase 6 — SPEC REVIEW

Per implementer task: dispatch using [`references/prompt-spec-reviewer.md`](references/prompt-spec-reviewer.md).

- Loop bound: ≤3 iterations of (review → implementer fixes → re-review).
- On ISSUES, dispatch a **fresh** implementer subagent with the original prompt plus an "Issues from spec review" addendum and require fixes.
- On APPROVED → Phase 7.

### Phase 7 — CODE-QUALITY REVIEW

Per implementer task: dispatch using [`references/prompt-code-reviewer.md`](references/prompt-code-reviewer.md).

- Default reviewer: `pr-review-toolkit:code-reviewer`.
- Architectural cases (Beads label `architecture` / `design` / `breaking`, OR task touches CLAUDE.md / runbook / `docs/` / `.claude/`): `senior-reviewer`.
- Fallback (R2 — neither installed): `general-purpose` with read-only addendum.
- Loop bound: ≤3 iterations.
- For `parallel-decomposable` mode: after all per-task code-quality reviews APPROVED, run **one** integration-pass code-reviewer dispatch on the combined diff of the parent ref. This catches issues that per-task reviewers cannot see (e.g., conflicting helpers, redundant abstractions). Same loop bound.

### Phase 8 — END-OF-RUN PIPELINE (parallel)

Single tool-call with three concurrent `Agent()` invocations:

- doc-proposer subagent — [`references/prompt-doc-proposer.md`](references/prompt-doc-proposer.md) — edits to existing doc CONTENT
- knowledge-harvester subagent — [`references/prompt-knowledge-harvester.md`](references/prompt-knowledge-harvester.md) — LightRAG inserts
- doc-curator subagent — [`references/prompt-doc-curator.md`](references/prompt-doc-curator.md) — edits to manifest STRUCTURE (add/archive/restructure entries; bootstrap if missing)

All three return summaries (no raw diffs). Proposer and curator proposals are stored for architect review in Phase 9; harvester's inserts are already done.

The three subagents are independent: proposer touches `*.md` content, curator touches `docs/MANIFEST.md` structure, harvester touches LightRAG. No shared state.

### Phase 9 — COMPACT SUMMARY

Print to architect chat. The summary has TWO halves: **architect-facing** (what changed, how to use it, what's next) on top, and **audit detail** (commits, verification, beads) on the bottom. The architect should be able to act on the run after reading only the top half.

**Required structure:**

```markdown
## /delegate-with-context — completed run

**Mission:** <one line>
**Mode:** trivial | non-trivial | parallel(N)

### ✓ Что изменилось для вас (Impact)
<2-5 plain-language lines describing what new capability/fix/feature LANDED from
the architect's perspective. NOT a commit list. Use product/user/operator
language, not source paths. If versions bumped, mention them.>

### ▶ Как этим воспользоваться сейчас (How to use)
<Numbered list of CONCRETE actions the architect needs to take next.
Examples: merge a worktree branch, deploy backend, run a test, click a link,
re-run a script, close a Beads issue. Each step should be copy-paste-runnable
or one-click-clear. If nothing is required (e.g., a doc-only fix landed
directly on master), say "ничего не требуется — изменение уже применено".
If a follow-up dispatch is offered, give the exact /delegate-with-context
phrase the architect can type.>

### 📋 Что осталось на потом (Optional follow-ups)
<Non-blocking items: code-quality nits, polishing rounds, deferred R3
spot-checks, etc. Say "ничего" if empty. These are NOT action-required
items — those go in "Как воспользоваться" above.>

### 🔍 Где смотреть детали (Where to look)
<3-7 paths to the most important touched files, with one-line description
each. Optional — skip if the change is small enough that the file list
would just be noise.>

---

**Beads:** closed bd-X, bd-Y; opened bd-Z (<reason>); open bd-W (<deploy-then-close>)
**Commits:** <SHA list with one-line subject>; flag worktree branches separately
**Verification (Iron Law evidence):**
  - bd-X: <command> → exit <code>, <stdout summary line>
  - bd-Y: <command> → exit <code>, <stdout summary line>
**Doc proposals applied:** <N> (or "APPROVE-NEEDED:" if waiting on architect)
**Knowledge harvest:** <N inserts, M skipped (similarity)> | SKIPPED — no LightRAG
```

**The four sections above the `---` line are MANDATORY. Skipping any of them is a contract violation.**

**Why:**
- "Mission" + "Mode" — situational awareness in two lines.
- "Что изменилось" — answers "what should I tell my team / my future self about this run?" without reading commits.
- "Как воспользоваться" — answers "is there something I need to do RIGHT NOW?" Without this, the architect has to reverse-engineer next steps from the audit detail.
- "Что осталось на потом" — separates optional polish from required action; prevents scope confusion.
- "Где смотреть детали" — for the architect who wants to inspect; reduces "I'd rather read the code" syndrome.

The audit detail below `---` is reference material, not narrative. The architect reads it only if the top half raises a question.

If the architect approves any doc proposals (replies with "apply 1, 3" or similar), apply them yourself via `Edit` directly — no separate applier subagent. Then commit with conventional message.

Release the lock file (`rm .claude/skills/delegate-with-context/.lock`).

## Status contract — Iron Law

Every implementer / reviewer subagent MUST return a status block per [`references/status-contract.md`](references/status-contract.md). The `verification` block is **required** for `DONE` and `DONE_WITH_CONCERNS`. If absent, reject as `BLOCKED` with the message specified in status-contract.md and re-dispatch a fresh subagent.

This is the single most important contract in the skill. Without it, all the loop bounds and reviewers are theatre — agents can claim success without proof.

## --dry-run flag

If invoked with `--dry-run`:

1. Run Phases 1–4 normally (DISTILL, BEADS-RECONCILE, CLASSIFY, BUILD CONTEXT BUNDLE).
2. For Phase 5 (DISPATCH), instead of calling `Agent()`, **print** the planned implementer prompt(s) to the architect chat — full bundle + task spec, formatted as the actual prompt would look.
3. Skip Phases 6, 7, 8, 9.
4. Release the lock file.

Useful for debugging the classifier, the bundle assembly, and the prompt templates without burning subagent budget.

## References

- [status-contract.md](references/status-contract.md) — Iron Law contract (mandatory)
- [context-bundle.md](references/context-bundle.md) — bundle structure + size budget + adaptive deepening
- [beads-reconcile.md](references/beads-reconcile.md) — find-or-create + 6-point template + no-Beads fallback
- [triviality-classifier.md](references/triviality-classifier.md) — modes + overlay-hook + model selection
- [doc-manifest.md](references/doc-manifest.md) — Phase 0 manifest schema + lifecycle + decision trees
- [prompt-implementer.md](references/prompt-implementer.md) — implementer subagent prompt
- [prompt-spec-reviewer.md](references/prompt-spec-reviewer.md) — spec-compliance review
- [prompt-code-reviewer.md](references/prompt-code-reviewer.md) — code-quality review with R2 fallback
- [prompt-doc-proposer.md](references/prompt-doc-proposer.md) — architectural doc proposals (content)
- [prompt-doc-curator.md](references/prompt-doc-curator.md) — manifest structural updates (Phase 8)
- [prompt-knowledge-harvester.md](references/prompt-knowledge-harvester.md) — Memory Pyramid + dedup
- [overlay-schema.md](references/overlay-schema.md) — optional per-project YAML signals
