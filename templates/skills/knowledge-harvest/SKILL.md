---
name: knowledge-harvest
description: >
  Analyze all conversation sessions for the current project, cross-reference with LightRAG knowledge base,
  and propose new or updated entries. Use when the user says "knowledge harvest", "что записать в базу",
  "проанализируй диалоги", "what should we save", "harvest knowledge", or at the end of a long work session.
  Do NOT use for searching existing knowledge (use query_text directly) or for saving a single explicit fact
  (use insert_text directly).
---

# Knowledge Harvest

Scan project knowledge for the current project, compare with what LightRAG already knows, and propose additions/updates. Never save without explicit user approval.

## Source Selection

Harvest pulls from three source types. Each yields a qualitatively different layer of knowledge — don't treat them as interchangeable.

| Source | What it yields |
|--------|---------------|
| **Session history** | Incident facts, user preferences, decisions, conversation-only knowledge |
| **Code + documentation** | Sanctioned patterns, architectural conventions, reusable techniques visible in self-documenting code, rules files, architecture docs |
| **Git history** | Battle scars — recurring bug classes, ordering fixes, silent failure patterns revealed by fix commits (clusters of 3+ similar commits = strong signal) |

### Default behavior: run all three in optimal order

**When the user says `/knowledge-harvest` with no explicit source override, run ALL THREE sources in this exact order within a single session:**

1. **Session history first** — establishes context: who the user is, recent incidents, current decisions. Without this, later findings look like context-free noise.
2. **Code + docs second** — captures sanctioned patterns ("this is how we decided to do it"), often only visible in `END_HEADER` blocks, `.claude/rules/`, or self-documenting script headers. These are intentional design statements.
3. **Git log third** — extracts battle scars: repeating commit messages ("fix correct order", "fix subshell issue") reveal bug classes and produce the most valuable process lessons (Priority 1). Git log is unintentional signal — the ops team stumbling on the same rake multiple times.

**Why this order matters:** Sessions set the frame. Code/docs show intended state. Git log shows reality. Reversing makes git-findings look like trivia (you don't know the architecture yet) and code-findings look like decoration (you don't know which patterns were hard-won).

**How to run three sources in one session:** Complete Workflow Steps 1-7 fully for source 1 (including approval and save to LightRAG). Then announce "Переходим ко второму источнику: code + docs" (match user language) and restart Workflow at Step 1 for source 2. Same for source 3. Each source gets its own proposal batch and approval — do NOT bundle all 3 sources into one giant proposal list; the user needs to approve incrementally, and context accumulates between sources (source 2 can reference what was saved from source 1). After all three — give a combined summary (total items saved, grouped by source).

### Single-source override

User can explicitly request one source only. Recognize these triggers:

| User says | Run only |
|-----------|----------|
| "harvest sessions", "только сессии", "по сессиям", "по диалогам" | Session history |
| "harvest code", "подходы к разработке", "patterns from docs", "посмотри скрипт", "по коду", "из документации" | Code + docs |
| "harvest git log", "посмотри коммиты", "что из истории", "recurring bugs", "по git", "из коммитов" | Git history |

In single-source mode — run only the named source, skip the other two, and say so explicitly at the start.

### Source-Specific Extraction

- **Sessions:** Workflow Steps 1-2 (JSONL parsing of `~/.claude/projects/{project-key}/*.jsonl`).
- **Code + docs:** Read `CLAUDE.md`, `.claude/rules/*`, `docs/**/*.md`, and large self-documenting scripts — look for `END_HEADER` markers, `# SECTION N` banners, `# INVENTORY:` blocks, anti-pattern lists, data-structure comments. Target: explicit pattern declarations that a future session would miss without reading the file.
- **Git log:** `git log --all --pretty=format:"%h %ad %s" --date=short` + `git log | grep -iE "fix.*(order|race|subshell|silent|stdin|escap|heredoc|quote|timeout|retry)"`. For each interesting commit: `git show <hash>` to read the full context (commit message explains root cause). Strong signal: 3+ commits fixing similar-sounding issues — that's a bug CLASS, not a one-off.

Each source runs the same Workflow below (Steps 1-7: show → extract → cross-reference with LightRAG → propose → wait for approval → save). Only the extraction method in Steps 1-2 differs.

## Workflow

### Step 1: Show Sessions and Ask

**Always start by showing what's available.** Determine the project key from `$PWD`:

```
/root/projects/paperclip → -root-projects-paperclip
```

Find all `.jsonl` files in `~/.claude/projects/{project-key}/` (excluding `*/subagents/`), sorted by modification time (newest first). Extract the first user message from each file to use as a label.

Show a table:

```
| # | Date       | Msgs | Topic                                  |
|---|------------|------|----------------------------------------|
| * | (current)  | —    | (this conversation)                    |
| 1 | 2026-04-10 | 12   | Проанализируй обновления paperclip...  |
| 2 | 2026-04-06 | 6    | Создай проект Topdog-monitor...        |
| 3 | 2026-03-29 | 77   | Расскажи мне о проекте paperclip...    |
```

Then ask:

> Какие сессии анализировать? Варианты: `все`, `*` (текущий чат), номера через запятую (`1, 3`), диапазон (`1-3`)

Wait for the user's response before proceeding.

- `все` / `all` → analyze all sessions including current
- `*` / `this` / `текущий` → only the current conversation (from context, no file parsing)
- `1, 3` → specific sessions by number
- `1-3` → range of sessions
- `* + 1` or `текущий + 1` → current conversation plus session #1

### Step 2: Extract User Messages

For each `.jsonl` session file, extract messages where `type == "user"`. The message format:

```json
{
  "type": "user",
  "message": {
    "role": "user",
    "content": [{"type": "text", "text": "..."}]
  }
}
```

Also extract `type == "assistant"` messages to capture key conclusions, recommendations, and decisions made by Claude — these often contain the most valuable knowledge (architecture decisions, root cause analyses, procedure discoveries).

Skip:
- System messages, tool results, file snapshots
- Messages that are purely navigational (`<ide_opened_file>`, `<system-reminder>`)
- Messages shorter than 20 characters

Build a condensed summary of each session: what was discussed, what was decided, what was learned.

#### Extracting Conceptual Lessons (failure→success arcs)

Beyond facts and decisions, actively look for **process improvement patterns** — the most valuable harvest output. Scan for:

1. **Failed attempts:** Where did the agent (or user) try something that didn't work? What was the wrong assumption?
2. **Root cause discovery:** What was the ACTUAL cause vs what was initially suspected?
3. **Breakthrough moments:** What insight or approach finally solved the problem?
4. **Repeated patterns:** Did "fix here, break there" happen? Did the same class of error appear multiple times?
5. **User corrections:** When did the user say "no, that's wrong" or "you missed X" — these reveal blind spots.

Focus on **conceptual, reusable lessons** — not specific to one bug or one file, but applicable to any similar situation in the future.

### Step 3: Query LightRAG for Existing Knowledge

Run 2-3 MCP `query_text` calls (mode: `hybrid`) with queries derived from the session topics. Example queries:
- Project name + "architecture deployment update"
- Project name + "decisions preferences lessons"
- Project name + "procedures configuration setup"

Collect all referenced file names from the results — these are the existing knowledge entries.

### Step 4: Cross-Reference and Identify Gaps

Compare session content against existing LightRAG entries. Classify each potential finding:

#### Memory Pyramid (priority order)

| Priority | Type | What to look for |
|----------|------|-----------------|
| 1 (highest) | **Process lessons** | Failure→success arcs: conceptual patterns that prevent repeating mistakes |
| 2 | **Decisions & reasons** | Why X was chosen over Y, trade-offs, rejected approaches |
| 3 | **Lessons learned** | Mistakes made, workarounds discovered, "gotchas" (single-instance, not patterns) |
| 4 | **Project facts** | Architecture, infrastructure, procedures, configurations |
| 5 | **Preferences** | User's preferred approaches, tools, conventions |
| 6 (lowest) | **Documentation** | Key takeaways from guides/APIs — only if unique |

#### Action types

- **NEW** — topic not covered in LightRAG at all
- **UPDATE** — existing entry has outdated or incomplete information. Show what was vs what is now
- **SKIP** — already covered accurately, or derivable from code/git

### Step 5: Present Proposals

Format each proposal as a numbered item. Use the appropriate template based on type:

#### For Process Lessons (Priority 1)

```
### N. ACTION: title
**File:** lesson-{slug}.txt
**Priority:** Process lessons
**Урок:** Conceptual, reusable insight (1-2 sentences). Not specific to one file/bug — applicable broadly.
**Проблема:** What went wrong in this specific session.
**Причина:** Root cause — why the problem occurred.
**Превенция:** Concrete action to prevent recurrence in future sessions.
```

Process lessons are the **most valuable** harvest output. They improve the entire workflow, not just record what happened. Every session with failed attempts or user corrections should yield at least one.

#### For all other types (Priority 2-6)

```
### N. ACTION: title
**File:** proposed-filename.txt
**Priority:** Decisions / Lessons / Facts / Preferences / Docs
**What:** 1-2 sentence description of what will be saved
**Why:** Why this matters for future sessions
**Existing:** [if UPDATE] what's currently in LightRAG entry X
```

Group by priority: Process lessons first, then Decisions, then others. Within each group: NEW first, then UPDATE. Include a SKIP summary at the end showing what was considered but excluded, and why.

### Step 6: Wait for Approval

Say explicitly:

> Записывать все, или укажи номера? (например: 1, 3, 5-7)

Accepted formats:
- "все" / "all" / "да" → save all
- "1, 3, 5" → save only those numbers
- "1-5" → save range
- "все кроме 3" → save all except 3
- "нет" / "отмена" → save nothing

### Step 7: Save Approved Items

For each approved item, call MCP `insert_text` with:
- `text`: The knowledge entry, prefixed with `[YYYY-MM-DD]`
- `file_source`: The proposed filename from Step 5

Format rules for the text:

**For Process Lessons** (Priority 1) — use this structure:
```
[YYYY-MM-DD] Lesson: {title}. {Conceptual insight — reusable, not specific to one file}.
Problem: {what went wrong}. Cause: {root cause}.
Prevention: {concrete action to avoid recurrence}.
```
Each process lesson = 3-5 sentences covering all four parts. The prevention line is the most valuable — it's the actionable takeaway.

**For all other types** (Priority 2-6):
- 1-3 sentences maximum
- Include project name when applicable
- Include the reason/context ("because...", "to prevent...")

**Common rules:**
- Use absolute dates, not relative ("2026-04-10", not "today")
- No raw code, logs, or large data dumps
- `file_source` must match the `File:` field from Step 5

Report results: how many saved, any failures.

## What NOT to Propose

Never propose saving:
- **In session-harvest mode:** code patterns, file paths, or raw git history details — these are derivable from the current project state when someone looks.
- Debugging steps or fix recipes (the fix is in the code; the commit message has the context)
- Temporary state or in-progress work details
- Anything already in CLAUDE.md files
- Duplicate of an existing LightRAG entry that's still accurate
- Version numbers, specific UUIDs, secrets, ephemeral config values

**Nuance for code/git harvest modes:** when explicitly harvesting from code/docs or git log (see Source Selection), the "derivable from codebase" exclusion does NOT apply. The whole point is to lift *conceptual patterns* out of files into LightRAG, where they become available to future sessions without reading the repo. In these modes, propose:
- Self-documented patterns from `END_HEADER`/`INVENTORY` blocks and rules files (only the *reusable* abstraction, not project-specific function names)
- Repeating commit clusters as process lessons ("X bug class happened 4 times, root cause was Y")
- Architectural decisions visible only in code comments or commit message bodies

Still skip even in these modes: exact line numbers (rot fast), project-specific API names without the underlying pattern, raw diffs.

## Language

Match the user's language. If sessions are in Russian, propose entries in Russian or mixed (technical terms in English). If sessions are in English, use English.

## Edge Cases

- **No sessions found:** Report "No conversation history for this project" and suggest the user run from the correct project directory
- **Sessions too large (>500 user messages total):** Focus on the most recent 3 sessions. Note that older sessions were skipped
- **LightRAG unavailable:** Report the error and offer to output proposals as a markdown list instead, for manual insertion later
- **Mixed projects in sessions:** If sessions discuss multiple projects, only propose entries relevant to the current project (by PWD)
