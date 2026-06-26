# Codex agent set — current-chat coordinator + scoped workers

Starter `~/.codex/agents/*.toml` worker set for OpenAI Codex CLI. The main Codex chat remains the coordinator.

Full rationale, model-selection reasoning, ready-pack comparison, and caveats:
**`../../docs/002-codex-agent-orchestration.md`**.

## What's here

| File | Role | Model | Effort | Sandbox |
|---|---|---|---|---|
| `code-scout.toml` | Locate / map code | gpt-5.4-mini | low | read-only |
| `backend-engineer.toml` | Python/FastAPI/SQLAlchemy | gpt-5.4 | high | workspace-write |
| `frontend-engineer.toml` | React/TypeScript | gpt-5.4 | high | workspace-write |
| `test-engineer.toml` | pytest / vitest suites | gpt-5.4 | high | workspace-write |
| `debugger.toml` | Root-cause first | gpt-5.4 | high | workspace-write |
| `infra-engineer.toml` | Docker/nginx/systemd/deploy | gpt-5.4 | medium | workspace-write |
| `code-reviewer.toml` | Review a diff (read-only) | gpt-5.4 | high | read-only |
| `config.toml.example` | Sets Codex sub-agent concurrency | — | — | — |
| `AGENTS.md.example` | Delegation policy for the current chat | — | — | — |

## Install

```bash
mkdir -p ~/.codex/agents
cp backend-engineer.toml frontend-engineer.toml test-engineer.toml \
   debugger.toml infra-engineer.toml code-reviewer.toml code-scout.toml \
   ~/.codex/agents/

# merge the [agents] block from config.toml.example into ~/.codex/config.toml
# drop AGENTS.md.example content into your repo's AGENTS.md
```

Scope: `~/.codex/agents/` = global (every project); `<repo>/.codex/agents/` = that repo only.
The `cp` above installs them **global**. Custom agents beat built-ins of the same name;
personal-vs-project precedence for the same name isn't documented — keep the generic set
global and add only project-specific agents under the repo (or use distinct names).

## How it runs

The **main session = the coordinator**. You ask it to do a multi-step task; it plans, then **explicitly** spawns the scoped workers per role and integrates their results. Codex does not auto-decompose-and-delegate and does not auto-pick models — model is pinned per agent in these files, and delegation is a thing you explicitly ask for.

> Before adopting any third-party agent set, scan it. These files are local and reviewed; treat
> external packs as untrusted until scanned.
