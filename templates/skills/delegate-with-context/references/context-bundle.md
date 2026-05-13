# Context Bundle

Single Markdown artifact assembled by the controller in Phase 4 and passed verbatim to every implementer subagent in this run, plus reviewer subagents (with task-specific addendum). The goal: every subagent has enough context to do its work right the first time.

## Structure

The bundle is a single Markdown document with these nine sections in order:

```markdown
# Mission
[1 paragraph: what and why; the "definition of done" criterion in plain language]

## Project context
- **Global conventions:** <inline excerpt from ~/.claude/CLAUDE.md, only sections
  relevant to this task — e.g., "Documentation Style: Mandatory TOC" if the task
  touches docs. NOT all of it.>
- **Project conventions:** <inline the entire local <project>/CLAUDE.md — it is
  short and every section can become relevant>
- **Project map:** <5-10 key paths only, NOT a full `tree`. Pick by relevance
  to the task zone.>

## Architecture refs (targeted)
- **Source: Phase 0 output** — paths come from `docs/MANIFEST.md` if present (always include General group + task-type group matching Phase 3 mode), else from a `docs/` scan fallback
- Inline whole if ≤200 lines; otherwise inline only the relevant sections
- `archived` manifest entries are NEVER inlined here
- Aim: subagent doesn't have to discover file structure; you point it at refs

## Task spec / linked task record
- Task ID (if tracked externally), Title, Description, Design, Notes, Comments — inline in full
- Dependencies: parent epic, blockers, related (from task spec or linked task record)

## Recent activity (last 5 commits, adaptive)
[git log -5 --stat output, plus `git diff HEAD~5..HEAD -- <files in zone>`]
[On NEEDS_CONTEXT.reason=history-too-short → expand to 20 commits, see "Adaptive deepening" below]

## Files in scope
- `path/to/file1` — ROLE: implementation, full content inline
- `path/to/file2` — ROLE: reference (read-only), full content inline
- `path/to/file3` — ROLE: nearby pattern (style example), full content inline
[Only files the subagent will actually read or edit. Not "in case it needs them".]

## Decision distilled (from architect chat)
[Whatever Phase 1 (DISTILL) extracted. Format adapts to what context contained:

 - If a discussion with alternatives happened: "Chosen X. Rejected Y and Z,
   reason: <user picked X from set {A,B,X,C}> or explicit reason."
 - If no alternatives were discussed (handoff blob, primary kickoff, short
   pick without prior list): just the task description. **Do NOT fabricate
   rejected alternatives that weren't actually discussed** — silence is
   acceptable here.
 - In all cases: special invariants or "must not" rules surfaced anywhere
   in context]

## Constraints
- **Branch:** <current branch>; work here, no worktree
- **TDD:** follow superpowers:test-driven-development (red → green → refactor)
- **Verification (Iron Law):** follow superpowers:verification-before-completion;
  return verification block per references/status-contract.md — REQUIRED
- **Project conventions:** follow <project>/CLAUDE.md (inlined above)
- **User conventions:** follow ~/.claude/CLAUDE.md (relevant sections inlined above)
- **Project-specific overrides:** follow overlay.md if present in skill directory

## Definition of done
- [ ] Failing test exists for the change, and is now green (give command + file)
- [ ] Close the task: commit message body OR PR description OR tracker close-comment carrying the 4-point reason (scope / how tested / leftover / verification command output)
- [ ] Status report includes complete `verification` block
      (without it, your DONE will be rejected as BLOCKED)
```

## What NOT to include

- **Verbatim rejected branches** from the chat — only the summary line in "Decision distilled". Including full discussion floods the subagent with content that contradicts the chosen path.
- **Tool output noise** from controller's own session: full tracker-state dumps, `git status` output, search results. The bundle is a curated artifact, not a session transcript.
- **Files outside the task zone** — even if "they're related" or "for context". If the subagent needs them, it returns NEEDS_CONTEXT and you add them deliberately.
- **Duplicates** between CLAUDE.md and README.md — keep in CLAUDE.md (closer to engineering rules), leave a marker `(see local CLAUDE.md)` where the README has the rule.

## Size budget

| Tier | Target | Action |
|------|--------|--------|
| Soft target | ≤25K tokens | preferred |
| Warning | 25–50K tokens | controller prints to chat: "bundle is large; trimming X, Y, Z" |
| Hard cap | 50–60K tokens | trim by priority (below); set flag `bundle_truncated=true` for subagent |

**Truncation priority (from highest = "never trim" to lowest = "trim first"):**
1. Mission, Decision distilled, Constraints, Definition of done — never trim
2. Task spec / linked task record — never trim
3. Files in scope — never trim (if forced, the task zone is sliced wrong; reconsider Phase 3)
4. Project conventions (local CLAUDE.md) — never trim
5. Recent commits — trim diff first, then stat
6. Architecture refs — trim long files (>200 lines) down to relevant sections
7. Global conventions excerpt — trim retained sections to the core

If the bundle still does not fit at hard cap with category 5–7 fully trimmed, the task is too large for one dispatch. CLASSIFY phase should re-categorize as `parallel-decomposable` (split into sub-tasks).

## Adaptive deepening (greedy strategy)

Every `Agent()` call is a fresh subagent — there is no "redispatch the same agent". Therefore deepening is greedy: when the subagent returns `NEEDS_CONTEXT`, expand the bundle by a **wide** margin in one go, not in small increments. A second deepening round will cost the same as the first, so prefer one generous expansion to several small ones.

| Subagent's `needs.reason` | Controller action |
|---------------------------|-------------------|
| `history-too-short` | `git log -20 --stat HEAD~5..HEAD~25` plus `git diff` for files in zone; bundle's "Recent activity" section grows from 5 to ~20–25 commits |
| `missing-file: <path>` | inline `<path>` AND 2–3 logically adjacent files (same module / same import group / nearby in the file system) |
| `unclear-spec` | controller does NOT silently expand — returns to Phase 1 (DISTILL) and asks the architect for clarification, then re-dispatches with sharpened spec |
| `missing-doc: <path>` | inline `<path>` plus any other `*.md` it links to in `docs/` |

**Bound:** ≤2 deepening rounds per task. After two rounds without DONE, controller escalates to architect: "subagent still says NEEDS_CONTEXT after two deepenings — recommend re-checking spec."

## Deduplication rules

- File appears in both `git diff HEAD~5..HEAD` AND `Files in scope`?
  → keep full inline content in `Files in scope`; in `Recent activity`, leave only the file's stat line, drop the diff (the current file IS the post-diff state).
- Rule appears in both `~/.claude/CLAUDE.md` and `<project>/CLAUDE.md`?
  → keep in `<project>/CLAUDE.md` (closer to project context); in the global excerpt, leave a marker `(see local CLAUDE.md, section "<name>")`.
- Same file referenced from multiple "ROLE" lines in `Files in scope`?
  → inline once, list multiple roles together: `ROLE: implementation + nearby pattern`.
