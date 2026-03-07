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
curl -sSL https://raw.githubusercontent.com/USERNAME/orchestration-kit/main/install.sh | bash

# Multi-purpose project (sub-projects in src/)
curl -sSL https://raw.githubusercontent.com/USERNAME/orchestration-kit/main/install.sh | bash -s -- multi
```

Or clone manually:
```bash
git clone --depth 1 https://github.com/USERNAME/orchestration-kit.git /tmp/orch-kit
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

### Atomic (default)

Single-purpose project. One application, library, or service.

```
my-app/
├── .claude/agents/       # 11 agents
├── .claude/skills/       # 7+ skills
├── docs/orchestration/   # AI-generated artifacts
├── orchestration-config.json
└── CLAUDE.md             # With orchestration section
```

### Multi-purpose

Multiple sub-projects in one repo, organized under `src/`.

```
web-scripts/
├── src/
│   ├── forms-scripts/    # Sub-project 1
│   ├── plugins/          # Sub-project 2
│   └── tools/            # Sub-project 3
├── .claude/agents/       # Shared agents
├── .claude/skills/       # Shared skills
├── docs/orchestration/   # Shared output
├── orchestration-config.json
└── CLAUDE.md             # With sub-project index
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
