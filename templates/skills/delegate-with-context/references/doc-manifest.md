# Doc Manifest

Per-project curated index of documentation, maintained by the skill across runs. Reduces ramp-up cost on every dispatch — Phase 0 looks up relevant docs from the manifest instead of re-scanning `docs/` and re-classifying.

## File location — two scopes

The skill supports manifests at two scopes; a project may have either, both, or neither.

**Project-wide manifest** — covers project-level documentation (general conventions, ops runbooks, architecture-wide refs):
```
<project root>/docs/MANIFEST.md
```

**Sub-project manifest** — scoped to a self-contained sub-project (a kit, module, microservice, or independently-developed subdirectory):
```
<project root>/<sub-project-path>/MANIFEST.md
```

Examples of sub-project manifest locations:
- `scripts/<kit-name>/MANIFEST.md` — self-contained script kit
- `services/<service-name>/MANIFEST.md` — microservice in a monorepo
- `apps/<app-name>/MANIFEST.md` — sub-application

Each manifest is independent. Sub-project manifests are scoped — they do NOT include unrelated project-level docs. Project-wide manifest covers project-level concerns. Phase 0 discovers both via lookup priority (next section).

Tracked in git, human-readable, machine-parseable (Markdown with H2/H3 sections + bulleted entries).

The manifest is **optional**. If neither scope exists, Phase 0 gracefully degrades to scanning `docs/` as before, and the doc-curator (Phase 8) proposes creating an initial manifest at the right scope.

## Lookup priority (Phase 0)

When the task zone is in or related to a sub-project area (file paths inside `<sub-project>/`, components mentioned in distilled task, Beads tags pointing to sub-project):
1. Read `<sub-project>/MANIFEST.md` first — primary source
2. Optionally also read `<project root>/docs/MANIFEST.md` if it exists AND the task has cross-cutting context (touches files outside the sub-project, mentions project-wide concerns)
3. Fallback to `docs/` scan if no manifest at either scope

When the task zone is project-wide (root files, multiple sub-projects touched, no clear sub-project locus):
1. Read `<project root>/docs/MANIFEST.md` first — primary source
2. Fallback to `docs/` scan

The architect's distilled task spec (Phase 1) is what determines "sub-project vs project-wide" — file paths, mentioned components, and Beads issue context.

## Path conventions

Entries in any manifest use paths RELATIVE to the manifest's own location:

**In project-wide manifest** (`<root>/docs/MANIFEST.md`):
- Project root: `../README.md`, `../CLAUDE.md`
- Other docs: `runbook.md`, `research/<topic>.md`
- Sub-projects: `../scripts/<kit>/README.md`

**In sub-project manifest** (e.g., `scripts/anamnesis/MANIFEST.md`):
- Same sub-project: bare paths (`README.md`, `setup/install.sql`)
- Project root: parent traversal (`../../docs/runbook.md`, `../../CLAUDE.md`)
- Other sub-projects: parent traversal (`../other-kit/README.md`)

Avoid project-root-absolute paths from a 2-level-deep sub-project manifest — they break when the sub-project is moved or copied.

## Lifecycle states (per entry)

Each entry in the manifest has a state. Skill behavior depends on the state:

| State | Loaded into bundle? | Meaning |
|-------|--------------------|---------|
| `active` | yes (when group matches task) | currently relevant; living artifact (runbook, research, design ref) |
| `spec-in-progress` | yes (when explicitly relevant to the in-flight task) | task spec; will become `archived` when the result artifact lands |
| `plan-in-progress` | yes (when explicitly relevant to the in-flight task) | implementation plan; same lifecycle as spec |
| `archived` | NO (kept in manifest for history only) | superseded; entry must include `superseded-by: <path>` link |

`archived` entries are NOT auto-loaded into the bundle. They serve as audit trail ("where did the old plan go? — superseded by the runbook").

## Two presentation modes

The manifest auto-switches based on size and diversity:

**Flat mode** — total entries ≤ 8 AND no clear task-type split:

```markdown
# Documentation Manifest

## Documentation
- README.md — what this project is, audience: client | active
- CLAUDE.md — engineering conventions | active
- runbook.md — operational procedures | active
- docs/architecture.md — high-level architecture | active
```

**Grouped mode** — total entries > 8 OR ≥ 2 distinguishable task-types:

```markdown
# Documentation Manifest

## General (always relevant)
- README.md — project overview, audience: clients | active
- CLAUDE.md — engineering conventions | active
- runbook.md — operational procedures | active

## For tasks: <task-type-1>
- docs/<topic>.md — short purpose | active
- docs/research/<topic>.md — research report | active

## For tasks: <task-type-2>
- docs/<other-topic>.md — short purpose | active

## Archived (kept for history, NOT auto-loaded)
- docs/superpowers/plans/<old-plan>.md
  superseded-by: docs/runbook.md
- docs/superpowers/specs/<old-spec>.md
  superseded-by: docs/architecture.md
```

Auto-switching thresholds:
- Flat → Grouped: when `active` entries exceed 8, OR when the curator identifies ≥ 2 task-types from commits/Beads tags.
- Grouped → Flat: when `active` entries fall to ≤ 5 AND only one task-type remains.

The doc-curator (Phase 8) proposes the switch; the architect approves it.

## Entry format

Each bullet is one line, parseable:

```
- <path> — <one-line purpose, ≤80 chars> | <state>
```

For `archived` entries, the next indented line carries `superseded-by`:

```
- <path>
  superseded-by: <path-or-URL>
```

For `spec-in-progress` and `plan-in-progress`, the next indented line carries the bd ID it belongs to (so the curator can detect when to auto-archive):

```
- docs/superpowers/specs/<topic>-design.md — design spec | spec-in-progress
  bd: <project-prefix>-<id>
```

When that bd is closed AND a result artifact appears (runbook / research / new doc cross-referenced from commits), the curator proposes:
- Move spec/plan entries → `archived` with `superseded-by: <result-doc>`
- Add result-doc as `active`

## First-time bootstrap

When a project adopts the skill but has no `docs/MANIFEST.md`:

1. The architect runs `/delegate-with-context` on a regular task.
2. Phase 0 detects no manifest, falls back to scanning `docs/`.
3. Phase 8 doc-curator's first proposal in this project's summary is:
   > "No `docs/MANIFEST.md` exists. Initial draft based on this project's `docs/` tree:
   > <draft manifest>
   > APPLY?"
4. Architect reviews and approves; controller writes `docs/MANIFEST.md` directly via `Edit`.

After bootstrap, every subsequent run uses Phase 0 lookup. No manual maintenance required — curator keeps it in sync.

## How Phase 0 uses the manifest

```
Phase 0 — PROJECT-DOCS-LOAD
    │
    ├─ Read docs/MANIFEST.md
    │   ├─ Not found → fallback (scan docs/), flag for curator proposal
    │   └─ Found → parse sections
    │
    ├─ Always include: General group (or all entries in flat mode)
    │
    ├─ Phase 3 (CLASSIFY) decides task-type / mode
    │   └─ Pick matching "For tasks: X" group → include those entries
    │
    └─ Output: list of paths to inline into bundle's "Architecture refs"
       section (governed by context-bundle.md size budget)
```

## How Phase 1 user-link analysis interacts

When the architect's invocation message contains links/paths to docs:

| Branch | Action |
|--------|--------|
| Link is already in manifest (any state) | Already loaded; no flag |
| Link is NOT in manifest, looks one-shot (debugging, throwaway reference) | Include in bundle for THIS run only; do NOT flag for manifest |
| Link is NOT in manifest, looks like permanent context (architecture doc, new pattern) | Include in bundle for this run; **flag** for Phase 8 curator: "user provided <path>; consider adding to manifest, group: <inferred>" |
| Link is NOT in manifest, irrelevant to task (off-topic, accidental paste) | IGNORE; note in summary "user-provided <path> appears off-topic — skipped" |

The "permanent vs one-shot" inference uses these signals:
- One-shot: Beads issue is `--type bug`, single-file task, decision-distilled is local fix
- Permanent: doc adds project-wide knowledge (architecture, runbook section, decision record), not tied to one bug

When uncertain → treat as one-shot (conservative, avoids manifest pollution).

## How Phase 8 curator updates the manifest

Curator's auto-checks (each can produce one or more proposals):

| Trigger | Proposal |
|---------|----------|
| Result artifact (`runbook*.md`, `docs/research/*.md`, new `docs/<topic>.md`) was created/modified | ADD as `active` to relevant group |
| Existing `spec-in-progress` or `plan-in-progress` entry's bd-id is now closed AND a result artifact landed in same area | ARCHIVE that entry with `superseded-by: <result-path>` |
| `active` entries in any one group/section exceed 8 | RESTRUCTURE — split group into sub-groups |
| Flat mode hit threshold (>8 entries OR ≥2 task-types) | RESTRUCTURE — convert flat → grouped |
| Grouped mode shrunk back (≤5 entries, 1 task-type) | RESTRUCTURE — convert grouped → flat |
| Phase 1 flagged a user-provided link | ADD with reasoning from Phase 1 |
| Existing `active` entry's path no longer exists in repo | ARCHIVE with note `removed from repo at <commit>` |
| Existing `active` entry hasn't been referenced in any commit message or Beads body for >90 days AND no result artifact references it | propose ARCHIVE with reason `dormant`; architect can override |

Each proposal goes into the run summary as APPROVE-NEEDED. Controller applies approved proposals via `Edit` directly.

## Manifest hygiene rules (the curator must follow)

- **Never auto-delete entries.** Archive instead — preserves audit trail.
- **Never auto-add entries that came from one-shot user references.** Only add if Phase 1 flagged them as "permanent" AND architect approves.
- **Always include `superseded-by` for archived entries** if the supersession is identifiable; otherwise mark `superseded-by: <reason>` (e.g., `removed from repo` or `dormant`).
- **Don't fabricate task-types.** Group names must come from real Beads tags or actual file-tree organization, not invented categories.

## Generic examples (no project-specific bindings)

### Web application project

```markdown
## General (always relevant)
- README.md — what the app does, audience: end-users | active
- CLAUDE.md — engineering conventions | active
- ARCHITECTURE.md — service map | active

## For tasks: Frontend
- docs/frontend/components.md — component catalog | active
- docs/frontend/state-management.md — Redux patterns | active

## For tasks: Backend API
- docs/api/openapi.yaml — API spec | active
- docs/api/authentication.md — auth flows | active

## Archived
- docs/old-deployment.md
  superseded-by: docs/runbook.md
```

### Data pipeline project

```markdown
## Documentation
- README.md — pipeline overview | active
- CLAUDE.md — conventions | active
- docs/dbt-models.md — model layer doc | active
- docs/runbook.md — ops procedures | active
```

### Library project (truly small, flat mode)

```markdown
## Documentation
- README.md — usage and API surface | active
- CHANGELOG.md — version history | active
- CONTRIBUTING.md — contributor guide | active
```
