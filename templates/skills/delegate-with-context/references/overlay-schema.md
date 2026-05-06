# Overlay Schema (optional per-project)

Optional file that lets a project add project-specific signals to the triviality classifier and other phase-extension hooks, without modifying the skill itself. The skill is portable; the overlay is project-local.

## File location

```
<project>/.claude/skills/delegate-with-context/overlay.md
```

This file is **optional** and **gitignore-able**. The skill works fully on generic signals if no overlay exists.

When copying the skill to a new project, do NOT copy your previous project's `overlay.md`. Each project gets its own (or none).

## Schema

The overlay is a Markdown file with one or more YAML code blocks. Controller parses YAML blocks, ignores prose around them.

```yaml
non_trivial_signals:
  - path_glob: <glob pattern relative to project root>
    reason: <why this path is non-trivial in this project>
  - cross_subtree:
      - <glob 1>
      - <glob 2>
    reason: <why coordination matters>

doc_paths:
  # OPTIONAL — additional docs the doc-proposer should scan beyond defaults
  - <path>

skip_phases:
  # OPTIONAL — disable phases that don't apply in this project
  # Allowed values: knowledge-harvest, doc-proposer
  - <phase-name>

model_override:
  # OPTIONAL — override default model selection (see triviality-classifier.md)
  # Keys: trivial, non_trivial, non_trivial_arch, doc_proposer, knowledge_harvester
  # Values: any model identifier the harness accepts
  trivial: <model-id>
  non_trivial: <model-id>
  non_trivial_arch: <model-id>
  doc_proposer: <model-id>
  knowledge_harvester: <model-id>
```

All four top-level keys are independent — supply only what you need.

## Field details

### `non_trivial_signals`

Array of signal definitions. Each entry flips the task to non-trivial when matched. Two signal kinds:

**`path_glob`** — match by file path:
- `path_glob: "<glob>"` — any file in the task zone matching this glob makes the task non-trivial
- `reason` — human explanation, surfaced in the controller's mini-plan

**`cross_subtree`** — match by zone-spanning:
- `cross_subtree: [<glob1>, <glob2>]` — non-trivial if the task touches files matching BOTH globs (i.e., changes span the two subtrees)
- `reason` — explanation

### `doc_paths`

If your project has docs in non-standard locations (e.g., `wiki/` or `internal-docs/`), list them here. Doc-proposer adds them to its scan list in addition to the defaults (`README*.md`, `docs/**/*.md`, `<project>/CLAUDE.md`).

### `skip_phases`

If a phase doesn't apply (e.g., the project has no LightRAG and you don't want the harvester to even attempt), list it here. Currently supported:
- `knowledge-harvest` — skip Phase 8's knowledge-harvester subagent entirely
- `doc-proposer` — skip Phase 8's doc-proposer subagent entirely

Don't use `skip_phases` to hide problems — if the phase should run but is failing, fix the cause. Use this only when the phase is structurally inapplicable.

## Examples

### Web application overlay

```yaml
non_trivial_signals:
  - path_glob: "frontend/src/components/**"
    reason: "shared components — changes ripple across pages"
  - cross_subtree:
      - "frontend/src/**"
      - "backend/api/**"
    reason: "API contract crosses both — coordination required"

doc_paths:
  - "wiki/architecture.md"
```

### Data pipeline overlay

```yaml
non_trivial_signals:
  - path_glob: "pipelines/dbt/models/*.sql"
    reason: "business logic — must review thresholds and joins"
  - path_glob: "schemas/*.json"
    reason: "data contract — downstream consumers depend on it"

skip_phases:
  - knowledge-harvest  # this project doesn't use LightRAG
```

### Minimal overlay (just one extra signal)

```yaml
non_trivial_signals:
  - path_glob: "config/feature-flags.yaml"
    reason: "feature flags affect production behavior"
```

## How controller loads it

1. Phase 3 (CLASSIFY) starts.
2. Controller checks for `<project>/.claude/skills/delegate-with-context/overlay.md`.
3. If present, parses all YAML code blocks; merges:
   - `non_trivial_signals` ADD to the generic signal list (additive — overlay never removes generic signals)
   - `doc_paths` ADD to doc-proposer's scan list
   - `skip_phases` directly disables the named phases for this run
4. If overlay file is malformed YAML or has unknown top-level keys, controller logs a warning to the architect chat and proceeds with generic signals only.

The overlay is loaded fresh on every dispatch, so changes take effect immediately without restarting anything.
