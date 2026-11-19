---
story: tails-1115-14
status: done
returned: DONE
worker: worker-code
model: opus
wave: 6
blocked_by: []
narrow: true
red: required
red_reason: human-check.sh exit 0 with no redact.sh (missing)
red_verified_at: 2026-11-17T18:32:44Z 99dcedd78815f27ef2030d9307f6361bda1ab2a448cce36d65ccdf390df9e65d
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 4. Secret masking and leak checking cover the shapes listed privately, and a masking failure stops the write instead of passing it through (S15-S17); CI actions are pinned to immutable versions (S18).
> 6. Dead mechanisms are retired: the unwritten learnings chain and the never-read pre-compact snapshots, without deleting any data already in a hive.

## Findings
ASK 4: RED - secret masking, failure stops the write, CI pins - run: shapes piped to `bash scripts/redact.sh`; `PATH=/nonexistent bash scripts/redact.sh`; GitHub API on the 3 pinned SHAs; `sed -n 165,173p scripts/human-check.sh`, `sed -n 130,138p scripts/acceptance-log.sh` saw: long flags, inflected and Cyrillic values, user:pass masked; a failing redact prints [VULYK:REDACT-FAILED], exit 1; all 3 SHAs exist (HTTP 200); but human-check.sh and acceptance-log.sh still take the branch `else SAFE_NOTE=NOTE` when scripts/redact.sh is absent, so the note goes unmasked into committed ledgers where journal.sh and ship-check.sh refuse (read from the code, not run: a run would write in the court; no test covers it)
ASK 6: RED - dead mechanisms retired, no hive data deleted - run: `bash tests/maintenance.test.sh --part upkeep`; `sed -n 1,20p .claude/commands/vulyk-gc.md`; grep of snapshots and learnings in docs and skills saw: 166 checks 0 failed, context-guard.sh gone, the brief leaves learnings byte-identical; but /vulyk-gc still runs `find memory/snapshots -type f -mtime +14 ! -name .gitkeep -delete`, which now removes only data already in a hive; docs/memory-system.md:19 and docs/command-reference.md:39 still describe the PreCompact snapshot and "consolidate learnings (cap 40)" as live; insight-harvester and skill-gardener still list memory/learnings as inputs
1. tests/telemetry.test.sh:2855 [regression] suite telemetry part rg2 is red (also :2859, :2868): its three "nothing is written locally" checks must hold now that install.sh:2243 only offers the model pin, since they still expect the `null` that a settings.local.json created by the unconditional pin used to give - repro: `bash tests/telemetry.test.sh --part rg2` -> `8 checks, 3 failed` (expected [1 null], got [1 ]); base: `git show 8291c19b:install.sh` lines 2059-2067 run `top-model.sh --apply` with no flag, and `PART telemetry:rg2 ok 48s` in docs/specs/narrow-repair-1115/council/merge-suite.log
2. tests/council.test.sh:5388 [regression] suite council parts round-scope (282 s) and round-scope2 (234 s) are cut for running past 70% of their 300 s cap after story 13 added its cases to both: each part must end under 210 s, by a split, never a raised cap (card test-gate-one-long-limit, How-to) - repro: `bash scripts/suite-parts-check.sh docs/specs/tails-1115/council/round-1/suite.log` -> two `cut part ... (grew)` lines, exit 1; base: 156-187 s for both parts in docs/specs/narrow-repair-1115/council/*/suite.log
1. .claude/commands/vulyk-gc.md:15 [ask 6] with the PreCompact snapshot retired, `/vulyk-gc` must not delete snapshot files already in a hive: the line this diff rewrote still runs `find memory/snapshots -type f -mtime +14 ! -name .gitkeep -delete` (also vulyk-gc.md:2 and :10, .claude/agents/librarian.md:21), so the first gc after 14 days removes every snapshot the hive holds, against the ask's "without deleting any data already in a hive" and story 06's own "memory/snapshots/ is never touched"
- [regression] PART council:round-scope2 ok 234s cap 300s
- [regression] PART council:round-scope ok 282s cap 300s
- [regression] PART telemetry:rg2 FAIL 50s cap 300s
- Queen (2026-11-17): the inherited `Defect hooks` line of story 03 is dropped from `## Verification`: story 07 split
  that row; its two halves (`Defects`, `Inject`) are already listed.
- Worker (2026-11-17, NEEDS_CONTEXT, nothing edited): two RED asks need files outside `## Files`.
  ASK 4: the unmasked `else SAFE_NOTE="$NOTE"` branch lives in `scripts/human-check.sh` (:165-173) and
  `scripts/acceptance-log.sh` (:130-138); neither is listed, and the fix cannot go in `scripts/redact.sh`
  (the branch runs exactly when redact.sh is absent). ASK 6: besides the listed `.claude/commands/vulyk-gc.md`,
  the finding names `.claude/agents/librarian.md` (:21 snapshot prune), `docs/memory-system.md` (:19 PreCompact
  as live), `docs/command-reference.md` (:39 learnings cap 40, snapshot prune),
  `.claude/skills/_meta/insight-harvester/SKILL.md` and `.claude/skills/_meta/skill-gardener/SKILL.md`
  (memory/learnings as input). Question: add these 7 paths to `## Files` (and the test that seals the
  redact-absent refusal), or split ASK 4/6 into their own repair story?

- Queen (2026-11-17): widen this story, one story for the round. The seven paths join `## Files`. Ask 4: a missing
  or failing `scripts/redact.sh` stops `human-check.sh` and `acceptance-log.sh` from writing the note, as `journal.sh`
  and `ship-check.sh` already do, with a test of both scripts (original and neighbour form) in a test file this
  story names. Ask 6: no command or agent deletes snapshot or learnings files already in a hive; the docs and the two
  meta-skills stop naming the retired inputs. Then the review's two criticals (telemetry rg2 expectations; split the
  council parts round-scope and round-scope2 so each ends under 210 s, never a raised cap). Major 2 (token-report
  share) is unanchored: leave it for the next circle.
- Worker (2026-11-17, NEEDS_CONTEXT, stopped by PAUSE): `stamp-red` resumed four times (exit 7, lines 4, 10, 13,
  17), then returned exit 3 `paused: Andrei · owner: stop and fix the speed of building and testing VULYK in this repo
  first · 2026-11-17T18:13:03Z`. No red receipt yet, no implementation edit made. Tests written and left uncommitted
  in the tree (sealed set, before the receipt): `tests/maintenance.test.sh` part redact (redact.sh missing and a
  directory in its place, both scripts: 12 checks red today), `tests/telemetry.test.sh` rg2 (`rg_val` reads a
  missing file as `absent`; part green, 8 checks 0 failed), `tests/council.test.sh` split into round-scope (145 s),
  round-scope2 (146 s), new round-scope3 (98 s) and round-scope4 (46 s), all ok, timed four in parallel. Resume:
  once the PAUSE is lifted, rerun the same `stamp-red`, then the redact refusal in human-check.sh and acceptance-log.sh,
  the ask 6 docs/agent/gc edits and the card.

- Owner, 2026-11-17: «Чинить сейчас (Рекомендую)» for ask 4 (the redact refusal in both scripts, in this repair);
  «Всё на 0.55 (Рекомендую)» for the review's unanchored major and the minors. Under the owner's rule for this repo
  (checks sized to the change), `## Verification` is cut from the 35 inherited lines to the tests of this repair's
  files; the full suite runs once before merge.

## Implementation notes
- scripts/human-check.sh, scripts/acceptance-log.sh: no redact.sh (missing or not a file) now refuses, exit 1, nothing recorded; the `else SAFE_NOTE=NOTE` branch is gone.
- tests/maintenance.test.sh part redact: original (file missing) and neighbour (a directory in its place) for both scripts; red receipt taken before the fix.
- tests/telemetry.test.sh rg2: a missing settings.local.json reads `absent` (install.sh only offers the pin now); expectations updated.
- tests/council.test.sh: round-scope and round-scope2 cut into round-scope..round-scope4, each timed under 210 s in the earlier attempt; no cap raised.
- .claude/commands/vulyk-gc.md, .claude/agents/librarian.md: no snapshot prune step; snapshots and learnings stay untouched.
- docs/memory-system.md, docs/command-reference.md, the two _meta skills: the PreCompact snapshot and learnings are no longer named as live inputs.
- docs/defects/safeguard-bypassable-or-late.md: Never line extended with the redact-absent write case.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- tests/telemetry.test.sh
- tests/council.test.sh
- .claude/commands/vulyk-gc.md
- scripts/redact.sh
- .claude/hooks/handoff.py
- scripts/journal.sh
- scripts/ship-check.sh
- scripts/leak-check.sh
- tests/maintenance.test.sh
- tests/handoff-hooks.test.py
- tests/defects.test.sh
- CLAUDE.md
- .github/workflows/ci.yml
- scripts/tag-push-check.sh
- scripts/git-hooks/pre-push
- scripts/trace-autopsy.py
- .claude/commands/vulyk-ship.md
- docs/defects/public-release-per-change.md
- docs/defects/INDEX.md
- tests/cycle.test.sh
- tests/symbol-map.test.sh
- docs/defects/*
- scripts/human-check.sh
- scripts/acceptance-log.sh
- .claude/agents/librarian.md
- docs/memory-system.md
- docs/command-reference.md
- .claude/skills/_meta/insight-harvester/SKILL.md
- .claude/skills/_meta/skill-gardener/SKILL.md

## Verification
`bash tests/maintenance.test.sh --part redact`
`bash tests/maintenance.test.sh --part upkeep`
`bash tests/telemetry.test.sh --part rg2`
`bash tests/council.test.sh --part round-scope`
`bash tests/council.test.sh --part round-scope2`
`bash tests/council.test.sh --part round-scope3`
`bash tests/council.test.sh --part round-scope4`
`bash scripts/defects-check.sh`

## Red receipt
- command: bash tests/maintenance.test.sh --part redact
- exit: 1
- tests: 99dcedd78815f27ef2030d9307f6361bda1ab2a448cce36d65ccdf390df9e65d (tests/council.test.sh, tests/maintenance.test.sh, tests/telemetry.test.sh)
- impl: 16b3557073e36e7ce72a9e6fdc24fd06922083e8049594d6631251c9deb8b1f7
- stamped: 2026-11-17T18:32:44Z

```
::error::human-check.sh exit 0 with no redact.sh (missing)
--- human-check.sh --show: code paths first, spec paperwork after, inside the one cap (tails-1115-05, T16)
  ok    human-check --show: 400 paperwork lines leave the 20-line code diff whole
  ok    human-check --show: the code diff comes before the paperwork
  ok    human-check --show: paperwork past the cap is cut
  ok    human-check --show: code and paperwork share the 300-line cap
  ok    human-check --show: only paperwork changed prints as today
--- handoff.sh: a python3 that is a stub (the Windows Store alias, exit 49) is passed over (post-043-tails)
  ok    handoff.sh status with a stub python3 first on PATH reaches a working Python or exits 0
  ok    handoff.sh starts a working python3 once per call, never a probe beside it
maintenance.test.sh: 432 checks, 12 failed
```
