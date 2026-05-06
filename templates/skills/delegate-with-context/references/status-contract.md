# Status Contract

Every implementer / reviewer subagent dispatched by `/delegate-with-context` MUST return a structured YAML block matching this contract. The controller parses this block to decide the next step. Free-form prose responses are rejected.

## Required block: verification (DONE / DONE_WITH_CONCERNS only)

The `verification` block proves the subagent actually ran the work, instead of merely claiming it. **This is the Iron Law of `/delegate-with-context`: claim without evidence is not accepted.**

```yaml
verification:
  command: "<exact command the subagent ran>"
  exit_code: <integer>
  stdout_tail: |
    <last ~30 lines of stdout, verbatim>
```

For test-running tasks: `command` = the test command, `exit_code` = test runner's exit code, `stdout_tail` = the summary lines (e.g., `pytest`'s `===== N passed in M.Ms =====`).

For non-test tasks where no test command is meaningful: pick a verification command that PROVES the requested change happened — `git diff --stat HEAD~1`, `grep -c "<new symbol>" <path>`, etc. Empty placeholders are not accepted.

## Each status — when and what

```yaml
status: DONE
summary: <one line — what was implemented>
verification:
  command: "..."
  exit_code: 0
  stdout_tail: "..."
```

```yaml
status: DONE_WITH_CONCERNS
summary: <one line>
verification:
  command: "..."
  exit_code: 0
  stdout_tail: "..."
concerns:
  - <one line — non-blocking observation>
  - <one line>
```

```yaml
status: NEEDS_CONTEXT
summary: <one line — what is missing>
needs:
  reason: history-too-short | missing-file | unclear-spec | missing-doc
  detail: <what specifically the subagent needs>
```

```yaml
status: BLOCKED
summary: <one line>
blocker:
  category: context-insufficient | task-too-large | spec-contradictory | env-broken | model-not-capable
  detail: <what happened>
```

## Rejection rule (Iron Law)

If a subagent returns `status: DONE` or `status: DONE_WITH_CONCERNS` without a complete `verification` block (all three keys: `command`, `exit_code`, `stdout_tail`), the controller MUST reject the response with this message:

> "Run the verification command, capture its stdout (last 30 lines) and exit code, return them in the verification block, then re-submit. The Iron Law of /delegate-with-context: claim without evidence is not accepted."

The controller treats the rejected response as if it were `status: BLOCKED, blocker.category: env-broken` and re-dispatches a fresh subagent with the same task plus the rejection notice prepended.

## Examples

### DONE — green test run

```yaml
status: DONE
summary: implement parse_decimal validator with locale fallback
verification:
  command: "pytest backend/tests/test_validators.py -v"
  exit_code: 0
  stdout_tail: |
    tests/test_validators.py::test_parse_decimal_en PASSED
    tests/test_validators.py::test_parse_decimal_ru PASSED
    tests/test_validators.py::test_parse_decimal_invalid PASSED
    ===== 3 passed in 0.12s =====
```

### DONE_WITH_CONCERNS — green test plus observation

```yaml
status: DONE_WITH_CONCERNS
summary: add rate limiter to /api/v1/diagnostic
verification:
  command: "pytest backend/tests/test_api.py::test_rate_limit -v"
  exit_code: 0
  stdout_tail: |
    test_rate_limit PASSED
    ===== 1 passed in 0.04s =====
concerns:
  - rate_limit value (10 rpm) is hardcoded — should move to env var in follow-up
```

### NEEDS_CONTEXT — adaptive deepening trigger

```yaml
status: NEEDS_CONTEXT
summary: cannot determine why send_report() retries 3 times
needs:
  reason: history-too-short
  detail: bundle includes last 5 commits but the retry logic was introduced earlier; need history reaching back to the original implementation of send_report
```

### BLOCKED — task too large

```yaml
status: BLOCKED
summary: scope is bigger than one task
blocker:
  category: task-too-large
  detail: spec asks to refactor anamnesis pipeline + add new endpoint + migrate DB schema in one pass; recommend split into 3 sub-tasks via bd dep add ... --type discovered-from
```

## Spot-check note (R3 — deferred)

Controller MAY randomly pick a fraction of returned `verification` blocks (e.g., 10–20%) and re-run the reported `command` itself, comparing its own `stdout_tail` against the subagent's. Mismatch flags suspicious agent behavior.

This is a defense against fabricated evidence. Implementation is **deferred to a follow-up Beads issue** — first version of the skill ships without it. Document it here so reviewers know it is a known gap, not an oversight.
