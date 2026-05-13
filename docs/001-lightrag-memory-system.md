# LightRAG Memory System (parked)

> **Status:** parked / not in active use. System underperformed in practice. Kept here as reference in case re-adoption is reconsidered.
> **Date moved out of global `CLAUDE.md`:** 2026-05-13.

## Contents

- [Mandatory First Action — LightRAG Knowledge Base](#mandatory-first-action--lightrag-knowledge-base)
- [LightRAG — Ongoing Memory](#lightrag--ongoing-memory)
- [LightRAG Auto-Capture](#lightrag-auto-capture)

## Mandatory First Action — LightRAG Knowledge Base

**BEFORE anything else — before file reads, before answer, before think — MUST search LightRAG.**

NON-NEGOTIABLE. Every session starts with:

1. Take user first message
2. Call MCP tool `query_text` with mode `hybrid` + relevant query
3. Use returned context to inform response
4. Do NOT mention search to user — use context silently

**Skip this step → response lacks critical context on user, projects, preferences, history. WILL give wrong/generic answers.**

## LightRAG — Ongoing Memory

LightRAG = shared knowledge base across ALL sessions + agents. Know who user is, what they work on, what they prefer.

### During work

Significant decision, preference, bug fix, or project fact emerges → save IMMEDIATELY via MCP `insert_text`. No wait. No permission ask.

**Memory Pyramid decides WHAT to save + priority:**

1. **Decisions & reasons** (highest priority) — why X chosen, why Y rejected, trade-offs + arguments. Most valuable — decision context unrecoverable from code.
2. **Project facts** (high) — tech stack, architecture, tasks in progress.
3. **Preferences** (medium) — user preferred tech, approaches, constraints.
4. **Documentation** (basic) — key takeaways from READMEs, APIs, guides — only if unique.

**NEVER save:** raw code, logs, DB dumps, drafts, intermediate debugging, typos, duplicates, temporary values.

**Rule:** analyze each piece via pyramid. Break by levels, save what found. Not every material has all levels — save what's there.

**Format:** 1-3 sentences. Include project name + reason when applicable.

**CRITICAL — always pass `file_source`:** MCP tool `insert_text` hardcodes `text_input.txt` as default. LightRAG API dedupes by file_source → all later inserts fail with "duplicated". ALWAYS pass unique `file_source` in format `{topic-slug}-{YYYYMMDD}.txt`.

Example: `insert_text(text="...", file_source="beads-workflow-20260414.txt")`

### Explicit commands

- **"remember/запомни/запиши <text>"** → save to LightRAG via `insert_text`
- **"recall/вспомни/найди в базе знаний <topic>"** → search LightRAG via `query_text` (hybrid), share results

## LightRAG Auto-Capture

User says "save everything here" / "записывай всё" (or similar):
1. Insert every user message into LightRAG via `insert_text`
2. Format: "[YYYY-MM-DD] Author: full message text"
3. Include quoted/forwarded context if present
4. Do NOT insert own replies or system messages

Deactivate: user says "stop recording" or similar.
