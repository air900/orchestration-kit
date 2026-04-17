---
name: deploy-orchestration
description: Interactive orchestration setup — Phase 2 after deploy.sh. User provides task context, skill asks clarifying questions, discovers skills via find-skills-my, and generates CLAUDE.md with Superpowers integration. Use when setting up orchestration in a new project.
---

# Deploy Orchestration — Phase 2 (Interactive)

**Prerequisite:** `deploy.sh` has already copied agents, skills, config, and hooks to this project.

**Usage:**
```
/deploy-orchestration [initial context]
```

The initial context is a brief description of what the project is about. It sets the direction — then the skill asks follow-up questions to configure everything properly.

**Examples:**
```
/deploy-orchestration develop wordpress plugin for SEO optimization
/deploy-orchestration build REST API for user management with FastAPI
/deploy-orchestration create React dashboard with charts and auth
/deploy-orchestration collection of automation scripts for data processing
```

**If no context provided**, show these examples and ask:
```
What will you be building in this project? Describe briefly — I'll ask follow-up questions.
```

## Workflow

### Step 1: Read Initial Context & Scan Project

Take the user's description as starting context. Then scan the project:

```
1. Read package.json / pyproject.toml / go.mod / Cargo.toml (whichever exists)
2. Read README.md if it exists
3. Scan directory structure (ls top-level + src/ if exists)
4. Note what deploy.sh already set up (check .claude/agents/, .claude/skills/, settings.json)
```

Also check Beads status:
```
5. Check if .beads/ exists (bd init already run by deploy.sh)
6. If not — check if bd command is available, offer to run bd init
7. If bd not available — note in summary, recommend installing
```

Combine user input + detected info. Output a brief summary:
```
Got it — "{user's description}".
Detected: {language/framework if found, or "fresh project, no code yet"}
Beads: {initialized | not installed — run: npm install -g @beads/bd && bd init}
```

### Step 2: Ask Clarifying Questions

**This is the key step.** Ask the user focused questions to understand the project well enough to pick the right skills and generate a useful CLAUDE.md.

Use the AskUserQuestion tool. Ask **2-4 questions** depending on how much was already clear from the initial context.

#### Question 1: Project structure (always ask)

```
How is this project organized?

  1. Single project — one app/plugin/API/library in this repo
  2. Multiple sub-projects — several related but independent things
     (e.g., scripts + plugins + tools, or themes + plugins + blocks)
```

If user selects "Multiple sub-projects", follow up:
```
List the sub-projects with short descriptions.
Example: "scrapers: web scrapers, parsers: data parsers, reporters: report generators"
```

#### Question 2: Tech stack (ask if not obvious from context + detected files)

```
What tech stack will you use?

Examples:
  - PHP + WordPress
  - TypeScript + React + Next.js
  - Python + FastAPI + PostgreSQL
  - Go + gRPC
  - Vanilla JS, no framework
```

Skip this if the tech stack is already clear from:
- The user's initial description ("FastAPI" → Python + FastAPI)
- Detected files (package.json with react → React)

#### Question 3: Key features or domains (ask to improve skill search)

```
What are the main areas this project will cover?
This helps me find the right skills for your stack.

Examples for a WordPress SEO plugin:
  - SEO meta tags, sitemaps, schema markup, performance optimization

Examples for a React dashboard:
  - Auth, data tables, charts, form validation, API integration
```

#### Question 4: Development conventions (optional, ask for non-trivial projects)

```
Any specific conventions or requirements?

  1. Standard — I'll set up sensible defaults
  2. I have preferences — (describe: testing framework, code style, commit conventions, etc.)
```

### Step 3: Discover & Install Skills

Based on collected answers, extract search keywords and find relevant skills:

```bash
# Build keyword list from:
# - Tech stack answer (react, nextjs, fastapi, wordpress...)
# - Feature areas (auth, charts, forms, seo...)
# - Detected language

npx skills find [keyword1]
npx skills find [keyword2]
npx skills find [keyword3]
# ... up to 3-4 targeted searches
```

Present results to user:
```
Found skills for your project:

1. vercel-labs/agent-skills@vercel-react-best-practices
   React/Next.js performance optimization from Vercel Engineering

2. giuseppe-trisciuoglio/developer-kit@shadcn-ui
   Complete shadcn/ui component library patterns

Which ones should I install? (select from list)
```

For each selected skill:
```bash
npx skills add {package} -y
```

Create symlinks for Claude Code visibility:
```bash
ln -sf ../../.agents/skills/{name} .claude/skills/{name}
```

If no relevant skills found:
```
No additional skills found for [keywords]. The 7 base skills cover
quality, security, documentation, and skill management — Superpowers handles the dev loop.
```

### Step 4: Set Up Multi-Purpose Structure (if applicable)

For multi-purpose projects, create sub-project directories from Step 2 answers:

```bash
mkdir -p src/{sub-project-1}
mkdir -p src/{sub-project-2}
# ...
```

### Step 5: Generate CLAUDE.md

Build CLAUDE.md from all collected information. The content should be specific to THIS project, not generic.

**For atomic projects**, generate:

```markdown
# {Project Name}

{Purpose — from user's context + clarifying answers}

## Tech Stack

{Language, framework, key libraries — from Step 2 answers}

## Commands

```bash
{Detected or standard commands for the stack}
# Example for Python: pip install -e ., pytest, ruff check
# Example for Node: npm install, npm run dev, npm test
```

## Project Conventions

{From Step 2 Q4 answers, or sensible defaults}

## Claude Automations

### Development Methodology (D1)

**Entry point:** `/workflow-gate <task>` — slash command. Delegates to `template-bridge:unified-workflow` and layers our Beads quality overlay on top.

Flow (9 steps from unified-workflow):
1. `bd create` (6-point description — see `workflow-gate` skill § Phase 2)
2. Skill `superpowers:brainstorming`
3. Skill `superpowers:writing-plans`
4. Sub-tasks (`bd create` + `bd dep add`)
5. `superpowers:using-git-worktrees` (if non-trivial)
6. TDD via `superpowers:test-driven-development`
7. `superpowers:verification-before-completion` — **Iron Law:** no fresh test output → no "tested" claim
8. `superpowers:finishing-a-development-branch`
9. `bd close` (4-point reason incl Verification — `workflow-gate` skill § Phase 4)

**Beads artefacts (descriptions, notes, reasons, remember) are written in English** for token efficiency. User-facing communication stays in the user's language.

Manual commands:
- `/beads:create`, `/beads:ready`, `/beads:close` — direct Beads operations
- Skill `superpowers:brainstorming` — brainstorm without full `/workflow-gate`
- `/browse-templates` — 413+ on-demand specialist agents (Template Bridge)

**DO NOT use:** `/superpowers:brainstorm` (no `ing`) — deprecated, just prints a notice. Always invoke the skill `superpowers:brainstorming`.

**Workflow summary:** epic → sub-tasks with deps → `bd ready` → claim → work → verify → close → next ready task.

### Skills

**Quality & Review:**
- `/arch-review` — Architecture review for design patterns, SOLID, dependencies
- `/security-audit` — Security vulnerability audit (OWASP Top 10)
- `/refactor-code` — Guided code refactoring without behavior change
- `/012-update-docs` — Post-task documentation verification (did code changes break docs?)

**Utility:**
- `/find-skills-my` — Discover and install new skills from registry (custom deep-discovery version; renamed to avoid collision with vercel-labs/skills' own `find-skills`)
- `/sync-skills` — Detect unregistered skills in `.claude/skills/`
- `/knowledge-harvest` — Extract insights from sessions to knowledge base
- `/workflow-gate` — Beads quality-overlay entry (delegates to template-bridge:unified-workflow)
- `/workflow-gate-check` — Post-task audit (Mode 1) or independent second opinion on a proposed solution (Mode 2). Slash: `/workflow-gate-check` or `/workflow-gate-check 02`

{FOR EACH INSTALLED EXTERNAL SKILL:}
**External:**
- `/{skill-name}` — {skill description}

### Specialist Agents (on-demand)

These agents are NOT a pipeline. Call them when you need deep specialized analysis:

- `planner` — Break complex tasks into subtasks with dependency graphs
- `security-auditor` — OWASP Top 10 vulnerability scanning (read-only)
- `senior-reviewer` — Architecture review with health scores (read-only)
- `refactor` — Code refactoring specialist (modifies code)
- `documenter` — Create completion reports, update project docs
- `doc-keeper` — Process doc-drafts: analyze, cross-reference, recommend doc updates
- `observer` — Analyze completed work sessions, identify process improvements

**After significant work**, run this sequence:
1. `documenter` — generates completion report and doc-drafts
2. `doc-keeper` — processes doc-drafts, presents recommendations for approval
3. `observer` — analyzes the session, saves improvement insights

### Hooks

- **PreToolUse**: Safety guard blocking `rm -rf`, `git push --force`, `git reset --hard`
{IF LANGUAGE HOOKS:}
- **PostToolUse:Edit**: {language}-specific type/lint check after edits
- **PostToolUse:Write|MultiEdit**: Auto-format for {language} files

### Config

- `.claude/orchestration-config.json` — Paths and toggles for AI-generated artifacts (plans, reports, issues, doc-drafts, observer-reports)
- `.claude/references/` — Shared reference docs (code quality standards, doc-drafts format, issue tracking, documentation structure)

### Template Catalog (on-demand specialists)

When a task needs expertise not covered by installed skills or agents, pull a specialist from the template catalog (413+ agents across 26 categories):

```bash
npx claude-code-templates@latest --agent <category/name> --yes
```

Examples: `security/security-auditor`, `api-graphql/api-architect`, `devops/kubernetes-specialist`.

List all available: `npx claude-code-templates@latest --agent list`

Agents are installed locally. Delete after use if not needed long-term.

### Skill Discovery

On session start, scan `.claude/skills/` for skills not listed in the Skills section above.
Use `find -L .claude/skills -maxdepth 2 -name "SKILL.md" -type f` (NOT Glob — it doesn't follow symlinks).
If new skills are found, notify the user and suggest running `/sync-skills` to update this file.

```

**For multi-purpose projects**, add after the Config section:

```markdown
---

## Sub-Projects

| Name | Path | Description |
|------|------|-------------|
{FOR EACH SUB-PROJECT from Step 2:}
| {name} | src/{name}/ | {description} |

{FOR EACH SUB-PROJECT:}
### Sub-Project: {name}

**Path:** `src/{name}/`
**Description:** {description}
**Tech stack:** {from Step 2 answers}
**Build/Run:** {detected or TBD}

**Conventions:**
- {from answers or placeholder for user to fill in}
```

### Step 6: Apply to CLAUDE.md

If CLAUDE.md exists:
1. Check if it already has a `## Claude Automations` section (grep for it)
2. If yes: ask user whether to replace or append
3. If no: append the generated section at the end

If CLAUDE.md does not exist:
1. Create it with the full generated content from Step 5

### Step 7: Output Summary

```
Orchestration setup complete!

Project: {name}
Type: {atomic | multi-purpose}
Purpose: {from conversation}
Tech stack: {from answers}
Skills: 7 (arch-review, security-audit, refactor-code, 012-update-docs, find-skills-my, sync-skills, knowledge-harvest)
External skills: {count} ({list names})
Specialist agents: 7 (planner, security-auditor, senior-reviewer, refactor, documenter, doc-keeper, observer)

CLAUDE.md: {created | updated}
Config: .claude/orchestration-config.json

Development approach:
  Superpowers  — dev loop (brainstorm → plan → TDD → review → verify)
  Beads        — task tracking (bd ready → claim → work → close)
  Templates    — on-demand specialists (npx claude-code-templates@latest --agent ...)
  
Quality checks:
  /arch-review      — Architecture health
  /security-audit   — OWASP vulnerability scan
  /refactor-code    — Guided refactoring
  /012-update-docs  — Verify docs match code
```

## Key Rules

1. **Initial description is context, not final answer** — always ask clarifying questions
2. **Ask smart questions** — skip what's already obvious from context + file detection
3. **2-4 questions max** — don't interrogate, ask focused questions that improve the outcome
4. **Always ask about project structure** (atomic vs multi) — don't auto-detect this silently
5. **Always ask before modifying existing CLAUDE.md** — never silently overwrite
6. **Install skills locally** (no `-g` flag) — keep project self-contained
7. **Create symlinks** for installed skills — ensures `.claude/skills/` visibility
8. **Don't install base skills via npx** — they were already copied by deploy.sh
9. **Verify .claude/orchestration-config.json exists** before finishing — it's required by agents
10. **If no initial context provided**, show usage examples and ask user to describe the project
11. **Do NOT call ExitPlanMode** — this is a setup skill, not a plan. Output the summary and stop
