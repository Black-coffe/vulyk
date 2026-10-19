---
story: rules-tree-07
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 2. Разрешение — самостоятельная запись с областью и словами владельца; перебивает запрет только явной ссылкой на него (с фикстурой «проверка запрета на разрешённую форму не срабатывает»); пересечение без ссылки — действует запрет, гейт красный.
> 7. Фраза «внеси в запрет / правило / разрешение» (RU/UK/EN) в любом канале, включая вставки, — сессия сразу пишет карточку дословно; автонаходка без фразы — пишет сразу со строкой-отчётом и «отмени».
> 11. Разовый разбор приватной памяти в карточки — режим `/vulyk-gc`: в карточку / личное / удалить, одобрение одним списком, без фальшивых цитат, перенесённое удаляется из приватной памяти.

## Findings
ASK 7: RED - explicit phrase in any channel incl. pastes; auto-capture with «отмени» - run: defect-intake.sh prompt probes saw: «Вот это внеси в запрет» → never; «put this under allowed» → allowed; «додай до заборон» → never; phrase inside <pasted_content> → allowed (good); typed «опять ты обрезал фразу» → `file the quote now ... report one line with «отмени»` (good); BUT «внеси это в запрет» → <silent>: the RU/UK regexes require the verb directly before `в`, so the owner's commonest spoken form («внеси это / вот это в запрет», «добавь это в правило») is dropped without a word - the dictation channel the brief exists for (Q between 12 and 13) misses it
1. .claude/commands/vulyk-status.md:2 [regression] the agent + command description total must stay within DESCRIPTIONS_MAX_BYTES (4983 B) so `bash tests/maintenance.test.sh` (named in the plan's integration gate) is green: head measures 4998 B after ", defect counts" was added, base measures 4983 B (`git archive c468706 .claude/agents .claude/commands | tar -x -C <dir>; cat <dir>/.claude/agents/*.md <dir>/.claude/commands/*.md | tr -d '\r' | grep '^description:' | wc -c` -> 4983) - repro: `bash tests/maintenance.test.sh` prints `::error::agent + command descriptions 4998 B > 4983 B`, exit 1.
2. scripts/defects-check.sh:300 [ask 2] a permissive card whose `exception:` names a never card that has a `check:` must be a red EXCEPTION when it lists no `passes:` fixture (ADR-021 D9: the exception needs the fixture the never check passes), instead of `continue`-ing to GREEN - repro: in a scratch library with the test suite's `never` card (`status: block`, `check: bash check.sh <arg>`, 2 fixtures, `paths: ["src/never/**"]`) add `allow.md` with `paths: ["src/never/**"]`, `exception: never`, no `passes:`, one dated `## Allowed` line, uncommitted; `bash scripts/defects-check.sh` prints `GREEN: 1 blocking checks`, exit 0.
1. scripts/memory-triage.sh:37 [ask 11] the default memory dir must be derived the way Claude Code names it (every non-alphanumeric character of the repo path becomes `-`, so `D:/YouTube_AI` is `D--YouTube-AI`, not `D--YouTube_AI`), otherwise the triage reports `no private memory` and exits 0 for any hive whose path has `_`, `.`, a space or non-ASCII - repro: `printf '%s' "D:/YouTube_AI" | sed 's#[:/\]#-#g'` prints `D--YouTube_AI`, while `ls ~/.claude/projects` holds `D--YouTube-AI`.
2. .claude/commands/vulyk-status.md:2 [regression] the agent + command descriptions budget must stay within `DESCRIPTIONS_MAX_BYTES` (4983): the added "defect counts, " in the description makes them 4998 B, so `tests/maintenance.test.sh` fails, and that suite is in the plan's integration gate - repro: `bash tests/maintenance.test.sh` prints `::error::agent + command descriptions 4998 B > 4983 B` (1 failed); base evidence: the merge-base tree measures exactly 4983 B (`cat .claude/agents/*.md .claude/commands/*.md | tr -d '\r' | grep '^description:' | wc -c`) and passes.

## Files
- .claude/hooks/defects_lib.py
- scripts/defects-check.sh
- tests/defects.test.sh
- docs/defects/README.md
- CLAUDE.md
- .claude/rules/always.md
- .claude/rules/README.md
- docs/memory-system.md
- tests/maintenance.test.sh
- install.sh
- scripts/defects-index.sh
- docs/defects/INDEX.md
- .claude/commands/vulyk-status.md
- .claude/hooks/defects-inject.sh
- tests/inject.test.sh
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh
- .claude/settings.json
- docs/hooks-reference.md
- tests/telemetry.test.sh
- .claude/commands/vulyk-gc.md
- scripts/memory-triage.sh
- CHANGELOG.md
- docs/adr/014-defect-library.md
- docs/adr/018-*.md
- docs/adr/019-*.md

## Verification
`python -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash scripts/defects-check.sh`
`bash tests/maintenance.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`
`bash tests/telemetry.test.sh`
