# Полный анализ: статья «3000+ часов в Claude Code» vs текущий стек

> Источник: https://habr.com/ru/articles/1017110/ (Игорь Масленников, 30.03.2026)
> Дата анализа: 2026-04-12

---

## 1. Текущее состояние (что есть сейчас)

### Orchestration Kit (проект /root/projects/orchestration-kit/)
- **11 агентов**: planner, worker, test-runner, debugger, reviewer, security-auditor, documenter, doc-keeper, observer, senior-reviewer, refactor
- **10 скиллов**: orchestrate, implement, code-review, arch-review, security-audit, refactor-code, 012-update-docs, knowledge-harvest, find-skills, sync-skills
- **Развёрнут** на 7+ проектах: hr-bot, web-scripts, seo-audit, frm-client, check-parameters-sql-server, mtproxy-telegram, test-orchestration

### Глобальный стек (уже установлено)
- **Superpowers v5.0.7** — установлен, активен (TDD, brainstorming, code review, verification)
- **LightRAG** — работает как cross-session память (MCP)
- **Context7** — MCP для актуальной документации
- **Playwright** — MCP для проверки фронтенда
- **22 плагина** в /root/.claude/plugins/
- **9 глобальных скиллов** в /root/.claude/skills/

### Чего НЕТ (из статьи)
- **Beads** — не установлен
- **Template Bridge** — не установлен

---

## 2. Что предлагает статья

| Компонент | Роль | Заменяет |
|-----------|------|----------|
| **Superpowers** | Методология (КАК) — TDD, brainstorm, review | Скиллы orchestrate, implement, code-review |
| **Beads** | Память задач (ЧТО) — git-backed issue tracker | SpecKit, plan-files, ручной DAG |
| **Template Bridge** | Каталог специалистов (КТО) — 413+ шаблонов | 11 локальных агентов |

Главный тезис: **интеграция вместо изобретения**. Три поддерживаемых сообществом плагина + тонкий клей вместо монолитной системы из 11 агентов + 10 скиллов.

---

## 3. ЧТО СТОИТ ПОМЕНЯТЬ (принять из статьи)

### 3.1. Установить Beads — git-backed трекер задач

**Зачем:** LightRAG и Beads — НЕ конкуренты, а дополнения:
- **LightRAG** = граф знаний (факты, решения, предпочтения) — долгосрочная память
- **Beads** = трекер задач (тикеты, зависимости, блокеры) — оперативная память проекта

Beads решает конкретную проблему: при context compaction задачи и их статусы теряются. `bd prime` восстанавливает контекст автоматически при старте сессии. Плюс `bd ready` показывает «фронт готовности» — какие задачи разблокированы.

**Что заменит:**
- Ручное управление DAG через TaskCreate/TaskUpdate
- Plan-files, которые раздувают контекст
- Потерю контекста задач между сессиями

**Приоритет: ВЫСОКИЙ** — это ключевой недостающий компонент.

### 3.2. Отказаться от агрессивной изоляции контекста

**Было:** Архитектура Orchestration Kit строилась вокруг экономии 200K окна — MCP-switching, Return Control Pattern, принудительный вывод в субагенты.

**Стало:** 1M контекста = ~900K свободного рабочего пространства. Половина архитектурных решений превратилась из необходимости в over-engineering.

**Конкретно убрать:**
- MCP-switching паттерн (переключение MCP серверов между агентами)
- Принудительную изоляцию через субагенты для экономии токенов
- Return Control Pattern как обязательный элемент

**Оставить изоляцию только где она нужна по существу:** параллельные воркеры на независимых задачах (worktree), длинные фоновые процессы.

### 3.3. Упростить пайплайн: убрать жёсткую цепочку SubagentStop

**Было:** Worker → Test-Runner → Security-Auditor → Reviewer → Debugger — детерминированная цепочка через хуки.

**Проблема:** Статья верно отмечает — при каждом обновлении Claude Code формат взаимодействия с Agent tool менялся, что ломало хуки. Жёсткие цепочки хрупки.

**Предлагается:** Superpowers задаёт методологию (brainstorm → plan → TDD → review → verify), но без жёсткой маршрутизации. Claude сам решает когда запускать тесты и когда ревьюить на основе скилла, а не хука.

### 3.4. Заменить SpecKit на brainstorming из Superpowers

Статья честно признаёт: SpecKit (Specification → Plan → Tasks → Implementation в JSON) мощный инструмент для команд, но избыточен для режима «соло-разработчик + Claude».

**Superpowers brainstorming даёт 80% ценности SpecKit при 20% церемонии.** Для текущих проектов (соло-разработка) это правильный trade-off.

### 3.5. Рассмотреть Template Bridge для on-demand специалистов

**Зачем:** Вместо хранения 11 локальных агентов — подтягивать нужного из каталога 413+ шаблонов по запросу (`npx claude-code-templates@latest --agent security/security-auditor --yes`).

**Преимущества:**
- Всегда свежая версия (не устаревает как локальные)
- Удаление после задачи (не засоряет контекст)
- 413+ специализаций vs 11 фиксированных

**Приоритет: СРЕДНИЙ** — полезно, но не критично. См. оговорки в разделе 5.

---

## 4. ЧТО НЕ СТОИТ МЕНЯТЬ (сохранить из Orchestration Kit)

### 4.1. Language-specific PostToolUse hooks (auto-lint/format)

**Ни один плагин из статьи не покрывает это.** Авто-линтинг после каждого Edit/Write:
- TypeScript: `tsc` + `prettier`
- Python: `ruff check` + `ruff format`
- Go: `go vet` + `gofmt`
- Rust: `cargo check` + `rustfmt`

Это **ортогональная ценность** — работает на уровне файлов, не зависит от методологии. Сохранить в `language-hooks/` и продолжать деплоить.

### 4.2. Documentation Draft System (3-stage)

Трёхстадийная система обновления документации:
1. Worker/Debugger создают драфты в `doc-drafts/`
2. Doc-Keeper обрабатывает драфты, верифицирует, рекомендует
3. Пользователь утверждает

**Аналога в Superpowers/Beads/Template Bridge нет.** Для проектов с активной документацией (hr-bot, web-scripts) это ценный процесс.

### 4.3. Observer agent — цикл улучшения процесса

Observer анализирует завершённые прогоны, находит системные bottleneck'и, предлагает улучшения. Это **уникальная возможность рефлексии**, отсутствующая в новом стеке.

Можно упростить (не обязательно отдельный агент — может быть скилл), но функцию сохранить.

### 4.4. Configuration-driven artifact paths

`orchestration-config.json` управляет куда AI-генерируемые артефакты сохраняются:
```json
{
  "documentation": {
    "paths": {
      "plans": "docs/orchestration/plans",
      "reports": "docs/orchestration/reports",
      "doc_drafts": "docs/orchestration/doc-drafts"
    }
  }
}
```

Это проект-специфичное управление выводом. Плагины работают глобально и не дают такой гранулярности.

### 4.5. Knowledge Harvest скилл

Интеграция с LightRAG — анализ сессий и кросс-ссылка с базой знаний. Это **наш кастомный скилл**, не покрываемый ничем из статьи. Критически важен для долгосрочной памяти.

### 4.6. find-skills + sync-skills

Автоматическое обнаружение и регистрация скиллов через симлинки. Свежий код (последние коммиты — deep analysis, local inventory). **Актуален и поддерживается.**

### 4.7. Deploy.sh — портативный деплой

Двухфазная модель деплоя позволяет быстро развернуть orchestration на новом проекте. Phase 1 (атомарный) + Phase 2 (интерактивный) — это **инфраструктура**, которую плагины не заменяют.

### 4.8. Bash audit log (добавлено 2026-04-16)

Per-project `PreToolUse`-хук `.claude/hooks/log-commands.sh` пишет каждую Bash-команду Claude Code в `.claude/command-log.txt` с ISO-8601 таймстампами. Аналога в Superpowers/Beads/Template Bridge нет — плагины логируют на уровне задач и коммитов, а не shell-команд.

**Почему per-project, а не глобально:** каждый проект получает изолированный аудит, файл гитигнорится через `.claude/.gitignore`, scope лога совпадает со scope'ом работы. Deploy копирует скрипт в `.claude/hooks/` и добавляет запись в `.claude/.gitignore`.

**Ценность:** форензика после инцидентов (особенно при мульти-проектной работе через SSH), отладка того, что Claude делал 3 сессии назад, доказательная база при аудитах деплоев.

---

## 5. ОГОВОРКИ И РИСКИ

### 5.1. Offline-доступ
Template Bridge тянет шаблоны с GitHub через `npx`. Без интернета — только заранее установленные агенты. Если какие-то из 7+ деплоев работают в ограниченных окружениях (VPS без npm, закрытые сети) — это блокер.

### 5.2. Универсальность vs специализация шаблонов
Статья честно признаёт: шаблонные агенты из каталога более общие, чем кастомные из Orchestration Kit. Наши агенты заточены под конкретный стек (Next.js + Supabase + TypeScript, WordPress + PHP). Template Bridge может требовать «дотачивания».

### 5.3. Зрелость Beads
Beads — относительно новый проект. Стоит проверить:
- Совместимость с текущей версией Claude Code
- Как взаимодействует с существующим TaskCreate/TaskUpdate workflow
- Нет ли конфликтов с Superpowers planning

### 5.4. Миграция развёрнутых проектов
7+ проектов уже используют Orchestration Kit. Миграция на новый стек — не одномоментный switch. Нужен план постепенного перехода.

---

## 6. РЕКОМЕНДУЕМЫЙ ПЛАН ДЕЙСТВИЙ

### Фаза 1: Дополнить (не ломать)
1. **Установить Beads** — протестировать на одном проекте (hr-bot или web-scripts)
2. **Интегрировать Beads + Superpowers + LightRAG** — настроить unified workflow
3. **Не трогать** деплои на существующих проектах

### Фаза 2: Оценить
4. Поработать 1-2 недели с Beads на одном проекте
5. Сравнить с TaskCreate/TaskUpdate workflow
6. Оценить: Template Bridge нужен или каталог шаблонов избыточен для текущих задач

### Фаза 3: Упростить Orchestration Kit
7. Удалить из шаблонов: MCP-switching, Return Control Pattern, агрессивную изоляцию
8. Сохранить: language hooks, doc-draft system, observer, config paths, deploy.sh
9. Переупаковать как **lightweight orchestration** — дополнение к Superpowers/Beads, а не замена

### Фаза 4: Обновить деплои
10. На новых проектах — сразу новый стек (Superpowers + Beads + lightweight orchestration)
11. Существующие проекты — мигрировать по мере необходимости

---

## 7. ИТОГОВАЯ МАТРИЦА

| Компонент Orchestration Kit | Решение | Причина |
|---|---|---|
| 11 агентов (planner, worker...) | **УПРОСТИТЬ** | Superpowers + on-demand шаблоны покрывают 90% |
| SubagentStop pipeline | **УБРАТЬ** | Хрупкий, ломается при обновлениях Claude Code |
| MCP-switching | **УБРАТЬ** | Не нужен при 1M контексте |
| Return Control Pattern | **УБРАТЬ** | Over-engineering при 1M контексте |
| SpecKit | **ЗАМЕНИТЬ** на Superpowers brainstorming | 80/20 trade-off |
| Language hooks | **СОХРАНИТЬ** | Уникальная ценность, нет аналога |
| Bash audit log (`log-commands.sh`) | **ДОБАВЛЕНО** 2026-04-16 | Форензика shell-команд per project, плагины не покрывают |
| Doc-draft system | **СОХРАНИТЬ** | Уникальная ценность, нет аналога |
| Observer | **СОХРАНИТЬ** (как скилл) | Рефлексия процесса, нет аналога |
| Config paths | **СОХРАНИТЬ** | Проект-специфичный контроль |
| Deploy.sh | **СОХРАНИТЬ** | Инфраструктура деплоя |
| find-skills | **СОХРАНИТЬ** | Свежий, полезный |
| knowledge-harvest | **СОХРАНИТЬ** | Критичен для LightRAG |
| DAG через TaskCreate | **ЗАМЕНИТЬ** на Beads | Beads даёт persistence + `bd ready` |
| Plan-files | **ЗАМЕНИТЬ** на Beads + Superpowers plans | Меньше церемонии |

---

## 8. РЕАЛИЗОВАННАЯ АРХИТЕКТУРА (обновлено 2026-04-12)

> ⚠️ **Историческая справка.** Раздел описывает pre-D1 модель enforcement (маркер `.workflow-active` + PreToolUse-блокировка Edit/Write). С 2026-04-14 (рефакторинг D1) маркер удалён: `/workflow-gate` переведён в slash-command, а PreToolUse hook ограничен только деструктивным Bash (`rm -rf`, `git push --force`, `git reset --hard`). Актуальная модель — в `README.md` и `migration-plan.md`.

```
┌─────────────────────────────────────────────────────────────┐
│                    PLUGINS (глобальные)                       │
│  Superpowers (dev loop) + Beads (tasks) + Template Bridge    │
├─────────────────────────────────────────────────────────────┤
│                ORCHESTRATION KIT v2 (локально)               │
│  7 agents + 8 skills + language hooks + doc workflow          │
│  workflow-gate + PreToolUse enforcement                       │
├─────────────────────────────────────────────────────────────┤
│                     ENFORCEMENT (pre-D1, устарело)            │
│  PreToolUse hook: Edit/Write BLOCKED без .workflow-active     │
│  /workflow-gate → touch .workflow-active → unified-workflow   │
│  SessionStart: rm .workflow-active + bd prime                 │
└─────────────────────────────────────────────────────────────┘
```

### Полный стек

| Слой | Компонент | Тип | Роль |
|------|-----------|-----|------|
| Plugins | Superpowers | глобальный | brainstorm → plan → TDD → review → verify |
| Plugins | Beads | глобальный | bd create/ready/close, persistence через compaction |
| Plugins | Template Bridge | глобальный | unified-workflow + каталог 413+ агентов |
| Local | workflow-gate | project skill | Создаёт маркер → запускает unified-workflow |
| Local | PreToolUse hook | project settings | Блокирует Edit/Write без маркера |
| Local | SessionStart hook | project settings | Удаляет маркер + bd prime |
| Local | 7 specialist agents | project agents | on-demand: planner, security-auditor, senior-reviewer, refactor, documenter, doc-keeper, observer |
| Local | 8 skills | project skills | arch-review, security-audit, refactor-code, 012-update-docs, find-skills, sync-skills, knowledge-harvest, workflow-gate |
| Local | Language hooks | project settings | auto-lint/format после Edit/Write |
| Local | Bash audit log hook | project settings + `.claude/hooks/log-commands.sh` | Лог каждой Bash-команды в `.claude/command-log.txt` (gitignored) |
| Local | Doc workflow | project agents | documenter → doc-keeper → observer |
| Local | Config | project .claude/ | artifact paths, references |

### Flow (pre-D1, устарело)

> ⚠️ Flow ниже — pre-D1. С 2026-04-14 маркер `.workflow-active` удалён, шаги `touch`/`rm` исключены; `/workflow-gate` напрямую запускает Beads-дисциплину.

```
/workflow-gate <задача>
  │
  ├─ touch .workflow-active (разблокирует Edit/Write)
  ├─ unified-workflow (Template Bridge)
  │   ├─ bd create (Beads)
  │   ├─ brainstorm (Superpowers)
  │   ├─ plan (Superpowers)
  │   ├─ TDD: RED → GREEN → REFACTOR (Superpowers)
  │   ├─ review + verify (Superpowers)
  │   └─ bd close (Beads)
  └─ rm .workflow-active (re-arm gate)
```

### Статус миграции

| Проект | Статус |
|--------|--------|
| orchestration-kit | ✅ Шаблон обновлён |
| web-scripts | ✅ Мигрирован 2026-04-12 |
| test-orchestration | ✅ Развёрнут с нуля |
| hr-bot | ⬜ Pending |
| seo-audit | ⬜ Pending |
| frm-client-automatization | ⬜ Pending |
| check-parameters-sql-server | ⬜ Pending |
| mtproxy-telegram | ⬜ Pending |
