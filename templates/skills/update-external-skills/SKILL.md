---
name: update-external-skills
description: >
  Inspect and refresh external skills installed from skills.sh (via `npx skills add`)
  in THIS project. READ-ONLY: prints a status report + ready-to-paste install
  commands, does NOT run npx itself, does NOT modify the lock or commit. Safe for
  auto-mode — there is no execution surface to bypass. TRIGGER via slash
  /update-external-skills, by skill name, or phrases: "обнови внешние скиллы",
  "update external skills", "которые скиллы устарели", "refresh skills.sh",
  "обнови скиллы с skills.sh", "skills drift check", "sync external skills".
  Do NOT use for: kit-shipped skills (use `deploy.sh --update-skills`), creating
  new skills (use skill-creator), finding new skills to install (use find-skills).
---

# Update External Skills

Report + safe-command generator for `npx skills add`-installed skills in this project.

## How the model works

This is a **two-phase, user-approved** workflow:

1. **Phase 1 — Report** (this script, read-only):
   - Runs `python3 .claude/skills/update-external-skills/scripts/update.py`.
   - Prints stats, table, **install commands** grouped per source repo.
   - Exits. Touches nothing on disk.

2. **Phase 2 — Apply** (Claude + user, via the printed commands):
   - User reviews the report, decides which skills to refresh.
   - Claude runs the matching `npx skills add <source> -s <name> -p -y` commands.
   - Claude diffs the working tree against `HEAD` using git.
   - Claude produces a **semantic summary** (not raw diff dump) and asks the user
     whether to commit.
   - On approval: `git add <scoped paths> && git commit && git push`.

This split exists because earlier iterations tried to combine report + execution +
auto-commit inside the script. Auto-mode agents bypassed the interactive prompt
and called `npx skills update` directly, which for project-level locks
**re-installs the whole source repo** (50+ skills from a multi-skill monorepo,
unwanted). By making the script read-only, there is nothing to bypass.

## Why `npx skills add -s <name>`, never `npx skills update <name>`

Confirmed in `vercel-labs/skills` source (`src/update-source.ts` →
`buildLocalUpdateSource`): when a lock entry lacks a `skillPath` (the project-level
lock format v1 that `npx skills` currently writes), `skills update` delegates to
`skills add <source>` WITHOUT a skill-path restriction. Result: the whole source
repo is re-installed. For multi-skill repos like `coreyhaines31/marketingskills`
this can mean +40 skills unwantedly.

The `-s <name>` flag on `skills add` pins installation to the listed skills only.
This is the safe form. `update.py` prints commands in exactly this shape.

## How to invoke

From project root (or any subdirectory — the script walks up to find
`skills-lock.json`):

```bash
python3 .claude/skills/update-external-skills/scripts/update.py
```

Or via slash command: `/update-external-skills` — dispatched through
`/kit-update --update-external-skills`.

## What the script prints (show ALL blocks VERBATIM to the user)

In order:

1. **Rate-limit banner** — if ≥50% of GitHub API calls hit 403, a prominent warning.
2. **Stats summary** — counts, unique repos, most-popular, most-recent push.
3. **Status legend** — meaning of `current` / `stale` / `no-meta` / `missing`.
4. **Skills table** — fixed-width, sorted by ⭐ desc. Columns: `#`, `Skill`, `Repo`,
   `Stars`, `Remote pushed`, `Status`.
5. **Install commands** — grouped per source repo, `npx skills add <source> -s ... -p -y`.
6. **Maintenance commands** — `npx skills remove`, ghost cleanup (only if ghosts exist).
7. **Usage footer** — next-step instructions (git-status check, apply, git-diff, commit).

**Do NOT:**

- Reformat the fixed-width table into a markdown table.
- Drop the `Stars` or `Status` columns.
- Collapse the stats summary or legend into terse prose.
- Hide "current" rows to save space — the user wants the full picture.

Those columns and blocks ARE the statistics the user is asking for. If the table
appears wide, let it wrap naturally — do not squeeze it narrower by dropping
columns.

## Status semantics

| Status    | Meaning |
| :-------- | :------ |
| `current` | Upstream's `pushed_at` is ≤ local SKILL.md mtime. Likely in-sync. |
| `stale`   | Upstream's `pushed_at` is > local mtime. Update likely available. |
| `no-meta` | GitHub API call failed (rate limit / 404 / network). Status unknown. |
| `missing` | Entry in lock, no local files (`.agents/skills/<name>/SKILL.md` absent). Ghost. |

**Two caveats — do not treat status as ground truth:**

- **Multi-skill repos**: `pushed_at` bumps on any sibling skill's change, so all
  siblings move to `stale` together even if your specific skill was untouched.
- **Lagged install**: if you installed from a push that already contained
  upstream work, the status will say `current` but you actually missed that delta.

The authoritative drift test is to actually re-run the `add -s <name>` command
and diff. If the content is identical, nothing changes (git sees no diff). If
there's real drift, git shows it.

## Phase 2 — Apply (for Claude)

This section tells Claude how to act on the report. **Every step requires user
context; do not proceed silently in auto mode.**

### Step 1 — Ask the user what to refresh

Based on the report, present the candidates (typically the `stale` rows) and ask
which to refresh. Accept: "все stale", "все", specific names, or specific row
indexes from the table.

### Step 2 — Verify the working tree is clean on scoped paths

Before running any `add` command, check that these paths have no uncommitted
changes:

```bash
git status --short skills-lock.json .agents/skills .claude/skills
```

If anything is listed, STOP and tell the user. The semantic-diff step relies on
`git diff HEAD` being a clean before→after — pre-existing uncommitted work on
these paths breaks that.

### Step 3 — Run the install command(s)

Copy the relevant `npx skills add ...` line(s) from the report and run them.
Edit the `-s` list if you want only a subset of that repo's skills. Example:

```bash
# Report had:
#   npx skills add coreyhaines31/marketingskills -s ai-seo -s copywriting -s ... -p -y
# User wanted only copywriting → run:
npx skills add coreyhaines31/marketingskills -s copywriting -p -y
```

**Never** run `npx skills update <name>` on a project-level install — always use
`add -s <name>`. If you're unsure whether the lock is project-level, assume yes:
it's the only form `npx skills` currently writes.

### Step 4 — Diff using git

The authoritative record of what changed is `git diff`. Grab it:

```bash
git diff --stat skills-lock.json .agents/skills .claude/skills
git diff -- .agents/skills/<name>/SKILL.md
git diff -- .agents/skills/<name>/references/
```

Structural changes (files added or deleted) show up in `--stat`; content changes
show up in the per-file diff.

### Step 5 — Produce a semantic summary (NOT a raw diff dump)

This is the valuable deliverable. Read the diff, then describe WHAT changed in
concept, not what the individual `+`/`-` lines are. Target format:

```
Update Check — copywriting
Yes, есть обновления. Upstream (coreyhaines31/marketingskills@main, 21.8k⭐)
на версии 1.1.0, у тебя 1.0.0.

Что изменилось (3 хунка, 31 строка diff, только в SKILL.md; references/ идентичны)
  1. Description расширен — добавлен trigger "email copy" и negative trigger
     "не для long-form SEO".
  2. Путь к контексту обновлён: `references/voice.md` → `references/tone.md`.
  3. Правило #6 в Quick Quality Check переформулировано: было "cut fluff",
     стало "cut fluff and vague qualifiers".
```

Rules for the summary:

- Group changes by semantic category (description / structure / rules / references).
- Number changes when there are >2 — helps scanning.
- If frontmatter `version:` moved, state it explicitly (`1.0.0 → 1.1.0`).
- If a file is added or deleted, call it out — structural changes are more
  significant than content edits.
- If hash changed but no visible textual diff (binary / whitespace-only), say so —
  do not invent changes.
- If there is no diff at all, report that plainly and ask the user whether to
  still update the lock-only hash (rarely relevant) or bail.

### Step 6 — Ask about commit

Ask the user whether to commit the scoped paths. Only on explicit approval:

```bash
git add skills-lock.json .agents/skills .claude/skills
git commit -m "chore(skills): refresh <names> via npx skills add -s ..."
git push
```

Never use `git add -A` — the scope is critical. Never amend an existing commit.
Never skip hooks.

### Safety — what Claude must NOT do

- **Do NOT** call `npx skills update` — ever.
- **Do NOT** invent `-s` flags beyond what's in the report unless the user said so.
- **Do NOT** commit before showing the semantic summary and getting approval.
- **Do NOT** use `git add -A` / `git add .` — always explicit paths.
- **Do NOT** auto-continue into more skills after one is done — re-ask.
- **Do NOT** run any `rm`, `git clean`, `git checkout -- ...` to "fix" unexpected
  state. Stop and tell the user.

## Rate limits

GitHub API anon: 60 requests/hour. The script dedups by unique repo, so 40 skills
from 10 repos = 10 calls. Export `GITHUB_TOKEN` for 5000/hr:

```bash
export GITHUB_TOKEN="ghp_..."
```

No token → the script falls back gracefully; metadata columns show `-` and rows
are tagged `no-meta`. The report is still usable.

## Who writes `skills-lock.json`?

The `npx skills` CLI (from `vercel-labs/skills`) is the only writer. Our
`find-skills` slash command only *recommends* the install command; the CLI does
the install + lock write. A `missing` entry means the CLI wrote the lock but the
files did not land (partial install, path issue, or manual deletion later).

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `No skills-lock.json found` | Project has never run `npx skills add` | Install a skill first: `npx skills add <owner/repo> -s <name> -p -y` |
| All rows show `no-meta` | GitHub rate limit hit | Export `GITHUB_TOKEN` or wait 1h |
| `add -s` exits non-zero | Network / registry / version issue | Re-run the single command to see full error |
| Unexpected extra skills appear on disk | Someone ran `skills update` instead of `add -s` | Revert: `git checkout HEAD -- <paths>` + `git clean -fd .agents/skills .claude/skills` |

## What this skill does NOT do

- Install *new* skills — use `/find-skills` then the install command it gives.
- Update kit-shipped skills — use `/kit-update --update-skills`.
- Touch anything outside `skills-lock.json`, `.agents/skills/`, `.claude/skills/`.
- Run `npx` on its own. Every CLI invocation is printed for the user/Claude to run.
- Auto-commit. Every commit is user-approved.

## Design notes

- **Read-only core**: the script prints. Execution is explicit bash the user can
  see and audit. There is no hidden action path to bypass.
- **Git is the snapshot mechanism**: clean working tree → `git diff HEAD` after
  apply gives the authoritative before→after. Simpler and more truthful than an
  in-memory Python snapshot.
- **One command per source repo**: grouping by source means exactly N × skills
  from that repo get installed — the CLI cannot silently widen the install.
- **Autonomy**: the script lives inside the skill directory, so after
  `deploy.sh --update-skills` each project has a fresh copy. No orchestration-kit
  checkout required to run the report.
