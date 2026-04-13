---
name: workflow-gate
description: >
  Entry point for all development work. Creates .workflow-active marker (unlocks Edit/Write),
  then invokes template-bridge:unified-workflow. Use BEFORE any task — edits are blocked without this.
  TRIGGER: Always use this instead of unified-workflow directly.
---

# Workflow Gate

**This skill is the ONLY way to unlock code editing in this session.**

A PreToolUse hook blocks Edit/Write/MultiEdit until `.workflow-active` exists.
This skill creates that marker and launches the full development workflow.

---

## Phase 1: Session Start

### 1.1 Activate gate

```bash
touch .workflow-active
```

Run IMMEDIATELY. Without it, all edits are blocked.

### 1.2 Load context

```bash
bd prime          # Workflow context: open issues, priorities, blockers
bd recall         # Persistent memory: conventions, patterns, past decisions
bd ready --json   # Structured list of claimable work
```

If resuming work from a previous session — check what's in progress before starting anything new.

### 1.3 Launch unified workflow

Invoke `template-bridge:unified-workflow` skill for the full flow.

---

## Phase 2: Issue Creation — Quality Standard

Beads — операционная память проекта. Каждая issue должна содержать достаточно контекста, чтобы **другая сессия без доступа к текущему разговору** могла продолжить работу.

### Обязательные поля при `bd create`

Всегда указывай `--type` и `--priority` (без них — интерактивный промпт, агент зависнет):

```bash
bd create --title "Title" --type bug --priority 1 --description "..." --json
```

### Description — 6 обязательных пунктов

1. **Что сломано/нужно** — конкретное поведение, не абстракция
2. **Где в коде** — файл, функция, строки (`tree.js:2420, compact()`)
3. **Как воспроизвести** — входные данные, URL, параметры (`pid=7 tmode=5`)
4. **Что уже найдено** — root cause, отвергнутые подходы
5. **Связь с контекстом** — почему задача появилась, что вскрыло проблему
6. **Ресурсы** — всё что нужно следующей сессии:
   - Файлы кода с номерами строк (`src/tree.js:1840-1870`)
   - Спеки/документация (`docs/line-spec.md §4.5`)
   - Скриншоты (`assets/screenshots/overlap-pid7.png`)
   - Тестовые данные, конфиги
   - Внешние ссылки (GitHub issues, статьи, ТЗ)

**Плохо:** `"Fix bond-drop crossing"`
**Хорошо:**
```
Bond-drop (grey bio line) crosses ⊔ former connector crossbar.
Root cause: _dropOff() in tree.js:1850 doesn't check ⊔ connectors.
Visible on pid=7 tmode=5, pair 35+34.
Found during GENP=140 testing — was hidden at GENP=100.

Resources:
- Code: src/plugins/drevo-zhizni-web/assets/js/tree.js:1840-1870
- Spec: docs/drevo-zhizni-web/line-spec.md §4.3
- Screenshot: assets/drevo-zhizni-web/images/overlap-pid7-tmode5.png
- Related: web-scripts-grw (dynamic gap — parent task)
```

### Побочные находки — discovered-from

Нашёл баг во время работы над другой задачей? Сразу:

```bash
bd create --title "Found bug X" --type bug --priority 2 --description "..." --json
bd dep add <new-id> <current-id> --type discovered-from
```

Это создаёт цепочку провенанса — как был обнаружен баг.

---

## Phase 3: During Work

### Notes — обновляй СРАЗУ

При обнаружении нового факта — не копить до конца:

```bash
bd update <id> --notes "FINDING: compact() at line 2420 ignores spouse gap. Tested on pid=5,7,213."
```

### Remember — персистентная память

Нашёл паттерн или конвенцию, которая пригодится в будущих сессиях:

```bash
bd remember "test-pattern: All tree layout tests use pid=5 tmode=2 as baseline"
bd remember "convention: DREVO_VERSION bumped on every visual change"
bd remember "gotcha: _formerSlot and gOffset go in opposite directions — never mix"
```

`bd recall` восстановит эти записи в следующей сессии.

### Коммиты — с issue ID

Всегда включай ID задачи в коммит:

```
git commit -m "Fix spacing for 4+ children (web-scripts-a3f2)"
```

Это позволяет `bd doctor` находить orphaned issues.

---

## Phase 4: Closing — Quality Standard

### `--claim-next` вместо простого close

```bash
bd close <id> --reason "..." --claim-next
```

Атомарно закрывает текущую + берёт следующую из ready queue. Предотвращает гонки в multi-agent.

### Reason — 3 обязательных пункта

1. **Суть решения** — что конкретно сделано (1-2 предложения)
2. **Root cause** — почему ошибка возникла
3. **Prevention** — что сделать чтобы не повторилось (тест, правило, проверка)

**Плохо:** `--reason "Fixed"`
**Хорошо:**
```
--reason "Добавлен expandRowGaps() post-pass после allocateCombSlots().
Root cause: GENP фиксированный — не учитывал количество гребней в промежутке.
Prevention: expandRowGaps() динамически раздвигает ряды — при новых коннекторах
проверять что их высота учтена в дефиците."
```

---

## Phase 5: Session End — "Land the Plane"

Сессия НЕ завершена пока не выполнены ВСЕ пункты:

1. **Открытые задачи** — обновить notes с текущим статусом:
   ```bash
   bd update <id> --notes "PROGRESS: steps 1-3 done. NEXT: step 4 (refactor drawBond). BLOCKED BY: nothing."
   ```

2. **Побочные находки** — оформить как issues с `discovered-from`

3. **Память** — сохранить конвенции и инсайты:
   ```bash
   bd remember "key-learning: description"
   ```

4. **Git** — чистое состояние:
   ```bash
   git pull --rebase && git push
   ```

5. **Маркер** — снять:
   ```bash
   rm -f .workflow-active
   ```

---

## Phase 6: Maintenance (периодически)

```bash
bd doctor --fix           # Диагностика и авто-фикс (запускать ежедневно)
bd compact --days 30      # Сжатие старых closed issues (LLM-суммаризация)
bd upgrade                # Обновление bd CLI (каждые 1-2 недели)
bd stats                  # Общее состояние проекта
```

Не допускать > 200 активных issues. При приближении — `bd compact` или `bd cleanup --days N`.

---

## Rules

- NEVER skip Phase 1 — edits blocked without marker
- NEVER create `.workflow-active` outside this skill
- NEVER use `bd create` without `--type`, `--priority`, `--description`
- NEVER use `bd edit` — it opens interactive editor, agent зависнет. Use `bd update --description`
- ALWAYS use `--json` flag for programmatic output
- ALWAYS write rich descriptions — they are the project's memory
- ALWAYS update notes immediately — don't batch
- ALWAYS include issue ID in commit messages
- ALWAYS use `--claim-next` when closing if more work exists
- ALWAYS "land the plane" before session end — notes, git push, remove marker
