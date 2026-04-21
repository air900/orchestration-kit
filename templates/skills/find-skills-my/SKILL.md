---
name: find-skills-my
description: >
  Deep skill discovery with analysis of skill content, overlap detection, and reasoned recommendations.
  Use when the user asks "find a skill for X", "how do I do X", "is there a skill that can...",
  or wants to extend agent capabilities. Do NOT use for creating new skills (use skill-creator).
  Renamed from `find-skills` to avoid collision with the upstream `vercel-labs/skills`
  package's `find-skills` skill, which has different (and simpler) behaviour.
---

# Find Skills — Deep Discovery (my version)

Find the right skill by actually reading what each candidate does, comparing it with what is already installed, and presenting a reasoned recommendation — not just a keyword match.

## Philosophy

A keyword search returns names. A deep search returns understanding. The difference:

| Keyword search | Deep search |
|---------------|-------------|
| "Found 5 results for react" | "3 candidates. One overlaps 80% with your installed skill. One is unmaintained. One fills the exact gap you described." |
| Lists names and install counts | Reads SKILL.md, analyzes fit, explains trade-offs |
| User guesses which to install | Agent recommends with reasoning |

## Process

### Phase 1: Understand the Need

Before searching, clarify what the user actually needs:

1. **Domain** — what technology/area? (React, testing, deployment, SEO...)
2. **Task** — what specific thing? (write tests, optimize performance, review PRs...)
3. **Gap** — what can't the agent do well without a skill? Why is a skill needed?

If the request is vague ("find me something useful"), ask one clarifying question. Do not search blindly.

### Phase 2: Inventory — What Is Already Installed

Run the inventory script to see what the user already has:

```bash
python3 .claude/skills/find-skills-my/scripts/inventory_local.py --cwd "$(pwd)"
```

This returns JSON with all locally installed skills: names, descriptions, paths, scope (global vs project).

**Why this matters:** If the user asks for "a PR review skill" and they already have `code-review` installed, you need to know that before recommending another one. Overlap detection prevents skill bloat.

Review the inventory and note:
- Skills in the same domain as the user's request
- Potential overlaps or gaps
- Whether the need might already be covered

### Phase 3: Discovery — Find Candidates

#### 3a: Search the ecosystem

Run the search with a focused query:

```bash
npx skills find [query]
```

Use specific keywords derived from Phase 1. If the first query returns poor results, try synonyms or broader/narrower terms. Run up to 3 different queries if needed.

#### 3b: Read each candidate's content

This is the critical step that makes the search "deep". For each promising result:

1. **Fetch the SKILL.md** from the skill's repository or skills.sh page using WebFetch
2. **Read the full content** — not just the description, but the body: what workflow it defines, what tools it uses, what patterns it follows
3. **Note key characteristics:**
   - What specific tasks does it handle?
   - What tools/MCP servers does it require?
   - Does it include scripts? References? Assets?
   - How opinionated is it? (rigid workflow vs flexible guidance)
   - How large is it? (token budget impact)

If you cannot fetch the SKILL.md (no direct link, private repo), note this as a risk factor — you're recommending something you haven't read.

### Phase 4: Analysis — Compare and Reason

Build a comparison for the user. For each candidate, assess:

#### Fit Score (how well it matches the need)

- **Direct match** — skill is designed exactly for this task
- **Partial match** — skill covers this task among others
- **Adjacent** — skill is in the same domain but different focus

#### Overlap with installed skills

- **No overlap** — fills a new gap
- **Complementary** — works alongside existing skill, different focus
- **Overlapping** — duplicates functionality of an installed skill
- **Supersedes** — does everything an installed skill does, plus more

#### Quality signals

- Install count (1K+ = established, <100 = experimental)
- Source reputation (known orgs vs unknown authors)
- Body quality (structured workflow vs vague advice)
- Has scripts (deterministic operations bundled = more reliable)
- Size (>500 lines = heavy context cost)

### Phase 5: Present Recommendations

Structure your response as a reasoned recommendation, not a search dump.

#### Format

```
## Skill Recommendations for [user's need]

### Already installed
[List relevant installed skills and what they cover/don't cover]

### Recommended: [skill-name]
**Why:** [1-2 sentences explaining why this is the best fit]
**What it does:** [Brief summary from reading the actual SKILL.md]
**Overlap:** [None / Complements X / Partially overlaps with Y]
**Quality:** [Install count, source, body quality assessment]

Install: `npx skills add <owner/repo@skill> -g -y`

### Also considered
- **[skill-2]** — [why it's second choice, e.g. "good but overlaps with your existing X"]
- **[skill-3]** — [why not recommended, e.g. "unmaintained, 12 installs, vague instructions"]
```

#### Rules for recommendations

1. **Never recommend a skill you haven't read.** If you couldn't fetch the SKILL.md, say so explicitly.
2. **Always check overlap.** If an installed skill already covers 80%+ of the need, say "you already have this" instead of recommending a new one.
3. **Explain the trade-off.** If recommending installation, explain what the user gains vs the cost (extra context, potential conflicts).
4. **Cap at 3 candidates.** More than 3 creates decision paralysis. Pick the best, mention alternatives briefly.
5. **Be honest about uncertainty.** "I couldn't verify the quality" is better than a confident bad recommendation.

## When Nothing Fits

If no good skill exists:

1. Explain what you searched and why nothing matched
2. Check if the need can be met by combining existing installed skills
3. Offer to help directly with the task
4. If the task is recurring, suggest creating a custom skill: `npx skills init my-skill`

## Common Mistakes

- **Recommending by name alone.** "react-best-practices" sounds good but might be a 10-line file with generic advice. Read it first.
- **Ignoring installed skills.** The user already has 10 skills — adding #11 that overlaps with #3 creates confusion.
- **Over-searching.** If the user's need is clear and one skill is an obvious fit, don't pad the response with weak alternatives.
- **Recommending heavy skills for light tasks.** A 500-line workflow skill for a one-time task is overkill. Sometimes "I can just do this for you" is the right answer.
