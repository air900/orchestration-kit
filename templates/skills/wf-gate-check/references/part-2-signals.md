# Part 2 — detailed band-aid and structural signal reference

This file backs the condensed tables in `SKILL.md` Part 2. Load it when grading a proposal or landed fix in Modes 1 or 2 and you need the full signal description plus project-specific examples.

## Band-aid signals — detailed

Any ONE ⇒ `WARNINGS` minimum; TWO+ ⇒ `BLOCKED`. Tag each finding with its code so the report is traceable.

### Diagnosis-level (`D*`)

- **`D1` Wrong problem framing** — the fix addresses a symptom or a mis-scoped version of the real question. The proper question is upstream. *Classic: "make X not error" instead of "why is X called with garbage inputs".*
- **`D2` Shallow root-cause analysis** — the first plausible cause was accepted; there is no evidence that alternatives were considered or ruled out. The close reason reads like one line of guesswork.
- **`D3` Symptom over cause** — the user-visible message changed, or a CSS hack was applied for a JS bug, or a DB query was tuned instead of the N+1 upstream being fixed.

### Approach-level (`A*`)

- **`A1` Wrong layer** — the fix sits in the consumer when the invariant belongs in the producer (or vice versa). Leaves the bug reachable via other code paths.
- **`A2` Wrong primitive** — a right-sounding function that does the wrong thing. *Project example: `wp_kses_post()` used for template text where `sanitize_textarea_field()` was correct — `ail-prompt-sanitizer-fix`.*
- **`A3` New mechanism on top of broken one** — a correction or compensation layer added instead of replacing the broken mechanism it papers over.
- **`A4` Bypass of existing abstraction** — direct DB call skipping the repository; direct `fetch` skipping the API client; new global state instead of using the existing context.
- **`A5` Magic number or compensation offset** — arbitrary margin / timeout / delay / retry that papers over a calculation or flow error. *Project example: adding a fixed pixel offset to layout prediction instead of using measured data as ground truth — `drevo` LINE-CARD-CROSSING, where `measureCardBBoxes` was moved post-render.*
- **`A6` Fight with design intent** — the fix works against the prevailing architectural direction of the codebase (e.g., sprinkles global state in a codebase that has been moving toward explicit DI).

### Execution-level (`E*`)

- **`E1` Scope mismatch** — the fix is either too narrow (solves only the reported instance, not the class) OR too broad (unrelated refactors bundled in, inflating blast radius).
- **`E2` Fallback that swallows errors** — `try { ... } catch { /* log and continue */ }`, `?? defaultValue` on data that should never be null, silent retries that mask upstream brokenness.
- **`E3` Duplication instead of reuse** — a new helper / component / class whose logic already exists elsewhere. DRY violated.
- **`E4` Hardcode instead of config** — values that belong in settings / env / CLAUDE.md / DB are baked into code.
- **`E5` Regressions in adjacent code** — any previously-green test fails after the change, even if "unrelated". *Project example: `drevo` stagger-unification was rejected because it regressed elsewhere.*
- **`E6` No regression test** — the exact bug could recur tomorrow and CI would not catch it.
- **`E7` Technical debt left in** — `TODO`, `FIXME`, `// temporary`, commented-out old implementation, "will fix later" with no follow-up issue filed (`discovered-from`).
- **`E8` Readability / testability reduced** — the code is harder to read or harder to test than what it replaces. Future maintainers pay the tax.

## Structural signals — detailed

Present in the fix ⇒ lean toward `APPROVED`. These are positive quality dimensions, not just "absence of band-aid".

### Diagnosis-level

- **`sD1` Correct diagnosis evidenced** — the close reason or proposal articulates the root cause at a level where the fix addresses it; alternatives were considered and ruled out explicitly.
- **`sD2` Class of bugs identified and eliminated** — not just this instance; the change closes the shape of the bug at its source.

### Approach-level

- **`sA1` Right layer** — invariant placed where it belongs (producer, not every consumer).
- **`sA2` Correct primitive adopted** — the right function / type / tool for the job, not a workalike.
- **`sA3` Single source of truth made authoritative** — when two representations diverge, one is promoted to ground truth and the other derived from it (the `drevo` layout/measurement pattern).
- **`sA4` Design intent respected** — the fix extends the codebase's existing direction rather than working around it.
- **`sA5` Architectural prevention** — a new type, invariant, contract, or schema prevents the shape of the bug rather than relying on developer discipline.

### Execution-level

- **`sE1` Right scope** — diff as small as correctness allows, as large as correctness demands. Neither under- nor over-engineered for the problem.
- **`sE2` Existing abstraction improved** — DRY preserved or strengthened; shared code upgraded rather than forked.
- **`sE3` Regression test added** — a concrete test that fails without the fix and passes with it, in the right suite.
- **`sE4` No behavioural side effects** — all existing callers see identical behaviour except the fixed case; verified by full test sweep / Playwright run.
- **`sE5` Readability / testability preserved or improved** — a maintainer in six months understands both WHAT changed and WHY; the code is not harder to test than before.
- **`sE6` Proportionate complexity** — complexity of the fix matches complexity of the problem. A 5-line guard for a 5-line bug. A new subsystem only when a new subsystem is required.
