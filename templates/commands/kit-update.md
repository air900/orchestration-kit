---
description: Unified post-install refresh. Two modes — kit content (--update-skills) or user-installed skills.sh skills (--update-external-skills). The external mode is read-only; Claude drives apply + commit.
---

User args: $ARGUMENTS

## Dispatch

Parse `$ARGUMENTS` and route to the right backend:

### 1. `--update-skills` → kit content refresh

Run from the project root:

```bash
.claude/scripts/deploy.sh . --update-skills
```

What happens:
- `deploy.sh` detects no `templates/` alongside, clones kit from GitHub
  (`ORCHESTRATION_KIT_REPO`/`_REF` env vars or defaults to `air900/orchestration-kit@main`)
  into a tmp dir.
- Refreshes `.claude/agents/`, `.claude/skills/` (dirs — with `rm -rf` + `cp -r` to
  handle ref-count changes), `.claude/commands/`, `.claude/hooks/`, `.claude/references/`,
  merges `.claude/settings.json` hooks.
- Custom (non-kit-named) files left untouched.
- Auto-commits (explicit path staging, never `git add -A`) + pushes.
- Cleans up tmp clone.

If `.claude/scripts/deploy.sh` is missing:

```
ERROR: .claude/scripts/deploy.sh not found.
First install the deploy tool:
  curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- --update-deploy
```

### 2. `--update-external-skills` → user skills.sh report (read-only)

Run from the project root:

```bash
python3 .claude/skills/update-external-skills/scripts/update.py
```

What the script does (all read-only):
- Reads `skills-lock.json` at project root.
- Fetches GitHub metadata per unique repo (stars, pushed_at). Deduplicated.
- Prints: stats summary, status legend, skills table (sorted by ⭐ desc),
  **install commands grouped per source**, maintenance commands, usage footer.
- Exits. Touches nothing on disk. Does not run `npx`. Does not modify the lock.
  Does not commit.

**After the script exits, Claude drives Phase 2 — apply, diff, summarize, commit.**
The detailed procedure lives in the skill's SKILL.md (sections "Phase 2 — Apply"
and "Safety — what Claude must NOT do"). Follow it exactly.

If `.claude/skills/update-external-skills/scripts/update.py` is missing:

```
ERROR: update-external-skills script not found.
Run /kit-update --update-skills first — the script ships with the kit.
```

### 3. Empty args, `--help`, or `-h`

Print usage:

```
Usage: /kit-update --update-skills | --update-external-skills

  --update-skills            Refresh kit-shipped content (agents, skills,
                             commands, hooks, references) via deploy.sh.
                             Self-bootstraps templates from GitHub.

  --update-external-skills   Print a status report for user-installed skills.sh
                             skills (tracked in skills-lock.json). Read-only —
                             Claude + user handle apply and commit from the
                             printed commands, following SKILL.md's Phase 2.
```

### 4. Unknown flag

Error and print usage (same as empty args).

## Non-negotiables

### Shared (both modes)

- Do NOT run both modes in one invocation — user must explicitly choose.
- Do NOT stage paths outside what each backend owns — preserve user's unrelated
  uncommitted work.
- On missing backend file, print the exact remediation command — do NOT silently
  fall back to something else.
- If `$ARGUMENTS` is parseable as both flags, print usage and exit — ambiguous.

### Read-only report mode (`--update-external-skills`)

- **Show the script's output VERBATIM.** Do NOT reformat the fixed-width table
  into markdown, do NOT drop the `Stars` or `Status` columns, do NOT omit the
  install-commands block. These blocks ARE the stats the user asked for. If the
  table is wide, let it wrap rather than compact it.
- **Do NOT convert fixed-width text tables into markdown tables.** The aligned
  spacing is deliberate and renders fine.

### Apply (Phase 2) — Claude's responsibility

The script prints `npx skills add <source> -s <name> ... -p -y` lines. Claude
uses those — and only those — to perform refreshes. Hard rules:

- **NEVER run `npx skills update <name>`.** For project-level locks it re-installs
  the ENTIRE source repo, silently adding unwanted sibling skills. This is a
  confirmed bug/design limitation in `vercel-labs/skills` (see SKILL.md for
  source-code reference). The only safe form is `npx skills add <source> -s <name>`.
- **NEVER widen the `-s` list** beyond the skills the user explicitly chose.
  Copy the exact line from the report and strip `-s` flags for unwanted skills;
  never add flags the report didn't list.
- **ALWAYS verify a clean working tree** on `.agents/skills`, `.claude/skills`,
  and `skills-lock.json` BEFORE running `add -s` — the semantic-diff step relies
  on `git diff HEAD` being a clean before→after.
- **ALWAYS use `git diff` for the change report**, not a hand-rolled snapshot.
  Clean-tree precondition + post-install `git diff HEAD` = authoritative delta.
- **ALWAYS produce a semantic summary** (not a raw diff dump) — describe WHAT
  changed in concept: "description extended", "rule #6 reworded", "new
  reference file". The example format is in SKILL.md.
- **NEVER commit without user approval.** After showing the semantic summary,
  ask. On yes: `git add skills-lock.json .agents/skills .claude/skills` (explicit
  paths) + commit + push. Never `git add -A`, never amend, never `--no-verify`.
- **On anomaly, STOP and tell the user.** Examples: more files changed than
  expected, unknown skills appeared, upstream hash did not change. Do NOT run
  `git clean`, `rm -rf`, or `git checkout --` to "fix" it silently — that can
  destroy in-progress work.

### "Auto mode" is not a licence to mutate

If the current session is running in auto/agent mode, the apply step still
requires user acknowledgement of the selection and the commit. Do not pick a
"safe default" and proceed. The user picks.
