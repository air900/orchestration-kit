# Orchestration Kit

Lightweight development orchestration for Claude Code. Deploys specialist agents, quality skills, and language hooks to any project — designed to work **alongside Superpowers** (methodology) and **Template Bridge** (workflow orchestration).

## What You Get

- **7 specialist agents** — planner, security-auditor, senior-reviewer, refactor, documenter, doc-keeper, observer
- **8 skills** — `/arch-review`, `/security-audit`, `/refactor-code`, `/012-update-docs`, `/find-skills-my`, `/sync-skills`, `/knowledge-harvest`, `/delegate-with-context`
- **Language hooks** — auto-lint/format after every edit (TypeScript, Python, Go, Rust, JavaScript)
- **Safety guard** — PreToolUse hook blocking `rm -rf`, `git push --force`, `git reset --hard`
- **Config-driven artifacts** — plans, reports, issues, doc-drafts, observer reports

## Architecture

Orchestration Kit follows the **D1 3-layer model** — each layer has a single clear responsibility, glued together by a thin project-local layer on top.

```
┌─────────────────────────────────────────────────────────────┐
│ L1 — TEMPLATE BRIDGE (workflow orchestrator)                │
│   Plugin: maslennikov-ig/template-bridge                    │
│   Skill: unified-workflow (end-to-end flow)                 │
│   Bonus: template-catalog + /browse-templates               │
├─────────────────────────────────────────────────────────────┤
│ L2 — SUPERPOWERS (dev-loop skills, used as-is)              │
│   Plugin: obra/superpowers                                  │
│   Skills: brainstorming, writing-plans,                     │
│           test-driven-development,                          │
│           verification-before-completion (Iron Law),        │
│           finishing-a-development-branch,                   │
│           using-superpowers (SessionStart 1% rule)          │
├─────────────────────────────────────────────────────────────┤
│ L3 — ORCHESTRATION-KIT (thin glue, project-local)           │
│   • .claude/commands/workflow-gate.md — slash command       │
│   • .claude/skills/workflow-gate/ — task-discipline ref     │
│   • .claude/settings.json — simplified hooks                │
└─────────────────────────────────────────────────────────────┘
```

Superpowers handles the core dev loop. Template Bridge's `unified-workflow` skill orchestrates it end-to-end. Orchestration Kit adds the `/workflow-gate` entry point plus **deep specialized analysis** that Superpowers doesn't cover: OWASP security audits, architecture health checks, documentation lifecycle, process improvement.

## Quick Start

### 1. Prerequisites

Install plugins (once, used by all projects):
```bash
# Required — development methodology (dev-loop skills)
claude plugin install superpowers

# Required — workflow orchestrator (unified-workflow skill + template-catalog)
claude plugin marketplace add maslennikov-ig/template-bridge
claude plugin install template-bridge
```

### 2. Deploy orchestration to your project

```bash
cd /path/to/my-project

# Atomic project (single-purpose)
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash

# Multi-purpose project (sub-projects in src/)
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
```

Or clone manually:
```bash
git clone --depth 1 https://github.com/air900/orchestration-kit.git /tmp/orch-kit
/tmp/orch-kit/deploy.sh /path/to/my-project
rm -rf /tmp/orch-kit
```

After the initial install, each project gets:
- `.claude/scripts/deploy.sh` — backend for kit-content refresh (self-bootstraps templates from GitHub on every run)
- `.claude/commands/kit-update.md` — unified slash command (two flags)

No kit clone needed at runtime.

### 2b. Post-install updates — `/kit-update` slash command

One slash command in Claude Code, two flags:

```
/kit-update --update-skills           # refresh kit-shipped content
/kit-update --update-external-skills  # refresh user-installed skills.sh skills
```

Both modes auto-commit + auto-push on real drift, with explicit path staging (never `git add -A`) so unrelated uncommitted work is preserved. Commit messages reference the kit SHA for traceability.

**`/kit-update --update-skills`**

Claude reads `.claude/commands/kit-update.md` and invokes `.claude/scripts/deploy.sh . --update-skills`:
- Detects no local `templates/` alongside; `git clone --depth 1` of the kit into /tmp (or tarball fallback if git missing).
- Re-copies kit content: `.claude/agents/`, `.claude/skills/` (with `references/`), `.claude/commands/`, `.claude/hooks/`, `.claude/references/`; merges `.claude/settings.json` hooks.
- For **skill directories**: `rm -rf` + `cp -r` (handles 5→3 references case).
- For **single files**: overwrite same-name only; custom-named files untouched.
- Cleans up tmp clone on exit.

**`/kit-update --update-external-skills`**

Invokes `python3 .claude/skills/update-external-skills/scripts/update.py`. Reads `skills-lock.json`, fetches GitHub metadata, shows a numbered selection table (`0` = all, `1,3,5` = specific, `1-5` = range), runs `npx skills update <selected>`, reports what actually updated. See [update-external-skills/SKILL.md](templates/skills/update-external-skills/SKILL.md).

### 2c. Refreshing `deploy.sh` + `/kit-update` themselves from the repo

If either file has changed upstream (new flag, bug fix), pull the latest versions with one curl from the project root:

```bash
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- --update-deploy
```

What this does:
- Downloads the latest `deploy.sh` and `kit-update.md` (~20 KB total, no full kit clone)
- Places them at `<project>/.claude/scripts/deploy.sh` and `<project>/.claude/commands/kit-update.md`
- Auto-commits + pushes (same traceability semantics as `/kit-update`)

Environment overrides (work for all three update paths): `ORCHESTRATION_KIT_REPO` (default `air900/orchestration-kit`), `ORCHESTRATION_KIT_REF` (default `main`).

### What these layers do NOT touch

- `.claude/settings.local.json` — your local permissions
- `.claude/orchestration-config.json` — project artefact paths
- `docs/orchestration/` — generated content
- `CLAUDE.md` — project documentation
- Any `.claude/skills/<custom-name>/` not shipped by the kit
- Any unrelated uncommitted changes in the target

### Batch update across multiple projects

For CI or a single shell pass across a fleet, invoke the bash backend directly (the slash command is only used interactively in Claude Code):

```bash
for p in project-a project-b project-c; do
  (cd "/root/projects/$p" && .claude/scripts/deploy.sh . --update-skills)
done
```

Each iteration auto-commits + pushes in its own project; final state is every project synced to the current kit HEAD.

### 3. Interactive setup (in Claude Code)

```
/deploy-orchestration develop REST API with FastAPI and PostgreSQL
/deploy-orchestration build React dashboard with auth and charts
/deploy-orchestration create WordPress plugin for SEO optimization
```

This discovers relevant skills for your stack and generates CLAUDE.md.

### 4. Start working

#### Полный flow разработки

**Точка входа — `/workflow-gate`** перед задачей. Это запускает полный flow:

```
/workflow-gate <описание задачи>
```

```
User: /workflow-gate fix LINE-CARD-CROSSING P1
  │
  ▼ Claude Code resolves the slash command.
  ▼ commands/workflow-gate.md injects task text + quality overlays.
  │
  ▼ template-bridge:unified-workflow runs:
     1. Task record   (6-point description — our overlay; tracker or docs/orchestration/issues/)
     2. superpowers:brainstorming
     3. superpowers:writing-plans
     4. sub-tasks (track in same place as parent)
     5. superpowers:using-git-worktrees (if non-trivial)
     6. TDD via superpowers:test-driven-development
     7. superpowers:verification-before-completion (Iron Law)
     8. superpowers:finishing-a-development-branch
     9. Task close    (4-point reason in commit body or tracker close — our overlay)
```

After the core flow you can plug in specialist agents on demand:

```
/arch-review            — architecture health
/security-audit         — OWASP Top 10
/refactor-code          — structural refactor
/012-update-docs        — docs sweep
/delegate-with-context  — chat-to-subagents dispatch (Iron Law evidence)
```

And for end-of-epic documentation: `documenter` → `doc-keeper` → `observer`.

> **Enforcement:** The Iron Law lives in `superpowers:verification-before-completion` — no claim of "done" without evidence. `/workflow-gate` is the disciplined entry point that routes you through `unified-workflow`; there is no file-marker or Edit/Write block anymore.

#### Кто что делает

| Компонент | Роль | Когда работает |
|-----------|------|----------------|
| **Template Bridge** (`unified-workflow`) | Оркестратор: склеивает Superpowers в единый flow | Всегда — точка входа через `/workflow-gate` |
| **Superpowers** | Dev loop: brainstorm, plan, TDD, review, verify | Всегда — основной движок |
| **Specialist agents** | Глубокий анализ: архитектура, безопасность, рефакторинг | По запросу |
| **Template Catalog** | 413+ on-demand специалистов (K8s, Rust, GraphQL...) | Когда нет нужного скилла |
| **Language hooks** | Auto-lint/format после каждого Edit/Write | Всегда, фоново |
| **Doc workflow** | documenter → doc-keeper → observer | После крупных задач |

#### Примеры на реальных задачах

**Быстрый фикс** (5 минут, одна сессия):
```
ТЫ: /workflow-gate Кнопка не работает на мобильных, исправь
→ create task record (issue tracker / PR body / docs/orchestration/issues/)
→ superpowers: brainstorm → fix → verify
→ close task with 4-point reason in commit body or tracker close-comment
→ коммит
```

**Задача посерьёзнее** (1 сессия):
```
ТЫ: /workflow-gate Карточки накладываются в дереве, нужен зазор между семьями
→ create task record (bug P1)
→ superpowers: brainstorm → plan → TDD → fix → verify
→ close task with 4-point reason
```

**Эпик** (несколько сессий, зависимости):
```
СЕССИЯ 1:
  /workflow-gate Рефакторинг рендеринга дерева
  → create task record (epic + 3 sub-tasks)
  → superpowers: brainstorm → plan
  → claim "Layout алгоритм"
  → superpowers: TDD → fix → verify
  → close task with 4-point reason

СЕССИЯ 2:
  /workflow-gate
  → claim "Координаты связей"
  → superpowers: работает...
  → close task with 4-point reason

СЕССИЯ 3:
  /workflow-gate
  → claim "Адаптив мобильные"
  → superpowers: работает...
  → close task → epic закрыт
  → documenter → doc-keeper → observer
```

**Нужен редкий специалист:**
```
ТЫ: "Нужно оптимизировать GraphQL запросы"
CLAUDE: "Для GraphQL есть api-graphql/graphql-performance-optimizer — установить?"
ТЫ: "Да"
→ npx claude-code-templates@latest --agent api-graphql/graphql-performance-optimizer --yes
→ Работает с установленным агентом
→ Удаляет после задачи
```

### Migrating an existing deployment

If you previously installed orchestration-kit when it shipped with Beads / LightRAG integration, your project still carries some legacy state. Run these one-time steps:

```bash
# 1. Refresh the kit-shipped content (skills, commands, hooks)
/kit-update --update-skills

# 2. (If you no longer want Beads) Remove the local Beads state and plugin
rm -rf .beads/
claude plugin uninstall beads

# 3. Hand-edit .claude/settings.json — remove any leftover hook entry that runs `bd prime`
#    Check: jq '.hooks.SessionStart, .hooks.PreCompact' .claude/settings.json
#    The kit no longer ships those entries; `/kit-update` only ADDS hooks, it does not
#    remove stale ones.

# 4. Regenerate CLAUDE.md to drop Beads-flavoured sections
/deploy-orchestration <your project description>
# When prompted about overwriting Claude Automations block, accept.
```

The `knowledge-harvest` skill currently still requires LightRAG MCP; it remains in the deployed roster but is scheduled for a rewrite that persists findings into project files. If your project does not have LightRAG MCP installed, the skill will return a `SKIPPED — no LightRAG MCP` notice when invoked.

## Supported Languages

| Language | Detected By | PostToolUse Hooks |
|----------|------------|-------------------|
| TypeScript | `tsconfig.json` or `typescript` in package.json | tsc + prettier |
| JavaScript | `package.json` (no TS) | eslint + prettier |
| Python | `pyproject.toml`, `requirements.txt`, `setup.py` | ruff check + ruff format |
| Go | `go.mod` | go vet + gofmt |
| Rust | `Cargo.toml` | cargo check + rustfmt |
| Generic | (fallback) | No language hooks |

## Specialist Agents

These agents are called **on-demand**, not as a pipeline. Use them when you need deep specialized analysis:

| Agent | Model | Purpose | When to Use |
|-------|-------|---------|-------------|
| `planner` | opus | Break complex tasks into subtask DAGs | Before large features with multiple parts |
| `security-auditor` | sonnet | OWASP Top 10 vulnerability scan | After auth, API, or data-handling changes |
| `senior-reviewer` | sonnet | Architecture review with health scores | Before merging significant refactors |
| `refactor` | sonnet | Code restructuring without behavior change | When code smells accumulate |
| `documenter` | haiku | Completion reports, doc updates | After significant work sessions |
| `doc-keeper` | sonnet | Process doc-drafts, recommend doc changes | After documenter creates drafts |
| `observer` | sonnet | Analyze sessions, identify process improvements | End of major work cycles |

### Post-work documentation cycle

After significant work, run this sequence:
1. **documenter** — generates completion report and doc-drafts
2. **doc-keeper** — processes doc-drafts, presents recommendations for approval
3. **observer** — analyzes the session, saves improvement insights

## Project Types

### Atomic (default) — One product, one repo

Use when your repo has **a single purpose**: one app, API, library, service.

**Structure after install:**
```
my-app/
├── src/                              # Your code (unchanged)
├── .claude/
│   ├── agents/                       # 7 specialist agents
│   ├── skills/                       # 7+ quality & utility skills
│   ├── references/                   # Shared reference docs
│   └── orchestration-config.json     # Artifact paths & toggles
├── docs/orchestration/               # AI-generated artifacts
│   ├── plans/                        #   Task breakdown plans
│   ├── reports/                      #   Completion reports
│   ├── issues/                       #   Tech debt tracking (ISS-NNN)
│   ├── doc-drafts/                   #   Documentation change proposals
│   └── observer-reports/             #   Process improvement insights
└── CLAUDE.md                         # Project rules + automations
```

### Multi-purpose — Multiple projects, one direction

Use when your repo contains **several independent projects** sharing a common theme.

```bash
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
```

CLAUDE.md will include a sub-project index with per-project sections (path, tech stack, commands, conventions).

### Decision flowchart

```
Does your repo build ONE product?
  ├── YES → atomic
  └── NO
       └── Several independent projects, common theme?
             ├── YES → multi
             └── NO (tightly coupled monorepo)
                  └── atomic (use your monorepo tool for builds)
```

## Configuration

### .claude/orchestration-config.json

Controls where AI-generated artifacts are saved:

```json
{
  "documentation": {
    "paths": {
      "plans": "docs/orchestration/plans",
      "reports": "docs/orchestration/reports",
      "issues": "docs/orchestration/issues",
      "doc_drafts": "docs/orchestration/doc-drafts",
      "observer_reports": "docs/orchestration/observer-reports"
    },
    "enabled": {
      "plans": true,
      "reports": true,
      "issues": true,
      "doc_drafts": true,
      "observer_reports": true
    }
  }
}
```

Set `enabled: false` to get output in chat instead of files.

## Customization

### Adding project-specific behavior

Agents read CLAUDE.md for project conventions. Add your coding standards, design system, and patterns there — agents follow them automatically.

### Adding skills

```bash
npx skills find [keyword]
npx skills add owner/repo@skill-name -y
ln -sf ../../.agents/skills/skill-name .claude/skills/skill-name
```

### Cross-session memory — two sources

Between sessions, context lives in two places:
- **Git history** — every commit, diff, and message is always there
- `docs/orchestration/conventions.md` (or CLAUDE.md) — cross-session patterns, gotchas, and conventions persisted by the `workflow-gate` skill's "land the plane" phase

### Template Catalog (on-demand specialists)

413+ specialized agents from [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates), organized in 26 categories. Pull a specialist when you need expertise not covered by installed agents:

```bash
# Install a specific agent
npx claude-code-templates@latest --agent security/security-auditor --yes

# Browse all available
npx claude-code-templates@latest --agent list

# Examples
npx claude-code-templates@latest --agent devops/kubernetes-specialist --yes
npx claude-code-templates@latest --agent api-graphql/graphql-architect --yes
npx claude-code-templates@latest --agent ai-specialists/prompt-engineer --yes
```

Agents are installed locally to the project. Delete after use if not needed long-term. Always fresh version from GitHub — no local staleness.

## License

Apache 2.0
