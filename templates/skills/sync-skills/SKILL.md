---
name: sync-skills
description: Scan .claude/skills/ for skills not listed in CLAUDE.md and offer to register them. Use when new skills were installed but not yet referenced in orchestration, or at session start when CLAUDE.md instructs skill discovery.
---

# Sync Skills

Detect skills present in `.claude/skills/` but missing from the `## Claude Automations` → `### Skills` section in CLAUDE.md. Offer to register them so orchestration is aware of all installed skills.

## Workflow

### Step 1: Collect Installed Skills

**IMPORTANT:** Many skills are installed as symlinks (e.g., external skills from `npx skills add` — `.claude/skills/<name>` links to `../../.agents/skills/<name>/`). The Glob tool does NOT follow symlinks. You MUST use Bash to discover skills:

```bash
find -L .claude/skills -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null
```

The `-L` flag follows symlinks. For each found `SKILL.md`, read it and extract:
- **name** from frontmatter field `name:`
- **description** from frontmatter field `description:` (first sentence only)

Skip directories that don't contain a SKILL.md file.

### Step 2: Collect Registered Skills

Read `CLAUDE.md`. Find the `## Claude Automations` section, then the `### Skills` subsection.

Extract all skill names mentioned there — look for patterns like:
- `- /skill-name` or `- \`/skill-name\``
- Lines containing skill directory names

Build a set of registered skill names.

### Step 3: Compare

Internal skills (exclude from all comparisons — never report as new or stale):
- orchestrate, implement, code-review, arch-review, security-audit, refactor-code, 012-update-docs, sync-skills, deploy-orchestration

Find skills that are **installed but not registered**:
```
new_skills = installed_skills - registered_skills - internal_skills
```

Also find skills that are **registered but not installed** (stale references):
```
stale_skills = registered_skills - installed_skills - internal_skills
```

### Step 4: Report

If no new or stale skills found:
```
All skills in sync. {N} skills installed, all registered in CLAUDE.md.
```

If new skills found, present them:
```
Found {N} skill(s) installed but not in CLAUDE.md:

  1. /skill-name — description from SKILL.md
  2. /other-skill — description from SKILL.md

Add them to CLAUDE.md?
```

If stale skills found, also report:
```
Found {M} skill(s) in CLAUDE.md but not installed:

  - /removed-skill
  - /old-skill

Remove stale references from CLAUDE.md?
```

Use AskUserQuestion for each decision.

### Step 5: Update CLAUDE.md

For each approved new skill, add a line to the `**External:**` block under `### Skills`:
```markdown
- `/{skill-name}` — {description}
```

If no `**External:**` block exists, create it after the `**Quality:**` block:
```markdown
**External:**
- `/{skill-name}` — {description}
```

For approved stale removals, delete the corresponding lines.

### Step 6: Summary

```
CLAUDE.md updated:
  + Added: /skill-1, /skill-2
  - Removed: /old-skill

Skills in sync: {total} installed, {total} registered.
```

## Rules

1. **Never auto-update** — always ask user before modifying CLAUDE.md
2. **Preserve formatting** — match existing indentation and style in CLAUDE.md
3. **Read SKILL.md for descriptions** — don't guess, use the actual frontmatter
4. **Skip non-skill directories** — directories without SKILL.md are not skills
5. **Idempotent** — running twice produces no changes if already in sync
