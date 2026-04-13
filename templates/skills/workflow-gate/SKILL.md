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

## Steps

### Step 1: Activate gate

```bash
touch .workflow-active
```

Run this Bash command IMMEDIATELY. Without it, all edits will be blocked.

### Step 2: Launch unified workflow

Invoke the `template-bridge:unified-workflow` skill. It handles the full flow:
1. Beads: create task/epic
2. Brainstorm (superpowers)
3. Plan (superpowers)
4. TDD implementation
5. Review + verification
6. Close task

### Step 3: When done

After task is closed and committed, remove the marker:

```bash
rm -f .workflow-active
```

This re-arms the gate for the next task.

## Beads Issue Quality Standard

Beads — операционная память проекта. Каждая issue должна содержать достаточно контекста, чтобы **другая сессия без доступа к текущему разговору** могла продолжить работу.

**При создании issue (bd create) ОБЯЗАТЕЛЬНО включи в description:**

1. **Что сломано/нужно** — конкретное поведение, не абстракция
2. **Где в коде** — файл, функция, строки (например: `tree.js:2420, функция compact()`)
3. **Как воспроизвести** — входные данные, URL, параметры (например: `pid=7 tmode=5`)
4. **Что уже найдено** — выводы анализа, root cause, отвергнутые подходы
5. **Связь с контекстом** — почему появилась задача, что вскрыло проблему
6. **Ресурсы** — ссылки на всё, что нужно следующей сессии:
   - Файлы документации/спеки (`docs/line-spec-v4.md §4.5`)
   - Скриншоты/изображения (`assets/screenshots/overlap-pid7.png`)
   - Конфиги, тестовые данные (`test-data/pid7-tmode5.json`)
   - Внешние ссылки (GitHub issues, статьи, ТЗ)

**Плохо:** `"Fix bond-drop crossing"`
**Хорошо:**
```
Bond-drop (grey bio line) crosses ⊔ former connector crossbar.
Root cause: _dropOff() in tree.js:1850 doesn't check ⊔ connectors
when computing horizontal shift. Visible on pid=7 tmode=5, pair 35+34.
Found during GENP=140 testing — was hidden at GENP=100.

Resources:
- Code: src/plugins/drevo-zhizni-web/assets/js/tree.js:1840-1870
- Spec: docs/line-spec-v4.md §4.5 (bond-drop rules)
- Screenshot: assets/drevo-zhizni-web/images/overlap-pid7-tmode5.png
- Related: web-scripts-grw (dynamic gap — parent task)
```

**При обнаружении нового факта** — сразу `bd update <id> --notes "..."`. Не копить до конца сессии.

**При закрытии issue (bd close) ОБЯЗАТЕЛЬНО включи в reason:**

1. **Краткая суть решения** — что конкретно сделано (1-2 предложения)
2. **Root cause** — почему ошибка возникла
3. **Prevention** — что сделать, чтобы такие ошибки не повторялись (правило, тест, проверка)

**Плохо:** `bd close <id> --reason "Fixed"`
**Хорошо:**
```
bd close <id> --reason "Добавлен expandRowGaps() post-pass после allocateCombSlots().
Root cause: GENP был фиксированным — не учитывал количество гребней в конкретном промежутке.
Prevention: expandRowGaps() динамически раздвигает ряды — при добавлении новых типов коннекторов
проверять что их высота учтена в дефиците."
```

## Rules

- NEVER skip Step 1 — edits will fail without the marker
- NEVER create `.workflow-active` outside of this skill — the gate exists to enforce workflow
- If the marker already exists (resumed session), proceed to Step 2
- ALWAYS write rich descriptions when creating beads issues — they are the project's operational memory
- ALWAYS update notes immediately when discovering new facts — don't batch until session end
