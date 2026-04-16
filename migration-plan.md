# Миграция существующих проектов → Orchestration Kit v2

> Шаблон для обновления проектов с Orchestration Kit v1 (11 агентов, pipeline) на v2 (7 агентов, Superpowers + Beads).
> Первый прогон: web-scripts, 2026-04-12.

## D1 Changes (2026-04-14)

For any existing project that has the old workflow-gate setup:

1. **Create** `.claude/commands/workflow-gate.md` — copy from
   `orchestration-kit/templates/commands/workflow-gate.md`.
2. **Shrink** `.claude/skills/workflow-gate/SKILL.md` — copy from updated
   `orchestration-kit/templates/skills/workflow-gate/SKILL.md` (Phases
   2, 3, 3.0, 4, 5, 6 only; no Phase 1 marker content).
3. **Replace** `.claude/settings.json` hooks section — copy from
   `orchestration-kit/templates/settings-hooks.json` (destructive Bash
   matcher + `bd prime` only).
4. **Delete** any existing `.workflow-active` marker file in the project
   root: `rm -f .workflow-active`.
5. **Update** project `CLAUDE.md` — remove any paragraph describing
   "Edit/Write заблокированы" or the marker lifecycle. Reference the
   slash command `/workflow-gate` as the entry point and the
   `workflow-gate` skill as the Beads-discipline reference.
6. **Verify** Template Bridge plugin is enabled in the user's global
   settings. If not, the agent falls back to `superpowers:brainstorming`
   directly (graceful degradation per design § 3.5).

Reference: `docs/superpowers/specs/2026-04-14-workflow-gate-d1-design.md`
and `docs/superpowers/plans/2026-04-14-workflow-gate-d1.md`.

---

## Новая архитектура

```
Superpowers (plugin)         — HOW: brainstorm → plan → TDD → review → verify
Beads (plugin + bd CLI)      — WHAT: git-backed tasks, deps, survives compaction
Orchestration Kit v2 (local) — WHO: 7 specialist agents + 7 skills + language hooks
Template Catalog (npx)       — ON-DEMAND: 413+ agents from davila7/claude-code-templates
```

---

## Шаги миграции

### 1. Удалить старые агенты, заменить новыми

**Удалить** из `.claude/agents/`:
- `worker.md`, `test-runner.md`, `reviewer.md`, `debugger.md` (покрыты Superpowers)

**Перезаписать** новыми версиями из `orchestration-kit/templates/agents/`:
- `planner.md`, `security-auditor.md`, `documenter.md`, `doc-keeper.md`, `observer.md`, `senior-reviewer.md`, `refactor.md`

```bash
rm PROJECT/.claude/agents/{worker,test-runner,reviewer,debugger}.md
cp orchestration-kit/templates/agents/*.md PROJECT/.claude/agents/
```

### 2. Удалить старые скиллы, заменить новыми

**Удалить** из `.claude/skills/`:
- `orchestrate/`, `implement/`, `code-review/` (заменены Superpowers)

**Перезаписать**: `arch-review/`, `security-audit/`, `refactor-code/`, `012-update-docs/`, `sync-skills/`

**Добавить**: `knowledge-harvest/`, `find-skills/` (если нет как симлинк)

**Обновить**: `deploy-orchestration/SKILL.md`

```bash
rm -rf PROJECT/.claude/skills/{orchestrate,implement,code-review}
for d in orchestration-kit/templates/skills/*/; do cp -r "$d" PROJECT/.claude/skills/$(basename "$d"); done
cp orchestration-kit/SKILL.md PROJECT/.claude/skills/deploy-orchestration/SKILL.md
```

**НЕ ТРОГАТЬ**: symlinked external skills

### 3. Добавить shared references

```bash
mkdir -p PROJECT/.claude/references
cp orchestration-kit/templates/references/*.md PROJECT/.claude/references/
```

### 4. Обновить settings.json — убрать SubagentStop

Удалить весь блок `"SubagentStop": [...]`. Оставить `PreToolUse` и все `PostToolUse`.

**НЕ ТРОГАТЬ**: `settings.local.json`

### 5. Инициализировать Beads

```bash
cd PROJECT && bd init
```

Если bd не установлен: `npm install -g @beads/bd`

### 6. Обновить CLAUDE.md

Заменить секцию `## Claude Automations` на новую (шаблон в SKILL.md):
- Superpowers как dev loop
- Beads workflow (bd create, bd ready, bd claim, bd close)
- 7 specialist agents (on-demand, НЕ pipeline)
- Скиллы (quality + utility + external)
- Template Catalog
- Hooks (только PreToolUse + PostToolUse)
- Config и references paths

**Сохранить** всё выше секции Claude Automations (описание проекта, tech stack, conventions).

### 7. Активировать Template Bridge

**Глобально (один раз на сервере):**
- Установить плагин: `claude plugin marketplace add maslennikov-ig/template-bridge && claude plugin install template-bridge`
- Добавить хуки в `~/.claude/settings.json` (SessionStart + PreCompact из `settings.example.json` плагина)
- Добавить workflow правила в `~/.claude/CLAUDE.md` (из CLAUDE.md плагина)

**Использование:** перед задачей вызвать `/unified-workflow` — это запускает полный flow (beads → brainstorm → plan → TDD → verify → close). Хуки обеспечивают `bd prime` при старте сессии.

### 8. НЕ ТРОГАТЬ

- `docs/orchestration/` — вся история (doc-drafts, reports, plans, issues, observer-reports)
- `.claude/orchestration-config.json` — пути артефактов
- `settings.local.json` — permissions override
- `.agents/skills/` — external skills (симлинки)
- Uncommitted changes в рабочих файлах проекта

---

## Верификация

```bash
# 1. Ровно 7 агентов
ls .claude/agents/

# 2. Нет SubagentStop
cat .claude/settings.json | jq '.hooks | keys'

# 3. Нет ссылок на удалённые скиллы
grep -rl "/orchestrate\|/implement\|/code-review" .claude/ CLAUDE.md

# 4. Superpowers + Beads в CLAUDE.md
grep "Superpowers" CLAUDE.md
grep "bd ready\|Beads" CLAUDE.md

# 5. Beads инициализирован
ls .beads/

# 6. Документация на месте
ls docs/orchestration/doc-drafts/ | wc -l
```

---

## Статус миграции проектов

| Проект | Статус | Дата | Примечания |
|--------|--------|------|------------|
| web-scripts | ✅ Готово | 2026-04-12 | 10 external skills, 39 doc-drafts |
| mtproxy-telegram | ✅ Готово | 2026-04-16 | 2 custom symlinks preserved (docker-expert, bash-defensive-patterns). Deploy.sh `cp -r` nested-dir bug discovered + fixed (commit 6735bf2) |
| check-parameters-sql-server-for-1c | ✅ Готово | 2026-04-16 | 2 custom symlinks preserved (postgresql-optimization, powershell-windows) |
| frm-client-automatization | ✅ Готово | 2026-04-16 | 2 custom symlinks preserved (proposal-writer, commercial-proposal-writer). Russian skill descriptions retained |
| vpn-manager-openwrt-x-ui | ✅ Готово | 2026-04-16 | Non-standard start: project had tech-lead-orchestrator fleet (47 agents, no skills). Wiped wholesale, installed kit v2 fresh per user directive. CLAUDE.md appended (no pre-existing Automations section) |
| hr-bot-project | ✅ Готово | 2026-04-16 | Customised migration per user: all 11 old agents removed (none needed), 6 kit-overlap skills removed, 4 skills kept (vercel-react-best-practices, shadcn-ui, find-skills, security-audit). `.claude/commands/` and `.claude/rules/` preserved intact |
| text4site-create-modified | ✅ Готово | 2026-04-16 | 11 custom skills preserved (6 dirs avers*/afr* content pipelines + 5 symlinks). Russian descriptions retained. Pre-migration WIP snapshot commit for `.agents/skills/find-skills/` changes |
| seo-audit | ✅ Готово | 2026-04-16 | **24 custom symlinks preserved** (SEO auditing 10 + marketing strategy 7 + keyword/competitive 2 + copywriting 3 + utility 2). Strict pre/post diff verification at 3 checkpoints — zero drift |
