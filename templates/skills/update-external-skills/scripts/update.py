#!/usr/bin/env python3
"""
update-external-skills — manage npx-skills (skills.sh) installs in this project.

Invoke from the project root; the script reads skills-lock.json, fetches remote
metadata from GitHub, presents an interactive selection, runs `npx skills update`,
and reports what actually changed. On success with changes, auto-commits and pushes.

Usage:
    python3 .claude/skills/update-external-skills/scripts/update.py

Optional env:
    GITHUB_TOKEN  — increases GitHub API rate limit from 60/hr to 5000/hr.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
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


def info(msg: str):
    log(msg, prefix="[INFO] ", colour=C.BLUE)


def ok(msg: str):
    log(msg, prefix="[OK] ", colour=C.GREEN)


def warn(msg: str):
    log(msg, prefix="[WARN] ", colour=C.YELLOW)


def err(msg: str):
    log(msg, prefix="[ERROR] ", colour=C.RED)


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
    source: str          # "owner/repo" for sourceType=github
    source_type: str
    old_hash: str
    new_hash: Optional[str] = None
    repo_meta: Optional[RepoMeta] = None
    local_mtime: Optional[datetime] = None
    selected: bool = False

    @property
    def updated(self) -> bool:
        return self.new_hash is not None and self.new_hash != self.old_hash

    @property
    def repo_key(self) -> str:
        return self.source if self.source_type == "github" else f"{self.source_type}:{self.source}"


# --- Lock-file handling -----------------------------------------------------

def find_project_root() -> Path:
    """Start at cwd; walk up to find a skills-lock.json."""
    here = Path.cwd().resolve()
    for parent in [here, *here.parents]:
        if (parent / LOCK_FILE_NAME).is_file():
            return parent
    raise SystemExit(
        f"No {LOCK_FILE_NAME} found in {here} or any parent. "
        f"Run this from a project that has external skills installed."
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
            old_hash=entry.get("computedHash", ""),
        )
    return records


def stat_local_mtimes(root: Path, records: dict[str, SkillRecord]) -> None:
    """Attach the mtime of each skill's SKILL.md for relative reporting."""
    for rec in records.values():
        candidates = [
            root / ".agents" / "skills" / rec.name / "SKILL.md",
            root / ".claude" / "skills" / rec.name / "SKILL.md",
        ]
        for c in candidates:
            if c.is_file():
                rec.local_mtime = datetime.fromtimestamp(c.stat().st_mtime, tz=timezone.utc)
                break


# --- GitHub metadata --------------------------------------------------------

def fetch_repo_meta(owner: str, repo: str) -> RepoMeta:
    url = f"{GITHUB_API}/repos/{owner}/{repo}"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "update-external-skills/1.0"}
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
    """Fetch GitHub metadata once per unique repo; attach to all owning records."""
    repo_cache: dict[str, RepoMeta] = {}
    unique_repos = [r.source for r in records.values() if r.source_type == "github"]
    unique_repos = sorted(set(unique_repos))

    info(f"Fetching metadata for {len(unique_repos)} unique GitHub repo(s)...")
    for source in unique_repos:
        if "/" not in source:
            continue
        owner, repo = source.split("/", 1)
        repo_cache[source] = fetch_repo_meta(owner, repo)

    for rec in records.values():
        if rec.source_type == "github":
            rec.repo_meta = repo_cache.get(rec.source)


# --- Reporting helpers ------------------------------------------------------

def rel_time(ts: Optional[datetime]) -> str:
    if ts is None:
        return "-"
    now = datetime.now(tz=timezone.utc)
    delta = now - ts
    secs = delta.total_seconds()
    if secs < 3600:
        return f"{int(secs // 60)}m ago"
    if secs < 86400:
        return f"{int(secs // 3600)}h ago"
    days = int(secs // 86400)
    if days < 30:
        return f"{days}d ago"
    if days < 365:
        return f"{days // 30}mo ago"
    return f"{days // 365}y ago"


def is_stale(rec: SkillRecord) -> bool:
    """Remote repo has been pushed after this skill was last installed locally."""
    if not rec.repo_meta or not rec.repo_meta.pushed_at or not rec.local_mtime:
        return False
    return rec.repo_meta.pushed_at > rec.local_mtime


def fmt_stars(n: Optional[int]) -> str:
    if n is None:
        return "-"
    if n >= 1000:
        return f"{n / 1000:.1f}k"
    return str(n)


# --- Interactive selection --------------------------------------------------

def print_stats_summary(rows: list[SkillRecord]) -> None:
    """Aggregate numbers first, so stats are visible even if the table is
    reformatted by a wrapping layer."""
    total = len(rows)
    unique_repos: dict[str, RepoMeta] = {}
    for rec in rows:
        if rec.repo_meta and rec.source_type == "github":
            unique_repos[rec.source] = rec.repo_meta

    stale_count = sum(1 for r in rows if is_stale(r))
    current_count = total - stale_count - sum(1 for r in rows if r.repo_meta and r.repo_meta.fetch_error)
    no_meta_count = sum(1 for r in rows if r.repo_meta and r.repo_meta.fetch_error)

    total_stars = sum(m.stars or 0 for m in unique_repos.values())
    most_popular = max(unique_repos.items(), key=lambda kv: kv[1].stars or 0, default=(None, None))
    most_recent = max(
        (m for m in unique_repos.values() if m.pushed_at),
        key=lambda m: m.pushed_at,
        default=None,
    )

    print()
    print(f"{C.BOLD}=== Stats summary ==={C.RESET}")
    print(f"  Skills tracked:      {total}")
    print(f"  Unique repos:        {len(unique_repos)}")
    print(f"  Stale (updatable):   {C.YELLOW}{stale_count}{C.RESET}")
    print(f"  Current:             {C.GREEN}{current_count}{C.RESET}")
    if no_meta_count:
        print(f"  No-metadata:         {C.RED}{no_meta_count}{C.RESET}")
    print(f"  Total stars (sum):   {fmt_stars(total_stars)}")
    if most_popular[0] and most_popular[1].stars:
        print(f"  Most popular repo:   {most_popular[0]} ({fmt_stars(most_popular[1].stars)} ⭐)")
    if most_recent:
        print(f"  Most recent push:    {most_recent.owner}/{most_recent.repo} ({rel_time(most_recent.pushed_at)})")
    print()


def print_selection_table(rows: list[SkillRecord]) -> None:
    header = f"{C.BOLD}  #  {'Skill':<38} {'Repo':<40} {'Stars':>6}  {'Remote pushed':<14}  Status{C.RESET}"
    print()
    print(f"{C.BOLD}=== Skills table (preserve all columns — this is the \"stats\" the user asked for) ==={C.RESET}")
    print(header)
    print(f"  {'-' * 3} {'-' * 38} {'-' * 40} {'-' * 6}  {'-' * 14}  {'-' * 16}")
    for idx, rec in enumerate(rows, start=1):
        meta = rec.repo_meta
        pushed = rel_time(meta.pushed_at) if meta else "-"
        stars = fmt_stars(meta.stars) if meta else "-"
        repo = rec.source if rec.source_type == "github" else f"({rec.source_type}:{rec.source})"
        status = f"{C.YELLOW}stale{C.RESET}" if is_stale(rec) else (f"{C.RED}no-meta{C.RESET}" if meta and meta.fetch_error else "current")
        print(f"  {idx:>3}  {rec.name[:38]:<38} {repo[:40]:<40} {stars:>6}  {pushed:<14}  {status}")
    print()


def parse_selection(raw: str, max_idx: int) -> list[int]:
    """Return 1-based indexes of selected skills; [] means cancel; [0] expands to all."""
    raw = raw.strip()
    if not raw:
        return []
    if raw == "0":
        return list(range(1, max_idx + 1))

    selected: set[int] = set()
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            lo, hi = part.split("-", 1)
            try:
                a, b = int(lo), int(hi)
                for i in range(min(a, b), max(a, b) + 1):
                    if 1 <= i <= max_idx:
                        selected.add(i)
            except ValueError:
                warn(f"Skipping invalid range: {part}")
        else:
            try:
                i = int(part)
                if 1 <= i <= max_idx:
                    selected.add(i)
            except ValueError:
                warn(f"Skipping invalid index: {part}")
    return sorted(selected)


def prompt_selection(records: list[SkillRecord]) -> list[SkillRecord]:
    print_stats_summary(records)
    print_selection_table(records)
    print(f"{C.BOLD}Select skills to update:{C.RESET}")
    print("  0         — all")
    print("  1,3,5     — specific (comma-separated)")
    print("  1-5       — range")
    print("  (empty)   — cancel")
    try:
        raw = input(">> ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return []
    idxs = parse_selection(raw, len(records))
    return [records[i - 1] for i in idxs]


# --- Update + report --------------------------------------------------------

def run_npx_update(selected: list[SkillRecord], root: Path) -> int:
    """Invoke `npx skills update` for the chosen skills (or all)."""
    if not selected:
        return 0
    if len(selected) == 1:
        names_arg = [selected[0].name]
    else:
        names_arg = [s.name for s in selected]

    cmd = ["npx", "--yes", "skills", "update", *names_arg, "-p", "-y"]
    info(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=root)
    return result.returncode


def reload_hashes(root: Path, records: dict[str, SkillRecord]) -> None:
    """After npx skills update, read lock again and record new hashes."""
    data = json.loads((root / LOCK_FILE_NAME).read_text())
    skills = data.get("skills", {})
    for name, entry in skills.items():
        if name in records:
            records[name].new_hash = entry.get("computedHash", "")


def print_final_report(records: dict[str, SkillRecord], selected_names: set[str]) -> None:
    updated = [r for r in records.values() if r.updated]
    unchanged = [r for r in records.values() if r.name in selected_names and not r.updated]
    not_attempted = [r for r in records.values() if r.name not in selected_names and selected_names]

    print()
    print(f"{C.BOLD}=== Update report ==={C.RESET}")
    print(f"Attempted: {len(selected_names)}   Updated: {C.GREEN}{len(updated)}{C.RESET}   Unchanged: {len(unchanged)}")
    print()

    if updated:
        print(f"{C.GREEN}✓ UPDATED ({len(updated)}):{C.RESET}")
        for r in sorted(updated, key=lambda x: x.name):
            meta = r.repo_meta
            pushed = rel_time(meta.pushed_at) if meta else "-"
            stars = fmt_stars(meta.stars) if meta else "-"
            print(f"  • {r.name}")
            print(f"    hash:  {r.old_hash[:12]} → {r.new_hash[:12]}")
            print(f"    repo:  {r.source}   ⭐ {stars}   pushed {pushed}")
        print()

    if unchanged:
        print(f"{C.DIM}⏸ UNCHANGED ({len(unchanged)}):{C.RESET}")
        for r in sorted(unchanged, key=lambda x: x.name):
            print(f"  • {r.name} — already on latest hash ({r.old_hash[:12]})")
        print()

    skipped = [r for r in records.values() if r.name not in selected_names]
    if skipped and selected_names:
        print(f"{C.DIM}(skipped {len(skipped)} skill(s) not selected){C.RESET}")
        print()


# --- Git auto-commit + push -------------------------------------------------

def git_autosync(root: Path, updated_count: int) -> None:
    if not (root / ".git").is_dir():
        warn("Not a git repo — skipping auto-commit/push.")
        return
    if updated_count == 0:
        info("No real drift (hash-identical) — no commit.")
        return

    def git(*args: str, capture: bool = False) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["git", *args],
            cwd=root,
            capture_output=capture,
            text=True,
            check=False,
        )

    # Stage only paths that external-skills might change. Custom unrelated work
    # the user has elsewhere is not swept in.
    git("add", LOCK_FILE_NAME, ".agents/skills", ".claude/skills")

    status = git("diff", "--cached", "--quiet")
    if status.returncode == 0:
        info("Lock file unchanged — no commit.")
        return

    commit_msg = (
        "chore(skills): refresh external skills via npx skills update\n\n"
        f"Updated {updated_count} skill(s) to latest upstream hashes.\n"
        "Auto-synced by: update-external-skills script.\n\n"
        "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
    )
    commit_res = git("commit", "-m", commit_msg)
    if commit_res.returncode != 0:
        err("git commit failed.")
        return

    sha = git("rev-parse", "--short", "HEAD", capture=True).stdout.strip()
    ok(f"Committed: {sha}")

    # Push only if upstream is tracked
    upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", capture=True)
    if upstream.returncode != 0:
        warn("No upstream branch — run 'git push -u origin <branch>' manually.")
        return
    push_res = git("push", "--quiet")
    if push_res.returncode == 0:
        ok(f"Pushed to {upstream.stdout.strip()}")
    else:
        warn("git push failed — commit is preserved locally.")


# --- Main -------------------------------------------------------------------

def main() -> int:
    root = find_project_root()
    info(f"Project root: {root}")

    records = load_lock(root)
    if not records:
        warn(f"{LOCK_FILE_NAME} has no skills. Nothing to update.")
        return 0

    info(f"Tracked: {len(records)} skill(s)")
    stat_local_mtimes(root, records)
    enrich_repo_meta(records)

    sorted_records = sorted(records.values(), key=lambda r: r.name)
    selected = prompt_selection(sorted_records)
    if not selected:
        info("No skills selected. Exiting.")
        return 0

    ok(f"Selected {len(selected)} skill(s) for update.")
    rc = run_npx_update(selected, root)
    if rc != 0:
        err(f"`npx skills update` exited with code {rc}. Check output above.")
        return rc

    reload_hashes(root, records)

    selected_names = {s.name for s in selected}
    print_final_report(records, selected_names)

    updated_count = sum(1 for r in records.values() if r.updated)
    git_autosync(root, updated_count)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print()
        err("Interrupted.")
        sys.exit(130)
