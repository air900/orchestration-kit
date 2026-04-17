# Common mistakes the auditor itself makes

Load this file during any Mode when the skill is about to produce its verdict. These are the failure modes that turn expert opinion into mechanical checklist compliance — exactly what the skill exists to prevent.

## Contents

- Across all modes
- Modes 1 & 2 specific
- Mode 3 specific

## Across all modes

- **Grep-level verdict** — if your conclusion could have been produced by a checklist runner or a linter, you did not give expert opinion. The verdict is the compressed form of reasoning — the reasoning itself must be visible in the findings.
- **Assuming a code-project default** — this skill is domain-agnostic. Check project signals (`tests/` vs `assets/` vs `docs/runbooks/`) before applying any pattern. A code-first framing imposed on a content or infra project is its own kind of band-aid.
- **Half-audit** — all six Part 1 sections run in Mode 1; all three Part 2 layers run in Modes 1-2; all three Part 3 phases run in Mode 3. No shortcuts.

## Modes 1 & 2 specific

- **Skipping Layer 1 (Diagnosis)** — most tempting failure. Code looks clean → pronounce APPROVED → but the fix solved the wrong problem. Always ask first: "was the right question answered?"
- **Taking "I did it systemically" on trust** — always check the diff. Structural work is visible in code, not in prose.
- **Confusing churn with depth** — a 10-line diff can be structural; a 300-line PR can be band-aid. "Minimal diff" is not a structural signal on its own — a 2-line `if (foo) return;` is still a band-aid.
- **Leniency on verification** — "tested, works" without artefacts is not verification. It is a claim. → `BLOCKED`.
- **Confirmation bias** — when the user is senior / confident / just explained the fix at length, the temptation to rubber-stamp is maximal. Resist it. Independent second opinion is the entire value of this skill.
- **Withholding an Alternative** — saying `BLOCKED` without "here is what I would do instead" is low-value. Expert judgement is actionable; the alternative is part of the product.
- **Redesigning the feature** — the opposite failure. Audit what landed; don't scope-creep into a product redesign. If the real issue is product-level, say so in one sentence and defer.

## Mode 3 specific

- **Enriching unrelated tasks** — Mode 3's scope filter exists for a reason. Pumping unrelated P1 tasks with noise from this session's context hides future signal.
- **Dumping conversation into bd notes** — bad form. Extract *knowledge atoms* (one-line findings, mappings, decisions with rationale), not transcripts. If the content is transcript-shaped, commit it to `docs/orchestration/doc-drafts/` and link from the issue.
- **Fabricating a design decision** — if the conversation is ambiguous about "why was X chosen", ask the user before `bd decision`. A wrong decision record is worse than no record.
- **Silently losing volatile state** — if `S1` artefacts are about to die and you cannot recover them, say so explicitly in the report. Don't pretend.
- **Force-fitting code vocabulary to non-code domains** — "runtime invariants" for a content task is a smell. Use the domain-appropriate wording (brand voice rule, SEO guardrail, legal boundary) and flag the category (`S4`) the same.
- **Acting before approval** — Mode 3 Phase 2 requires the user to approve the enrichment plan. Running `bd update` / `bd decision` / `git commit` before approval is a trust violation.
- **Stopping at "everything looks fine"** — if Phase 1 finds zero gaps on every related task, either (a) no related tasks existed, (b) the scope filter was wrong, or (c) your gap detection was shallow. Re-check before declaring APPROVED.
