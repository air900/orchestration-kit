#!/usr/bin/env python3
"""
external-skills report — list npx-skills (skills.sh) installs in this project.

READ-ONLY. This script does NOT run `npx`, does NOT modify `skills-lock.json`,
does NOT touch files, does NOT commit. It prints a report and exits.

Output:
  1. Stats summary      — counts, unique repos, most-popular, most-recent push
  2. Status legend      — what current / stale / no-meta / missing mean
  3. Skills table       — fixed-width columns, sorted by ⭐ desc
  4. Install commands   — grouped per source repo, ready to paste into bash
  5. Usage footer       — next-step instructions

Why read-only: earlier versions of this script tried to run `npx skills update`
and auto-commit. Two classes of bug followed:

  (a) `npx skills update <name>` re-installs the ENTIRE source repo when the
      lock entry has no `skillPath` (project-level lock format v1). Safe
      alternative: `npx skills add <source> -s <name> -p -y`.
  (b) Agents running in auto mode bypassed the interactive TTY guard and
      invoked `npx skills update` themselves — the exact command (a) forbids.

The fix: remove the execution path from this script entirely. What's printed
is plain bash; the user (or Claude, following the rules in SKILL.md) runs it.

Usage:
    python3 .claude/skills/update-external-skills/scripts/update.py

Optional env:
    GITHUB_TOKEN  — raises GitHub API rate limit from 60/hr to 5000/hr.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

GITHUB_API = "https://api.github.com"
LOCK_FILE_NAME = "skills-lock.json"


# --- Terminal colour helpers ------------------------------------------------

class C:
    RESET = "\033[0m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    CYAN = "\033[36m"
    BOLD = "\033[1m"


def log(msg: str, *, prefix: str = "", colour: str = ""):
    sys.stdout.write(f"{colour}{prefix}{C.RESET if colour else ''}{msg}\n")


def info(msg: str): log(msg, prefix="[INFO] ", colour=C.BLUE)
def warn(msg: str): log(msg, prefix="[WARN] ", colour=C.YELLOW)
def err(msg: str):  log(msg, prefix="[ERROR] ", colour=C.RED)


# --- Data model -------------------------------------------------------------

@dataclass
class RepoMeta:
    owner: str
    repo: str
    stars: Optional[int] = None
    pushed_at: Optional[datetime] = None
    description: Optional[str] = None
    html_url: Optional[str] = None
    fetch_error: Optional[str] = None


@dataclass
class SkillRecord:
    name: str
    source: str
    source_type: str
    computed_hash: str
    repo_meta: Optional[RepoMeta] = None
    local_mtime: Optional[datetime] = None
    installed: bool = False

    @property
    def status(self) -> str:
        """One of: missing, no-meta, stale, current."""
        if not self.installed:
            return "missing"
        if self.repo_meta and self.repo_meta.fetch_error:
            return "no-meta"
        if (
            self.repo_meta
            and self.repo_meta.pushed_at
            and self.local_mtime
            and self.repo_meta.pushed_at > self.local_mtime
        ):
            return "stale"
        return "current"


# --- Lock + disk scan -------------------------------------------------------

def find_project_root() -> Path:
    here = Path.cwd().resolve()
    for parent in [here, *here.parents]:
        if (parent / LOCK_FILE_NAME).is_file():
            return parent
    raise SystemExit(
        f"No {LOCK_FILE_NAME} found in {here} or any parent.\n"
        f"Run from a project that has external skills installed."
    )


def load_lock(root: Path) -> dict[str, SkillRecord]:
    data = json.loads((root / LOCK_FILE_NAME).read_text())
    skills = data.get("skills", {})
    records: dict[str, SkillRecord] = {}
    for name, entry in skills.items():
        if not isinstance(entry, dict):
            continue
        records[name] = SkillRecord(
            name=name,
            source=entry.get("source", ""),
            source_type=entry.get("sourceType", ""),
            computed_hash=entry.get("computedHash", ""),
        )
    return records


def stat_local_mtimes(root: Path, records: dict[str, SkillRecord]) -> None:
    for rec in records.values():
        for c in [
            root / ".agents" / "skills" / rec.name / "SKILL.md",
            root / ".claude" / "skills" / rec.name / "SKILL.md",
        ]:
            if c.is_file():
                rec.local_mtime = datetime.fromtimestamp(c.stat().st_mtime, tz=timezone.utc)
                rec.installed = True
                break


# --- GitHub metadata --------------------------------------------------------

def fetch_repo_meta(owner: str, repo: str) -> RepoMeta:
    url = f"{GITHUB_API}/repos/{owner}/{repo}"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "update-external-skills/2.0"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, headers=headers)
    meta = RepoMeta(owner=owner, repo=repo)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            payload = json.loads(resp.read().decode())
            meta.stars = payload.get("stargazers_count")
            meta.description = payload.get("description")
            meta.html_url = payload.get("html_url")
            pushed = payload.get("pushed_at")
            if pushed:
                meta.pushed_at = datetime.fromisoformat(pushed.replace("Z", "+00:00"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            meta.fetch_error = "repo not found"
        elif e.code == 403:
            meta.fetch_error = "rate-limited (set $GITHUB_TOKEN for 5000/hr)"
        else:
            meta.fetch_error = f"HTTP {e.code}"
    except Exception as e:
        meta.fetch_error = str(e)
    return meta


def enrich_repo_meta(records: dict[str, SkillRecord]) -> None:
    unique = sorted({r.source for r in records.values() if r.source_type == "github"})
    info(f"Fetching metadata for {len(unique)} unique GitHub repo(s)...")
    cache: dict[str, RepoMeta] = {}
    for source in unique:
        if "/" not in source:
            continue
        owner, repo = source.split("/", 1)
        cache[source] = fetch_repo_meta(owner, repo)
    for rec in records.values():
        if rec.source_type == "github":
            rec.repo_meta = cache.get(rec.source)


# --- Formatting helpers -----------------------------------------------------

def rel_time(ts: Optional[datetime]) -> str:
    if ts is None:
        return "-"
    now = datetime.now(tz=timezone.utc)
    secs = (now - ts).total_seconds()
    if secs < 3600:  return f"{int(secs // 60)}m ago"
    if secs < 86400: return f"{int(secs // 3600)}h ago"
    days = int(secs // 86400)
    if days < 30:    return f"{days}d ago"
    if days < 365:   return f"{days // 30}mo ago"
    return f"{days // 365}y ago"


def fmt_stars(n: Optional[int]) -> str:
    if n is None:      return "-"
    if n >= 1000:      return f"{n / 1000:.1f}k"
    return str(n)


def status_badge(s: str) -> str:
    return {
        "missing": f"{C.RED}missing{C.RESET}",
        "no-meta": f"{C.RED}no-meta{C.RESET}",
        "stale":   f"{C.YELLOW}stale{C.RESET}",
        "current": f"{C.GREEN}current{C.RESET}",
    }.get(s, s)


# --- Report blocks ----------------------------------------------------------

def print_rate_limit_banner(rows: list[SkillRecord]) -> None:
    gh = {r.source: r.repo_meta for r in rows if r.source_type == "github" and r.repo_meta}
    if not gh:
        return
    limited = sum(1 for m in gh.values() if m.fetch_error and "rate-limit" in m.fetch_error)
    if limited == 0 or limited / len(gh) < 0.5:
        return
    print()
    print(f"{C.RED}{C.BOLD}╔══════════════════════════════════════════════════════════════════════╗{C.RESET}")
    print(f"{C.RED}{C.BOLD}║  ⚠ GITHUB API RATE LIMIT HIT  —  stats are temporarily unavailable   ║{C.RESET}")
    print(f"{C.RED}{C.BOLD}╚══════════════════════════════════════════════════════════════════════╝{C.RESET}")
    print(f"  {limited} of {len(gh)} unique repos returned {C.RED}HTTP 403{C.RESET}.")
    print(f"  Fix: export {C.BOLD}GITHUB_TOKEN{C.RESET} (5000 req/hr) or wait ~1h for reset.")
    print()


def print_stats_summary(rows: list[SkillRecord]) -> None:
    total = len(rows)
    unique_repos: dict[str, RepoMeta] = {}
    for rec in rows:
        if rec.repo_meta and rec.source_type == "github":
            unique_repos[rec.source] = rec.repo_meta

    status_counts = {"missing": 0, "no-meta": 0, "stale": 0, "current": 0}
    for r in rows:
        status_counts[r.status] = status_counts.get(r.status, 0) + 1

    total_stars = sum(m.stars or 0 for m in unique_repos.values())
    most_popular = max(unique_repos.items(), key=lambda kv: kv[1].stars or 0, default=(None, None))
    most_recent = max(
        (m for m in unique_repos.values() if m.pushed_at),
        key=lambda m: m.pushed_at, default=None,
    )

    all_no_meta = status_counts["no-meta"] + status_counts["missing"] == total

    print()
    print(f"{C.BOLD}=== Stats summary ==={C.RESET}")
    print(f"  Skills in lock:      {total}")
    print(f"  Unique repos:        {len(unique_repos)}")
    if all_no_meta and status_counts["no-meta"] > 0:
        print(f"  Current:             {C.DIM}unknown (rate-limited){C.RESET}")
        print(f"  Stale (updatable):   {C.DIM}unknown (rate-limited){C.RESET}")
    else:
        print(f"  Current:             {C.GREEN}{status_counts['current']}{C.RESET}")
        print(f"  Stale (updatable):   {C.YELLOW}{status_counts['stale']}{C.RESET}")
    if status_counts["no-meta"]:
        print(f"  No-metadata:         {C.RED}{status_counts['no-meta']}{C.RESET}   (metadata fetch failed)")
    if status_counts["missing"]:
        print(f"  {C.RED}Missing (ghosts):    {status_counts['missing']}{C.RESET}   (in lock but not on disk)")
    if total_stars > 0:
        print(f"  Total stars (sum):   {fmt_stars(total_stars)}")
    if most_popular[0] and most_popular[1].stars:
        print(f"  Most popular repo:   {most_popular[0]} ({fmt_stars(most_popular[1].stars)} ⭐)")
    if most_recent:
        print(f"  Most recent push:    {most_recent.owner}/{most_recent.repo} ({rel_time(most_recent.pushed_at)})")
    print()

    if status_counts["missing"]:
        print(f"{C.RED}{C.BOLD}⚠ Ghost entries (in lock but files not on disk):{C.RESET}")
        for r in rows:
            if r.status == "missing":
                print(f"  • {r.name!r}  (source: {r.source})")
        print(f"  Remedy: re-install via add command below, OR edit {LOCK_FILE_NAME} to drop the entry.")
        print()


def print_status_legend() -> None:
    print(f"{C.BOLD}=== Status meanings ==={C.RESET}")
    print(f"  {C.GREEN}current{C.RESET}  — upstream has NOT been pushed since your install (mtime-based heuristic).")
    print(f"  {C.YELLOW}stale{C.RESET}    — upstream HAS been pushed since your install; an update is likely available.")
    print(f"  {C.RED}no-meta{C.RESET}  — couldn't fetch GitHub metadata; status unknown.")
    print(f"  {C.RED}missing{C.RESET}  — lock entry exists but no local files — ghost install.")
    print()
    print(f"  {C.DIM}Note: status is a likelihood signal, not ground truth. Two caveats:{C.RESET}")
    print(f"  {C.DIM}  - For multi-skill repos, `pushed_at` bumps on any skill; all siblings move in lockstep.{C.RESET}")
    print(f"  {C.DIM}  - If you installed from a push that already contained upstream work, current may be false.{C.RESET}")
    print(f"  {C.DIM}  Authoritative drift test: re-run the install command and diff.{C.RESET}")
    print()


def print_skills_table(rows: list[SkillRecord]) -> None:
    print(f"{C.BOLD}=== Skills table (sorted by ⭐ desc) ==={C.RESET}")
    print(f"{C.BOLD}  #  {'Skill':<38} {'Repo':<40} {'Stars':>6}  {'Remote pushed':<14}  Status{C.RESET}")
    print(f"  {'-' * 3} {'-' * 38} {'-' * 40} {'-' * 6}  {'-' * 14}  {'-' * 16}")
    for idx, rec in enumerate(rows, start=1):
        meta = rec.repo_meta
        pushed = rel_time(meta.pushed_at) if meta else "-"
        stars = fmt_stars(meta.stars) if meta else "-"
        repo = rec.source if rec.source_type == "github" else f"({rec.source_type}:{rec.source})"
        print(f"  {idx:>3}  {rec.name[:38]:<38} {repo[:40]:<40} {stars:>6}  {pushed:<14}  {status_badge(rec.status)}")
    print()


def print_install_commands(rows: list[SkillRecord]) -> None:
    """Print ready-to-paste bash commands grouped by source repo.

    Format: `npx skills add <source> -s <name1> -s <name2> ... -p -y`

    This is the ONLY safe invocation for multi-skill repos on project-level
    locks — `skills update` re-installs the whole repo. The `-s` flag pins
    installation to the explicit names.

    Indexes follow the table above, so row 4 maps to the command that
    contains `-s <name_of_row_4>`.
    """
    by_source: dict[str, list[tuple[int, str]]] = defaultdict(list)
    for idx, rec in enumerate(rows, start=1):
        if rec.source_type != "github":
            continue  # non-github sources printed separately below
        by_source[rec.source].append((idx, rec.name))

    print(f"{C.BOLD}=== Install / refresh commands ==={C.RESET}")
    print(f"  One command per source repo. `-s` restricts installation to the listed skills only.")
    print(f"  {C.BOLD}Do NOT use `npx skills update <name>`{C.RESET} — it re-installs the whole source repo for")
    print(f"  project-level locks. Always `add -s <name>` as shown below.")
    print()

    for source in sorted(by_source):
        entries = by_source[source]
        idx_list = ", ".join(f"#{i}" for i, _ in entries)
        names = [n for _, n in entries]
        print(f"  {C.DIM}# {source}  ({idx_list}){C.RESET}")
        flags = " ".join(f"-s {n}" for n in names)
        print(f"  npx skills add {source} {flags} -p -y")
        print()

    non_github = [r for r in rows if r.source_type != "github"]
    if non_github:
        print(f"  {C.DIM}# Non-github sources (no generated command; consult the source tool):{C.RESET}")
        for r in non_github:
            print(f"  {C.DIM}#   {r.name}  ({r.source_type}:{r.source}){C.RESET}")
        print()


def print_maintenance_commands(rows: list[SkillRecord]) -> None:
    """Delete + ghost-clean helpers as plain bash, for the user to run if wanted."""
    ghosts = [r for r in rows if r.status == "missing"]
    print(f"{C.BOLD}=== Maintenance (optional) ==={C.RESET}")
    print(f"  {C.DIM}# Uninstall a skill (replace <name>):{C.RESET}")
    print(f"  npx skills remove <name> -p -y")
    print()
    if ghosts:
        names = " ".join(g.name for g in ghosts)
        print(f"  {C.DIM}# Remove {len(ghosts)} ghost entry(ies) from {LOCK_FILE_NAME}:{C.RESET}")
        print(f"  python3 - <<'PY'")
        print(f"import json, pathlib")
        print(f"p = pathlib.Path('{LOCK_FILE_NAME}')")
        print(f"d = json.loads(p.read_text())")
        print(f"for g in {names.split()!r}:")
        print(f"    d['skills'].pop(g, None)")
        print(f"p.write_text(json.dumps(d, indent=2) + '\\n')")
        print(f"PY")
        print()


def print_usage_footer() -> None:
    print(f"{C.BOLD}=== What to do next ==={C.RESET}")
    print(f"  1. Review the status column — {C.YELLOW}stale{C.RESET} rows likely have upstream updates.")
    print(f"  2. Ensure working tree is clean on scoped paths:")
    print(f"     {C.DIM}git status .agents/skills .claude/skills {LOCK_FILE_NAME}{C.RESET}")
    print(f"  3. Run the {C.BOLD}install command(s){C.RESET} above for the source(s) you want to refresh.")
    print(f"     If only some skills — edit the command to keep only the desired `-s <name>` flags.")
    print(f"  4. Inspect changes with git:")
    print(f"     {C.DIM}git diff --stat .agents/skills .claude/skills {LOCK_FILE_NAME}{C.RESET}")
    print(f"     {C.DIM}git diff -- .agents/skills/<name>/{C.RESET}")
    print(f"  5. Commit if desired, scoped to the paths above:")
    print(f"     {C.DIM}git add {LOCK_FILE_NAME} .agents/skills .claude/skills && git commit -m \"...\"{C.RESET}")
    print()


# --- Main -------------------------------------------------------------------

def main() -> int:
    root = find_project_root()
    info(f"Project root: {root}")

    records = load_lock(root)
    if not records:
        warn(f"{LOCK_FILE_NAME} has no skills. Nothing to report.")
        return 0

    info(f"Tracked: {len(records)} skill(s)")
    stat_local_mtimes(root, records)
    enrich_repo_meta(records)

    def sort_key(r: SkillRecord) -> tuple:
        stars = r.repo_meta.stars if r.repo_meta and r.repo_meta.stars else 0
        return (-stars, r.name.lower())

    rows = sorted(records.values(), key=sort_key)

    print_rate_limit_banner(rows)
    print_stats_summary(rows)
    print_status_legend()
    print_skills_table(rows)
    print_install_commands(rows)
    print_maintenance_commands(rows)
    print_usage_footer()
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        err("Interrupted.")
        sys.exit(130)
