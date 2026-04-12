# Orchestration Kit

Lightweight development orchestration for Claude Code. Deploys specialist agents, quality skills, and language hooks to any project — designed to work **alongside Superpowers** (methodology) and **Beads** (task tracking).

## What You Get

- **7 specialist agents** — planner, security-auditor, senior-reviewer, refactor, documenter, doc-keeper, observer
- **7 skills** — `/arch-review`, `/security-audit`, `/refactor-code`, `/012-update-docs`, `/find-skills`, `/sync-skills`, `/knowledge-harvest`
- **Language hooks** — auto-lint/format after every edit (TypeScript, Python, Go, Rust, JavaScript)
- **Safety guard** — PreToolUse hook blocking `rm -rf`, `git push --force`, `git reset --hard`
- **Config-driven artifacts** — plans, reports, issues, doc-drafts, observer reports

## Architecture

```
Superpowers (plugin)         — HOW: brainstorm → plan → TDD → review → verify
Beads (plugin, recommended)  — WHAT: git-backed task tracking, dependencies, session persistence
Orchestration Kit (this)     — WHO: specialist agents + quality skills + language hooks + doc workflow
```

Superpowers handles the core dev loop. Orchestration Kit provides **deep specialized analysis** that Superpowers doesn't cover: OWASP security audits, architecture health checks, documentation lifecycle, process improvement.

## Quick Start

### 1. Prerequisites

Install plugins (once, used by all projects):
```bash
# Required — development methodology
claude plugin install superpowers

# Recommended — persistent task tracking
claude plugin marketplace add steveyegge/beads
claude plugin install beads
npm install -g @beads/bd
```

### 2. Deploy orchestration to your project

```bash
cd /path/to/my-project

# Atomic project (single-purpose)
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash

# Multi-purpose project (sub-projects in src/)
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
```

Or clone manually:
```bash
git clone --depth 1 https://github.com/air900/orchestration-kit.git /tmp/orch-kit
/tmp/orch-kit/deploy.sh /path/to/my-project
rm -rf /tmp/orch-kit
```

### 3. Interactive setup (in Claude Code)

```
/deploy-orchestration develop REST API with FastAPI and PostgreSQL
/deploy-orchestration build React dashboard with auth and charts
/deploy-orchestration create WordPress plugin for SEO optimization
```

This discovers relevant skills for your stack and generates CLAUDE.md.

### 4. Start working

Superpowers drives development. Use specialist skills when needed:

```
/arch-review            — Architecture health check
/security-audit         — OWASP vulnerability scan
/refactor-code          — Guided refactoring
/012-update-docs        — Verify docs still match code
```

## Supported Languages

| Language | Detected By | PostToolUse Hooks |
|----------|------------|-------------------|
| TypeScript | `tsconfig.json` or `typescript` in package.json | tsc + prettier |
| JavaScript | `package.json` (no TS) | eslint + prettier |
| Python | `pyproject.toml`, `requirements.txt`, `setup.py` | ruff check + ruff format |
| Go | `go.mod` | go vet + gofmt |
| Rust | `Cargo.toml` | cargo check + rustfmt |
| Generic | (fallback) | No language hooks |

## Specialist Agents

These agents are called **on-demand**, not as a pipeline. Use them when you need deep specialized analysis:

| Agent | Model | Purpose | When to Use |
|-------|-------|---------|-------------|
| `planner` | opus | Break complex tasks into subtask DAGs | Before large features with multiple parts |
| `security-auditor` | sonnet | OWASP Top 10 vulnerability scan | After auth, API, or data-handling changes |
| `senior-reviewer` | sonnet | Architecture review with health scores | Before merging significant refactors |
| `refactor` | sonnet | Code restructuring without behavior change | When code smells accumulate |
| `documenter` | haiku | Completion reports, doc updates | After significant work sessions |
| `doc-keeper` | sonnet | Process doc-drafts, recommend doc changes | After documenter creates drafts |
| `observer` | sonnet | Analyze sessions, identify process improvements | End of major work cycles |

### Post-work documentation cycle

After significant work, run this sequence:
1. **documenter** — generates completion report and doc-drafts
2. **doc-keeper** — processes doc-drafts, presents recommendations for approval
3. **observer** — analyzes the session, saves improvement insights

## Project Types

### Atomic (default) — One product, one repo

Use when your repo has **a single purpose**: one app, API, library, service.

**Structure after install:**
```
my-app/
├── src/                              # Your code (unchanged)
├── .claude/
│   ├── agents/                       # 7 specialist agents
│   ├── skills/                       # 7+ quality & utility skills
│   ├── references/                   # Shared reference docs
│   └── orchestration-config.json     # Artifact paths & toggles
├── docs/orchestration/               # AI-generated artifacts
│   ├── plans/                        #   Task breakdown plans
│   ├── reports/                      #   Completion reports
│   ├── issues/                       #   Tech debt tracking (ISS-NNN)
│   ├── doc-drafts/                   #   Documentation change proposals
│   └── observer-reports/             #   Process improvement insights
└── CLAUDE.md                         # Project rules + automations
```

### Multi-purpose — Multiple projects, one direction

Use when your repo contains **several independent projects** sharing a common theme.

```bash
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
```

CLAUDE.md will include a sub-project index with per-project sections (path, tech stack, commands, conventions).

### Decision flowchart

```
Does your repo build ONE product?
  ├── YES → atomic
  └── NO
       └── Several independent projects, common theme?
             ├── YES → multi
             └── NO (tightly coupled monorepo)
                  └── atomic (use your monorepo tool for builds)
```

## Configuration

### .claude/orchestration-config.json

Controls where AI-generated artifacts are saved:

```json
{
  "documentation": {
    "paths": {
      "plans": "docs/orchestration/plans",
      "reports": "docs/orchestration/reports",
      "issues": "docs/orchestration/issues",
      "doc_drafts": "docs/orchestration/doc-drafts",
      "observer_reports": "docs/orchestration/observer-reports"
    },
    "enabled": {
      "plans": true,
      "reports": true,
      "issues": true,
      "doc_drafts": true,
      "observer_reports": true
    }
  }
}
```

Set `enabled: false` to get output in chat instead of files.

## Customization

### Adding project-specific behavior

Agents read CLAUDE.md for project conventions. Add your coding standards, design system, and patterns there — agents follow them automatically.

### Adding skills

```bash
npx skills find [keyword]
npx skills add owner/repo@skill-name -y
ln -sf ../../.agents/skills/skill-name .claude/skills/skill-name
```

### Task tracking with Beads

Beads is a Dolt-backed issue tracker that survives context compaction. Install once:

```bash
# Plugin (hooks + commands in Claude Code)
claude plugin marketplace add steveyegge/beads
claude plugin install beads

# CLI
npm install -g @beads/bd

# Initialize in project (deploy.sh does this automatically if bd is available)
cd your-project && bd init
```

Workflow:

```bash
bd create -t epic "JWT authorization"    # Create epic (container)
bd create "Token table schema"           # Create subtask
bd create "Verification middleware"      # Create subtask
bd dep add middleware tokens             # middleware needs tokens first
bd ready                                 # Show unblocked tasks (readiness frontier)
bd claim <id>                            # Atomically claim + set in_progress
# ... work ...
bd close <id> --reason "Implemented"     # Close → dependents become ready
bd ready                                 # Next unblocked tasks appear
```

Beads hooks auto-run `bd prime` at session start and before compaction — no manual context recovery needed.

### Template Catalog (on-demand specialists)

413+ specialized agents from [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates), organized in 26 categories. Pull a specialist when you need expertise not covered by installed agents:

```bash
# Install a specific agent
npx claude-code-templates@latest --agent security/security-auditor --yes

# Browse all available
npx claude-code-templates@latest --agent list

# Examples
npx claude-code-templates@latest --agent devops/kubernetes-specialist --yes
npx claude-code-templates@latest --agent api-graphql/graphql-architect --yes
npx claude-code-templates@latest --agent ai-specialists/prompt-engineer --yes
```

Agents are installed locally to the project. Delete after use if not needed long-term. Always fresh version from GitHub — no local staleness.

## License

Apache 2.0
