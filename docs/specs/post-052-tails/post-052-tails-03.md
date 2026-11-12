---
story: post-052-tails-03
spec: post-052-tails
status: todo
returned:
tier: 2
worker: worker-code
wave: 3
blocked_by: [post-052-tails-02]
red: required           # a new branch in the busy guard (subfolder sessions, cwd match) that decides a write into hives
red_reason:
---

# A session opened in a hive's subfolder makes the hive busy

## Goal
`hives-behind.sh --busy <hive>` also sees a session started in a subfolder of the hive. Claude Code names the
transcript folder after the session's working directory, so such a session writes under `<slug>-<rest>`, which the
exact-slug lookup from story 01 never reads. A transcript folder whose name starts with `<slug>-` counts only when a
fresh transcript in it carries a `"cwd"` that is the hive path or below it (so a sibling hive such as `X:/Acme_co`
does not make `X:/Acme` busy); a fresh transcript whose `cwd` cannot be read makes the hive busy. Found by a side
agent's note on 2026-11-12, after story 01 closed (plan delta).

## Requirements
> 7. Шаг 2a /vulyk-ship на каждом выпуске перепроверяет все паузы и перед обновлением любого улья проверяет, не занят ли он: обновляется только улей с чистым деревом на своей ветке, без файла сборки DRIVER и без записи в журнал сессии за последние 60 минут; если журналы улья не найдены - он считается занятым; занятый улей получает паузу с причиной. Перед коммитом в улье проверка повторяется: появились чужие файлы - стоп и сообщение владельцу. Первая такая проверка проходит при выпуске этой правки, до 19.11.

## Files
- scripts/hives-behind.sh
- tests/maintenance.test.sh
- CHANGELOG.md

## Non-goals
- Do not change the exact-slug path, the 60-minute window, the roots or the `unknown` rule.
- A prefix folder does not count as "transcripts found" for `unknown`: only the exact folder does (unchanged).
- No map edit here: `/vulyk-ship`'s drone-docs pass carries the `--busy` bullet.

## Map slice
`memory/map/scripts.md` (`hives-behind.sh`)

## Acceptance criteria
- [ ] A fresh transcript under `<root>/projects/<slug>-sub/` whose first `"cwd"` is `<hive>/sub` makes `--busy` print `busy` (exit 1).
- [ ] A fresh transcript under `<slug>-x/` whose `cwd` is a sibling path (`<hive>_x`, not under `<hive>/`) leaves the hive `idle`.
- [ ] A fresh transcript under `<slug>-sub/` with no readable `"cwd"` makes the hive `busy`.
- [ ] `cwd` comparison ignores `\` vs `/` and the drive letter's case; JSON-escaped `\\` is read as one separator.
- [ ] CHANGELOG `[Unreleased]` busy-hive entry mentions subfolder sessions.

## Verification
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
