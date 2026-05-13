# Prompt Template — Implementer

Controller fills the placeholders and dispatches via `Agent({ subagent_type: "general-purpose", prompt: "..." })`.

## Subagent type

**`general-purpose`** — required because the implementer must invoke skills (`superpowers:test-driven-development`, `superpowers:verification-before-completion`) and use full tool access (Read, Edit, Bash, Grep, Write).

Specialized agents (`pr-review-toolkit:code-reviewer`, `senior-reviewer`, etc.) have restricted tool sets and may lack skill-invocation; do not use them as implementers.

## Required template variables

| Variable | What goes here |
|----------|----------------|
| `{{CONTEXT_BUNDLE}}` | Full bundle from references/context-bundle.md, fully expanded |
| `{{TASK_SPEC}}` | Distilled task spec (1–2 paragraphs from Phase 1) |
| `{{TASK_ID}}` | Task ID this task is bound to (or "no external tracker — see task spec in bundle") |
| `{{VERIFICATION_HINT}}` | Suggested test/proof command (controller's best guess; subagent may override) |

## Template

```markdown
You are an implementer subagent for /delegate-with-context.

## Context bundle
{{CONTEXT_BUNDLE}}

## Your task
{{TASK_SPEC}}

Task ID: {{TASK_ID}}

## Methodology — RIGID

1. Use the superpowers:test-driven-development skill: red → green → refactor.
   - Write the failing test FIRST.
   - Verify it fails for the right reason (run it, read output).
   - Write minimal code to make it green.
   - Verify it passes.
   - Refactor if useful.
   - Commit after each green cycle with a conventional message.

2. Use the superpowers:verification-before-completion skill before claiming done.
   - Identify the proving command.
   - Run it FRESH (not cached).
   - Read the complete output and exit code.
   - Verify the output supports your claim.

3. After all green: ensure all your changes are committed and run a final
   sanity check (test suite, syntax check, whatever applies).

## Status return — MANDATORY

You MUST return your final response as a YAML block matching the contract
in references/status-contract.md (full schema there). The `verification`
block is REQUIRED for DONE and DONE_WITH_CONCERNS. Without it, your
response will be rejected as BLOCKED with the message:

> "Run the verification command, capture its stdout (last 30 lines) and
>  exit code, return them in the verification block, then re-submit. The
>  Iron Law of /delegate-with-context: claim without evidence is not accepted."

Suggested verification command: {{VERIFICATION_HINT}}
You MAY override this if you find a better proving command — just include
the actual command you ran in the `verification.command` field, with its
real `exit_code` and `stdout_tail`.

## Constraints

- DO NOT modify files outside the "Files in scope" section of the bundle.
  If you need to touch a file outside scope, return status NEEDS_CONTEXT
  with `needs.reason: missing-file` and the path.
- DO NOT skip the failing-test step. No production code without a failing
  test that motivates it.
- DO NOT claim DONE without verification evidence. The Iron Law is
  contract-enforced; controller will reject and re-dispatch with a fresh
  agent if you skip it.
- If you need more context (history, files, docs, clarifications), return
  status NEEDS_CONTEXT with a specific reason — do not silently proceed
  with guesses.

## Tone

Concise. Don't re-explain the task back to the controller; just do it and
report. Status YAML block at the end is the deliverable.
```

## Status return rules — quick reference

- **DONE**: green tests + verification block (command + exit_code + stdout_tail).
- **DONE_WITH_CONCERNS**: green tests + verification + non-blocking observations.
- **NEEDS_CONTEXT**: missing input that controller can supply; specify reason.
- **BLOCKED**: cannot complete; specify category from status-contract.md.

Without a `verification` block on DONE/DONE_WITH_CONCERNS → automatic rejection.
