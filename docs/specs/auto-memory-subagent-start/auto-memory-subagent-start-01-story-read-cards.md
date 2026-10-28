---
story: auto-memory-subagent-start-01-story-read-cards
spec: auto-memory-subagent-start
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: ::error::a hive on the 0.32 matcher gets the one with Read
red_verified_at: 2026-10-28T15:18:18Z 47a4d0c1a61c1477ac69070a465cca747d2e0a8e212d2557fa4e77ec9eadedc0
---

# Cards on reading a story

## Goal
A `Read` of a story file (`docs/specs/<slug>/<name>.md` with `story:` in its frontmatter) makes
`defects-inject.sh` print the text cards whose `paths:` match any `## Files` entry of that story, under the
same budget, order and per-agent dedup as today, as PreToolUse `additionalContext`. Any other Read prints
nothing, and the bash half exits before starting python unless the input names `docs/specs/`. `Read` joins
the PreToolUse matcher in `.claude/settings.json` and in `install.sh` (`INJECT_MATCHER`); a hive still on
the 0.32 matcher is unwired and rewired on upgrade, as the 0.19 one is.

## Requirements
> 1. Когда агент читает файл истории, ему сразу показываются карточки docs/defects/ для файлов её ## Files, до первой правки, каждая карточка один раз на агента.
> Сейчас defects-inject.sh срабатывает на PreToolUse (когда агент уже решил вызвать инструмент). Если подключить его ещё и на SubagentStart (фильтруя карточки по ## Files истории, которую передали воркеру), то worker-code получит нужные карточки «Нельзя / Как надо» (docs/defects/) до первого хода мышления, не читая лишних файлов.

## Files
- .claude/hooks/defects-inject.sh
- .claude/settings.json
- install.sh
- tests/inject.test.sh
- tests/intake.test.sh
- tests/telemetry.test.sh
- docs/hooks-reference.md
- docs/wiki/rules-tree.md

## Non-goals
- No `SubagentStart` or `SubagentStop` hook.
- Do not change card parsing in `defects_lib.py` or the dedup state format.
- Do not deliver on reading `brief.md`, `plan.md` or any non-story file.

## Map slice
memory/map/scripts.md: the defect hooks section; docs/wiki/rules-tree.md: Delivery.

## Acceptance criteria
- [x] Read of a fixture story whose `## Files` names a path a text card scopes prints that card; the same agent reading it again prints nothing; a later Edit of that path by the same agent prints nothing for that card.
- [x] Read of `brief.md`, of a non-story `.md` and of a source file prints nothing.
- [x] Upgrade of a hive on the `Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*` matcher ends with the new matcher and `defects-inject.sh` wired once; a hand-set matcher stays.
- [x] Time of one non-story Read through the hook, measured on this machine, is written in `## Implementation notes`.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/telemetry.test.sh --part library`
`bash tests/telemetry.test.sh --part wrapper`

## Implementation notes
- `defects-inject.sh`: bash leaves on a Read whose input names neither `docs/specs/` nor `docs\\specs\\`; python `story_files()` takes `## Files` entries (backticks stripped, `<!-- -->` lines skipped) of a `docs/specs/<slug>/<name>.md` with `story:` in its frontmatter. Checked by hand with a backslash Windows `file_path` too (the test fixture paths are forward-slash).
- Non-story Read median through the hook on this machine: 71 ms over 30 calls (YouTube_AI library copy); the Edit path stays where it was. Asserted <= 100 ms in the latency part.
- `install.sh` rewires the 0.19 and 0.32 matchers (one ERE with an optional tail); a hand-set matcher is kept (intake test).
- Verification trimmed: `telemetry --part upgrade` dropped, it never reads the matcher (`PRE_M` is used by `library` and `wrapper` only).
- Red receipt sealed on the installer half: the first `&&` segment (`intake.test.sh`) failed before `inject.test.sh` ran; the story-read cases were red too in a direct run (3 failed of 71) before any implementation edit.

## Findings

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 47a4d0c1a61c1477ac69070a465cca747d2e0a8e212d2557fa4e77ec9eadedc0 (tests/inject.test.sh, tests/intake.test.sh, tests/telemetry.test.sh)
- impl: 9c81db90c7c1f74deb9021355e803c1d5a444b3c79b4de487af2247cda01dccc
- stamped: 2026-10-28T15:18:18Z

```
  ok    median latency <= 200 ms
--- --lexicon exports the lexicon as ERE lines
  ok    --lexicon exits 0 without reading stdin
  ok    a stem matches at a word start (переделайте)
  ok    neighbour: a stem inside a word does not match
  ok    a phrase with a punctuation edge matches (again!)
  ok    neighbour: a phrase needs both edges (against)
  ok    a capitalised Cyrillic stem matches under a UTF-8 locale
  ok    one ERE line per stem and phrase of the hook's own lists
intake.test.sh: 74 checks, 2 failed
```
