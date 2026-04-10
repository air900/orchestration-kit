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

Scan conversation history for the current project, compare with what LightRAG already knows, and propose additions/updates. Never save without explicit user approval.

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
- Code patterns or file paths (derivable from codebase)
- Git history or commit details (use `git log`)
- Debugging steps or fix recipes (the fix is in the code)
- Temporary state or in-progress work details
- Anything already in CLAUDE.md files
- Duplicate of an existing LightRAG entry that's still accurate

## Language

Match the user's language. If sessions are in Russian, propose entries in Russian or mixed (technical terms in English). If sessions are in English, use English.

## Edge Cases

- **No sessions found:** Report "No conversation history for this project" and suggest the user run from the correct project directory
- **Sessions too large (>500 user messages total):** Focus on the most recent 3 sessions. Note that older sessions were skipped
- **LightRAG unavailable:** Report the error and offer to output proposals as a markdown list instead, for manual insertion later
- **Mixed projects in sessions:** If sessions discuss multiple projects, only propose entries relevant to the current project (by PWD)
