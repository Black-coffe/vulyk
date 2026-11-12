---
story: post-052-tails-03
spec: post-052-tails
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 3
blocked_by: [post-052-tails-02]
red: required           # a new branch in the busy guard (subfolder sessions, cwd match) that decides a write into hives
red_reason: hives-behind --busy: a fresh session in a hive subfolder is busy
red_verified_at: 2026-11-12T19:57:15Z f28b53de0fc88e59525f03e0cb55c5553423b148bea121dd68a08aad0749e1b8
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
- `norm_path` (shared by `hive_slug` and the cwd match): `\` -> `/`, trailing `/` cut, Git Bash `/e/x` -> `E:/x`, drive upper-case; JSON `\\` becomes `//`, collapsed. Real transcripts write `"cwd":"E:\\Projects\\vulyk"` (checked).
- Prefix folders `<slug>-*` are scanned in every root, also when the exact folder is absent; they never count as "found" for `unknown`.
- Side-agent note (stale DRIVER from a dead build holds a hive forever): no age rule (a real Tier 3-4 build can run for hours); the busy line now names the file and the `cycle.sh release` command to free it. The vulyk source's own `docs/specs/weekly-budget/DRIVER` is left for the owner (vulyk is not a registered hive).
- Real probes: three registered hives idle; vulyk busy on the stale DRIVER.

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: f28b53de0fc88e59525f03e0cb55c5553423b148bea121dd68a08aad0749e1b8 (tests/maintenance.test.sh)
- impl: ee3aa6b467e1a71cecedc502a92d138c2e43bfe21c5a4578f3ae6b16528295ab
- stamped: 2026-11-12T19:57:15Z

```
::error::hives-behind --busy: a fresh session in a hive subfolder is busy - expected 'busy' in:
  ok    ship 2a: the local-beta step ends on hives-behind.sh
  ok    ship 2a: the step skips by name without a registry
  ok    ship 2a: the dev build is never pushed
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
maintenance.test.sh: 593 checks, 4 failed
```
