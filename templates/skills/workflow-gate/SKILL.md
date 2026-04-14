---
name: workflow-gate
description: >
  Beads-discipline reference for all development work: issue quality standards,
  notes/remember/commits policy, 4-point close reason with verification evidence.
  Dev-loop orchestration lives in slash-command /workflow-gate, which delegates
  to template-bridge:unified-workflow.
  TRIGGER: Consult this skill whenever creating/closing Beads issues or
  uncertain about project conventions.
---

# Workflow Gate

**Role:** Reference for Beads-discipline in this project.
**Orchestration:** handled by slash-command `/workflow-gate` (delegates to
`template-bridge:unified-workflow`). This skill does NOT orchestrate; it
documents the quality standards that apply to any workflow.

**There is no marker file, no unlock mechanism, no Edit/Write hook block.**
Those were removed in the D1 redesign (see spec
`docs/superpowers/specs/2026-04-14-workflow-gate-d1-design.md`).

---

## Phase 2: Issue Creation — Quality Standard

Beads is the project's operational memory. Every issue must carry enough
context that **another session, with no access to the current conversation,**
can continue the work.

### Required fields for `bd create`

Always pass `--type` and `--priority` (without them `bd` opens an interactive
prompt and the agent hangs):

```bash
bd create --title "Title" --type bug --priority 1 --description "..." --json
```

### Description — 6 required points — WRITE IN ENGLISH

**Language rule:** Beads issue descriptions, titles, notes, and close reasons
MUST be written in English. Rationale: English uses ~half the tokens of
Russian for the same information, which matters because Beads is read back
into every session (`bd prime`/`bd show`) and consumes context budget. The
agent communicates with the user in Russian (or whatever language the user
uses), but writes Beads artefacts in English.

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
- Related: web-scripts-grw (dynamic gap — parent task)
```

### Side findings — `discovered-from`

Found a bug while working on a different task? Immediately:

```bash
bd create --title "Found bug X" --type bug --priority 2 --description "..." --json
bd dep add <new-id> <current-id> --type discovered-from
```

This creates a provenance chain — how the bug was discovered.

---

## Phase 3: During Work

### 3.0 Session start — load Beads context

**Note:** SessionStart hook already runs `bd prime` automatically. Below is
for manual re-loading mid-session or after switching projects.

```bash
bd prime          # Workflow context: open issues, priorities, blockers
bd recall         # Persistent memory: conventions, patterns, past decisions
bd ready --json   # Structured list of claimable work
```

If resuming work from a previous session, check what's in progress via
`bd show <id>` before starting anything new.

---

### Notes — update IMMEDIATELY

When you discover a new fact, don't batch until the end:

```bash
bd update <id> --notes "FINDING: compact() at line 2420 ignores spouse gap. Tested on pid=5,7,213."
```

### Remember — persistent memory

Found a pattern or convention that will be useful in future sessions:

```bash
bd remember "test-pattern: All tree layout tests use pid=5 tmode=2 as baseline"
bd remember "convention: DREVO_VERSION bumped on every visual change"
bd remember "gotcha: _formerSlot and gOffset go in opposite directions — never mix"
```

`bd recall` restores these entries in the next session.

### Commits — include issue ID

Always include the task ID in the commit message:

```
git commit -m "Fix spacing for 4+ children (web-scripts-a3f2)"
```

This lets `bd doctor` find orphaned issues.

---

## Phase 4: Closing — Quality Standard

### `--claim-next` instead of plain close

```bash
bd close <id> --reason "..." --claim-next
```

Atomically closes the current issue AND claims the next one from the ready
queue. Prevents races in multi-agent setups.

### Reason — 4 required points

1. **Solution** — what was concretely done (1-2 sentences)
2. **Root cause** — why the defect existed
3. **Prevention** — what will stop it from recurring (test, rule, check)
4. **Verification** — concrete artefacts from `superpowers:verification-before-completion`:
   - Test command + snapshot of its output (fresh, run in this session)
   - Screenshot paths (mandatory for UI changes)
   - Before/after evidence for bug fixes
   - "Tested — works" WITHOUT artefacts is an invalid reason. Rewrite.

**Bad:** `--reason "Fixed"` — no points
**Bad:** `--reason "Fix + tested"` — no root cause, prevention, or concrete evidence
**Good:**
```
--reason "1. Added expandRowGaps() post-pass after allocateCombSlots().
2. Root cause: GENP was fixed and didn't account for the number of combs in the gap.
3. Prevention: expandRowGaps() now dynamically widens rows — for any new connector,
   confirm its height is accounted for in the deficit calculation.
4. Verification:
   - node tests/channel-integrity-full.js → COMB-COLLISION: 0 (was 30)
   - Playwright pid=5,7,213 tmode=5 at 1920x1080:
     assets/screenshots/2026-04-14-after-comb-*.png (visual OK)
   - Full sweep 261 pids: no regression in LINE-CARD-CROSSING/CARD-OVERLAP."
```

---

## Phase 5: Session End — "Land the Plane"

The session is NOT complete until ALL of these are done:

1. **Open tasks** — update notes with current status:
   ```bash
   bd update <id> --notes "PROGRESS: steps 1-3 done. NEXT: step 4 (refactor drawBond). BLOCKED BY: nothing."
   ```

2. **Side findings** — file them as issues with `discovered-from`

3. **Memory** — persist conventions and insights:
   ```bash
   bd remember "key-learning: description"
   ```

4. **Git** — clean state:
   ```bash
   git pull --rebase && git push
   ```

---

## Phase 6: Maintenance (periodic)

```bash
bd doctor --fix           # Diagnose + auto-fix (run daily)
bd compact --days 30      # Compress old closed issues (LLM summarisation)
bd upgrade                # Update bd CLI (every 1-2 weeks)
bd stats                  # Overall project health
```

Don't let active issues exceed 200. When approaching the limit, run
`bd compact` or `bd cleanup --days N`.

---

## Rules

- NEVER use `bd create` without `--type`, `--priority`, `--description`
- NEVER use `bd edit` — it opens an interactive editor and the agent hangs. Use `bd update --description`
- ALWAYS use `--json` for programmatic output
- ALWAYS write rich descriptions — they are the project's memory
- ALWAYS write Beads artefacts (descriptions, notes, reasons, remember) in English — token efficiency
- ALWAYS update notes immediately — don't batch
- ALWAYS include the issue ID in commit messages
- ALWAYS use `--claim-next` when closing if more work exists
- ALWAYS "land the plane" before session end — notes, git push
