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

#### Полный flow разработки

**Точка входа — `/workflow-gate`** перед задачей. Это запускает полный flow:

```
/workflow-gate <описание задачи>
```

```
┌─────────────────────────────────────────────────────────────┐
│ 1. /workflow-gate <задача>                                │
│    Запускает Template Bridge — связывает Beads + Superpowers │
├─────────────────────────────────────────────────────────────┤
│ 2. BEADS (автоматически)                                    │
│    Создаёт задачу в трекере                                  │
├─────────────────────────────────────────────────────────────┤
│ 3. SUPERPOWERS (автоматически)                              │
│    brainstorm → план → TDD → реализация → verification      │
├─────────────────────────────────────────────────────────────┤
│ 4. SPECIALIST AGENTS (по необходимости)                     │
│    /arch-review      — архитектура                          │
│    /security-audit   — OWASP уязвимости                     │
│    /refactor-code    — рефакторинг                          │
│    /012-update-docs  — проверка документации                 │
├─────────────────────────────────────────────────────────────┤
│ 5. TEMPLATE CATALOG (если нужен редкий специалист)           │
│    npx claude-code-templates@latest --agent <name> --yes    │
├─────────────────────────────────────────────────────────────┤
│ 6. ЗАКРЫТИЕ (автоматически)                                 │
│    Beads: bd close → следующая задача через bd ready         │
│    Эпик: documenter → doc-keeper → observer                 │
└─────────────────────────────────────────────────────────────┘
```

> **Enforcement:** PreToolUse hook **блокирует** Edit/Write/MultiEdit без маркера `.workflow-active`.
> `/workflow-gate` создаёт маркер и запускает flow. Без него Claude физически не может редактировать файлы.

#### Кто что делает

| Компонент | Роль | Когда работает |
|-----------|------|----------------|
| **Superpowers** | Dev loop: brainstorm, plan, TDD, review, verify | Всегда — основной движок |
| **Beads** | Задачи, зависимости, история, межсессионный контекст | Когда нужна persistence |
| **Specialist agents** | Глубокий анализ: архитектура, безопасность, рефакторинг | По запросу |
| **Template Catalog** | 413+ on-demand специалистов (K8s, Rust, GraphQL...) | Когда нет нужного скилла |
| **Language hooks** | Auto-lint/format после каждого Edit/Write | Всегда, фоново |
| **Doc workflow** | documenter → doc-keeper → observer | После крупных задач |

#### Примеры на реальных задачах

**Быстрый фикс** (5 минут, одна сессия):
```
ТЫ: /workflow-gate Кнопка не работает на мобильных, исправь
→ beads: создаёт задачу
→ superpowers: brainstorm → fix → verify
→ beads: закрывает задачу
→ коммит
```

**Задача посерьёзнее** (1 сессия):
```
ТЫ: /workflow-gate Карточки накладываются в дереве, нужен зазор между семьями
→ beads: создаёт bug P1
→ superpowers: brainstorm → plan → TDD → fix → verify
→ beads: закрывает с reason
```

**Эпик** (несколько сессий, зависимости):
```
СЕССИЯ 1:
  /workflow-gate Рефакторинг рендеринга дерева
  → beads: создаёт epic + 3 подзадачи с зависимостями
  → superpowers: brainstorm → plan
  → bd ready → "Layout алгоритм"
  → superpowers: TDD → fix → verify
  → bd close
  [ сессия закончилась ]

СЕССИЯ 2 (bd prime авто-восстанавливает контекст):
  /workflow-gate
  → bd ready → "Координаты связей"
  → superpowers: работает...
  → bd close

СЕССИЯ 3:
  /workflow-gate
  → bd ready → "Адаптив мобильные"
  → superpowers: работает...
  → bd close → epic закрыт
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

Beads — Dolt-backed операционная память проекта. Задачи, зависимости, заметки переживают context compaction и восстанавливаются автоматически.

#### Установка (один раз)

```bash
claude plugin marketplace add steveyegge/beads && claude plugin install beads
npm install -g @beads/bd
cd your-project && bd init    # deploy.sh делает это автоматически
```

#### Когда использовать

| Ситуация | Beads? |
|----------|--------|
| Быстрый фикс в одну сессию | Нет — `/workflow-gate <задача>` достаточно |
| Задача на несколько сессий | Да — `bd prime` восстановит контекст |
| Эпик из 5+ подзадач | Да — `bd ready` покажет readiness frontier |
| Нужна история проекта | Да — всё в Dolt-базе |
| Работа в нескольких терминалах | Да — atomic claim, нет гонок |

#### Lifecycle задачи

```
Создание                    Работа                      Закрытие
─────────                   ──────                      ────────
bd create                   bd update --claim           bd close --reason "..." --claim-next
  --type bug                bd update --notes "..."       ├── суть решения
  --priority 1              bd remember "pattern: ..."    ├── root cause
  --description "6 пунктов" bd dep add (discovered-from)  └── prevention
  --json
```

#### Quality Standards (подробно в workflow-gate skill)

**Создание** — 6 обязательных пунктов в description:
что сломано → где в коде → как воспроизвести → что найдено → контекст → ресурсы

**Во время работы:**
- `bd update --notes` сразу при находке (не в конце сессии)
- `bd remember` для конвенций и паттернов (персистентно между сессиями)
- `bd dep add --type discovered-from` для побочных находок
- Issue ID в коммитах: `git commit -m "Fix spacing (web-scripts-a3f2)"`

**Закрытие** — 3 обязательных пункта в reason:
суть решения → root cause → prevention

**Конец сессии** ("land the plane"):
обновить notes → оформить находки → `bd remember` → `git push` → `rm .workflow-active`

#### Epics

Epic — контейнер подзадач с зависимостями. Думай как constraint graph, не как ordered list:

```
Epic: "JWT авторизация"
  ├── Задача: "Миграция таблиц"              ✅ closed
  ├── Задача: "Middleware верификации"         🔄 in_progress (зависит от таблиц)
  └── Задача: "Refresh token логика"          ⬜ blocked (ждёт middleware)
```

| Ситуация | Epic или задача? |
|----------|-----------------|
| Фикс одного бага | Задача |
| Рефакторинг системы | Epic → подзадачи |
| Новая фича из 3+ частей | Epic → подзадачи |

#### Зависимости — 4 типа

| Тип | Влияет на `bd ready`? | Когда |
|-----|----------------------|-------|
| **blocks** | Да — блокирует | Задача B невозможна без A |
| **parent-child** | Нет | Иерархия epic → subtask |
| **related** | Нет | Связанные задачи |
| **discovered-from** | Нет | Провенанс: "нашёл во время работы над X" |

#### Maintenance (регулярно)

```bash
bd doctor --fix           # Ежедневно — диагностика и авто-фикс
bd compact --days 30      # Еженедельно — сжатие старых closed issues
bd upgrade                # Каждые 1-2 недели — обновление bd CLI
bd stats                  # По необходимости — общее состояние
```

Не допускать > 200 активных issues. При приближении — `bd compact`.

#### Три источника памяти проекта

| Источник | Что хранит | Пример |
|----------|-----------|--------|
| **Git** | Изменения в коде | `git log` — что менялось |
| **LightRAG** | Решения и причины | "Выбрали D3 потому что нужна интерактивность" |
| **Beads** | Задачи, прогресс, контекст | "Epic: рефакторинг. 3 задачи, 2 closed, 1 ready" |
| **bd remember** | Конвенции и паттерны | "test-pattern: baseline pid=5 tmode=2" |

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
