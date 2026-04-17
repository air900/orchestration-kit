# Mode 1 & Mode 2 — annotated examples and domain walkthroughs

This file backs the skeletons in `SKILL.md` Output template section for Modes 1 and 2. Load it when you need to see what a filled report looks like or when your target project is in an unfamiliar domain.

## Contents

- Mode 1 annotated output — code audit (WordPress plugin security release)
- Mode 2 annotated output — proposal review (React state-management refactor)
- Cross-domain Part 1 compliance walkthroughs (code / content / infra / design)
- Cross-domain Part 2 rubric in action

## Mode 1 annotated output — code audit

Example: auditing a just-landed security fix on a WordPress plugin before `bd close`.

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: 1 POST-TASK-AUDIT
Task: web-scripts-gxu7 — Fix ail sanitizer template pollution
Commit(s): a1b2c3d

### Verdict: WARNINGS

### Part 1 — Protocol compliance
[x] A. Beads description — 6-point (file:line, repro, context, resources)
[ ] B. Close reason — solution + root cause + prevention ticked; verification
      has "tested locally" but no command output snippet (severity: BLOCKED
      for Part 1, downgraded because smoke script lives in /tmp/smoke-ail.php
      that was reviewed in session)
[x] C. Commit message includes issue ID (gxu7)
[x] D. Notes updated during work (4 note entries)
[ ] E. README.md in src/plugins/ail/ NOT updated despite code changes to
      includes/ (pvbridge feedback rule) — severity: BLOCKED for Part 1
[x] F. git push done; open sibling tasks have progress notes

### Part 2 — Expert judgement

Layer 1 — Diagnosis: Correct. The fix identifies `wp_kses_post()` as the wrong
primitive for template text (strips intended markup) and specifies the replacement.
Root cause is at the sanitizer level, not at the consumer.

Layer 2 — Approach: Right layer (sanitizer function itself is replaced, not a
wrapper added in every caller). Right primitive (`sanitize_textarea_field` is the
WP-idiomatic choice for multi-line template text).

Layer 3 — Execution: Narrow diff, one-file change. Test exists but as a /tmp
smoke script — not integrated into PHPUnit suite.

Band-aid signals found:
- (none in the fix itself)
- E6 No regression test — the regressed class ("template pollution from
  wrong sanitizer") could recur; CI would not catch it.

Structural signals found:
- sA2 Correct primitive adopted (sanitize_textarea_field → right for template text)
- sD2 Class of bugs eliminated (any template string going through this path is
  now sanitized correctly, not just the reported instance)
- sE6 Proportionate complexity (one-line function call swap, zero new abstractions)

### Alternative path
No substantially different path — the fix matches what a principal reviewer
would do. Only recommendation is to lock it in with a regression test:
- Add a PHPUnit test case in tests/test-sanitizer.php that feeds a template
  string containing expected markup + script-injection attempt, asserts that
  legitimate markup survives and injection is neutralised.
- Track as follow-up: web-scripts-aob (PHPUnit backfill, already filed).

### Action items
1. Add test command output snippet (even of the /tmp smoke run) to close reason
   point 4, or wait until aob lands the proper PHPUnit test before closing gxu7.
2. Update src/plugins/ail/README.md with changelog entry for the sanitizer fix.
3. Then `bd close gxu7 --claim-next`.

### If verdict != APPROVED
- Do NOT call bd close yet.
- Preserve findings: `bd update gxu7 --notes "WORKFLOW-GATE-CHECK: missing
  verification artefact + README sync. See above."`
- Re-run /workflow-gate-check after fixing.
```

## Mode 2 annotated output — proposal review

Example: second opinion on an agent's proposal to refactor dashboard state management, before code is written.

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: 2 MID-TASK-SECOND-OPINION
Proposal source: agent chat message proposing "wrap each panel in its own
  useContext provider to fix the stale-data bug in the activity feed"

### Verdict: BLOCKED

### Part 2 — Expert judgement

Layer 1 — Diagnosis: Suspect. The bug is described as "stale data in activity
feed". The proposal assumes root cause = shared context re-rendering issue.
But the bug ticket (dashboard-42) describes the feed showing 30-sec-old data
even with a fresh context — this is a fetch/refetch staleness issue, not a
render-path issue. Wrong layer diagnosed.

Layer 2 — Approach: Wrong layer AND architectural fight. Splitting one context
into six providers fights the codebase's existing direction (the app has been
consolidating to a single `DashboardContext` per the v2.0 migration plan in
docs/architecture/). The proposed split would partially revert that migration.

Layer 3 — Execution: N/A — proposal does not solve the actual problem, so
execution quality is moot.

Band-aid signals found:
- D1 Wrong problem framing — diagnosis points at re-render, real issue is
  data freshness (stale query cache).
- A1 Wrong layer — if the refetch-interval is the issue, it belongs in the
  data layer (SWR / TanStack Query config), not the context layer.
- A6 Fight with design intent — reverses the v2.0 context consolidation.

Structural signals found:
- (none — proposal does not have structural merits)

### Alternative path
The activity feed shows stale data because its TanStack Query uses the default
5-min stale time while the user expects ~30s refresh.

Approach fresh:
- Set `staleTime: 30_000` and `refetchInterval: 30_000` on the `useActivityFeed`
  query (or whatever the feed hook is called — check src/hooks/).
- Keep the single DashboardContext as-is.
- Validate: open feed, wait 30s, verify refetch happens (network panel).
- This is a 3-line config change, not a 200-line refactor.

What this buys us:
- Fixes the actual bug (freshness) at the data layer.
- Preserves the v2.0 context architecture.
- Avoids 6 new provider components and their testing burden.

### Action items
1. Reject current proposal.
2. Reply to agent: "The bug is a data-freshness issue, not a render-path issue.
   See dashboard-42 user report: data is stale even after context refresh. The
   fix is staleTime / refetchInterval on useActivityFeed, not a context split."
3. Re-run /workflow-gate-check 02 on the revised proposal.
```

## Cross-domain Part 1 compliance walkthroughs

Part 1 grades process, not domain-specific content. But what "evidence" looks like varies — here is one per domain.

### Code session

`bd show` description (6-point):
- *What:* Null-pointer in user profile cache when user has no avatar.
- *Where:* `src/cache/profile.ts:142`, function `getUserAvatar`.
- *How:* `getUserAvatar({ userId: 101 })` returns `undefined.url`.
- *Known:* Happens when user never uploaded avatar; default path is not set in `new-user` code path.
- *Context:* Surfaced during onboarding QA for feature-X.
- *Resources:* `src/cache/profile.ts`, test `tests/cache/profile.test.ts`, screenshot `assets/qa/crash-101.png`.

Close reason point 4 verification: `npm test -- profile.test.ts` output + new test file committed.

### Content session

`bd show` description (6-point):
- *What:* avers020-article-n42 missing lawyer quote required by brand voice rule.
- *Where:* `assets/aversgroupp.ru/articles/n42.md`, section "Legal framework", lines 120-145.
- *How:* Open the article; section is present but lacks required quote block format.
- *Known:* Brand voice rule (2026-03-12) mandates lawyer quote in every legal article; rule was not applied during first draft.
- *Context:* Discovered during avers030 fact-check pass.
- *Resources:* Article file, brand voice rule `docs/brand/voice-legal.md §3.2`, SERP screenshot `assets/research/n42-serp.png`.

Close reason point 4 verification: article rendered in staging + link to staging URL + Playwright screenshot of new section.

### Infrastructure session

`bd show` description:
- *What:* s04 VPN node fails SSL renewal after docker compose pull.
- *Where:* `docs/runbooks/node-upgrade.md`, step 3 (cert-refresh).
- *How:* `ssh root@s04 && docker compose pull && docker compose up -d` → nextcloud container shows "cert expired" in logs.
- *Known:* xray-core must start AFTER nextcloud cert refresh; current compose order starts them in parallel (new discovery).
- *Context:* Surfaced during s04 upgrade (followed s03 successful upgrade).
- *Resources:* compose file, `docker logs nextcloud` snippet `docs/runbooks/s04-upgrade-2026-04-17.md`.

Close reason point 4 verification: upgrade re-run with `depends_on: nextcloud` added, curl SSL test output captured.

### Design session

`bd show` description:
- *What:* Dashboard empty-state lacks sufficient colour contrast for WCAG AA.
- *Where:* `assets/designs/dashboard/empty-state.fig` frame "Empty — No activity".
- *How:* Load the Figma frame; Stark plugin reports 3.9:1 on the secondary text.
- *Known:* Brand palette's `gray-500` on `gray-100` background falls below 4.5:1 threshold.
- *Context:* Accessibility audit raised it; affects all empty-states using secondary text on subtle background.
- *Resources:* Figma frame, Stark report export `assets/designs/dashboard/a11y-report-2026-04-17.pdf`.

Close reason point 4 verification: updated frame screenshot + re-run Stark report showing ≥4.5:1.

## Cross-domain Part 2 rubric in action

The Diagnosis → Approach → Execution layering works identically across domains. Only the *vocabulary* of findings adapts.

- **Code:** "Layer 2 wrong primitive — `wp_kses_post` used where `sanitize_textarea_field` belongs."
- **Content:** "Layer 2 wrong primitive — listicle structure used where brief promised expert-interview angle."
- **Infra:** "Layer 2 wrong primitive — `sed` in deploy script used where `envsubst` belongs (sed breaks on delimiter collisions)."
- **Design:** "Layer 2 wrong primitive — `opacity: 0.5` used where `color: token-gray-400` belongs (opacity breaks contrast calculations for a11y tools)."

When grading a proposal or a landed change in a domain you are less familiar with, default to asking "what is the domain-idiomatic right-tool-for-the-job here, and did the author reach for it or for a close-enough workalike?" — that is the universal form of `A2 Wrong primitive`.
