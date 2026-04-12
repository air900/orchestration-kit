# Orchestration Kit

Lightweight development orchestration for Claude Code. Deploys specialist agents, quality skills, and language hooks to any project — designed to work **alongside Superpowers** (methodology) and **Beads** (task tracking).

## What You Get

- **7 specialist agents** — planner, security-auditor, senior-reviewer, refactor, documenter, doc-keeper, observer
- **7 skills** — `/arch-review`, `/security-audit`, `/refactor-code`, `/012-update-docs`, `/find-skills`, `/sync-skills`, `/knowledge-harvest`
- **Language hooks** — auto-lint/format after every edit (TypeScript, Python, Go, Rust, JavaScript)
- **Safety guard** — PreToolUse hook blocking `rm -rf`, `git push --force`, `git reset --hard`
- **Config-driven artifacts** — plans, reports, issues, doc-drafts, observer reports

## Architecture

```
Superpowers (plugin)         — HOW: brainstorm → plan → TDD → review → verify
Beads (plugin, recommended)  — WHAT: git-backed task tracking, dependencies, session persistence
Orchestration Kit (this)     — WHO: specialist agents + quality skills + language hooks + doc workflow
```

Superpowers handles the core dev loop. Orchestration Kit provides **deep specialized analysis** that Superpowers doesn't cover: OWASP security audits, architecture health checks, documentation lifecycle, process improvement.

## Quick Start

### 1. Prerequisites

Install plugins (once, used by all projects):
```bash
# Required — development methodology
claude plugin install superpowers

# Recommended — persistent task tracking
claude plugin marketplace add steveyegge/beads
claude plugin install beads
npm install -g @beads/bd
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

### 3. Interactive setup (in Claude Code)

```
/deploy-orchestration develop REST API with FastAPI and PostgreSQL
/deploy-orchestration build React dashboard with auth and charts
/deploy-orchestration create WordPress plugin for SEO optimization
```

This discovers relevant skills for your stack and generates CLAUDE.md.

### 4. Start working

Superpowers drives development. Use specialist skills when needed:

```
/arch-review            — Architecture health check
/security-audit         — OWASP vulnerability scan
/refactor-code          — Guided refactoring
/012-update-docs        — Verify docs still match code
```

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

### Task tracking with Beads

Beads is a Dolt-backed issue tracker that survives context compaction. Install once:

```bash
# Plugin (hooks + commands in Claude Code)
claude plugin marketplace add steveyegge/beads
claude plugin install beads

# CLI
npm install -g @beads/bd

# Initialize in project (deploy.sh does this automatically if bd is available)
cd your-project && bd init
```

#### When to use Beads

| Ситуация | Beads нужен? |
|----------|-------------|
| Быстрый фикс в одну сессию | Нет — просто скажи Claude что сделать |
| Задача на несколько сессий | Да — контекст восстановится через `bd prime` |
| Эпик из 5+ подзадач с зависимостями | Да — `bd ready` покажет что разблокировано |
| Нужна история: что делал, когда, почему | Да — всё в Dolt-базе, переживает compaction |
| Работа в нескольких терминалах | Да — exclusive locks, нет конфликтов |

#### Slash-команды (не нужно запоминать CLI)

Beads plugin даёт slash-команды в Claude Code:

```
/beads:create    — создать задачу (интерактивно спросит тип, описание, приоритет)
/beads:ready     — показать разблокированные задачи
/beads:close     — закрыть задачу
/beads:epic      — создать/управлять эпиком
/beads:dep       — управление зависимостями
/beads:list      — все задачи
/beads:show      — детали задачи
/beads:stats     — статистика проекта
/beads:blocked   — что заблокировано и почему
/beads:workflow   — показать workflow-гайд
```

Или просто скажи на естественном языке — Claude вызовет нужную команду:
```
"Создай баг: карточки накладываются друг на друга, приоритет высокий"
"Что сейчас можно делать?"
"Закрой задачу — исправлено"
```

#### Flow 1: Быстрый баг-фикс (одна сессия)

Beads опционален. Superpowers делает всю работу:

```
ТЫ: "Карточки накладываются друг на друга в дереве, исправь"
 │
 ▼
SUPERPOWERS: brainstorm → план → TDD → fix → verify
 │
 ▼
ГОТОВО (коммит)
```

#### Flow 2: Баг-фикс с историей

```
ТЫ: /beads:create → тип: bug, "Карточки накладываются", приоритет 1
 │
 ▼
ТЫ: "Возьми задачу web-scripts-a3f2, исправь"
 │
 ▼
SUPERPOWERS: brainstorm → план → TDD → fix → verify
 │
 ▼
ТЫ: /beads:close → "Исправлен алгоритм spacing"
```

Зачем: через месяц `bd list --status closed` покажет что и когда чинил.

#### Flow 3: Эпик на несколько сессий

```
СЕССИЯ 1:
  /beads:epic → "Рефакторинг рендеринга дерева"
  /beads:create → "Исправить layout алгоритм"
  /beads:create → "Пересчёт координат связей"
  /beads:create → "Адаптив под мобильные"
  /beads:dep → связи блокируют layout (layout → связи → мобильные)

  /beads:ready → "layout алгоритм" (единственная разблокированная)
  Claude исправляет layout...
  /beads:close → "layout готов"
  [ контекст сжался / сессия закончилась ]

СЕССИЯ 2:
  bd prime (авто — hook при старте)
  → Claude видит: "Epic: рефакторинг дерева. Закрыто: layout. Ready: связи."

  /beads:ready → "Пересчёт координат связей"
  Claude работает...
  /beads:close → "связи пересчитаны"

СЕССИЯ 3:
  /beads:ready → "Адаптив под мобильные"
  ...
```

Beads hooks авто-запускают `bd prime` при старте сессии и перед compaction — контекст восстанавливается без ручных действий.

#### Три источника истории проекта

| Источник | Что хранит | Пример |
|----------|-----------|--------|
| **Git** | Изменения в коде | `git log --oneline` — что менялось в файлах |
| **LightRAG** | Решения и причины | "Выбрали D3 вместо Canvas потому что нужна интерактивность" |
| **Beads** | Задачи и их lifecycle | "Эпик: рефакторинг дерева. 3 подзадачи, 2 закрыты, 1 в работе" |

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
