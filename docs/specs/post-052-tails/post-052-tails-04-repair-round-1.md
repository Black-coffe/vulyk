---
story: post-052-tails-04
status: todo
returned:
worker: worker-code
model: opus
wave: 4
blocked_by: []
narrow: true
red: required
red_reason:
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 7. Шаг 2a /vulyk-ship на каждом выпуске перепроверяет все паузы и перед обновлением любого улья проверяет, не занят ли он: обновляется только улей с чистым деревом на своей ветке, без файла сборки DRIVER и без записи в журнал сессии за последние 60 минут; если журналы улья не найдены - он считается занятым; занятый улей получает паузу с причиной. Перед коммитом в улье проверка повторяется: появились чужие файлы - стоп и сообщение владельцу. Первая такая проверка проходит при выпуске этой правки, до 19.11.

## Findings
1. scripts/hives-behind.sh:116 [ask 7] `--busy` must count a transcript written in the last 60 minutes at any depth under the hive's transcript folder: Workflow agents write `<slug>/<session>/subagents/workflows/<wf>/agent-*.jsonl` (depth 5), `-maxdepth 3` never reads them, so a hive whose only fresh writes are a running Workflow's (main session quiet for an hour, no DRIVER file) is reported `idle` and upgraded - repro: `R=$(mktemp -d); mkdir -p $R/h; s=$(bash scripts/hives-behind.sh --slug $R/h); mkdir -p $R/r/projects/$s/sid/subagents/workflows/wf; : > $R/r/projects/$s/sid/subagents/workflows/wf/agent-a.jsonl; VULYK_SESSION_ROOTS=$R/r bash scripts/hives-behind.sh --busy $R/h` prints `idle`, exit 0 (the same file one level up at `sid/subagents/` prints `busy`); in this repo's own transcript folder 593 of 1181 transcripts sit at that depth and 4 past sessions had Workflow writes with no shallower write in the hour before (one stretch 135 minutes); a build that claimed a DRIVER is still caught by the first sign.

2. docs/specs/post-052-tails/post-052-tails-01.md:75 [unanchored] card `host-internals-in-public-repo` (Never: another project's transcript slug in this repository): the `--slug` test at tests/maintenance.test.sh:1147 and the red receipt that quotes it must use a synthetic stand-in path, not the path and transcript slug of a hive in the registry - evidence: `grep -n '<hive slug, masked>' tests/maintenance.test.sh docs/specs/post-052-tails/post-052-tails-01.md`; `leak-check.sh` passes on it, so nothing else stops it before a publish.
3. (minor) tests/maintenance.test.sh:1149 the fixture folder is named `busy`, so every `expect ... "busy"` also passes on an `unknown ...` line that names the path; the checks tell busy from idle, not busy from unknown.
4. (minor) scripts/hives-behind.sh:126 the subfolder `cwd` match is case-sensitive past the drive letter, so on Windows a registry path spelled in another case than the session's `cwd` leaves a subfolder session unseen.
5. (minor) tests/maintenance.test.sh:1198 the split check accepts 2 slices where ask 5 names 4.

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

## Verification
`bash tests/maintenance.test.sh`
