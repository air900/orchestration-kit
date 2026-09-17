#!/usr/bin/env python3
"""Uninstall orchestration-kit artifacts from every project under /root/projects.

Dry-run by default: prints, per project, what would be removed and what is kept.
`--apply` performs the removal (git rm for tracked files, rm for untracked),
strips the kit hooks from .claude/settings.json and the kit section from
CLAUDE.md, and commits per project. Global copies (~/.claude, ~/.codex) are
reported only; pass --global to remove the ~/.claude ones too.

Usage: uninstall_kit.py [--apply] [--global] [--projects-root /root/projects]
"""
import argparse, json, os, re, shutil, subprocess, sys
from pathlib import Path

KIT_SKILLS = {"012-update-docs", "arch-review", "delegate-with-context", "find-skills-my", "knowledge-harvest",
              "refactor-code", "security-audit", "sync-skills", "update-external-skills", "wf-gate", "wf-gate-check",
              "deploy-orchestration", "orchestrate", "implement", "code-review"}
KIT_AGENTS = {"planner", "worker", "test-runner", "debugger", "reviewer", "security-auditor", "documenter",
              "doc-keeper", "observer", "senior-reviewer", "refactor"}
KIT_COMMANDS = {"delegate-with-context", "kit-update", "wf-gate", "wf-gate-check"}
KIT_REFERENCES = {"code-quality-standards.md", "doc-drafts-format.md", "documentation-structure.md", "issue-tracking.md"}
KIT_FILES = [".claude/orchestration-config.json", ".claude/hooks/log-commands.sh", ".claude/scripts/deploy.sh",
             ".claude/scripts/orch.sh", ".claude/command-log.txt"]
KIT_SECTION_H1 = "# Claude Automations"
KIT_SUBSECTIONS = {"Development Methodology (D1)", "Skills", "Specialist Agents (on-demand)", "Agents", "Hooks", "Config",
                   "Template Catalog (on-demand specialists)", "Skill Discovery", "Maintenance"}
HOOK_MARKERS = ("log-commands.sh", "wf-gate", "Destructive command detected")
GLOBAL_KIT = [Path.home() / ".claude/skills/wf-gate", Path.home() / ".claude/skills/wf-gate-check",
              Path.home() / ".claude/commands/wf-gate.md", Path.home() / ".claude/commands/wf-gate-check.md"]
CODEX_AGENTS = Path.home() / ".codex/agents"


def git(project: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(project), *args], capture_output=True, text=True).stdout


def tracked(project: Path, rel: str) -> bool:
    return bool(git(project, "ls-files", "--error-unmatch", rel).strip()) if (project / ".git").exists() else False


def plan_project(project: Path) -> dict:
    remove, keep, notes = [], [], []
    for rel in KIT_FILES:
        if (project / rel).exists(): remove.append(rel)
    for kind, names, sub, suffix in (("skill", KIT_SKILLS, ".claude/skills", ""), ("agent", KIT_AGENTS, ".claude/agents", ".md"),
                                    ("command", KIT_COMMANDS, ".claude/commands", ".md"), ("reference", KIT_REFERENCES, ".claude/references", "")):
        base = project / sub
        if not base.exists(): continue
        for entry in sorted(base.iterdir()):
            name = entry.name[:-len(suffix)] if suffix and entry.name.endswith(suffix) else entry.name
            if entry.name in names or name in names: remove.append(f"{sub}/{entry.name}")
            else: keep.append(f"{sub}/{entry.name}")
    settings = project / ".claude/settings.json"
    hooks_to_drop = []
    if settings.exists():
        try:
            d = json.loads(settings.read_text())
            for event, entries in (d.get("hooks") or {}).items():
                for h in entries:
                    cmds = " ".join(x.get("command", "") for x in h.get("hooks", []))
                    if any(m in cmds for m in HOOK_MARKERS) or (event == "SubagentStop" and (h.get("matcher") or "") in KIT_AGENTS):
                        hooks_to_drop.append(f"{event}[{h.get('matcher') or '*'}]")
        except Exception as e:
            notes.append(f"settings.json unreadable: {e}")
    claude_md = project / "CLAUDE.md"
    section = None
    if claude_md.exists():
        lines = claude_md.read_text().splitlines()
        if KIT_SECTION_H1 in lines:
            start = lines.index(KIT_SECTION_H1)
            end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("# ")), len(lines))
            subs = [l[3:].strip() for l in lines[start:end] if l.startswith("## ")]
            foreign = [s for s in subs if s not in KIT_SUBSECTIONS]
            section = {"lines": (start + 1, end), "subsections": subs, "foreign": foreign}
    orch = project / "docs/orchestration"
    orch_note = None
    if orch.exists():
        n = sum(1 for _ in orch.rglob("*") if _.is_file())
        orch_note = f"docs/orchestration: {n} files — " + ("empty, remove" if n == 0 else "KEEP (documents, not kit code)")
    return {"remove": remove, "keep": keep, "hooks": hooks_to_drop, "section": section, "orch": orch_note, "notes": notes}


def apply_project(project: Path, plan: dict) -> None:
    for rel in plan["remove"]:
        target = project / rel
        if tracked(project, rel) or (target.is_dir() and git(project, "ls-files", rel).strip()):
            subprocess.run(["git", "-C", str(project), "rm", "-rq", rel], check=False)
        if target.is_dir(): shutil.rmtree(target, ignore_errors=True)
        elif target.exists(): target.unlink()
    for sub in (".claude/references", ".claude/hooks", ".claude/scripts", ".claude/commands", ".claude/agents"):
        p = project / sub
        if p.is_dir() and not any(p.iterdir()): p.rmdir()
    settings = project / ".claude/settings.json"
    if settings.exists() and plan["hooks"]:
        d = json.loads(settings.read_text()); hooks = d.get("hooks") or {}
        for event in list(hooks):
            hooks[event] = [h for h in hooks[event] if f"{event}[{h.get('matcher') or '*'}]" not in plan["hooks"]]
            if not hooks[event]: del hooks[event]
        if hooks: d["hooks"] = hooks
        else: d.pop("hooks", None)
        settings.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
    if plan["section"]:
        claude_md = project / "CLAUDE.md"; lines = claude_md.read_text().splitlines()
        start, end = plan["section"]["lines"][0] - 1, plan["section"]["lines"][1]
        block = lines[start:end]
        kept, i = [], 1  # drop the H1 line; keep foreign ## subsections verbatim
        while i < len(block):
            if block[i].startswith("## ") and block[i][3:].strip() in plan["section"]["foreign"]:
                j = i + 1
                while j < len(block) and not block[j].startswith("## "): j += 1
                kept.extend(block[i:j]); i = j
            else: i += 1
        new = lines[:start] + kept + lines[end:]
        while new and new[-1].strip() == "": new.pop()
        claude_md.write_text("\n".join(new) + "\n")
    orch = project / "docs/orchestration"
    if orch.exists() and not any(p.is_file() for p in orch.rglob("*")): shutil.rmtree(orch, ignore_errors=True)
    if (project / ".git").exists():
        subprocess.run(["git", "-C", str(project), "add", "-A", ".claude", "CLAUDE.md", "docs/orchestration"], check=False, capture_output=True)
        subprocess.run(["git", "-C", str(project), "commit", "-qm", "chore: uninstall orchestration-kit (skills, agents, commands, hooks, config, CLAUDE.md section)"], check=False, capture_output=True)


def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument("--apply", action="store_true"); ap.add_argument("--global", dest="glob", action="store_true")
    ap.add_argument("--projects-root", default="/root/projects"); a = ap.parse_args()
    root = Path(a.projects_root)
    for project in sorted(p for p in root.iterdir() if p.is_dir() and p.name != "orchestration-kit"):
        plan = plan_project(project)
        if not (plan["remove"] or plan["hooks"] or plan["section"] or plan["orch"]): continue
        print(f"\n### {project.name}")
        for r in plan["remove"]: print(f"  - remove  {r}")
        for h in plan["hooks"]: print(f"  - hook    {h}  (from .claude/settings.json)")
        if plan["section"]:
            s = plan["section"]; print(f"  - CLAUDE.md: strip '{KIT_SECTION_H1}' lines {s['lines'][0]}–{s['lines'][1]} ({', '.join(s['subsections'])})")
            if s["foreign"]: print(f"    keep non-kit subsections inside it: {', '.join(s['foreign'])}")
        if plan["orch"]: print(f"  - {plan['orch']}")
        for k in plan["keep"]: print(f"  · keep    {k}")
        for n in plan["notes"]: print(f"  ! {n}")
        if a.apply: apply_project(project, plan); print("  => applied and committed")
    print("\n### global (~)")
    for p in GLOBAL_KIT:
        if p.exists(): print(f"  - {'remove' if a.glob else 'kit copy (use --global to remove)'}  {p}")
        if a.apply and a.glob and p.exists(): shutil.rmtree(p) if p.is_dir() else p.unlink()
    if CODEX_AGENTS.exists():
        print(f"  · keep    {CODEX_AGENTS}/*.toml — referenced by ~/.claude/CLAUDE.md as Codex role defaults; remove by hand if unwanted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
