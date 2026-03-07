---
name: deploy-orchestration
description: Interactive orchestration setup — Phase 2 after deploy.sh. Discovers task-specific skills via find-skills, generates CLAUDE.md orchestration section, configures multi-project structure. Use when setting up orchestration in a new project.
---

# Deploy Orchestration — Phase 2 (Interactive)

**Prerequisite:** `deploy.sh` has already copied agents, skills, config, and hooks to this project.

This skill handles the interactive parts that need Claude's intelligence:
1. Detecting project context
2. Discovering and installing task-specific skills
3. Generating CLAUDE.md orchestration section
4. Configuring multi-project structure (if applicable)

## Workflow

### Step 1: Detect Project Context

Read the project to understand what it does:

```
1. Read package.json / pyproject.toml / go.mod / Cargo.toml (whichever exists)
2. Read README.md if it exists
3. Scan top-level directory structure
4. Identify: project name, language, framework, purpose
```

Output to user:
```
Detected project: {name}
Language: {lang}
Framework: {framework or "none detected"}
Purpose: {brief description based on README/package.json}
```

### Step 2: Determine Project Type

Ask the user if not already clear:

```
Is this project:
  1. Atomic — single-purpose (one application/library/service)
  2. Multi-purpose — multiple sub-projects in one repo (e.g., scripts + plugins + tools)
```

If **multi-purpose**, ask:
```
What sub-projects does this contain? Provide names and brief descriptions.
Example: "forms-scripts: Form generation scripts, plugins: Browser extensions"
```

For each sub-project, create `src/{name}/` directory.

### Step 3: Discover Task-Specific Skills

Use `find-skills` to discover skills relevant to this project:

```bash
# Extract keywords from project context
# Example: if project uses React + TypeScript → search for react, typescript, nextjs

npx skills find [keyword1]
npx skills find [keyword2]
# ... up to 3-4 searches based on detected tech stack
```

Present discovered skills to user:
```
Found skills for your project:

1. vercel-labs/agent-skills@vercel-react-best-practices
   React/Next.js performance optimization from Vercel Engineering

2. giuseppe-trisciuoglio/developer-kit@shadcn-ui
   Complete shadcn/ui component library patterns

Install these skills? (select which ones)
```

For each selected skill:
```bash
npx skills add {package} -y
```

After installation, create symlinks so skills are visible in `.claude/skills/`:
```bash
# Skills install to .agents/skills/{name}/
# Create symlink for Claude Code visibility
ln -sf ../../.agents/skills/{name} .claude/skills/{name}
```

### Step 4: Generate CLAUDE.md Orchestration Section

Read the template from `.claude/skills/deploy-orchestration/` context (the template is below).

**For atomic projects**, generate:

```markdown
## Claude Automations

### Skills

**Workflow:**
- `/orchestrate` — Full development cycle (Plan > Code > Test > Review > Fix > Document). For complex multi-step features.
- `/implement` — Simple workflow (Code > Test > Document). For single components or endpoints.
- `/012-update-docs` — Post-task documentation verification.

**Quality:**
- `/code-review` — Manual code review for quality, bugs, security, best practices.
- `/arch-review` — Architecture review for design patterns, SOLID, dependencies.
- `/security-audit` — Security vulnerability audit (OWASP Top 10).
- `/refactor-code` — Guided code refactoring without behavior change.

{FOR EACH INSTALLED EXTERNAL SKILL:}
**External:**
- `/{skill-name}` — {skill description}

### Agents

**Pipeline** (used by `/orchestrate` and `/implement`):
- `planner` — Break task into subtasks with dependencies
- `worker` — Implement code for each subtask
- `test-runner` — Run lint + tests + verify
- `debugger` — Fix issues from test/review/security reports
- `reviewer` — Code quality review
- `security-auditor` — Security vulnerability scanning
- `documenter` — Create completion report
- `doc-keeper` — Analyze doc drafts, recommend and apply doc updates
- `observer` — Analyze orchestration run, identify improvements

**Quality** (used by standalone quality skills):
- `senior-reviewer` — Architecture review with health scores (used by `/arch-review`)
- `refactor` — Code refactoring specialist (used by `/refactor-code`)

### Hooks

- **SubagentStop**: Pipeline transition hints for all 9 agents
- **PreToolUse**: Safety guard blocking `rm -rf`, `git push --force`, `git reset --hard`
{IF LANGUAGE HOOKS WERE INSTALLED:}
- **PostToolUse:Edit**: {language}-specific type/lint check after edits
- **PostToolUse:Write|MultiEdit**: Auto-format for {language} files

### Config

- `orchestration-config.json` — Paths and toggles for AI-generated artifacts (plans, reports, issues, doc-drafts, observer-reports)
```

**For multi-purpose projects**, add after the Config section:

```markdown
---

## Sub-Projects

| Name | Path | Description |
|------|------|-------------|
{FOR EACH SUB-PROJECT:}
| {name} | src/{name}/ | {description} |

{FOR EACH SUB-PROJECT:}
### Sub-Project: {name}

**Path:** `src/{name}/`
**Description:** {description}
**Tech stack:** {detected or "TBD — update after initial setup"}
**Build/Run:** {detected commands or "TBD"}

**Conventions:**
- {placeholder for user to fill in project-specific rules}
```

### Step 5: Apply to CLAUDE.md

If CLAUDE.md exists:
1. Check if it already has a `## Claude Automations` section (grep for it)
2. If yes: ask user whether to replace or append
3. If no: append the generated section at the end

If CLAUDE.md does not exist:
1. Create a minimal CLAUDE.md with:
   ```markdown
   # {Project Name}

   {Brief description from Step 1}

   ## Commands

   ```bash
   {detected build/run/test commands}
   ```

   {Generated orchestration section}
   ```

### Step 6: Output Summary

```
Orchestration setup complete!

Project: {name}
Type: {atomic|multi}
Base skills: 7 (orchestrate, implement, code-review, arch-review, security-audit, refactor-code, 012-update-docs)
External skills: {count} ({list names})
Agents: 11

CLAUDE.md: {created|updated}
Config: orchestration-config.json

Ready to use:
  /orchestrate [complex task]  — Full pipeline with planning
  /implement [simple task]     — Quick implementation
  /code-review                 — Review recent changes
```

## Key Rules

1. **Always ask before modifying existing CLAUDE.md** — never silently overwrite
2. **Install skills locally** (no `-g` flag) — keep project self-contained
3. **Create symlinks** for installed skills — ensures `.claude/skills/` visibility
4. **For multi-purpose projects**, each sub-project gets its own section in CLAUDE.md
5. **Don't install base skills via npx** — they were already copied by deploy.sh
6. **Verify orchestration-config.json exists** before finishing — it's required by agents
