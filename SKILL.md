---
name: deploy-orchestration
description: Interactive orchestration setup — Phase 2 after deploy.sh. Discovers task-specific skills via find-skills, generates CLAUDE.md orchestration section, configures multi-project structure. Use when setting up orchestration in a new project. User provides task description as argument.
---

# Deploy Orchestration — Phase 2 (Interactive)

**Prerequisite:** `deploy.sh` has already copied agents, skills, config, and hooks to this project.

**Usage:**
```
/deploy-orchestration [task description]
```

**Examples:**
```
/deploy-orchestration develop wordpress plugin for SEO optimization
/deploy-orchestration build REST API for user management with FastAPI
/deploy-orchestration create React dashboard with charts and auth
/deploy-orchestration web-scripts: form validators, browser plugins, CLI tools
```

The task description tells the skill:
- What tech stack to search skills for
- Whether this is atomic or multi-purpose (if description lists multiple things → multi)
- What to write in CLAUDE.md

## Workflow

### Step 0: Parse User Input

The user's task description after `/deploy-orchestration` is the primary input. Parse it to extract:

```
INPUT: "develop wordpress plugin for SEO optimization"
  → project_type: atomic (single thing)
  → keywords: [wordpress, plugin, seo, php]
  → purpose: "WordPress plugin for SEO optimization"

INPUT: "web-scripts: form validators, browser plugins, CLI tools"
  → project_type: multi (lists multiple things)
  → sub_projects: [{name: "form-validators", desc: "Form validation scripts"},
                    {name: "browser-plugins", desc: "Browser extension plugins"},
                    {name: "cli-tools", desc: "CLI utilities"}]
  → keywords: [javascript, typescript, browser-extension, cli]
```

**Detection rules for multi-purpose:**
- Contains comma-separated list of different things
- Uses words like "and", "plus", "also", listing distinct projects
- Explicitly mentions "scripts", "collection", "toolkit", "set of"

If unclear, **ask the user** — don't guess.

### Step 1: Detect Project Context

Read existing project files to enrich context:

```
1. Read package.json / pyproject.toml / go.mod / Cargo.toml (whichever exists)
2. Read README.md if it exists
3. Scan top-level directory structure
4. Combine with parsed user input
```

Output to user:
```
Setting up orchestration for: {purpose from user input}

Project: {name from directory or package.json}
Type: {atomic | multi-purpose}
Language: {detected or inferred from task}
{IF MULTI:}
Sub-projects:
  - {name}: {description}
  - {name}: {description}
```

### Step 2: Discover Task-Specific Skills

Use `find-skills` to discover skills relevant to the task:

```bash
# Extract keywords from task description + detected tech stack
# Example: "wordpress plugin" → search for wordpress, php
# Example: "React dashboard" → search for react, nextjs, charts

npx skills find [keyword1]
npx skills find [keyword2]
# ... up to 3-4 searches
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

### Step 3: Set Up Multi-Purpose Structure (if applicable)

For multi-purpose projects, create the sub-project directories:

```bash
mkdir -p src/{sub-project-1}
mkdir -p src/{sub-project-2}
# ...
```

### Step 4: Generate CLAUDE.md

**For atomic projects**, generate:

```markdown
# {Project Name}

{Purpose from user's task description}

## Commands

```bash
{detected or standard commands for the language}
```

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
**Tech stack:** {detected or inferred from task description}
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
1. Create it with the full generated content from Step 4

### Step 6: Output Summary

```
Orchestration setup complete!

Project: {name}
Type: {atomic|multi}
Purpose: {from user's task description}
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

1. **User's task description is the primary input** — don't ask questions that the description already answers
2. **Always ask before modifying existing CLAUDE.md** — never silently overwrite
3. **Install skills locally** (no `-g` flag) — keep project self-contained
4. **Create symlinks** for installed skills — ensures `.claude/skills/` visibility
5. **For multi-purpose projects**, each sub-project gets its own section in CLAUDE.md
6. **Don't install base skills via npx** — they were already copied by deploy.sh
7. **Verify orchestration-config.json exists** before finishing — it's required by agents
8. **If task description is missing**, show usage examples and ask user to provide one
