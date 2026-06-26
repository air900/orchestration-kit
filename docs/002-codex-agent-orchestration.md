# Codex: оркестрация агентов и наборы агент/модель

**Дата:** 2026-06-25
**Статус:** справка + готовый набор scoped worker агентов

## Содержание

- [TL;DR](#tldr)
- [Что Codex реально умеет по оркестрации](#что-codex-реально-умеет-по-оркестрации)
- [Выбор моделей: ручной, авто-роутинга нет](#выбор-моделей-ручной-авто-роутинга-нет)
- [Готовые наборы агентов: что есть у сообщества и OpenAI](#готовые-наборы-агентов-что-есть-у-сообщества-и-openai)
- [Схема файла агента (проверено по первоисточнику)](#схема-файла-агента-проверено-по-первоисточнику)
- [Мой набор под стек: 5.5 оркестратор + 5.4 воркеры](#мой-набор-под-стек-55-оркестратор--54-воркеры)
- [Установка и использование](#установка-и-использование)
- [Безопасность и оговорки](#безопасность-и-оговорки)
- [Источники](#источники)

## TL;DR

- **Оркестрация в Codex есть**, но это не автономный диспетчер: главная сессия (модель `gpt-5.5`) — оркестратор, **которым ты управляешь**. Codex спавнит субагента **только когда ты явно просишь**, и **сам модели агентам не подбирает** — модель пинуется в файле агента.
- **«Набор агентов И моделей»** = папка `~/.codex/agents/*.toml`, где в каждом worker-файле зашиты `model`, `model_reasoning_effort`, `sandbox_mode`, `developer_instructions`. Текущий чат остаётся координатором.
- **OpenAI готовой большой библиотеки агентов не даёт** — только механизм + доки + sample-конфиги. У сообщества наборы есть; достовернее всех `wshobson/agents` (мульти-харнес) и Codex-нативный `VoltAgent/awesome-codex-subagents` (но у последнего engagement-метрики пахнут накруткой — см. таблицу).
- **Готовый набор под мой стек лежит рядом:** [`../templates/codex-agents/`](../templates/codex-agents/) — 6 scoped workers (5.4) + 1 скаут (5.4-mini). Текущий чат на основной модели остаётся координатором. Схема проверена по реальному файлу VoltAgent и репозиторию `openai/codex`.

## Что Codex реально умеет по оркестрации

[verified: [developers.openai.com/codex/subagents](https://developers.openai.com/codex/subagents)]

- Спавнит специализированных субагентов **параллельно**, потом собирает в один консолидированный ответ.
- Сам ведёт механику: «spawning new subagents, routing follow-up instructions, waiting for results, and closing agent threads».
- ⚠️ **«Codex only spawns a new agent when you explicitly ask it to do so».** Сам по своей инициативе не дробит задачу и не делегирует — нужен твой триггер (или указание оркестратору в `AGENTS.md`).
- `spawn_agents_on_csv` (экспериментальный): строка CSV → один воркер-субагент на строку → батч → результат обратно в CSV.
- Детерминированные пайплайны: Codex как MCP-сервер + OpenAI Agents SDK.

**Важно понимать про «главного оркестратора».** Это не магия само-разбиения. «Оркестратор» = твоя главная сессия Codex на `gpt-5.5`, которой ты даёшь многошаговую задачу; она планирует и **явно** спавнит воркеров. Поведение «5.5 сам решил разбить на агентов и раздал им модели» — этого нет.

## Выбор моделей: ручной, авто-роутинга нет

[verified: [developers.openai.com/codex/models](https://developers.openai.com/codex/models)]

- Модель **назначаешь ты**: дефолт в `config.toml`, либо `/model` в сессии, либо флаг `--model`, либо поле `model` в файле агента.
- **Авто-роутинга моделей по сложности/типу задачи НЕТ.** Не укажешь — берётся «recommended model».
- Авто-выбор (`model_reasoning` / `model_execution` / `model_tool` по типу работы) — открытый [feature request #9205](https://github.com/openai/codex/issues/9205), не реализован.

Доступные модели (на 2026-06): `gpt-5.5` (фронтир), `gpt-5.4` (флагман), `gpt-5.4-mini` (быстрый/дешёвый), `gpt-5.3-codex-spark` (preview, near-instant, ChatGPT Pro).

## Готовые наборы агентов: что есть у сообщества и OpenAI

Цифры проверены через GitHub API (не через веб-сводку — она завышала). Колонка `s:w` = stars/watchers; у органики обычно 10–30:1, сильно выше = повод заподозрить накрутку.

| Репо | ⭐ | watch | forks | issues | s:w | Чтение |
|---|--:|--:|--:|--:|--:|---|
| **openai/codex** (офиц.) | 93 564 | 509 | 13 840 | **7 797** | 184:1 | Реальный, живой. Но это **инструмент**, не пак агентов |
| **wshobson/agents** | 37 170 | 314 | **4 002** | 9 | 118:1 | Лучший community-вариант. Мульти-харнес (Markdown-source → Codex ест нативно). Форков много = юзают |
| VoltAgent/awesome-agent-skills | 26 411 | 200 | 2 824 | 8 | 132:1 | 1000+ *скиллов* (не агентов), мульти-харнес |
| VoltAgent/awesome-codex-**subagents** | 5 313 | **22** | 597 | **3** | **241:1** ⚠️ | Codex-нативные `.toml` (60+ агентов). Но 22 watcher / 3 issue на 5.3K звёзд за 99 дней = запах накрутки. Брать как каталог формата, не доверять оптом |
| RoggeOhta/awesome-codex-cli | 338 | 4 | 99 | **89** | — | Не пак, а **индекс-карта** (awesome-list). Линкуется из офиц. discussion #16329 |
| betterup/codex-cli-subagents | 18 | 1 | 6 | 2 | — | Нишевый (enterprise). Низкое доверие |
| leonardsellem/codex-specialized-subagents | 64 | 0 | 3 | 3 | — | Нишевый (a11y, i18n, perf) |

**От OpenAI официально — строительные блоки, не готовый пак:** [config-sample](https://developers.openai.com/codex/config-sample), [subagents docs](https://developers.openai.com/codex/subagents), [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md), [Agents SDK](https://developers.openai.com/codex/guides/agents-sdk), [Cookbook](https://developers.openai.com/cookbook/topic/agents).

## Схема файла агента (проверено по первоисточнику)

Формат — **TOML** в `~/.codex/agents/*.toml` (личные) или `<repo>/.codex/agents/*.toml` (проектные). Подтверждено реальным файлом `VoltAgent/awesome-codex-subagents/.../backend-developer.toml`:

```toml
name = "backend-developer"
description = "Use when a task needs scoped backend implementation..."
model = "gpt-5.4"
model_reasoning_effort = "high"     # наблюдаемые значения: high, medium (есть low/minimal)
sandbox_mode = "workspace-write"    # либо read-only, либо danger-full-access
developer_instructions = """
...многострочные инструкции агенту...
Do not broaden ... unless explicitly requested by the parent agent.
"""
```

Поля `model` / `model_reasoning_effort` / `sandbox_mode` опциональны — если опустить, наследуются от родительской сессии. Фраза **«the parent agent»** в реальных файлах подтверждает модель «оркестратор → воркеры».

## Мой набор под стек: текущий чат-координатор + 5.4 воркеры

Файлы: [`../templates/codex-agents/`](../templates/codex-agents/). Маппинг моделей повторяет текущую рабочую схему: основной чат планирует и интегрирует, 5.4 — рабочая лошадка кодинга, mini — ретрив.

| Агент | Модель | Effort | Sandbox | Роль |
|---|---|---|---|---|
| `code-scout` | gpt-5.4-mini | low | read-only | Найти/смаппить код (дёшево, первым) |
| `backend-engineer` | gpt-5.4 | high | workspace-write | Python/FastAPI/SQLAlchemy async |
| `frontend-engineer` | gpt-5.4 | high | workspace-write | React/TypeScript (Vite) |
| `test-engineer` | gpt-5.4 | high | workspace-write | pytest / vitest |
| `debugger` | gpt-5.4 | high | workspace-write | Сначала root-cause, потом фикс |
| `infra-engineer` | gpt-5.4 | medium | workspace-write | Docker/compose/nginx/systemd/deploy |
| `code-reviewer` | gpt-5.4 | high | read-only | Ревью диффа перед merge |

Решения по дизайну:
- **Ревью и тесты на 5.4**. Компенсация: `model_reasoning_effort = "high"` + `read-only` для ревьюера.
- **`code-scout` на 5.4-mini** — для locate/map платить флагманом незачем (твоё же правило «haiku для ретрива»).
- **`infra-engineer` на medium** — конфиги механистичнее, чем код.
- Инструкции (`developer_instructions`) намеренно **короткие** — стартовые шаблоны, не простыни-эссе.

**Глобально или по-проектно.** Два места [verified: [subagents docs](https://developers.openai.com/codex/subagents)]:
- `~/.codex/agents/*.toml` — **глобально**, доступны в каждом проекте (сюда я и ставлю набор — он stack-level, полезен везде).
- `<repo>/.codex/agents/*.toml` — **только этот репо**.

Подтверждено: кастомный агент бьёт встроенный с тем же именем. А вот precedence «личный vs проектный» для одинакового имени **в доках не описан** — поэтому не закладывайся на молчаливое перекрытие: держи общий набор глобально, а проектно-специфичных агентов (напр. знающего golden-parity/tenant-правила конкретного сервиса) клади в `<repo>/.codex/agents/` под **отдельным именем**.

## Установка и использование

```bash
mkdir -p ~/.codex/agents
cp ~/projects/orchestration-kit/templates/codex-agents/{backend-engineer,frontend-engineer,test-engineer,debugger,infra-engineer,code-reviewer,code-scout}.toml ~/.codex/agents/
# config.toml.example НЕ копировать как .toml — это сниппет
```

1. Влей `[agents]` из `config.toml.example` в `~/.codex/config.toml` — он задаёт лимиты параллельности субагентов и не должен затирать существующие настройки.
2. Держи проектные инструкции в `CLAUDE.md`; `AGENTS.md` должен быть относительным symlink на него: `ln -s CLAUDE.md AGENTS.md`.
3. Дальше работаешь как обычно: даёшь главной сессии многошаговую задачу — она планирует и **явно** спавнит воркеров. Хочешь конкретного — проси по имени («delegate to backend-engineer»).

## Безопасность и оговорки

- Сторонние `.toml` исполняют `developer_instructions` в твоём окружении — это trust-поверхность. **Не ставить пачкой**, сканировать/читать перед адаптацией, cherry-pick. (Мой набор — локальный и просмотренный.)
- `sandbox_mode` — реальная защита: ревьюер и скаут `read-only`, чтобы не могли писать.
- Не путать с `*/agents/openai.yaml` в репо `openai/codex` — это **интерфейс скилла** (display_name/short_description/default_prompt), без поля `model`. Другое назначение.
- Авто-режима «оркестратор сам всё разрулил» нет — текущий чат должен явно управлять делегированием.

## Источники

- [Codex subagents](https://developers.openai.com/codex/subagents), [models](https://developers.openai.com/codex/models), [config-sample](https://developers.openai.com/codex/config-sample)
- [openai/codex](https://github.com/openai/codex) · [wshobson/agents](https://github.com/wshobson/agents) · [VoltAgent/awesome-codex-subagents](https://github.com/VoltAgent/awesome-codex-subagents) · [RoggeOhta/awesome-codex-cli](https://github.com/RoggeOhta/awesome-codex-cli)
- [feature request #9205 (авто-выбор моделей)](https://github.com/openai/codex/issues/9205) · [discussion #16329](https://github.com/openai/codex/discussions/16329)
- Схема `.toml` сверена с `VoltAgent/.../01-core-development/backend-developer.toml` и деревом `openai/codex` (GitHub API, 2026-06-25).
