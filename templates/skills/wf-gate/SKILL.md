---
name: wf-gate
description: >
  Tracker-agnostic task-discipline reference: 6-point task description, 4-point
  close reason with verification evidence, commit conventions, land-the-plane
  habits. The discipline is independent of any specific tracker (GitHub issues,
  Linear, plain commit messages, project-local task files) — apply the templates
  wherever your project records tasks. Orchestration of the dev loop is the
  responsibility of slash-command `/wf-gate` (delegates to
  `template-bridge:unified-workflow`); this skill is the reference manual that
  the controller and reviewers consult.
  TRIGGER: Consult this skill whenever creating or closing a task in your
  project's tracker, or whenever uncertain about task-description quality
  standards.
---

# WF Gate

**Role:** Reference for task-discipline in any project.
**Orchestration:** handled by slash-command `/wf-gate` (delegates to
`template-bridge:unified-workflow`). This skill does NOT orchestrate; it
documents the quality standards that apply to any workflow.

**There is no marker file, no unlock mechanism, no Edit/Write hook block.**
Those were removed in the D1 redesign (see spec
`docs/superpowers/specs/2026-04-14-wf-gate-d1-design.md`).

---

## Phase 2: Issue Creation — Quality Standard

A task description is the project's memory of *why* this work exists. It must
carry enough context that **another session, with no access to the current
conversation,** can pick up the work without re-derivation.

### Where the description lives

The same 6-point template applies wherever your project tracks tasks. Common
homes:

- A dedicated issue tracker (GitHub Issues, Linear, Jira, GitLab, Bitbucket)
- A project-local `docs/orchestration/issues/` file (configurable via
  `orchestration-config.json` → `documentation.paths.issues`)
- A pull-request body when work is small enough that "the PR is the task"
- A commit message body for trivial one-shot changes

Pick the tracker that already exists in the project. **Do not invent a new
tracker just because the kit does not ship one.** The skill is deliberately
tracker-neutral.

### Description — 6 required points — WRITE IN ENGLISH

**Language rule:** task descriptions, notes, and close reasons should be
written in English for token efficiency. The agent communicates with the user
in their language; written tracker artefacts go in English.

1. **What's broken / what's needed** — concrete behaviour, not abstraction
2. **Where in code** — file, function, line range (`tree.js:2420, compact()`)
3. **How to reproduce** — inputs, URL, parameters (`pid=7 tmode=5`)
4. **What's already known** — root cause candidates, approaches rejected
5. **Context link** — why this task emerged, what surfaced the problem
6. **Resources** — everything the next session will need:
   - Code files with line numbers (`src/tree.js:1840-1870`)
   - Specs / docs (`docs/line-spec.md §4.5`)
   - Screenshots (`assets/screenshots/overlap-pid7.png`)
   - Test data, configs
   - External links (GitHub issues, articles, specs)

**Bad:** `"Fix bond-drop crossing"`

**Good:**
```
Bond-drop (grey bio line) crosses ⊔ former connector crossbar.
Root cause: _dropOff() in tree.js:1850 doesn't check ⊔ connectors.
Visible on pid=7 tmode=5, pair 35+34.
Found during GENP=140 testing — was hidden at GENP=100.

Resources:
- Code: src/plugins/drevo-zhizni-web/assets/js/tree.js:1840-1870
- Spec: docs/drevo-zhizni-web/line-spec.md §4.3
- Screenshot: assets/drevo-zhizni-web/images/overlap-pid7-tmode5.png
- Related: prior issue tracking the dynamic-gap parent task
```

### Side findings — link provenance

When you discover a bug while working on a different task:

- If you use a tracker with link types (GitHub issues, Linear) — open a new
  task and link it with whatever the tracker calls `discovered-from`.
- If you use plain commit/PR-body tasks — reference the originating PR or
  commit SHA in the new task's description, in a single line like
  `Discovered during: PR #123 (commit abc1234)`.

The point is a provenance chain so future-you understands *how* the bug
surfaced.

---

## Phase 3: During Work

### Notes — update IMMEDIATELY

Whenever you discover a new fact, write it down in the task's notes/comments
field (or append it to the task file in `docs/orchestration/issues/`). Do
NOT batch findings until the end of the session — context loss between
discovery and recording is a leading cause of forgotten work.

Example note:
```
FINDING: compact() at line 2420 ignores spouse gap. Tested on pid=5,7,213.
```

### Remember — persistent memory

When a pattern, convention, or gotcha emerges that future sessions in this
project must respect, persist it. Two practical homes:

- `CLAUDE.md` in the project root — for project-wide conventions.
- A dedicated `docs/orchestration/conventions.md` (or per-component
  `README.md`) — for narrower scope.

Examples:
```
test-pattern: all tree layout tests use pid=5 tmode=2 as baseline
convention: DREVO_VERSION bumped on every visual change
gotcha: _formerSlot and gOffset go in opposite directions — never mix
```

### Commits — include task ID

Always include the task identifier in the commit message subject line:

```
git commit -m "Fix spacing for 4+ children (issue-123)"
```

This lets reviewers (and the `delegate-with-context` doc-curator) trace each
commit back to its driving task.

---

## Phase 4: Closing — Quality Standard

The close reason is what future maintainers read when revisiting why a
defect was fixed in a particular way. It belongs in:

- The tracker's close comment, OR
- The PR body for the merging change, OR
- The commit message body for direct-to-trunk fixes.

### Reason — 4 required points

1. **Solution** — what was concretely done (1-2 sentences)
2. **Root cause** — why the defect existed
3. **Prevention** — what will stop it from recurring (test, rule, check)
4. **Verification** — concrete artefacts from `superpowers:verification-before-completion`:
   - Test command + snapshot of its output (fresh, run in this session)
   - Screenshot paths (mandatory for UI changes)
   - Before/after evidence for bug fixes
   - "Tested — works" WITHOUT artefacts is an invalid reason. Rewrite.

**Bad:** `"Fixed"` — no points

**Bad:** `"Fix + tested"` — no root cause, prevention, or concrete evidence

**Good:**
```
1. Added expandRowGaps() post-pass after allocateCombSlots().
2. Root cause: GENP was fixed and didn't account for the number of combs in the gap.
3. Prevention: expandRowGaps() now dynamically widens rows — for any new connector,
   confirm its height is accounted for in the deficit calculation.
4. Verification:
   - node tests/channel-integrity-full.js → COMB-COLLISION: 0 (was 30)
   - Playwright pid=5,7,213 tmode=5 at 1920x1080:
     assets/screenshots/2026-04-14-after-comb-*.png (visual OK)
   - Full sweep 261 pids: no regression in LINE-CARD-CROSSING/CARD-OVERLAP.
```

---

## Phase 5: Session End — "Land the Plane"

The session is NOT complete until ALL of these are done:

1. **Open tasks** — update notes/comments with current status:
   ```
   PROGRESS: steps 1-3 done. NEXT: step 4 (refactor drawBond). BLOCKED BY: nothing.
   ```

2. **Side findings** — file them as new tasks with provenance link

3. **Memory** — persist conventions to CLAUDE.md or `docs/orchestration/conventions.md`

4. **Git** — clean state:
   ```bash
   git pull --rebase && git push
   ```

---

## Rules

- ALWAYS write rich descriptions — they are the project's memory
- ALWAYS write task artefacts (descriptions, notes, close reasons, conventions) in English — token efficiency
- ALWAYS update notes immediately — don't batch
- ALWAYS include the task ID in commit messages
- ALWAYS "land the plane" before session end — notes, git push
- NEVER claim "done" without verification artefacts (Iron Law from `superpowers:verification-before-completion`)
