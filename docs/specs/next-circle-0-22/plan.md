# Next circle 0.22: ship on one yes, bootstrap offered, reviewer minors, hosts upgraded (plan)

**Tier:** 2 · **Spec slug:** `next-circle-0-22` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-010, ADR-013, ADR-016, `docs/self-evolution.md` ("It runs itself"), `docs/specs/auto-maintenance/plan.md` (next-circle table)
**Depends on:** v0.21.1 (`3427d50`, published)

## Goal
Finish making VULYK usable by someone who knows only plan, build, update and handoff. A green build ends
with one question - «Выпускаем?» - and a yes runs `/vulyk-ship` itself. A project whose Profile still holds
`<fill in` rows is offered `/vulyk-bootstrap` once, by the SessionStart brief. The three round-1 minors of
`skills-json-exempt` close and README gets its v0.21 line. Then every host moves from 0.19 to this release,
merged locally, not pushed.

## Assumptions
- A1. The ship question uses `AskUserQuestion`; with no such tool (`claude -p`), the old behaviour stays:
  recommend `/vulyk-ship` in one line. A "no" prints that line too. Push and publish stay the owner's
  (`/vulyk-ship` step 3 unchanged).
- A2. Bootstrap is offered, never run without a yes (it is an interview). Not offered in the VULYK repo
  itself (marker: `telemetry/inbox/` exists - its Profile is the template), nor once the Profile carries a
  `| Bootstrap | declined <date> |` row (same pattern as the litopys offer's `Chronicle` row).
- A3. Hosts are the distinct git repositories among the directories that carry `.claude/vulyk-version`
  (`E:/Projects/*`, `D:/*`); the many `E:/Projects/fibi-*` directories are worktrees of one or a few repos -
  group them by `git rev-parse --git-common-dir` and upgrade each repo once, on its default branch.
- A4. Host procedure (the rollout section below) runs after this spec ships, as operations in other
  repositories - not a story (Law 3: stories touch only VULYK's files).
- A5. Version 0.22.0 (minor: new behaviour in build and the brief).

## Stories

**Wave 1**
- `next-circle-0-22-01-reviewer-minors` — ADR-010 reversal note, cycle.test.sh marker outside the fixture repo and stale label, README v0.21 line.
- `next-circle-0-22-02-ship-on-yes` — green terminal of `/vulyk-build` and `/vulyk-review` asks «Выпускаем?» and runs ship on yes.
- `next-circle-0-22-03-bootstrap-offer` — SessionStart brief offers bootstrap once in an unfilled hive.

## Contracts
- none

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n && bash tests/maintenance.test.sh && bash tests/cycle.test.sh && bash tests/solo.test.sh && bash tests/telemetry.test.sh`

## Rollout (after ship, ask 4)
For each host repository (A3), in this order - Varto first (the one on 0.19.1), then the rest:
1. Read its state: `git -C <repo> status --short`, current branch, default branch, and whether
   `E:/Projects/.vulyk-upgrade/<name>` (branch `vulyk/upgrade-0.19`) exists. A host whose main checkout is
   dirty or not on its default branch: do the upgrade on the worktree branch, do not merge, report it.
2. Upgrade on the branch `vulyk/upgrade-0.19` (rename to `vulyk/upgrade-0.22`), created from the default
   branch where it does not exist: `bash E:/Projects/vulyk/install.sh <worktree> --upgrade --constitution replace`
   (the installer keeps the host's Profile and Commands blocks and backs the old constitution up). Read the
   log for WARNING lines.
3. Check in the worktree: `bash .claude/hooks/handoff.sh status`, `jq -e . .claude/settings.json`,
   `echo '{}' | bash .claude/hooks/session-start-brief.sh`, `bash scripts/top-model.sh --floor`; grep the
   host's own `CLAUDE.md` for stale `TOP_MODEL =` pins (memory: katan had one).
4. Commit on the branch (`vulyk: upgrade to 0.22.0`), merge into the default branch locally (`--no-ff`),
   remove the worktree. No push.
5. One line per host in the final report: version before/after, merged or why not, warnings.

## Descoped

*(empty)*

## Plan deltas

**Approved:** Andrei, 2026-09-29 - "да" to the next-circle list; grill answers in brief.md
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** vulyk/next-circle-0-22
**Checked:** <written by scripts/human-check.sh>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
