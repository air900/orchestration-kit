# Triviality Classifier

Phase 3 logic. Decides whether the task is trivial (skip the gate, single dispatch, default reviewer), non-trivial single, non-trivial with architectural impact, or parallel-decomposable.

## Generic non-trivial signals (any one → not trivial)

| Signal | Source | Why non-trivial |
|--------|--------|------------------|
| ≥3 files in zone | `Files in scope` count from Phase 1 distillation | multi-file coordination |
| Public API / contract changes | spec keywords: "endpoint", "schema", "report format", "response shape", "API version", "migration" | breaks consumers |
| Touches `<project>/CLAUDE.md` / `README*.md` / `docs/**/*.md` | path matches in zone | documentation = architectural surface |
| SQL DDL changes | diff regex: `\b(CREATE|ALTER|DROP)\s+TABLE\b` | long-lived artifact |
| Touches `.claude/` or `.github/workflows/` | path matches | CC infrastructure / CI — cascade risk |
| ≥2 independently-doable sub-tasks in the spec | distillation found "and X, and Y, both independent" | parallel-decomposable candidate |

## Generic trivial signals (ALL must hold)

- ≤2 files in zone
- No public API change
- No architectural-doc changes (CLAUDE.md / README / docs/)
- Task is not flagged as epic or priority ≤ 1 in external tracker (if any)
- No `.claude/` / `.github/` / settings / hooks / workflow files touched
- DISTILL did not find "and X, and Y" — single localized task

If even one of these fails, the task is **non-trivial**.

## Mode resolution

Apply the signals; pick the most-restrictive matching mode:

| Mode | Conditions | Gate? | Number of impl agents | Parallel? | Default reviewer |
|------|------------|-------|------------------------|-----------|--------------------|
| `trivial` | all trivial signals hold; no non-trivial signal | no | 1 | — | `pr-review-toolkit:code-reviewer` |
| `non-trivial single` | any non-trivial signal AND no parallel-decomposable signal | yes | 1 | — | `pr-review-toolkit:code-reviewer` |
| `non-trivial + arch-tag` | non-trivial AND arch-signal (CLAUDE/README/docs touch OR task label `architecture`/`design`/`breaking`) | yes | 1 | — | `senior-reviewer` |
| `parallel-decomposable` | ≥2 independently-doable sub-tasks AND zones do not overlap (cross-reference check passes) | yes | N (one per sub-task) | yes | per sub-task tag |

**Default when uncertain:** `non-trivial single`. Better one extra gate than one wrong dispatch.

## Model selection (auto, follows mode)

Pass the `model` parameter to `Agent()` automatically based on the resolved mode. No manual override needed in normal flow.

| Subagent role | trivial | non-trivial single | non-trivial + arch-tag | parallel sub-task |
|---------------|---------|---------------------|--------------------------|--------------------|
| Implementer | `haiku` | `sonnet` | `opus` | per sub-task mode |
| Spec reviewer | `haiku` | `sonnet` | `opus` | match implementer |
| Code-quality reviewer | `haiku` | `sonnet` | `opus` (senior-reviewer) | match implementer |
| Doc-proposer | `sonnet` (always — judgment about arch-relevance) |
| Doc-curator | `sonnet` (always — judgment about archive vs keep, restructure thresholds, group naming) |

Concrete model identifiers (current): `claude-haiku-4-5`, `claude-sonnet-4-6`, `claude-opus-4-7`. Use Sonnet by default if a more specific identifier is unavailable in the harness.

**Why these defaults:**
- Trivial work (≤2 files, no API change, mechanical edits) does not need Opus or Sonnet — Haiku handles it cheaply and fast.
- Non-trivial single tasks (multi-file coordination, contract changes) benefit from Sonnet's depth without Opus cost.
- Architectural and breaking changes get Opus because the cost of a wrong call is much higher than the cost of one Opus dispatch.
- Doc-proposer is fixed at Sonnet because the filter ("arch-worthy or not?") is a judgment call that Haiku slightly under-handles in practice.

**Override via overlay.md** (optional, see [overlay-schema.md](overlay-schema.md)):

```yaml
model_override:
  trivial: claude-sonnet-4-6        # this project wants more rigor on trivial
  non_trivial_arch: claude-opus-4-7 # explicit, even if default already opus
```

## Project-specific signals via overlay.md

If `<project>/.claude/skills/delegate-with-context/overlay.md` exists, controller loads it in this phase and merges its signals with the generic table above. Overlay signals are additive: a path matching an overlay rule flips the task to non-trivial.

Overlay format and examples are documented in [overlay-schema.md](overlay-schema.md). Two minimal examples:

```yaml
# Web app overlay
non_trivial_signals:
  - path_glob: "frontend/src/components/**"
    reason: "shared components; changes ripple"
  - cross_subtree:
      - "frontend/src/**"
      - "backend/api/**"
    reason: "API contract crosses both — coordination required"
```

```yaml
# Data pipeline overlay
non_trivial_signals:
  - path_glob: "pipelines/dbt/models/*.sql"
    reason: "business logic — must review thresholds"
```

Without an overlay file, only the generic signals apply.

## Edge cases

- **File matches both trivial-allowed AND non-trivial signal?** Non-trivial wins. Trivial is the conservative side; promote up.
- **Spec mentions multiple sub-tasks but they share state** (e.g., both modify the same module's exported API)? NOT parallel-decomposable. Treat as `non-trivial single` with the zones merged into one task.
- **Parallel zones share imports** (file A in zone 1 imports file B from zone 2)? Cross-reference check fails — degrade to sequential. See SKILL.md Phase 5 for the grep-based detection logic.
- **Two trivial-looking sub-tasks but combined zone touches CLAUDE.md?** Non-trivial+arch wins; do NOT split into parallel.
- **Bundle hits hard cap (50–60K) at trivial mode?** Re-evaluate: the task is probably bigger than it seemed. Promote to non-trivial single, propose `parallel-decomposable` if signals fit.
