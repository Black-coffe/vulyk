---
story: post-052-tails-04
status: done
returned: DONE
worker: worker-code
model: opus
wave: 4
blocked_by: []
narrow: true
red: required
red_reason: hives-behind --busy: a fresh Workflow agent transcript (depth 5) is busy
red_verified_at: 2026-11-12T20:41:17Z 6b9f4efaa6f5fd2d0930643cd5809eddd11e6a3eeebfeb7f4e469f02f7489620
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 7. Шаг 2a /vulyk-ship на каждом выпуске перепроверяет все паузы и перед обновлением любого улья проверяет, не занят ли он: обновляется только улей с чистым деревом на своей ветке, без файла сборки DRIVER и без записи в журнал сессии за последние 60 минут; если журналы улья не найдены - он считается занятым; занятый улей получает паузу с причиной. Перед коммитом в улье проверка повторяется: появились чужие файлы - стоп и сообщение владельцу. Первая такая проверка проходит при выпуске этой правки, до 19.11.

## Implementation notes
- Finding 1: `fresh_jsonl` drops `-maxdepth`, so Workflow agent transcripts 5 levels down count; a real hive with ~1200 transcripts answers in 0.5 s.
- Finding 2: the `--slug` test uses `E:/Hives/Acme_co`; registered hive names and slugs masked in story 01's receipt, story 03, plan.md, this story and the round-1 review record (`<hive slug, masked>`, `X:/Acme`). Branch commits before this one still carry them: `/vulyk-ship` step 1 (fix history) must scrub them before any push. Card host-internals-in-public-repo unchanged: its Allowed line already names synthetic stand-ins.
- Minors: fixture folder `hbz` (a path in an unknown line no longer satisfies a busy check); split check wants >= 4 slices; on Windows the cwd match is case-insensitive (`same_case`), with a test that runs only there.
- Finding 6 (owner): step 2a canary bullet - a busy canary is held, not red; one upgraded green canary carries the rollout, owner told it was one shape; both busy stops and names the sessions. No test pin added: the test file was sealed by the receipt before the owner's answer.

## Findings
1. scripts/hives-behind.sh:116 [ask 7] `--busy` must count a transcript written in the last 60 minutes at any depth under the hive's transcript folder: Workflow agents write `<slug>/<session>/subagents/workflows/<wf>/agent-*.jsonl` (depth 5), `-maxdepth 3` never reads them, so a hive whose only fresh writes are a running Workflow's (main session quiet for an hour, no DRIVER file) is reported `idle` and upgraded - repro: `R=$(mktemp -d); mkdir -p $R/h; s=$(bash scripts/hives-behind.sh --slug $R/h); mkdir -p $R/r/projects/$s/sid/subagents/workflows/wf; : > $R/r/projects/$s/sid/subagents/workflows/wf/agent-a.jsonl; VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h` prints `idle`, exit 0 (the same file one level up at `sid/subagents/` prints `busy`); in this repo's own transcript folder 593 of 1181 transcripts sit at that depth and 4 past sessions had Workflow writes with no shallower write in the hour before (one stretch 135 minutes); a build that claimed a DRIVER is still caught by the first sign.

2. docs/specs/post-052-tails/post-052-tails-01.md:75 [unanchored] card `host-internals-in-public-repo` (Never: another project's transcript slug in this repository): the `--slug` test at tests/maintenance.test.sh:1147 and the red receipt that quotes it must use a synthetic stand-in path, not the path and transcript slug of a hive in the registry - evidence: `grep -n '<hive slug, masked>' tests/maintenance.test.sh docs/specs/post-052-tails/post-052-tails-01.md`; `leak-check.sh` passes on it, so nothing else stops it before a publish.
3. (minor) tests/maintenance.test.sh:1149 the fixture folder is named `busy`, so every `expect ... "busy"` also passes on an `unknown ...` line that names the path; the checks tell busy from idle, not busy from unknown.
4. (minor) scripts/hives-behind.sh:126 the subfolder `cwd` match is case-sensitive past the drive letter, so on Windows a registry path spelled in another case than the session's `cwd` leaves a subfolder session unseen.
5. (minor) tests/maintenance.test.sh:1198 the split check accepts 2 slices where ask 5 names 4.
6. (owner, plan delta 2026-11-12) A busy canary is held, not red: one upgraded green canary lets the rollout go on, the owner is told it was smoke-tested on one hive shape, the held canary goes first next ship; both busy stops the rollout and names the canary sessions to close.

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix. (Finding 1 has no owner correction behind it, so no card; finding 2 is card host-internals-in-public-repo, whose Allowed line already names synthetic stand-ins: the fix applies it, the card text is unchanged.)
- [ ] `--busy` reads fresh transcripts at any depth under the hive's transcript folders (a depth-5 Workflow agent transcript is busy).
- [ ] No registered hive's path, name or transcript slug remains in the spec files, the test or the receipts: synthetic stand-ins only.
- [ ] Minors 3-5: busy checks cannot pass on an unknown line; the split check wants 4 slices; on Windows the cwd match ignores case.

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh
- docs/specs/post-052-tails/post-052-tails-01.md
- docs/specs/post-052-tails/post-052-tails-03.md
- docs/specs/post-052-tails/plan.md
- .claude/commands/vulyk-ship.md

## Verification
`bash tests/maintenance.test.sh`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 6b9f4efaa6f5fd2d0930643cd5809eddd11e6a3eeebfeb7f4e469f02f7489620 (tests/maintenance.test.sh)
- impl: 74aa192728014b287b04428d92d38562dbd7d6c9c758bab728588ea118973c0d
- stamped: 2026-11-12T20:41:17Z

```
::error::hives-behind --busy: a fresh Workflow agent transcript (depth 5) is busy - expected 'busy' in:
  ok    ship 2a: the local-beta step ends on hives-behind.sh
  ok    ship 2a: the step skips by name without a registry
  ok    ship 2a: the dev build is never pushed
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 595 checks, 2 failed
```
