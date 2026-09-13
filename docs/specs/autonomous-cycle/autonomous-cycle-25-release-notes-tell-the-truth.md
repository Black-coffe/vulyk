---
story: autonomous-cycle-25
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 8
blocked_by: []
---

# The release notes describe the council that ships; the template offers Tier 1; CI proves the allow rules

## Goal
`CHANGELOG.md`'s `## [0.12.0]` entry says what v0.12.0 does after this repair: seats scale with the tier (C15), the court is an honour clause with a detector, the two drivers stop on failure and bound their retries the same way, staleness is code-only, and `--upgrade` never deletes a file. `templates/plan.md` offers `**Tier:** <1|2|3|4>` and says an unparsable tier stops `open-round`. The `install-smoke` job asserts the two `Bash(...)` allow rules exist in the installed target's settings.

## Requirements
> Tier 1+ — совет; Tier 0 — нет

> Мерж сам, публикация — нет

> Где Workflow недоступен — сегодняшняя петля в сессии, но через те же скрипты.

> The 0.12.0 entry must describe the shipped council

> the release notes must describe the two drivers' behaviour as it is, or the two drivers must actually match.

> an upgrade must retire framework-owned files the new version no longer ships, or say plainly that it does not.

> the `### Upgrading` paragraph says plainly that `--upgrade` never deletes and that `.claude/agents/drone-acceptance.md` is removed by hand, and the "verified from a real pre-0.12 install" claim is dropped

> the plan template must offer Tier 1, and the default for an unparsable `**Tier:**` must not silently buy the largest court.

> the install smoke job must prove the two allow rules exist in the installed target's settings.

## Files
- CHANGELOG.md
- templates/plan.md
- .github/workflows/ci.yml

## Non-goals
- Do not touch `VERSION`, `CITATION.cff` or `memory/memory.md` (already 0.12.0, story 13); do not edit the `## [0.11.0]` entry or earlier.
- Do not list this repair's findings as a `### Fixed` section — none of them shipped; describe 0.12.0 as it stands after stories 19-24, written from plan delta 6, not from diffs.
- Do not touch `install.sh` (m-3 is next circle) or restructure the `install-smoke` job; add assertions to its existing real-install and `--upgrade` steps.
- Do not invent measured numbers; the cost line stays the ADR's dated estimate.

## Map slice
`CHANGELOG.md:5-40` (the 0.12.0 entry, its `### Added/Changed/Removed/Notes/Upgrading` blocks) · `templates/plan.md:3` and the placeholder comment block at its end · `.github/workflows/ci.yml` job `install-smoke` (the real-install step story 14/16 extended; the `--upgrade` step) · `plan.md` delta 5 (C15) and delta 6: R6, R13, R15, R21, R22 · `install.sh` `wire_permissions` — the two rule strings, read only to copy them verbatim.

## Acceptance criteria
- [ ] `CHANGELOG.md` 0.12.0: seats by tier (Tier 1 `sonnet`; Tier 2 `sonnet`, `opus`, `lead-review`; Tier 3-4 the full court; Tier 4 a second reviewer), the `env` escalation as "every required seat ABSENT, or an ABSENT seat with nothing RED"; the court described per R15 (working tree holds only `brief.md`, history out of bounds, writes discarded — an honour clause with a detector); both drivers: stop on a failed verb, two attempts per story then `blocked`, one re-ask per seat, a RED round routes to `repair`; the staleness rule (only a non-paperwork commit stales a round); `### Upgrading` says `--upgrade` never deletes and `.claude/agents/drone-acceptance.md` is removed by hand, and no longer claims verification from a real pre-0.12 install; every path named exists in the tree.
- [ ] `templates/plan.md:3` reads `**Tier:** <1|2|3|4>`; one sentence in the file's comment block says `cycle.sh open-round` refuses a plan whose `**Tier:**` line is missing or unparsable.
- [ ] `install-smoke`: after the real install and after `--upgrade`, `jq -e` asserts `.permissions.allow` of the target's `.claude/settings.json` contains both `Bash(bash scripts/cycle.sh:*)` and `Bash(bash scripts/journal.sh:*)` exactly once each; the job's existing assertions stay.
- [ ] `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` still passes (no JSON touched); the YAML is what CI runs — say in the notes that it was not executed locally.

## Verification
`none — reviewed by lead-review`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
