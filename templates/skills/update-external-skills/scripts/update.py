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
    installed: bool = False    # does a local SKILL.md actually exist?
    selected: bool = False

    @property
    def updated(self) -> bool:
        return self.new_hash is not None and self.new_hash != self.old_hash

    @property
    def repo_key(self) -> str:
        return self.source if self.source_type == "github" else f"{self.source_type}:{self.source}"

    @property
    def status(self) -> str:
        """Returns one of: missing, no-meta, stale, current."""
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
    """Attach the mtime of each skill's SKILL.md + set installed=True if present.
    If neither .agents/skills/<name>/SKILL.md nor .claude/skills/<name>/SKILL.md
    exists, the lock entry is a 'ghost' — marked installed=False → status='missing'.
    """
    for rec in records.values():
        candidates = [
            root / ".agents" / "skills" / rec.name / "SKILL.md",
            root / ".claude" / "skills" / rec.name / "SKILL.md",
        ]
        for c in candidates:
            if c.is_file():
                rec.local_mtime = datetime.fromtimestamp(c.stat().st_mtime, tz=timezone.utc)
                rec.installed = True
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
    """Thin alias over rec.status for backward compatibility."""
    return rec.status == "stale"


def status_badge(s: str) -> str:
    """Coloured status tag for the table."""
    return {
        "missing": f"{C.RED}missing{C.RESET}",
        "no-meta": f"{C.RED}no-meta{C.RESET}",
        "stale":   f"{C.YELLOW}stale{C.RESET}",
        "current": f"{C.GREEN}current{C.RESET}",
    }.get(s, s)


def fmt_stars(n: Optional[int]) -> str:
    if n is None:
        return "-"
    if n >= 1000:
        return f"{n / 1000:.1f}k"
    return str(n)


# --- Interactive selection --------------------------------------------------

def print_rate_limit_banner(rows: list[SkillRecord]) -> None:
    """If most unique repos failed metadata fetch due to rate limit,
    print a prominent banner so the user doesn't mistake '-' cells
    and 0 counts for a broken table."""
    gh_repos = {r.source: r.repo_meta for r in rows if r.source_type == "github" and r.repo_meta}
    if not gh_repos:
        return
    rate_limited = sum(1 for m in gh_repos.values() if m.fetch_error and "rate-limit" in m.fetch_error)
    if rate_limited == 0:
        return
    ratio = rate_limited / len(gh_repos)
    if ratio < 0.5:
        return  # minor issue, not worth a banner

    print()
    print(f"{C.RED}{C.BOLD}╔══════════════════════════════════════════════════════════════════════╗{C.RESET}")
    print(f"{C.RED}{C.BOLD}║  ⚠ GITHUB API RATE LIMIT HIT  —  stats are temporarily unavailable   ║{C.RESET}")
    print(f"{C.RED}{C.BOLD}╚══════════════════════════════════════════════════════════════════════╝{C.RESET}")
    print(f"  {rate_limited} of {len(gh_repos)} unique repos returned {C.RED}HTTP 403 rate-limit{C.RESET}.")
    print(f"  That is why {C.BOLD}Stars{C.RESET} and {C.BOLD}Remote pushed{C.RESET} columns show '-' and")
    print(f"  most rows are tagged {C.RED}no-meta{C.RESET}. This is NOT a table-rendering bug.")
    print()
    print(f"  {C.BOLD}Fix in one of two ways:{C.RESET}")
    print(f"    1. Wait ~1 hour — anonymous limit (60 req/hr) will reset.")
    print(f"    2. Set {C.BOLD}GITHUB_TOKEN{C.RESET} env var (5000 req/hr with auth):")
    print(f"         export GITHUB_TOKEN=ghp_...   # classic PAT, no scopes needed for public repos")
    print(f"       then re-run this command.")
    print()


def print_stats_summary(rows: list[SkillRecord]) -> None:
    """Aggregate numbers first, so stats are visible even if the table is
    reformatted by a wrapping layer."""
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
        key=lambda m: m.pushed_at,
        default=None,
    )

    print()
    print(f"{C.BOLD}=== Stats summary ==={C.RESET}")
    print(f"  Skills in lock:      {total}")
    print(f"  Unique repos:        {len(unique_repos)}")
    # If metadata is mostly unavailable, mark stats as unknown rather than 0.
    all_no_meta = status_counts['no-meta'] + status_counts['missing'] == total
    if all_no_meta and status_counts['no-meta'] > 0:
        print(f"  Current:             {C.DIM}unknown (rate-limited){C.RESET}")
        print(f"  Stale (updatable):   {C.DIM}unknown (rate-limited){C.RESET}")
    else:
        print(f"  Current:             {C.GREEN}{status_counts['current']}{C.RESET}")
        print(f"  Stale (updatable):   {C.YELLOW}{status_counts['stale']}{C.RESET}")
    if status_counts['no-meta']:
        print(f"  No-metadata:         {C.RED}{status_counts['no-meta']}{C.RESET}   (metadata fetch failed)")
    if status_counts['missing']:
        print(f"  {C.RED}Missing (ghosts):    {status_counts['missing']}{C.RESET}   (in lock but not on disk — see below)")
    if total_stars > 0:
        print(f"  Total stars (sum):   {fmt_stars(total_stars)}")
    else:
        print(f"  Total stars (sum):   {C.DIM}unknown (rate-limited){C.RESET}")
    if most_popular[0] and most_popular[1].stars:
        print(f"  Most popular repo:   {most_popular[0]} ({fmt_stars(most_popular[1].stars)} ⭐)")
    if most_recent:
        print(f"  Most recent push:    {most_recent.owner}/{most_recent.repo} ({rel_time(most_recent.pushed_at)})")
    print()

    if status_counts['missing']:
        print(f"{C.RED}{C.BOLD}⚠ Ghost entries in skills-lock.json (not installed on disk):{C.RESET}")
        for r in rows:
            if r.status == "missing":
                print(f"  • {r.name!r}  (source: {r.source})")
        print(f"  Remedy: either {C.BOLD}npx skills add <source>@<name>{C.RESET} to install, or edit skills-lock.json to remove the ghost entry.")
        print()


def print_status_legend() -> None:
    print(f"{C.BOLD}=== Status meanings ==={C.RESET}")
    print(f"  {C.GREEN}current{C.RESET}  — upstream has NOT been pushed since your local install; no update needed.")
    print(f"  {C.YELLOW}stale{C.RESET}    — upstream HAS been pushed since your local install; likely has updates available.")
    print(f"  {C.RED}no-meta{C.RESET}  — couldn't fetch GitHub metadata (rate limit, 404, or network error); status unknown.")
    print(f"  {C.RED}missing{C.RESET}  — entry in skills-lock.json but NO local files (.agents/skills/<name>/ or .claude/skills/<name>/ do not exist). Ghost lock entry — install failed or files were deleted.")
    print()


def print_selection_table(rows: list[SkillRecord]) -> None:
    header = f"{C.BOLD}  #  {'Skill':<38} {'Repo':<40} {'Stars':>6}  {'Remote pushed':<14}  Status{C.RESET}"
    print(f"{C.BOLD}=== Skills table (sorted by ⭐ desc — preserve all columns; this is the \"stats\" the user asked for) ==={C.RESET}")
    print(header)
    print(f"  {'-' * 3} {'-' * 38} {'-' * 40} {'-' * 6}  {'-' * 14}  {'-' * 16}")
    for idx, rec in enumerate(rows, start=1):
        meta = rec.repo_meta
        pushed = rel_time(meta.pushed_at) if meta else "-"
        stars = fmt_stars(meta.stars) if meta else "-"
        repo = rec.source if rec.source_type == "github" else f"({rec.source_type}:{rec.source})"
        print(f"  {idx:>3}  {rec.name[:38]:<38} {repo[:40]:<40} {stars:>6}  {pushed:<14}  {status_badge(rec.status)}")
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


ACTION_UPDATE = "update"
ACTION_DELETE = "delete"
ACTION_CLEAN  = "clean"
ACTION_CANCEL = "cancel"


def prompt_selection(records: list[SkillRecord]) -> tuple[str, list[SkillRecord]]:
    """Returns (action, records):
      ("update", [SkillRecord, ...])  — install/update selected
      ("delete", [SkillRecord, ...])  — uninstall selected via `npx skills remove`
      ("clean",  [])                  — remove ghost entries from lock
      ("cancel", [])                  — exit without changes
    """
    print_rate_limit_banner(records)
    print_stats_summary(records)
    print_status_legend()
    print_selection_table(records)
    ghost_count = sum(1 for r in records if r.status == "missing")
    print(f"{C.BOLD}Action:{C.RESET}")
    print("  0             — UPDATE all")
    print("  1,3,5         — UPDATE specific (comma-separated)")
    print("  1-5           — UPDATE range")
    print("  del 1,3,5     — DELETE specific (uninstalls skills; updates lock)")
    print("  del 1-5       — DELETE range")
    if ghost_count:
        print(f"  clean         — remove {ghost_count} ghost entry(ies) from skills-lock.json (no install/update)")
    else:
        print("  clean         — (no ghosts present — nothing to clean)")
    print("  (empty)       — cancel")
    try:
        raw = input(">> ").strip()
    except (EOFError, KeyboardInterrupt):
        print()
        return (ACTION_CANCEL, [])

    low = raw.lower()

    if low in ("clean", "clean-ghosts", "c"):
        return (ACTION_CLEAN, [])

    # Detect delete prefix: "del ...", "rm ...", "delete ..."
    for prefix in ("delete ", "del ", "rm "):
        if low.startswith(prefix):
            rest = raw[len(prefix):]
            idxs = parse_selection(rest, len(records))
            return (ACTION_DELETE, [records[i - 1] for i in idxs])

    if not raw:
        return (ACTION_CANCEL, [])

    idxs = parse_selection(raw, len(records))
    return (ACTION_UPDATE, [records[i - 1] for i in idxs])


# --- Update + report --------------------------------------------------------

def run_npx_update(selected: list[SkillRecord], root: Path) -> int:
    """Invoke `npx skills update` for the chosen skills (or all)."""
    if not selected:
        return 0
    names_arg = [s.name for s in selected]
    cmd = ["npx", "--yes", "skills", "update", *names_arg, "-p", "-y"]
    info(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=root)
    return result.returncode


def run_npx_remove(selected: list[SkillRecord], root: Path) -> int:
    """Invoke `npx skills remove` for the chosen skills."""
    if not selected:
        return 0
    names_arg = [s.name for s in selected]
    cmd = ["npx", "--yes", "skills", "remove", *names_arg, "-p", "-y"]
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


# --- Ghost cleanup ----------------------------------------------------------

def clean_ghosts(root: Path, records: dict[str, SkillRecord]) -> int:
    """Remove entries from skills-lock.json whose files are not on disk.
    Returns number of ghosts removed."""
    ghosts = [r for r in records.values() if r.status == "missing"]
    if not ghosts:
        info("No ghost entries to clean.")
        return 0

    info(f"Removing {len(ghosts)} ghost entry(ies) from {LOCK_FILE_NAME}:")
    for g in ghosts:
        print(f"  • {g.name}  (source: {g.source})")

    lock_path = root / LOCK_FILE_NAME
    data = json.loads(lock_path.read_text())
    skills = data.get("skills", {})
    for g in ghosts:
        skills.pop(g.name, None)
    data["skills"] = skills
    lock_path.write_text(json.dumps(data, indent=2) + "\n")
    ok(f"Cleaned. skills-lock.json now tracks {len(skills)} skill(s).")
    return len(ghosts)


def _git_autosync_paths(root: Path, paths: list[str], commit_msg: str) -> None:
    """Shared git add/commit/push with explicit path staging. No-op if not a git repo."""
    if not (root / ".git").is_dir():
        warn("Not a git repo — skipping auto-commit/push.")
        return

    def git(*args: str, capture: bool = False) -> subprocess.CompletedProcess:
        return subprocess.run(["git", *args], cwd=root, capture_output=capture, text=True, check=False)

    git("add", *paths)
    if git("diff", "--cached", "--quiet").returncode == 0:
        info("No staged changes — no commit.")
        return
    if git("commit", "-m", commit_msg).returncode != 0:
        err("git commit failed.")
        return
    sha = git("rev-parse", "--short", "HEAD", capture=True).stdout.strip()
    ok(f"Committed: {sha}")
    upstream = git("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}", capture=True)
    if upstream.returncode != 0:
        warn("No upstream branch — run 'git push -u origin <branch>' manually.")
        return
    if git("push", "--quiet").returncode == 0:
        ok(f"Pushed to {upstream.stdout.strip()}")
    else:
        warn("git push failed — commit is preserved locally.")


def git_commit_lock_cleanup(root: Path, removed_count: int) -> None:
    if removed_count == 0:
        return
    _git_autosync_paths(
        root,
        [LOCK_FILE_NAME],
        f"chore(skills): remove {removed_count} ghost entry(ies) from skills-lock.json\n\n"
        "Ghost = lock entry with no corresponding files on disk (failed install\n"
        "or manual deletion). Auto-cleaned by update-external-skills script.\n\n"
        "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
    )


def git_commit_delete(root: Path, removed: list[SkillRecord]) -> None:
    if not removed:
        return
    names = ", ".join(r.name for r in removed)
    _git_autosync_paths(
        root,
        [LOCK_FILE_NAME, ".agents/skills", ".claude/skills"],
        f"chore(skills): remove {len(removed)} external skill(s) via npx skills remove\n\n"
        f"Removed: {names}\n\n"
        "Removed by: update-external-skills script (delete mode).\n"
        "Paths affected: skills-lock.json (entry removal), .agents/skills/<name>/\n"
        "(content removal), .claude/skills/<name> (symlink removal).\n\n"
        "Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
    )


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

    # Sort by ⭐ stars descending; skills without metadata sink to the bottom.
    # Secondary sort by name for stable ordering among ties.
    def sort_key(r: SkillRecord) -> tuple:
        stars = r.repo_meta.stars if r.repo_meta and r.repo_meta.stars else 0
        return (-stars, r.name.lower())

    sorted_records = sorted(records.values(), key=sort_key)
    action, selected = prompt_selection(sorted_records)

    # Guard against piped input from auto-running agents. An interactive
    # selection pre-fed via stdin is a trust violation: the user never saw
    # the prompt, never typed a choice. Require explicit opt-in.
    piped = not sys.stdin.isatty()
    auto_ok = os.environ.get("UPDATE_EXTERNAL_SKILLS_NON_INTERACTIVE") == "1"
    if piped and not auto_ok and action != ACTION_CANCEL:
        err("Stdin is not a TTY — this looks like input piped by an agent or automation.")
        err("The selection prompt is for the USER to answer interactively, not to be auto-filled.")
        err("If you really want to run non-interactively (e.g. CI), set:")
        err("    UPDATE_EXTERNAL_SKILLS_NON_INTERACTIVE=1")
        err("Aborting without making any changes.")
        return 2

    if action == ACTION_CLEAN:
        removed = clean_ghosts(root, records)
        git_commit_lock_cleanup(root, removed)
        return 0

    if action == ACTION_CANCEL:
        info("Cancelled. No changes made.")
        return 0

    if not selected:
        info("Empty selection. Nothing to do.")
        return 0

    if action == ACTION_DELETE:
        print()
        warn(f"About to REMOVE {len(selected)} skill(s) via `npx skills remove`:")
        for r in selected:
            print(f"  • {r.name}  (source: {r.source})")
        try:
            confirm = input("Proceed? [y/N] ").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            info("Cancelled.")
            return 0
        if confirm not in ("y", "yes"):
            info("Cancelled.")
            return 0
        rc = run_npx_remove(selected, root)
        if rc != 0:
            err(f"`npx skills remove` exited with code {rc}. Check output above.")
            return rc
        ok(f"Removed {len(selected)} skill(s).")
        git_commit_delete(root, selected)
        return 0

    # action == ACTION_UPDATE
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
