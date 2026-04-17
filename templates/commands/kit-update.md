---
description: Unified post-install refresh. Two modes — kit content (--update-skills) or user-installed skills.sh skills (--update-external-skills). Auto-commits + pushes on real drift.
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
- `deploy.sh` detects no `templates/` alongside, clones kit from GitHub (`ORCHESTRATION_KIT_REPO`/`_REF` env vars or defaults to `air900/orchestration-kit@main`) into a tmp dir.
- Refreshes `.claude/agents/`, `.claude/skills/` (dirs — with `rm -rf` + `cp -r` to handle ref-count changes), `.claude/commands/`, `.claude/hooks/`, `.claude/references/`, merges `.claude/settings.json` hooks.
- Custom (non-kit-named) files left untouched.
- Auto-commits (explicit path staging, never `git add -A`) + pushes.
- Cleans up tmp clone.

If `.claude/scripts/deploy.sh` is missing:

```
ERROR: .claude/scripts/deploy.sh not found.
First install the deploy tool:
  curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- --update-deploy
```

### 2. `--update-external-skills` → user skills.sh refresh

Run from the project root:

```bash
python3 .claude/skills/update-external-skills/scripts/update.py
```

What happens:
- Reads `skills-lock.json` at project root.
- Fetches GitHub metadata per unique repo (stars, pushed_at). Deduplicated.
- Shows indexed selection table with status (current / stale / no-meta).
- Prompts: `0` = all, `1,3,5` = specific, `1-5` = range, empty = cancel.
- Runs `npx skills update <selected> -p -y`, diffs computedHash pre/post.
- Auto-commits (`skills-lock.json`, `.agents/skills`, `.claude/skills`) + pushes.

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

  --update-external-skills   Refresh user-installed skills.sh skills
                             (tracked in skills-lock.json). Interactive
                             selection + GitHub stats.

Both modes auto-commit + auto-push on real drift using explicit path
staging (never `git add -A`).
```

### 4. Unknown flag

Error and print usage (same as empty args).

## Non-negotiables

- Do NOT run both modes in one invocation — user must explicitly choose.
- Do NOT stage paths outside what each backend owns — preserve user's unrelated uncommitted work.
- On missing backend file, print the exact remediation command — do NOT silently fall back to something else.
- If `$ARGUMENTS` is parseable as both flags (e.g., contains `--update-skills --update-external-skills`), print usage and exit — ambiguous invocation.
- **Show the backend script's output VERBATIM.** Do NOT reformat the selection table, do NOT drop columns, do NOT omit the `Stars` or `Status` columns. These are the "stats" the user asked for — they are the entire point of this command. If the table is wide, let it wrap rather than compact it into a narrower layout.
- **Do NOT convert fixed-width text tables into markdown tables.** The script prints aligned columns using spaces; that layout is deliberate. Claude Code renders the raw text just fine in its output pane.
- **NEVER pipe input into the script.** The Action prompt at the end of the script is an *interactive user choice*, not a task for the assistant to solve. Do NOT:
  - `echo "clean" | python3 update.py`
  - `echo "0" | python3 update.py`
  - `printf "del 1,3\n" | python3 update.py`
  - or any equivalent that pre-feeds a selection into stdin.
  Run the script so its output reaches the user, then **stop and ask the user in chat** which action they want. The user must type the selection themselves. Even "safe" actions like `clean` require explicit user go-ahead; a silently-applied `clean` that rewrites `skills-lock.json` and auto-commits is a trust violation regardless of how recoverable it is.
- **"Auto mode" is not a licence to mutate.** If the current session is running in auto/agent mode and the script's prompt blocks waiting for input, surface the output to the user and wait. Do not guess. Do not pick the least-destructive option "as a compromise". The user picks.
