# Mode 3 (Handoff Enrichment) — detailed references

This file holds tables and extended examples that support Part 3 of `SKILL.md`. Main file references this document; load it on demand when running Mode 3.

## Contents

- Gap → Action conversion table
- Persistence-path auto-detect table
- Cross-domain examples — what `S1`–`S5` look like per domain
- Mode 3 output template — annotated example
- Extended examples — domain-specific walkthroughs
  - Code session (PHP WordPress plugin)
  - Content session (text4site avers020 article)
  - Infrastructure session (vpn-manager node rollout)
  - Design session (mobile-first dashboard)

## Gap → Action conversion table

| Gap | Action |
|---|---|
| Missing file:line / page URL / asset path in Resources | `bd update <id> --description` — add to Resources block |
| `S2` missing design decision | `bd decision "<choice> — rationale: <why>. Rejected: <alternatives and why>."` |
| `S1` volatile artefact (reference-worthy) | Commit to project's artefact location (see persistence-path table below); add link to Resources in the bd issue |
| `S3` implicit mapping (short) | `bd update <id> --notes "ENRICHMENT: <mapping>"` |
| `S3` implicit mapping (long, >20 lines) | Commit to `docs/orchestration/doc-drafts/<issue-id>-<date>.md` and link from issue |
| `S4` discovered constraint (per-task) | `bd update <id> --notes "CONSTRAINT: <rule>"` |
| `S4` discovered constraint (cross-session pattern) | Above, additionally `bd remember "<rule>"` |
| `S5` external reference | Add URL to Resources block in `bd update --description` |

## Persistence-path auto-detect table

Before deciding where to commit an `S1` artefact, inspect the target project for these signals. Pick the path whose kind matches the artefact's kind.

| Detection signal | Preferred persistence path |
|---|---|
| `tests/` dir + test runner config (`phpunit.xml`, `jest.config.*`, `pytest.ini`, `cargo test`, etc.) | `tests/fixtures/<issue-id>/` |
| Content project: `assets/` + `.md` outlines | `assets/research/<issue-id>/` or `assets/<site>/research/<issue-id>/` |
| Infra project: `docs/runbooks/` or ops-focused | `docs/runbooks/<issue-id>-<date>.md` |
| Any project with `docs/orchestration/doc-drafts/` | `docs/orchestration/doc-drafts/<issue-id>-<date>.md` (default for transcript-style notes) |
| Generic fallback | `docs/session-artefacts/<YYYY-MM-DD>/<issue-id>-<slug>.<ext>` (create dir if missing) |

If multiple signals apply, pick the one closest in kind to the artefact (test fixture → `tests/fixtures/`; meeting-notes-like text → `doc-drafts/`). State the choice and reasoning in the enrichment plan.

## Cross-domain examples — what S1-S5 look like per domain

| Domain | Typical `S1` artefacts | Typical `S2` decisions | Typical `S3` mappings | Typical `S4` constraints |
|---|---|---|---|---|
| **Code** | smoke scripts in /tmp, test outputs, local benchmark JSON | algorithm choice, data-shape choice, library picked over alternative | test-file × fix × assertion-shape; module × caller list | lock ordering, re-render conditions, race windows |
| **Content** | research notes, SERP screenshots, competitor URL list, draft outlines | angle/framing, audience-tier choice, title pattern | keyword cluster × section × target-rank; draft × editor-note × revision | brand voice rules, legal/regulatory boundaries, SEO guardrails |
| **Infrastructure** | SSH transcripts, `docker logs` snippets, `kubectl describe` output | rollout order, SSL strategy, secret-rotation cadence | node × role × version; service × dependency × port | firewall rules, DNS ordering, start-order dependencies |
| **Design** | exploration sketches, colour/spacing variants tried | typography scale, grid choice, motion approach | screen × component × state; breakpoint × layout | accessibility requirements, device matrix, brand palette |

If a gap in a given session does not fit any domain example above, the categories `S1`–`S5` still apply — adapt the wording to the domain, don't force-fit a code metaphor onto content work.

## Mode 3 output template — annotated example

Skeleton template lives in `SKILL.md`. Below is a filled example for reference:

```
=== WORKFLOW-GATE-CHECK REPORT ===
Mode: 3 HANDOFF-ENRICHMENT
Session topic: v1.53.0 security release — 8 fixes landed, PHPUnit backfill deferred
Just-closed task: web-scripts-gxu7 — Security audit backfill
Related open tasks (criterion in brackets):
  - web-scripts-aob (a: discovered-from gxu7, P1 — PHPUnit backfill)
  - web-scripts-ebo (a: discovered-from gxu7, P3 — README changelog sync)

### Verdict: WARNINGS

### Per-task enrichment table

| Task | Before | Gaps found | Actions taken | After |
|------|--------|-----------|---------------|-------|
| aob  | ~70%   | S1 smoke /tmp LOST; S2 Option C rationale; S3 test→fix mapping; D2 bin/install-wp-tests.sh unclear | commit tests/fixtures/aob/smoke-*.php; bd decision "29j Option C …"; bd update --description with assertion-shape table; bd update --notes pointer to wp-cli template | ~95% |
| ebo  | ~60%   | S3 release→commits mapping absent; R6 Resources incomplete | bd update --description with pre-extracted `git log` per version | ~90% |

### Artefacts persisted
- tests/fixtures/aob/smoke-rate-limiter.php (from /tmp, 45 lines, code-project test fixture)
- tests/fixtures/aob/smoke-encryption.php (from /tmp, 32 lines)

### Decisions recorded
- <decision-id> 29j rate-limiter Option C (lock release before sleep, retry on contention).
  Rejected: A (sync lock, deadlock risk), B (async queue, over-engineered for current scale).
- <decision-id> ckb salt-migration strategy: in-place with versioned salt.
  Rejected: fresh-install only (breaks backwards compatibility).

### Remembered (cross-session)
- "test-pattern: rate-limiter regression tests use lock-contention two-process harness; see tests/fixtures/aob/"

### Handoff summary — to next session
v1.53.0 landed with 8 security fixes. Highest-priority follow-up is web-scripts-aob
(PHPUnit backfill) — all fixtures and design rationale now in the issue. web-scripts-ebo
(changelog) can batch into the first WP admin-facing release.

### Remaining gaps (if any)
- aob S1 smoke scripts from /tmp were recovered FROM conversation transcript, not original
  files; verify one full run of each fixture before treating as authoritative.

### If verdict != APPROVED
- Review the `Remaining gaps` list.
- Either recover what is still recoverable, or record explicit `bd remember` entries
  acknowledging the loss and next steps.
- Re-run /workflow-gate-check 03 after fixing.
```

## Extended examples — domain-specific walkthroughs

### Code session walkthrough (PHP WordPress plugin)

Session closed `aob-audit-backfill`, open tasks `aob-phpunit` and `ebo-changelog`.

- Phase 0: both open tasks are `discovered-from` gxu7 ⇒ criterion (a). Plus `aob-phpunit` shares `tests/` path with current diff ⇒ criterion (b) reinforces.
- Phase 1 gaps on `aob-phpunit`: S1 (smoke scripts in /tmp/smoke-*.php from this session), S2 (29j Option C chosen in brainstorm, not recorded), S3 (per-fix assertion-shape mapping built in conversation).
- Phase 2 plan: commit smokes to `tests/fixtures/aob/`, `bd decision` for Option C, `bd update --description` with assertion table.
- Phase 3 applied. After: 95% completeness; next session can `bd claim aob` and run immediately.

### Content session walkthrough (text4site avers020 article)

Session closed `avers020-article-n42`, open tasks `avers020-article-n43` (next in cluster), `avers030-fact-check-n42` (follow-up for same article).

- Phase 0: `avers030-fact-check-n42` is `blocks`→ just-closed (criterion a). `avers020-article-n43` is created in session (c) and shares cluster keyword (d).
- Phase 1 gaps: S1 (SERP screenshots + competitor URL list gathered this session, not filed), S2 (angle choice "expert-interview" vs "listicle" made after brainstorm, no record), S4 (discovered: audit-reshenie brand voice requires lawyer quote in every legal article — learned mid-session).
- Phase 2 plan: commit SERP artefacts to `assets/aversgroupp.ru/research/avers020-article-n42/`, `bd decision` for angle choice, `bd remember` for the voice constraint.
- Phase 3 applied. After: 92% completeness.

### Infrastructure session walkthrough (vpn-manager node rollout)

Session closed `vpn-s03-upgrade`, open task `vpn-s04-upgrade` (next in sequence).

- Phase 0: `vpn-s04-upgrade` shares runbook path (b).
- Phase 1 gaps: S1 (docker logs snippets from s03 that exposed a DNS startup race), S2 (decided to stagger rollout 1-by-1 based on s03 low-disk), S4 (DNS startup order: xray-core must start after nextcloud's cert refresh, else SNI mismatch).
- Phase 2 plan: commit logs to `docs/runbooks/vpn-s04-upgrade-2026-04-17.md`, `bd decision` for rollout strategy, `bd update --notes` for DNS order constraint.
- Phase 3 applied.

### Design session walkthrough (mobile-first dashboard)

Session produced breakpoint variants, open task `dashboard-empty-states`.

- Phase 0: shared asset path, keyword "dashboard" (b+d).
- Phase 1 gaps: S1 (Figma exploration frames saved as PNGs in /tmp), S2 (chose 320/768/1280 breakpoints not 360/720/1024, no record), S4 (brand palette restricts dashboard to 2 accent colours max).
- Phase 2: commit PNGs to `assets/designs/dashboard/exploration/`, decision + remember entries.
- Phase 3 applied.
