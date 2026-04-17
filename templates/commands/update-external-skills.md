---
description: Refresh external skills installed from skills.sh — interactive selection + GitHub stats + auto commit/push on real drift
---

Invoke skill `update-external-skills`. Then run the bundled script from the project root:

```bash
python3 .claude/skills/update-external-skills/scripts/update.py
```

The script:

1. Locates `skills-lock.json` (walks up from CWD).
2. Fetches GitHub metadata per unique repo (stars, `pushed_at`).
3. Presents an indexed table of all tracked skills with "current" / "stale" / "no-meta" status.
4. Prompts for selection:
   - `0` = all
   - `1,3,5` = specific indexes
   - `1-5` = range
   - empty = cancel
5. Runs `npx skills update <selected> -p -y` on the chosen set.
6. Diffs old vs new `computedHash` per skill, reports what actually updated.
7. Auto-commits + pushes (explicit paths: `skills-lock.json`, `.agents/skills/`, `.claude/skills/`) only if real drift occurred.

## Non-negotiables

- Do NOT install new skills from this command — use `/find-skills` instead.
- Do NOT update kit-shipped skills from this command — use the kit's update mode (`deploy.sh --update-skills`).
- Do NOT run `git add -A` — the script stages only paths the update can change, preserving user's unrelated uncommitted work.
- If the user says "cancel" or provides empty input at the prompt, exit cleanly without running `npx skills update`.

## Troubleshooting

- `No skills-lock.json found` → project has no external skills installed. Use `/find-skills` to install one first.
- `rate-limited` in the metadata column → GitHub API anon limit hit. Tell user to `export GITHUB_TOKEN=...` and re-run; update itself still works.
- `npx skills update` non-zero exit → re-run it directly to see full error; the script preserves state and doesn't half-apply.
