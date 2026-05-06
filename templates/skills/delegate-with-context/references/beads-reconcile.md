# Beads Reconcile

Phase 2 logic. Find or create the Beads issue this dispatch will be bound to. Update its description / notes / design when needed. Handle absence of Beads gracefully.

## Find-or-create logic

1. Extract 3–5 keywords from the distilled task (Phase 1).
2. Run `bd search "<keyword1 keyword2 ...>"` — case-insensitive, broad.
3. Inspect results:
   - **Exact match (one open issue clearly about this work):** mark as the target issue. Refine: append the distilled decision to `notes` if not already present (rejected variants are gold for future-you).
   - **Close match (one or more open issues, plausibly related):** show the architect the candidates. Ask: "Use #<id> or create new?" Default after 2-min wait: create new (existing ones may have stale scope).
   - **No match:** create new issue.
4. If creating new:
   - `bd create --title="<one-line summary>" --type=<task|bug|feature|epic> --priority=<2 or per overlay rules> --description="<6-point template, see below>"`
   - Then `bd update <new-id> --claim` to mark in_progress + take exclusive lock.
5. Update existing or fresh issue's `notes` with one line:
   `delegate-with-context dispatch <ISO8601 timestamp>: <one-line decision summary>`
   This breadcrumb makes future sessions audit-trail-friendly.

## 6-point issue template (English)

Always English (per global CLAUDE.md rule for Beads artefacts — token efficiency). Six required sections, no exceptions:

```markdown
## Why
<business / technical reason this issue exists; one short paragraph>

## Goal
<specific outcome we want; concrete enough to be falsifiable>

## Done when
<acceptance criteria; bullets are fine; must be testable>

## Approach
<high-level technical strategy; not full design — pointers to spec / plan if any>

## Risks
<known unknowns; things that could go wrong; mitigations if obvious>

## Verification
<how we'll prove it's done — test command + expected output, or other concrete check>
```

When updating existing issues whose original description doesn't have all six points, do NOT rewrite — instead add a `## delegate-with-context refinement` block at the bottom of the description with the missing points filled in. Preserves history.

## Update existing issue rules

Distribute new content into the right field; do not stuff everything into `notes`:

| New content | Beads field | Rationale |
|-------------|-------------|-----------|
| Decision distilled (chosen approach + rejected alternatives + reasons) | `description` (append "## Refinement" block) OR `design` if the issue tracks design separately | Structural, audit-trail value |
| Architect-surfaced invariant / constraint | `description` "Refinement" | Same |
| Run-by-run breadcrumbs (`delegate-with-context dispatch <ts>`) | `notes` | Per-run, not part of the spec |
| Code-review issues found (`blocker`/`important`/`nit`) | `comments` | Conversation-style |
| Discovered side-quest (out-of-scope finding) | `bd create` new issue + `bd dep add new-id current-id --type discovered-from` | Not a comment — a separate tracked issue |

## When project has no Beads

If `bd --version` fails OR `.beads/` directory does not exist in the project root:

1. Print to architect chat: "This project does not have Beads installed. Run `bd init` and re-invoke /delegate-with-context, OR confirm proceeding without Beads tracking (issues recorded only in final summary)."
2. Wait for architect response. **Default after 2 minutes of silence: proceed without Beads.**
3. If proceeding without Beads:
   - All "Beads-issue" mentions in the bundle are replaced with: "Beads not used in this project — task spec is the single source of truth."
   - Final summary's "Beads:" line becomes: "(no Beads in project; tracked here only)" plus the task description and verification evidence.
   - Subagents do not run `bd close`; their close-line in the bundle's "Definition of done" is replaced with: "commit with conventional message and include verification evidence in the message body".

## Drift caveat

This file inlines the 6-point template as it stood when the skill was authored. If the project ships a `workflow-gate` skill (or equivalent — `unified-workflow`, project-specific dispatcher), prefer the template defined there and re-sync this file periodically.

To re-sync: read the project's `workflow-gate/SKILL.md` and copy any updated section names or required fields into this file. Drift accepted; manual sync only.
