#!/usr/bin/env python3
"""
Patch CLAUDE.md to remove Beads/LightRAG references from auto-generated
"Claude Automations" section while preserving any project-local customisations
in surrounding prose.

Usage: migrate-claude-md.py <path/to/CLAUDE.md>

Idempotent: running twice on the same file produces no further changes.
Returns exit code 0 (patched), 1 (already clean), or 2 (file missing / unreadable).
"""

import re
import sys
from pathlib import Path

REPLACEMENTS = [
    # 1. Entry-point line (English + Russian) — optional "our/the" and "on top" suffix
    (
        r"Delegates to `template-bridge:unified-workflow`(?: and layers| layers|, layers)\s*(?:our |the )?Beads quality overlay(?: on top)?\.",
        "Delegates to `template-bridge:unified-workflow` and layers our task-discipline reference (`wf-gate` skill) on top.",
    ),
    (
        r"Делегирует\s+`template-bridge:unified-workflow`(?:,| и)\s+(?:накладывает|кладёт сверху)\s+Beads quality overlay\.?",
        "Делегирует `template-bridge:unified-workflow`, накладывает task-discipline reference (`wf-gate` skill).",
    ),
    # 2. Flow header
    (
        r"^Flow \(9 steps from unified-workflow\):$",
        "Flow (from unified-workflow):",
    ),
    (
        r"^Flow \(9 шагов unified-workflow\):?$",
        "Flow (из unified-workflow):",
    ),
    # 3. Step 1: bd create — English and Russian short variants
    (
        r"^1\. `bd create` \(6-point description — see `workflow-gate` skill § Phase 2\)$",
        "1. Task record (6-point description — see `wf-gate` skill § Phase 2 — lives in your tracker or `docs/orchestration/issues/`)",
    ),
    (
        r"^1\. `bd create` \(6-point description — `workflow-gate` skill § Phase 2\)$",
        "1. Task record (6-point description — `wf-gate` skill § Phase 2 — в трекере проекта или `docs/orchestration/issues/`)",
    ),
    # 4. Step 4: bd create + bd dep add
    (
        r"^4\. Sub-tasks \(`bd create` \+ `bd dep add`\)$",
        "4. Sub-tasks (track in same place as parent)",
    ),
    (
        r"^4\. Sub-tasks \(`bd create` \+ `bd dep add`\)\s*$",
        "4. Sub-tasks (трекаются там же, где родитель)",
    ),
    # 5. Step 9: bd close
    (
        r"^9\. `bd close` \(4-point reason incl Verification — `workflow-gate` skill § Phase 4\)$",
        "9. Task close (4-point reason in commit body, PR description, or tracker close — see `wf-gate` skill § Phase 4)",
    ),
    (
        r"^9\. `bd close` \(4-point reason incl Verification — `workflow-gate` skill § Phase 4\)\s*$",
        "9. Task close (4-point reason в commit body / PR description / tracker close — `wf-gate` skill § Phase 4)",
    ),
    # 6. Beads artefacts paragraph — English with optional "are" verb
    (
        r"\*\*Beads artefacts \(descriptions, notes, reasons, remember\)(?: are)? written in English\*\* for token efficiency\.",
        "**Task artefacts (descriptions, notes, close reasons) are written in English** for token efficiency.",
    ),
    # 6b. Russian variant
    (
        r"\*\*Beads артефакты \(descriptions, notes, reasons, remember\) — на английском\*\* для token efficiency\.",
        "**Task артефакты (descriptions, notes, close reasons) — на английском** для token efficiency.",
    ),
    # 7. Manual commands: drop /beads:* line entirely (English + Russian variants)
    (
        r"^- `/beads:create`, `/beads:ready`, `/beads:close` — direct Beads operations\n",
        "",
    ),
    (
        r"^- `/beads:create`, `/beads:ready`, `/beads:close` — direct Beads ops\n",
        "",
    ),
    (
        r"^- `/beads:create`, `/beads:ready`, `/beads:close` — прямые Beads\n",
        "",
    ),
    (
        r"^- `/beads:create`, `/beads:ready`, `/beads:close` — прямые Beads операции\n",
        "",
    ),
    # 8. Workflow summary
    (
        r"\*\*Workflow summary:\*\* epic → sub-tasks with deps → `bd ready` → claim → work → verify → close → next ready task\.",
        "**Workflow summary:** plan → sub-tasks → work → verify → close → next task.",
    ),
    (
        r"\*\*Workflow summary:\*\* epic → sub-tasks с deps → `bd ready` → claim → work → verify → close → next ready task\.",
        "**Workflow summary:** plan → sub-tasks → work → verify → close → next task.",
    ),
    # 9. Skills list: /wf-gate description
    (
        r"^- `/workflow-gate` — Beads quality-overlay entry(?: \(delegates to template-bridge:unified-workflow\))?$",
        "- `/wf-gate` — task-discipline overlay entry (delegates to template-bridge:unified-workflow)",
    ),
    # 10. Hooks section: bd prime line (multiple verb variants)
    (
        r"^- \*\*SessionStart\*\*(?: / \*\*PreCompact\*\*)?: `bd prime`[^\n]*Beads[^\n]*\n",
        "",
    ),
    (
        r"^- \*\*PreCompact\*\*: `bd prime`[^\n]*Beads[^\n]*\n",
        "",
    ),
]


def patch(text: str) -> tuple[str, int]:
    """Apply all replacements; return (new_text, total_substitutions)."""
    total = 0
    for pat, repl in REPLACEMENTS:
        new_text, n = re.subn(pat, repl, text, flags=re.MULTILINE)
        text = new_text
        total += n
    return text, total


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: migrate-claude-md.py <path/to/CLAUDE.md>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"not a file: {path}", file=sys.stderr)
        return 2

    original = path.read_text(encoding="utf-8")
    new_text, n = patch(original)

    if new_text == original:
        print(f"{path}: already clean (no changes)")
        return 1

    path.write_text(new_text, encoding="utf-8")
    print(f"{path}: applied {n} substitution(s)")

    # Residual scan — non-fatal warning
    residuals = re.findall(r"\bbeads\b|\bBeads\b|\bbd \b|LightRAG", new_text)
    if residuals:
        print(
            f"  warning: {len(residuals)} residual beads/bd/LightRAG mention(s) "
            f"remain after templated substitutions; review manually.",
            file=sys.stderr,
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
