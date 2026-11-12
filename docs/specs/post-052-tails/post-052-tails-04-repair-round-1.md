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

## Acceptance criteria
- [ ] The class card under docs/defects/ (its quote, Never line or check:) is added or updated in the same commit as the fix.

## Files
- 1.
- docs/defects/*

## Verification
`bash tests/maintenance.test.sh`
