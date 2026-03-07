# Orchestration Kit

Portable development orchestration system for Claude Code. Deploy a complete multi-agent pipeline to any project.

## What You Get

- **11 specialized agents** — planner, worker, test-runner, debugger, reviewer, security-auditor, documenter, doc-keeper, observer, senior-reviewer, refactor
- **7 workflow skills** — `/orchestrate`, `/implement`, `/code-review`, `/arch-review`, `/security-audit`, `/refactor-code`, `/012-update-docs`
- **Hooks** — SubagentStop pipeline transitions, PreToolUse safety guards, language-specific linting/formatting
- **Config-driven documentation** — plans, reports, issues, doc-drafts, observer reports

## Quick Start

### 1. Install (one command from your project directory)

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

### 2. Interactive setup (in Claude Code)

Open the project in Claude Code and run:

```
/deploy-orchestration
```

This will:
- Detect your project's tech stack
- Search for and install relevant skills (React, Python, etc.)
- Generate CLAUDE.md orchestration section
- For multi-purpose projects: set up sub-project structure

### 3. Start using

```
/orchestrate Add user authentication with JWT tokens
/implement Create a utility function for date formatting
/code-review
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

## Project Types

Choose the mode that matches your repo structure. If unsure — start with **atomic**, you can restructure later.

### Atomic (default) — One product, one repo

Use when your repo has **a single purpose**: one app, one API, one library, one service.

**When to use atomic:**
- A web app (Next.js, Django, Rails...)
- A backend API service
- A CLI tool
- A library/SDK
- A mobile app
- Any repo where all code serves one product

**Examples:**
| Repo | What it builds |
|------|---------------|
| `hr-bot` | HR dashboard + employee bot |
| `payment-api` | Payment processing service |
| `my-cli` | Command-line utility |
| `design-system` | Component library |

**Structure after install:**
```
my-app/
├── src/                         # Your code (unchanged)
├── .claude/
│   ├── agents/                  # 11 orchestration agents
│   └── skills/                  # 7+ workflow skills
├── docs/orchestration/          # AI-generated artifacts
│   ├── plans/                   #   Task breakdown plans
│   ├── reports/                 #   Completion reports
│   ├── issues/                  #   Tech debt tracking (ISS-NNN)
│   ├── doc-drafts/              #   Documentation change proposals
│   └── observer-reports/        #   Process improvement insights
├── orchestration-config.json    # Artifact paths & toggles
└── CLAUDE.md                    # Project rules + orchestration section
```

**Install:**
```bash
cd /path/to/my-app
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash
```

---

### Multi-purpose — Multiple projects, one direction

Use when your repo contains **several independent projects** that share a common theme or domain, but are not tightly coupled.

**When to use multi:**
- A collection of scripts (form scripts + validation scripts + migration scripts)
- Multiple plugins for the same platform
- A set of microservices in one repo
- Tools + libraries + examples in one place
- Any repo where you'd say "this has several things in it"

**Key difference from monorepo:** sub-projects here are loosely related (same domain), not tightly integrated (shared build system). For true monorepos with shared dependencies, use atomic mode with a monorepo tool.

**Examples:**
| Repo | Sub-projects inside |
|------|-------------------|
| `web-scripts` | `src/forms/` — form handlers, `src/plugins/` — browser extensions, `src/tools/` — CLI utilities |
| `ml-toolkit` | `src/preprocessing/` — data cleaning, `src/models/` — training scripts, `src/serving/` — inference API |
| `wordpress-kit` | `src/themes/` — custom themes, `src/plugins/` — WP plugins, `src/blocks/` — Gutenberg blocks |
| `automation` | `src/scrapers/` — data scrapers, `src/parsers/` — file parsers, `src/reporters/` — report generators |

**Structure after install:**
```
web-scripts/
├── src/                              # Sub-projects live here
│   ├── forms/                        #   Sub-project 1
│   │   ├── ...                       #     Its own code
│   │   └── README.md                 #     Its own docs
│   ├── plugins/                      #   Sub-project 2
│   │   ├── ...
│   │   └── README.md
│   └── tools/                        #   Sub-project 3
│       ├── ...
│       └── README.md
├── .claude/
│   ├── agents/                       # Shared — all sub-projects use same agents
│   └── skills/                       # Shared — same skills for everything
├── docs/orchestration/               # Shared — artifacts from all sub-projects
├── orchestration-config.json         # Shared config
└── CLAUDE.md                         # Sub-project index + per-project sections
```

**What CLAUDE.md looks like for multi:**
```markdown
## Sub-Projects

| Name | Path | Description |
|------|------|-------------|
| forms | src/forms/ | Form generation and validation scripts |
| plugins | src/plugins/ | Browser extension plugins |
| tools | src/tools/ | CLI utilities for data processing |

### Sub-Project: forms
**Path:** `src/forms/`
**Tech stack:** TypeScript, Zod
**Commands:** `npm run build:forms`, `npm test -- --project forms`

### Sub-Project: plugins
**Path:** `src/plugins/`
**Tech stack:** TypeScript, WebExtension API
**Commands:** `npm run build:plugins`
```

The planner agent reads these sections and **scopes tasks** to the correct sub-project automatically. When you say `/orchestrate add email validation to forms`, it knows to work in `src/forms/`.

**Install:**
```bash
cd /path/to/web-scripts
curl -sSL https://raw.githubusercontent.com/air900/orchestration-kit/main/install.sh | bash -s -- multi
```

---

### Decision flowchart

```
Does your repo build ONE product?
  ├── YES → atomic
  └── NO
       └── Does it contain several independent projects
           sharing a common theme/domain?
             ├── YES → multi
             └── NO (tightly coupled monorepo with shared deps)
                  └── atomic (use your monorepo tool for builds)
```

## Pipeline Overview

### `/orchestrate` — Full Development Cycle

```
Phase 1: Planning    — planner breaks task into subtasks with DAG
Phase 2: Task Loop   — for each unblocked task:
                        worker → test-runner → [security-auditor] → [reviewer]
                        debugger handles failures (max 3 retries per stage)
Phase 3: Docs        — documenter creates completion report
Phase 3.5: Doc Keeper — processes doc-drafts, recommends updates
Phase 3.75: Observer  — analyzes run, recommends improvements
Phase 4: Summary     — final output to user
```

### `/implement` — Simple Workflow

```
worker → test-runner → [debugger if needed] → documenter
```

## Configuration

### orchestration-config.json

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

Set `enabled: false` to get output in chat instead of files. Set path to `null` to disable completely.

## Customization

### Adding project-specific agent behavior

Agents read CLAUDE.md for project conventions. Add your coding standards, design system, and patterns there — agents will follow them automatically.

### Adding skills

Use find-skills to discover and install additional skills:

```bash
npx skills find [keyword]
npx skills add owner/repo@skill-name -y
```

Then add a symlink for Claude Code visibility:
```bash
ln -sf ../../.agents/skills/skill-name .claude/skills/skill-name
```

### Cross-session task persistence

Set the environment variable before starting Claude Code:
```bash
CLAUDE_CODE_TASK_LIST_ID=my-feature claude
```

Tasks will persist to `~/.claude/tasks/my-feature/` and survive session restarts.
