---
name: workflow-gate
description: >
  Entry point for all development work. Creates .workflow-active marker (unlocks Edit/Write),
  then invokes template-bridge:unified-workflow. Use BEFORE any task — edits are blocked without this.
  TRIGGER: Always use this instead of unified-workflow directly.
---

# Workflow Gate

**This skill is the ONLY way to unlock code editing in this session.**

A PreToolUse hook blocks Edit/Write/MultiEdit until `.workflow-active` exists.
This skill creates that marker and launches the full development workflow.

## Steps

### Step 1: Activate gate

```bash
touch .workflow-active
```

Run this Bash command IMMEDIATELY. Without it, all edits will be blocked.

### Step 2: Launch unified workflow

Invoke the `template-bridge:unified-workflow` skill. It handles the full flow:
1. Beads: create task/epic
2. Brainstorm (superpowers)
3. Plan (superpowers)
4. TDD implementation
5. Review + verification
6. Close task

### Step 3: When done

After task is closed and committed, remove the marker:

```bash
rm -f .workflow-active
```

This re-arms the gate for the next task.

## Rules

- NEVER skip Step 1 — edits will fail without the marker
- NEVER create `.workflow-active` outside of this skill — the gate exists to enforce workflow
- If the marker already exists (resumed session), proceed to Step 2
