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
| Missing file:line / page URL / asset path in Resources | Edit the task record's description — add to Resources block; if no task record exists, create one with the 6-point template |
| `S1` volatile artefact (reference-worthy) | Commit to project's artefact location (see persistence-path table below); use `orchestration-config.json` `documentation.paths` as source of truth for project-configured locations; link from the handoff file |
| `S2` missing design decision | Append a `### Decision: <id> — <choice>` block to the handoff file with rationale + rejected alternatives |
| `S3` implicit mapping (short) | Append a `### Mapping: <topic>` block to the handoff file |
| `S3` implicit mapping (long, >20 lines) | Commit to `docs/orchestration/handoff/NNN-<topic>-<subtopic>.md` and link from the handoff file |
| `S4` discovered constraint (per-task) | Append a "CONSTRAINT:" note in the related task record; if cross-session pattern, ALSO append to CLAUDE.md or `docs/orchestration/conventions.md` |
| `S5` external reference | Add URL to Resources block in the task record's description AND to the handoff file's External references section |

## Persistence-path auto-detect table

Before deciding where to commit an `S1` artefact, inspect the target project for these signals. Pick the path whose kind matches the artefact's kind. If `orchestration-config.json` defines `documentation.paths`, those values take precedence over the auto-detect heuristics below.

| Detection signal | Preferred persistence path |
|---|---|
| `tests/` dir + test runner config (`phpunit.xml`, `jest.config.*`, `pytest.ini`, `cargo test`, etc.) | `tests/fixtures/<task-id>/` |
| Content project: `assets/` + `.md` outlines | `assets/research/<task-id>/` or `assets/<site>/research/<task-id>/` |
| Infra project: `docs/runbooks/` or ops-focused | `docs/runbooks/<task-id>-<date>.md` |
| Any project with `docs/orchestration/doc-drafts/` | `docs/orchestration/doc-drafts/<task-id>-<date>.md` (default for transcript-style notes) |
| Generic fallback | `docs/session-artefacts/<YYYY-MM-DD>/<task-id>-<slug>.<ext>` (create dir if missing) |

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
=== WF-GATE-CHECK REPORT ===
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
| aob  | ~70%   | S1 smoke /tmp LOST; S2 Option C rationale; S3 test→fix mapping; D2 bin/install-wp-tests.sh unclear | commit tests/fixtures/aob/smoke-*.php; append to handoff file: ### Decision: aob-option-c — chose C because [rationale]; rejected A (deadlock risk), B (over-engineered); edit task record (aob) description to cross-link the handoff file | ~95% |
| ebo  | ~60%   | S3 release→commits mapping absent; R6 Resources incomplete | edit task record (ebo) description with pre-extracted `git log` per version | ~90% |

### Artefacts persisted
- tests/fixtures/aob/smoke-rate-limiter.php (from /tmp, 45 lines, code-project test fixture)
- tests/fixtures/aob/smoke-encryption.php (from /tmp, 32 lines)

### Decisions recorded
- aob-option-c: rate-limiter Option C (lock release before sleep, retry on contention).
  Rejected: A (sync lock, deadlock risk), B (async queue, over-engineered for current scale).
- ckb-salt-migration: in-place with versioned salt.
  Rejected: fresh-install only (breaks backwards compatibility).

### Handoff file written
- docs/orchestration/handoff/001-v153-security-release-handoff.md

### Handoff summary — to next session
v1.53.0 landed with 8 security fixes. Highest-priority follow-up is web-scripts-aob
(PHPUnit backfill) — all fixtures and design rationale now in the issue. web-scripts-ebo
(changelog) can batch into the first WP admin-facing release.

### Remaining gaps (if any)
- aob S1 smoke scripts from /tmp were recovered FROM conversation transcript, not original
  files; verify one full run of each fixture before treating as authoritative.

### If verdict != APPROVED
- Review the `Remaining gaps` list.
- Either recover what is still recoverable, or record explicit notes in CLAUDE.md or
  docs/orchestration/conventions.md acknowledging the loss and next steps.
- Re-run /wf-gate-check 03 after fixing.
```

## Extended examples — domain-specific walkthroughs

### Code session walkthrough (PHP WordPress plugin)

Session closed `aob-audit-backfill`, open tasks `aob-phpunit` and `ebo-changelog`.

- Phase 0: both open tasks are `Discovered during: gxu7` ⇒ criterion (a). Plus `aob-phpunit` shares `tests/` path with current diff ⇒ criterion (b) reinforces.
- Phase 1 gaps on `aob-phpunit`: S1 (smoke scripts in /tmp/smoke-*.php from this session), S2 (29j Option C chosen in brainstorm, not recorded), S3 (per-fix assertion-shape mapping built in conversation).
- Phase 2 plan:
  - commit smoke fixtures: tests/fixtures/aob/smoke-*.php
  - append to handoff file: `### Decision: aob-option-c — chose C because [rationale]; rejected A (reason), B (reason)`
  - edit task record (aob) description to cross-link the handoff file
- Phase 3 applied. After: 95% completeness; next session can pick up aob and run immediately.

### Content session walkthrough (text4site avers020 article)

Session closed `avers020-article-n42`, open tasks `avers020-article-n43` (next in cluster), `avers030-fact-check-n42` (follow-up for same article).

- Phase 0: `avers030-fact-check-n42` is `blocks`→ just-closed (criterion a). `avers020-article-n43` is created in session (c) and shares cluster keyword (d).
- Phase 1 gaps: S1 (SERP screenshots + competitor URL list gathered this session, not filed), S2 (angle choice "expert-interview" vs "listicle" made after brainstorm, no record), S4 (discovered: audit-reshenie brand voice requires lawyer quote in every legal article — learned mid-session).
- Phase 2 plan: commit SERP artefacts to `assets/aversgroupp.ru/research/avers020-article-n42/`; append decision for angle choice to handoff file; append brand-voice constraint to CLAUDE.md or `docs/orchestration/conventions.md`.
- Phase 3 applied. After: 92% completeness.

### Infrastructure session walkthrough (vpn-manager node rollout)

Session closed `vpn-s03-upgrade`, open task `vpn-s04-upgrade` (next in sequence).

- Phase 0: `vpn-s04-upgrade` shares runbook path (b).
- Phase 1 gaps: S1 (docker logs snippets from s03 that exposed a DNS startup race), S2 (decided to stagger rollout 1-by-1 based on s03 low-disk), S4 (DNS startup order: xray-core must start after nextcloud's cert refresh, else SNI mismatch).
- Phase 2 plan: commit logs to `docs/runbooks/vpn-s04-upgrade-2026-04-17.md`; append rollout-strategy decision to handoff file; append DNS order constraint note to the task record (vpn-s04-upgrade).
- Phase 3 applied.

### Design session walkthrough (mobile-first dashboard)

Session produced breakpoint variants, open task `dashboard-empty-states`.

- Phase 0: shared asset path, keyword "dashboard" (b+d).
- Phase 1 gaps: S1 (Figma exploration frames saved as PNGs in /tmp), S2 (chose 320/768/1280 breakpoints not 360/720/1024, no record), S4 (brand palette restricts dashboard to 2 accent colours max).
- Phase 2: commit PNGs to `assets/designs/dashboard/exploration/`; append breakpoint decision + brand constraint to handoff file.
- Phase 3 applied.
