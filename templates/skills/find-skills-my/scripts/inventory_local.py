#!/usr/bin/env python3
"""Scan local skill directories and output a JSON inventory.

Checks:
  - ~/.claude/skills/
  - ~/.agents/skills/
  - <cwd>/.claude/skills/
  - <cwd>/.agents/skills/

For each skill found, extracts frontmatter (name, description) and
reports the path, body size, and whether it has scripts/references.

Usage:
    python3 inventory_local.py [--cwd /path/to/project]
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path


def parse_frontmatter(text: str) -> dict:
    """Extract YAML frontmatter fields from SKILL.md content."""
    m = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not m:
        return {}
    result = {}
    for line in m.group(1).splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if value:
                result[key] = value
    return result


def scan_directory(base: Path) -> list[dict]:
    """Scan a skills directory and return metadata for each skill."""
    skills = []
    if not base.is_dir():
        return skills
    for entry in sorted(base.iterdir()):
        skill_md = entry / "SKILL.md"
        if not entry.is_dir() or not skill_md.exists():
            continue
        text = skill_md.read_text(errors="replace")
        fm = parse_frontmatter(text)
        body_lines = len(text.splitlines())
        has_scripts = (entry / "scripts").is_dir() and any((entry / "scripts").iterdir())
        has_references = (entry / "references").is_dir() and any((entry / "references").iterdir())

        skills.append({
            "name": fm.get("name", entry.name),
            "description": fm.get("description", ""),
            "path": str(entry),
            "body_lines": body_lines,
            "has_scripts": has_scripts,
            "has_references": has_references,
        })
    return skills


def main():
    parser = argparse.ArgumentParser(description="Inventory local agent skills")
    parser.add_argument("--cwd", default=os.getcwd(), help="Project root to scan")
    args = parser.parse_args()

    home = Path.home()
    cwd = Path(args.cwd)

    locations = [
        ("global-claude", home / ".claude" / "skills"),
        ("global-agents", home / ".agents" / "skills"),
        ("project-claude", cwd / ".claude" / "skills"),
        ("project-agents", cwd / ".agents" / "skills"),
    ]

    inventory = []
    for scope, path in locations:
        for skill in scan_directory(path):
            skill["scope"] = scope
            inventory.append(skill)

    # Deduplicate by name, preferring project-level over global
    seen = {}
    for s in inventory:
        name = s["name"]
        if name not in seen or s["scope"].startswith("project"):
            seen[name] = s

    result = {
        "total": len(seen),
        "skills": list(seen.values()),
    }
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    print()


if __name__ == "__main__":
    main()
