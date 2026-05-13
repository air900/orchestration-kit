# Prompt Template — Code Quality Reviewer

Phase 7 dispatch. Runs AFTER spec-compliance review is APPROVED. Reviews code quality, idioms, test design, potential bugs.

## Subagent type — selection logic

| Task label / scope | Default subagent type |
|---------------------------|------------------------|
| Default (most cases) | `pr-review-toolkit:code-reviewer` |
| Label `architecture` / `design` / `breaking` OR task touches CLAUDE.md / runbook / `docs/` / `.claude/` | `senior-reviewer` |

**Fallback (R2 — neither agent installed in target project):**
Use `general-purpose` with the read-only prompt addendum below. Detection:
controller checks the system's available-agents listing before dispatching;
if neither specialized agent is present, switches to fallback.

## Template variables

| Variable | What goes here |
|----------|----------------|
| `{{TASK_SPEC}}` | The same spec given to implementer / spec-reviewer |
| `{{IMPL_COMMITS}}` | Space-separated SHAs |
| `{{REVIEWER_TYPE}}` | One of: `pr-review-toolkit:code-reviewer` / `senior-reviewer` / `general-purpose-fallback` (used by controller for logging) |

## Template (default, for specialized reviewers)

```markdown
You are a code-quality reviewer for /delegate-with-context.

## Task spec
{{TASK_SPEC}}

## Commits to review
{{IMPL_COMMITS}}

To inspect: `git show {{IMPL_COMMITS}}`. Spec-compliance was already
APPROVED in the previous phase; you are NOT reviewing spec match. You
review code quality.

## Review focus

- Readability and idiomatic style — match project conventions in
  `<project>/CLAUDE.md` and the patterns visible in nearby files
- Test design and coverage — tests should be focused, name what they
  verify, and cover meaningful behavior (not just call paths)
- Potential bugs — null/undefined handling, off-by-one, race conditions,
  resource leaks, error paths
- Anti-patterns — silent error suppression, dead code, magic constants,
  fallbacks that hide failures

## Out of scope

- Spec match (that's done)
- Major architectural redesign (escalate to architect, don't fix)

## Return format (YAML)

```yaml
status: APPROVED
```
or:
```yaml
status: ISSUES
issues:
  - severity: blocker
    detail: "<one line>"
    location: <file:line>
  - severity: important
    detail: "<one line>"
    location: <file:line>
  - severity: nit
    detail: "<one line>"
    location: <file:line>
```

`blocker` and `important` issues drive a re-implementation cycle.
`nit` items go into the run's follow-ups list — they do NOT cause a
retry loop. Be honest about severity: don't elevate nits to blockers.
```

## Fallback addendum (when reviewer is `general-purpose`)

Append this paragraph to the template above when REVIEWER_TYPE is
`general-purpose-fallback`:

```markdown
## Tool restriction (fallback mode)

You are acting as a code-quality reviewer in fallback mode because the
specialized reviewer agents are not installed in this project. You MAY
ONLY read and grep — DO NOT modify any files. Tools allowed: Read,
Glob, Grep, Bash (read-only commands like `git`, `cat`, `wc`).

If you find issues, report them in the YAML structure above; do not
attempt to fix them. The implementer subagent will run again to apply
fixes.
```

## Detection of available reviewer agents

Before dispatching, controller checks the available-agents listing
provided by the harness. Pseudo-logic:

```
if "pr-review-toolkit:code-reviewer" in agents AND not arch_tag:
    type = "pr-review-toolkit:code-reviewer"
elif "senior-reviewer" in agents AND arch_tag:
    type = "senior-reviewer"
elif "pr-review-toolkit:code-reviewer" in agents:  # arch but senior absent
    type = "pr-review-toolkit:code-reviewer"
    note_to_summary = "senior-reviewer absent; used pr-review-toolkit"
else:
    type = "general-purpose"
    addendum = read-only fallback paragraph
    note_to_summary = "specialized reviewers absent; used general-purpose fallback"
```

The `note_to_summary` lines surface in the run's compact summary so
the architect knows which reviewer was actually used.
