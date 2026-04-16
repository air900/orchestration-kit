# v1 → v2 Migration of 7 Projects — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate 7 portfolio projects from Orchestration Kit v1 (pipeline, 11 agents) to v2 (lightweight, 7 agents + Superpowers/Beads), preserving 100% of custom artefacts.

**Architecture:** Manual, sequential, per-project migration with user checkpoint after each. No new batch scripts — explicit `rm`/`cp` for delete; existing `orchestration-kit/deploy.sh` for install. Preservation guaranteed by whitelist-by-absence (kit only knows its own names).

**Tech Stack:** Bash, `jq` (JSON-surgery on settings.json), `git` (rollback points), `deploy.sh` (kit's own deploy tool), harness TaskList (progress tracking), `bd` CLI (Beads init).

**Spec:** `docs/superpowers/specs/2026-04-16-v1-to-v2-migration-7-projects-design.md`

---

## Task 0: Prerequisites verification (one-time, before any migration)

**Files:**
- Read: `/root/projects/orchestration-kit/templates/` (verify kit assets)
- Verify: `bd`, `jq`, `git` CLIs on PATH
- Verify: claude plugins (`superpowers`, `beads`, `template-bridge`)

- [ ] **Step 0.1: Verify kit templates are intact**

```bash
cd /root/projects/orchestration-kit
ls templates/agents/ | sort
ls templates/skills/ | sort
ls templates/hooks/
ls templates/references/
test -f templates/settings-hooks.json && echo "OK settings-hooks.json"
test -f templates/claude-gitignore && echo "OK claude-gitignore"
test -f SKILL.md && echo "OK deploy-orchestration SKILL.md"
```

Expected output (trimmed):
```
doc-keeper.md  documenter.md  observer.md  planner.md  refactor.md  security-auditor.md  senior-reviewer.md
012-update-docs  arch-review  find-skills  knowledge-harvest  refactor-code  security-audit  sync-skills  workflow-gate
log-commands.sh  .gitignore
... 4 .md files ...
OK settings-hooks.json
OK claude-gitignore
OK deploy-orchestration SKILL.md
```

If any check fails — STOP. Kit is broken, needs repair before migration.

- [ ] **Step 0.2: Verify required CLIs**

```bash
command -v bd && bd --version
command -v jq && jq --version
command -v git && git --version
command -v claude && claude plugin list 2>&1 | grep -E "superpowers|beads|template-bridge"
```

Expected: all 3 CLIs respond with version; 3 plugins listed as installed.

If `bd` missing: `npm install -g @beads/bd` and re-check.
If plugins missing: installation commands per `deploy.sh` lines 82-127.

- [ ] **Step 0.3: Create TaskList with 7 migration tasks**

Using harness `TaskCreate`, add 7 tasks in this order:
1. Migrate mtproxy-telegram
2. Migrate check-parameters-sql-server-for-1c
3. Migrate frm-client-automatization
4. Migrate vpn-manager-openwrt-x-ui
5. Migrate hr-bot-project
6. Migrate text4site-create-modified
7. Migrate seo-audit

All start as `pending`.

---

## Task 1: Migrate `mtproxy-telegram` (risk: 🟢 low)

**Files:**
- Project root: `/root/projects/mtproxy-telegram`
- Delete: `.claude/agents/{worker,test-runner,reviewer,debugger}.md`
- Delete: `.claude/skills/{orchestrate,implement,code-review}/`
- Modify: `.claude/settings.json` (remove `.hooks.SubagentStop`)
- Overwrite: `.claude/agents/*.md` (7 files), `.claude/skills/*/` (8 dirs)
- Create: `.claude/hooks/log-commands.sh`, `.claude/.gitignore`, `.beads/`
- Modify: `CLAUDE.md` ("## Claude Automations" section)

### Phase 0: Pre-flight

- [ ] **Step 1.0.1: Mark task in_progress + enter project**

Update TaskList: task "Migrate mtproxy-telegram" → `in_progress`.

```bash
cd /root/projects/mtproxy-telegram
pwd && git status
```

Expected: `pwd` returns project path; `git status` shows clean tree OR uncommitted changes list.

- [ ] **Step 1.0.2: Create pre-migration rollback commit (only if uncommitted work exists)**

If `git status` showed uncommitted changes:

```bash
git add -A
git commit -m "pre-migration snapshot before v1→v2 orchestration update"
git log --oneline -1
```

If clean tree: skip — HEAD itself is the rollback point.

- [ ] **Step 1.0.3: Inventory current state**

```bash
echo "=== Agents ==="
ls .claude/agents/ 2>/dev/null | sort
echo "=== Skills ==="
ls -d .claude/skills/*/ 2>/dev/null | xargs -n1 basename | sort
echo "=== SubagentStop hooks ==="
jq '.hooks.SubagentStop // "none"' .claude/settings.json 2>/dev/null | head -5
echo "=== docs/orchestration tree file count ==="
find docs/orchestration -type f 2>/dev/null | wc -l
echo "=== Custom skills (not in kit) ==="
KIT_SKILLS="orchestrate implement code-review 012-update-docs arch-review refactor-code security-audit workflow-gate sync-skills knowledge-harvest find-skills deploy-orchestration"
for skill in $(ls -d .claude/skills/*/ 2>/dev/null | xargs -n1 basename); do
  if ! echo " $KIT_SKILLS " | grep -q " $skill "; then
    echo "  CUSTOM: $skill"
  fi
done
echo "=== Custom agents (not in kit) ==="
KIT_AGENTS="worker test-runner reviewer debugger planner security-auditor documenter doc-keeper observer senior-reviewer refactor"
for agent in $(ls .claude/agents/ 2>/dev/null | sed 's/\.md$//'); do
  if ! echo " $KIT_AGENTS " | grep -q " $agent "; then
    echo "  CUSTOM: $agent"
  fi
done
```

Expected: 11 agents (4 v1 + 7 v2-retained), 12 skills (3 v1 + 8 retained-or-new + ~1 custom), SubagentStop has 9 matchers, docs/orchestration has N files.

Present inventory to user. **Wait for "ok" before any deletion.**

### Phase 1: Delete v1 artefacts

- [ ] **Step 1.1.1: Delete 4 v1 agent files**

```bash
rm -v -f .claude/agents/worker.md \
         .claude/agents/test-runner.md \
         .claude/agents/reviewer.md \
         .claude/agents/debugger.md
```

Expected: 4 `removed` lines OR silent success if already absent.

- [ ] **Step 1.1.2: Delete 3 v1 skill directories**

```bash
rm -rv .claude/skills/orchestrate .claude/skills/implement .claude/skills/code-review 2>/dev/null || true
```

Expected: recursive-removed listings for existing dirs; no error if absent.

- [ ] **Step 1.1.3: Remove `SubagentStop` block from settings.json**

```bash
jq 'del(.hooks.SubagentStop)' .claude/settings.json > .claude/settings.json.tmp \
  && mv .claude/settings.json.tmp .claude/settings.json \
  && jq '.hooks | keys' .claude/settings.json
```

Expected: final output shows keys WITHOUT `SubagentStop` (e.g., `["PostToolUse", "PreToolUse"]`).

### Phase 2: Install v2 via deploy.sh

- [ ] **Step 1.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/mtproxy-telegram atomic
```

Expected: `[OK]` lines for: Directories created, Copied 7 agents, Copied 8 skills, Copied N reference docs, Installed N hook scripts, Created .claude/.gitignore (or appended), Copied deploy-orchestration skill, Merged into existing settings.json, Beads initialised. No `[ERROR]` lines.

- [ ] **Step 1.2.2: Sanity-check post-install structure**

```bash
cd /root/projects/mtproxy-telegram
ls .claude/agents/ | sort
ls -d .claude/skills/*/ | xargs -n1 basename | sort
ls -la .claude/hooks/log-commands.sh
test -f .claude/.gitignore && grep -q "command-log.txt" .claude/.gitignore && echo "gitignore OK"
test -d .beads && echo "Beads OK"
```

Expected: 7 kit agents + any custom; 8 kit skills + any custom (v1 `orchestrate/implement/code-review` gone); `log-commands.sh` executable; gitignore contains `command-log.txt`; `.beads/` exists.

### Phase 3: CLAUDE.md surgery

- [ ] **Step 1.3.1: Locate Claude Automations section**

```bash
grep -n "^## " CLAUDE.md
```

Expected: numbered headings. Identify the section name for AI automations (typically "## Claude Automations", may be "## Orchestration" / "## AI Agents" / "## Automations" in v1).

- [ ] **Step 1.3.2: Show old section content and propose replacement**

Read the section content (from identified heading to next `## ` or EOF). Present to user:
- Old content (verbatim)
- Proposed replacement (from `orchestration-kit/SKILL.md`, the "deploy-orchestration" skill's Claude Automations block)

**Wait for user approval of the replacement block.**

- [ ] **Step 1.3.3: Apply replacement via Edit tool**

Use `Edit` tool with exact `old_string` = full old section content, `new_string` = approved replacement. Verify via:

```bash
grep -c "Superpowers" CLAUDE.md && grep -c "Beads\|bd ready" CLAUDE.md
```

Expected: both counts > 0.

### Phase 4: Verification (7 checks)

- [ ] **Step 1.4.1: Run all 7 verification checks**

```bash
cd /root/projects/mtproxy-telegram

# Check 1: agents — 7 kit + custom, no v1
echo "=== Check 1: agents ==="
ls .claude/agents/ | sort
grep -q "worker.md\|test-runner.md\|reviewer.md\|debugger.md" <(ls .claude/agents/) \
  && echo "FAIL: v1 agents still present" || echo "PASS: no v1 agents"

# Check 2: no SubagentStop
echo "=== Check 2: SubagentStop ==="
jq '.hooks | has("SubagentStop")' .claude/settings.json \
  | grep -q "false" && echo "PASS: no SubagentStop" || echo "FAIL"

# Check 3: no v1 skill references
echo "=== Check 3: v1 skill references ==="
HITS=$(grep -rl "/orchestrate\b\|/implement\b\|/code-review\b" .claude/ CLAUDE.md 2>/dev/null | grep -v "deploy-orchestration" | wc -l)
[ "$HITS" = "0" ] && echo "PASS: no dangling refs" || { echo "FAIL: $HITS files with refs"; grep -rl "/orchestrate\|/implement\|/code-review" .claude/ CLAUDE.md | grep -v "deploy-orchestration"; }

# Check 4: CLAUDE.md mentions Superpowers + Beads
echo "=== Check 4: CLAUDE.md references ==="
grep -q "Superpowers" CLAUDE.md && echo "PASS: Superpowers ref" || echo "FAIL: no Superpowers ref"
grep -q "Beads\|bd ready\|bd create" CLAUDE.md && echo "PASS: Beads ref" || echo "FAIL: no Beads ref"

# Check 5: Beads initialized
echo "=== Check 5: Beads ==="
test -d .beads && echo "PASS: .beads/ exists" || echo "FAIL"

# Check 6: docs/orchestration intact
echo "=== Check 6: docs/orchestration ==="
if [ -d docs/orchestration ]; then
  find docs/orchestration -type f | wc -l
  echo "Compare with Phase 0 inventory count"
else
  echo "SKIP: no docs/orchestration dir in this project"
fi

# Check 7: audit-log hook live test
echo "=== Check 7: audit-log hook ==="
test -x .claude/hooks/log-commands.sh && echo "PASS: hook executable" || echo "FAIL: not executable"
echo '{"tool_input":{"command":"migration-verify-test"}}' \
  | CLAUDE_PROJECT_DIR=$(pwd) .claude/hooks/log-commands.sh
tail -1 .claude/command-log.txt | grep -q "migration-verify-test" \
  && echo "PASS: hook writes to log" || echo "FAIL: log write failed"
```

Expected: all 7 `PASS`, zero `FAIL`.

If any FAIL: record in phase-5 report, do NOT proceed to next task. Discuss with user.

### Phase 5: Checkpoint report

- [ ] **Step 1.5.1: Prepare diff summary**

```bash
cd /root/projects/mtproxy-telegram
git status
git diff --stat
```

- [ ] **Step 1.5.2: List custom artefacts preserved**

```bash
echo "=== Custom skills preserved ==="
KIT_SKILLS="012-update-docs arch-review refactor-code security-audit workflow-gate sync-skills knowledge-harvest find-skills deploy-orchestration"
for skill in $(ls -d .claude/skills/*/ 2>/dev/null | xargs -n1 basename); do
  echo " $KIT_SKILLS " | grep -q " $skill " || echo "  $skill"
done
echo "=== Custom agents preserved ==="
KIT_AGENTS="planner security-auditor documenter doc-keeper observer senior-reviewer refactor"
for agent in $(ls .claude/agents/ 2>/dev/null | sed 's/\.md$//'); do
  echo " $KIT_AGENTS " | grep -q " $agent " || echo "  $agent"
done
```

- [ ] **Step 1.5.3: Present Phase 5 report to user**

Show: 7-check results, git diff stat, custom preservation list.

**Wait for user "ok" before Task 2.**

- [ ] **Step 1.5.4: Commit migration to project's git**

```bash
cd /root/projects/mtproxy-telegram
git add -A
git commit -m "$(cat <<'EOF'
chore(orchestration): migrate from Kit v1 to v2

Remove v1 pipeline agents (worker/test-runner/reviewer/debugger)
and skills (orchestrate/implement/code-review); drop SubagentStop
hooks. Install v2 lightweight orchestration: 7 specialist agents,
8 kit skills (including workflow-gate, knowledge-harvest, find-skills),
audit-log Bash hook, Beads init, references/.

Custom skills and agents preserved unchanged.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 1.5.5: Mark task completed**

Update TaskList: task "Migrate mtproxy-telegram" → `completed`.

---

## Task 2: Migrate `check-parameters-sql-server-for-1c` (risk: 🟢 low)

**Files:**
- Project root: `/root/projects/check-parameters-sql-server-for-1c`
- All other files/paths identical to Task 1, substituting project path.

### Phase 0: Pre-flight

- [ ] **Step 2.0.1: Mark task in_progress + enter project**

Update TaskList: task "Migrate check-parameters-sql-server-for-1c" → `in_progress`.

```bash
cd /root/projects/check-parameters-sql-server-for-1c
pwd && git status
```

- [ ] **Step 2.0.2: Pre-migration rollback commit if needed**

If `git status` showed uncommitted:
```bash
git add -A && git commit -m "pre-migration snapshot before v1→v2 orchestration update"
```
Otherwise skip.

- [ ] **Step 2.0.3: Inventory (same script as Task 1)**

Run the full inventory script from Step 1.0.3 (substituting project path where needed — the script uses relative `.claude/` so works from CWD). Present to user. **Wait for "ok".**

### Phase 1: Delete v1 artefacts

- [ ] **Step 2.1.1: Delete 4 v1 agent files**

```bash
rm -v -f .claude/agents/worker.md .claude/agents/test-runner.md \
         .claude/agents/reviewer.md .claude/agents/debugger.md
```

- [ ] **Step 2.1.2: Delete 3 v1 skill dirs**

```bash
rm -rv .claude/skills/orchestrate .claude/skills/implement .claude/skills/code-review 2>/dev/null || true
```

- [ ] **Step 2.1.3: Remove SubagentStop**

```bash
jq 'del(.hooks.SubagentStop)' .claude/settings.json > .claude/settings.json.tmp \
  && mv .claude/settings.json.tmp .claude/settings.json
```

### Phase 2: Install v2

- [ ] **Step 2.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/check-parameters-sql-server-for-1c atomic
```

- [ ] **Step 2.2.2: Sanity-check (same as Step 1.2.2, from project dir)**

### Phase 3: CLAUDE.md surgery

- [ ] **Step 2.3.1: Locate + show + edit (same procedure as Task 1 Phase 3)**

### Phase 4: Verification

- [ ] **Step 2.4.1: Run 7 checks (identical script from Step 1.4.1)**

### Phase 5: Checkpoint + commit

- [ ] **Step 2.5.1: Diff summary + custom preservation list + user checkpoint (same as Task 1 Phase 5)**
- [ ] **Step 2.5.2: Commit with same template message**
- [ ] **Step 2.5.3: Mark task completed**

---

## Task 3: Migrate `frm-client-automatization` (risk: 🟢 low)

**Files:**
- Project root: `/root/projects/frm-client-automatization`

Identical procedure to Task 2, with these substitutions only:
- CWD path: `/root/projects/frm-client-automatization`
- TaskList name: "Migrate frm-client-automatization"

- [ ] **Step 3.0.1: Mark in_progress + `cd /root/projects/frm-client-automatization && git status`**
- [ ] **Step 3.0.2: Pre-migration commit if uncommitted**
- [ ] **Step 3.0.3: Inventory (script from Step 1.0.3) + user ok**
- [ ] **Step 3.1.1: `rm -v -f .claude/agents/{worker,test-runner,reviewer,debugger}.md`**
- [ ] **Step 3.1.2: `rm -rv .claude/skills/{orchestrate,implement,code-review} 2>/dev/null || true`**
- [ ] **Step 3.1.3: `jq 'del(.hooks.SubagentStop)' .claude/settings.json > .tmp && mv .tmp .claude/settings.json`**
- [ ] **Step 3.2.1: `cd /root/projects/orchestration-kit && ./deploy.sh /root/projects/frm-client-automatization atomic`**
- [ ] **Step 3.2.2: Sanity check (Step 1.2.2 script)**
- [ ] **Step 3.3.1: CLAUDE.md surgery (Phase 3 procedure)**
- [ ] **Step 3.4.1: 7 verification checks (Step 1.4.1 script)**
- [ ] **Step 3.5.1: Checkpoint report + user ok**
- [ ] **Step 3.5.2: Commit + mark completed**

---

## Task 4: Migrate `vpn-manager-openwrt-x-ui` (risk: 🟡 medium — unusual state)

**Files:**
- Project root: `/root/projects/vpn-manager-openwrt-x-ui`

**Special note:** this project has unusual state — 10 agents, 0 skills. The inventory in Phase 0 may reveal non-standard agent names. Check carefully before deleting.

- [ ] **Step 4.0.1: Mark in_progress + cd**

```bash
cd /root/projects/vpn-manager-openwrt-x-ui
pwd && git status
```

- [ ] **Step 4.0.2: Pre-migration commit if uncommitted**

- [ ] **Step 4.0.3: Inventory with extra scrutiny**

Run the full Step 1.0.3 inventory script. Additionally:

```bash
echo "=== All agent filenames (full) ==="
ls -la .claude/agents/
echo "=== Check for any non-standard agent ==="
for agent in $(ls .claude/agents/ 2>/dev/null); do
  echo "  $agent"
done
```

**Present inventory to user. If inventory shows agents NOT in the 11-agent v1 canonical set (worker, test-runner, reviewer, debugger, planner, security-auditor, documenter, doc-keeper, observer, senior-reviewer, refactor), STOP and discuss. The `rm -v -f` for 4 v1 names is still safe (targeted by name), but the 10/0 state suggests something unusual may need custom handling.**

- [ ] **Step 4.1.1: Delete 4 v1 agent files (only if present — `rm -f` is safe either way)**

```bash
rm -v -f .claude/agents/{worker,test-runner,reviewer,debugger}.md
```

- [ ] **Step 4.1.2: Skip skill deletion (0 skills — nothing to delete)**

Confirm:
```bash
ls -d .claude/skills/*/ 2>/dev/null | wc -l
```
Expected: 0. If >0 — run Step 1.1.2 to delete any accidental v1 residue.

- [ ] **Step 4.1.3: Remove SubagentStop if present**

```bash
jq 'has("hooks") and (.hooks | has("SubagentStop"))' .claude/settings.json 2>/dev/null
```

If `true`: run Step 1.1.3 jq command. If `false` or file absent: skip.

- [ ] **Step 4.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/vpn-manager-openwrt-x-ui atomic
```

- [ ] **Step 4.2.2: Sanity check (Step 1.2.2 script)**

- [ ] **Step 4.3.1: CLAUDE.md surgery (Phase 3 procedure)**

If no "## Claude Automations" section exists (this project may predate the convention): add a new section at the end of CLAUDE.md with the v2 template content. Present proposal to user before Edit.

- [ ] **Step 4.4.1: 7 verification checks (Step 1.4.1 script; check 6 will SKIP due to no docs/orchestration/)**

- [ ] **Step 4.5.1: Checkpoint + user ok**
- [ ] **Step 4.5.2: Commit + mark completed**

---

## Task 5: Migrate `hr-bot-project` (risk: 🟡 medium — production)

**Files:**
- Project root: `/root/projects/hr-bot-project`

**Special note:** Production project deployed to vsem-onboard.ru. Extra care with CLAUDE.md — it contains deployment-specific content (SSH hosts, PM2 ecosystem, Nginx configs) that MUST NOT be touched. Only the automation section changes.

- [ ] **Step 5.0.1: Mark in_progress + cd + status**

```bash
cd /root/projects/hr-bot-project
pwd && git status && git log --oneline -1
```

- [ ] **Step 5.0.2: Pre-migration commit if uncommitted**

- [ ] **Step 5.0.3: Inventory + user ok (Step 1.0.3 script)**

- [ ] **Step 5.1.1: Delete 4 v1 agents (Step 1.1.1 command)**
- [ ] **Step 5.1.2: Delete 3 v1 skill dirs (Step 1.1.2 command)**
- [ ] **Step 5.1.3: Remove SubagentStop (Step 1.1.3 command)**

- [ ] **Step 5.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/hr-bot-project atomic
```

- [ ] **Step 5.2.2: Sanity check (Step 1.2.2 script)**

- [ ] **Step 5.3.1: CLAUDE.md surgery — CAREFUL**

Before Edit, take extra inventory:
```bash
cd /root/projects/hr-bot-project
wc -l CLAUDE.md
grep -n "^## " CLAUDE.md
grep -n "vsem-onboard\|PM2\|ssh\|nginx\|deploy" CLAUDE.md | head -20
```

Show user:
- Full list of section headings
- Location of deployment-specific content (which must NOT be in the Automations section)
- Boundaries of the "## Claude Automations" section

Only after user confirms the boundary is correct — apply Edit.

- [ ] **Step 5.4.1: 7 verification checks (Step 1.4.1 script)**

Plus: verify deployment-specific content is untouched:
```bash
grep -c "vsem-onboard\|PM2\|ssh" CLAUDE.md
```
Compare with pre-migration count from Step 5.0.3. MUST be equal.

- [ ] **Step 5.5.1: Checkpoint + user ok (with visual diff of CLAUDE.md)**
- [ ] **Step 5.5.2: Commit + mark completed**

---

## Task 6: Migrate `text4site-create-modified` (risk: 🔴 high — ~13 custom skills)

**Files:**
- Project root: `/root/projects/text4site-create-modified`

**Special note:** This project has 21 skills total. Expected custom skills include `avers010-cluster-planner`, `avers020-article-writer`, `avers030-fact-checker`, `afr010-cluster-planner`, `afr020-article-writer`, and others in the 6-circles-content-strategy domain. ALL must be preserved.

- [ ] **Step 6.0.1: Mark in_progress + cd + status**

```bash
cd /root/projects/text4site-create-modified
pwd && git status
```

- [ ] **Step 6.0.2: Pre-migration commit if uncommitted**

- [ ] **Step 6.0.3: Enhanced inventory with full custom skill enumeration**

Run Step 1.0.3 script, PLUS:

```bash
echo "=== Full skill tree (names + SKILL.md presence) ==="
for d in .claude/skills/*/; do
  name=$(basename "$d")
  has_skill_md=$([ -f "$d/SKILL.md" ] && echo "Y" || echo "-")
  echo "  [$has_skill_md] $name"
done
echo "=== Custom skill directory sizes (MB) ==="
du -sh .claude/skills/*/ 2>/dev/null | sort -h | tail -10
```

Present inventory to user. **Explicitly highlight the custom skill list. Wait for user confirmation that all expected custom skills are present in the "will preserve" list.**

- [ ] **Step 6.1.1: Delete 4 v1 agents (Step 1.1.1)**
- [ ] **Step 6.1.2: Delete 3 v1 skill dirs (Step 1.1.2) — this affects ONLY `orchestrate/`, `implement/`, `code-review/`; custom skills are untouched by name**
- [ ] **Step 6.1.3: Remove SubagentStop (Step 1.1.3)**

- [ ] **Step 6.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/text4site-create-modified atomic
```

- [ ] **Step 6.2.2: Sanity check — verify custom skill count preserved**

```bash
cd /root/projects/text4site-create-modified
ALL_SKILLS=$(ls -d .claude/skills/*/ | wc -l)
KIT_SKILLS_PRESENT=$(ls -d .claude/skills/{012-update-docs,arch-review,find-skills,knowledge-harvest,refactor-code,security-audit,sync-skills,workflow-gate,deploy-orchestration}/ 2>/dev/null | wc -l)
CUSTOM_COUNT=$((ALL_SKILLS - KIT_SKILLS_PRESENT))
echo "Total skills: $ALL_SKILLS (expected 9 kit + ~13 custom = ~22)"
echo "Kit skills: $KIT_SKILLS_PRESENT (expected 9)"
echo "Custom skills: $CUSTOM_COUNT (expected ~13)"
echo "--- Custom skill names ---"
for d in .claude/skills/*/; do
  name=$(basename "$d")
  case "$name" in
    012-update-docs|arch-review|find-skills|knowledge-harvest|refactor-code|security-audit|sync-skills|workflow-gate|deploy-orchestration) ;;
    *) echo "  $name" ;;
  esac
done
```

Compare custom list to Phase 0 inventory — must be IDENTICAL. If any custom skill lost — STOP, rollback via `git reset --hard HEAD~1`, investigate.

- [ ] **Step 6.3.1: CLAUDE.md surgery (Phase 3 procedure)**

- [ ] **Step 6.4.1: 7 verification checks (Step 1.4.1 script)**

- [ ] **Step 6.5.1: Checkpoint + user ok — explicit confirmation of custom skill preservation**
- [ ] **Step 6.5.2: Commit + mark completed**

---

## Task 7: Migrate `seo-audit` (risk: 🔴 high — ~26 custom skills, max custom)

**Files:**
- Project root: `/root/projects/seo-audit`

**Special note:** Highest-stakes migration. This project has 34 skills total, most in the `searchfit-seo:*` family (seo-audit, keyword-clustering, internal-linking, on-page-seo, content-brief, content-translation, ai-visibility, schema-markup, broken-links, technical-seo, content-strategy, create-topic, create-content, etc.). 100% must be preserved.

- [ ] **Step 7.0.1: Mark in_progress + cd + status**

```bash
cd /root/projects/seo-audit
pwd && git status
```

- [ ] **Step 7.0.2: Pre-migration commit if uncommitted**

- [ ] **Step 7.0.3: Enhanced inventory with explicit custom enumeration**

```bash
cd /root/projects/seo-audit
echo "=== ALL skills (expected: 34) ==="
ls -d .claude/skills/*/ | xargs -n1 basename | sort
echo ""
echo "=== Expected to DELETE (v1): orchestrate, implement, code-review ==="
for name in orchestrate implement code-review; do
  test -d ".claude/skills/$name" && echo "  WILL DELETE: $name" || echo "  (already absent: $name)"
done
echo ""
echo "=== Expected to OVERWRITE (v2 kit): 012-update-docs, arch-review, ... ==="
for name in 012-update-docs arch-review find-skills knowledge-harvest refactor-code security-audit sync-skills workflow-gate deploy-orchestration; do
  test -d ".claude/skills/$name" && echo "  WILL OVERWRITE: $name" || echo "  (will be created: $name)"
done
echo ""
echo "=== Expected to PRESERVE (all else) ==="
for d in .claude/skills/*/; do
  name=$(basename "$d")
  case "$name" in
    orchestrate|implement|code-review|012-update-docs|arch-review|find-skills|knowledge-harvest|refactor-code|security-audit|sync-skills|workflow-gate|deploy-orchestration) ;;
    *) echo "  PRESERVE: $name" ;;
  esac
done | sort
echo ""
echo "Count of PRESERVE list should be ~25 for seo-audit"

# Save baseline for post-migration diff check (Step 7.2.2 consumes this)
for d in .claude/skills/*/; do
  name=$(basename "$d")
  case "$name" in
    orchestrate|implement|code-review|012-update-docs|arch-review|find-skills|knowledge-harvest|refactor-code|security-audit|sync-skills|workflow-gate|deploy-orchestration) ;;
    *) echo "$name" ;;
  esac
done | sort > /tmp/seo-audit-pre-preserve.txt
echo "=== Baseline saved to /tmp/seo-audit-pre-preserve.txt ($(wc -l < /tmp/seo-audit-pre-preserve.txt) entries) ==="
```

Present full inventory. **Explicitly wait for user to confirm the PRESERVE list looks correct.** If any of the listed `PRESERVE` items is actually stale / should be removed — user flags now, I add to deletion list.

- [ ] **Step 7.1.1: Delete 4 v1 agents (Step 1.1.1)**
- [ ] **Step 7.1.2: Delete 3 v1 skill dirs (Step 1.1.2)**
- [ ] **Step 7.1.3: Remove SubagentStop (Step 1.1.3)**

- [ ] **Step 7.2.1: Run deploy.sh**

```bash
cd /root/projects/orchestration-kit
./deploy.sh /root/projects/seo-audit atomic
```

- [ ] **Step 7.2.2: Rigorous custom skill preservation check**

```bash
cd /root/projects/seo-audit
# Exact same enumeration as Step 7.0.3 "PRESERVE" list
echo "=== Post-migration PRESERVE list ==="
for d in .claude/skills/*/; do
  name=$(basename "$d")
  case "$name" in
    orchestrate|implement|code-review|012-update-docs|arch-review|find-skills|knowledge-harvest|refactor-code|security-audit|sync-skills|workflow-gate|deploy-orchestration) ;;
    *) echo "  $name" ;;
  esac
done | sort > /tmp/seo-audit-post-preserve.txt
wc -l /tmp/seo-audit-post-preserve.txt
cat /tmp/seo-audit-post-preserve.txt
```

Compare this list LINE-BY-LINE with the Phase 7.0.3 PRESERVE list (keep a copy in `/tmp/seo-audit-pre-preserve.txt` written during Phase 0). Must be identical.

```bash
diff /tmp/seo-audit-pre-preserve.txt /tmp/seo-audit-post-preserve.txt && echo "PASS: custom skills identical" || { echo "FAIL: custom drift!"; exit 1; }
```

If FAIL — immediate rollback: `git reset --hard HEAD~1` and stop.

- [ ] **Step 7.3.1: CLAUDE.md surgery (Phase 3 procedure)**

- [ ] **Step 7.4.1: 7 verification checks (Step 1.4.1 script)**

- [ ] **Step 7.5.1: Checkpoint + user ok with explicit custom preservation confirmation**
- [ ] **Step 7.5.2: Commit + mark completed**

---

## Task 8: Post-migration documentation updates

**Files:**
- Modify: `/root/projects/orchestration-kit/migration-plan.md` (status table)
- Modify: `/root/projects/orchestration-kit/analysis-habr-3000hours.md` (§8 status table)

### Phase 8.1: Update migration-plan.md

- [ ] **Step 8.1.1: Update status table with all 7 Done entries**

Use `Edit` tool to replace the status table at end of `migration-plan.md`. Before:
```
| web-scripts | ✅ Готово | 2026-04-12 | 10 external skills, 39 doc-drafts |
| hr-bot | ⬜ Pending | — | |
| seo-audit | ⬜ Pending | — | |
| frm-client-automatization | ⬜ Pending | — | |
| check-parameters-sql-server | ⬜ Pending | — | |
| mtproxy-telegram | ⬜ Pending | — | |
```

After:
```
| web-scripts | ✅ Готово | 2026-04-12 | 10 external skills, 39 doc-drafts |
| mtproxy-telegram | ✅ Готово | 2026-04-16 | — |
| check-parameters-sql-server-for-1c | ✅ Готово | 2026-04-16 | — |
| frm-client-automatization | ✅ Готово | 2026-04-16 | — |
| vpn-manager-openwrt-x-ui | ✅ Готово | 2026-04-16 | Originally 10/0 state |
| hr-bot-project | ✅ Готово | 2026-04-16 | Production — особое внимание к CLAUDE.md |
| text4site-create-modified | ✅ Готово | 2026-04-16 | ~13 custom skills preserved |
| seo-audit | ✅ Готово | 2026-04-16 | ~26 custom skills preserved (searchfit-seo family) |
```

Fill in the "—" notes column with actual surprises encountered during each migration.

### Phase 8.2: Update analysis-habr-3000hours.md

- [ ] **Step 8.2.1: Update §8 status table**

Same pattern. Replace:
```
| hr-bot | ⬜ Pending |
| seo-audit | ⬜ Pending |
| frm-client-automatization | ⬜ Pending |
| check-parameters-sql-server | ⬜ Pending |
| mtproxy-telegram | ⬜ Pending |
```

With:
```
| mtproxy-telegram | ✅ Готово 2026-04-16 |
| check-parameters-sql-server-for-1c | ✅ Готово 2026-04-16 |
| frm-client-automatization | ✅ Готово 2026-04-16 |
| vpn-manager-openwrt-x-ui | ✅ Готово 2026-04-16 |
| hr-bot-project | ✅ Готово 2026-04-16 |
| text4site-create-modified | ✅ Готово 2026-04-16 |
| seo-audit | ✅ Готово 2026-04-16 |
```

### Phase 8.3: Summary report

- [ ] **Step 8.3.1: Build summary report**

Aggregate from all 7 Phase-5 checkpoint reports:
- Total files deleted (across all projects)
- Total kit files installed
- Total custom files preserved (sum of Phase-5 preservation lists)
- Any surprises encountered (project + description)
- Total time

Present to user in conversation as final summary. No separate file unless user requests.

### Phase 8.4: Commit doc updates

- [ ] **Step 8.4.1: Commit to orchestration-kit**

```bash
cd /root/projects/orchestration-kit
git add migration-plan.md analysis-habr-3000hours.md
git commit -m "$(cat <<'EOF'
docs(migration): mark 7 projects as migrated to v2 (2026-04-16)

Migrated projects:
- mtproxy-telegram
- check-parameters-sql-server-for-1c
- frm-client-automatization
- vpn-manager-openwrt-x-ui
- hr-bot-project
- text4site-create-modified
- seo-audit

Each migration: delete v1 artefacts, install v2 via deploy.sh,
preserve custom skills/agents/docs, verify 7 checks, git commit
in target project.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist (for executing agent)

Before declaring the whole migration done, run:

- [ ] All 7 TaskList tasks marked `completed`
- [ ] Each of 7 projects has 2 new commits in its git log (pre-migration snapshot + v1→v2 migration), OR 1 migration commit if clean state
- [ ] `orchestration-kit` has 1 new commit updating migration-plan.md and analysis-habr-3000hours.md
- [ ] No PASS check missed in any project verification phase
- [ ] Summary report presented to user

---

## Rollback Procedures (reference during execution)

### L1 — Single project rollback

```bash
cd /root/projects/$PROJECT
git log --oneline -3   # find the migration commit
git reset --hard HEAD~1  # or HEAD~2 if both pre-migration and migration commits exist
```

### L2 — Batch stop

Halt at current project's checkpoint. Do NOT auto-rollback. Discuss with user:
- Rollback current only
- Rollback current + all prior
- Skip current, continue
- Pause session for investigation

### L3 — Mass rollback

```bash
for proj in mtproxy-telegram check-parameters-sql-server-for-1c frm-client-automatization vpn-manager-openwrt-x-ui hr-bot-project text4site-create-modified seo-audit; do
  cd /root/projects/$proj || continue
  # find pre-migration commit by message
  preflight=$(git log --all --oneline --grep="pre-migration" -1 --format="%H")
  if [ -n "$preflight" ]; then
    git reset --hard "$preflight^"  # go to state BEFORE pre-migration snapshot
  fi
done
```

Do NOT run without explicit user request.

---

**End of plan. Execution: choose subagent-driven-development OR executing-plans skill.**
