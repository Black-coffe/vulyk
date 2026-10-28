---
story: auto-memory-subagent-start-01-story-read-cards
spec: auto-memory-subagent-start
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: no card on a story Read
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
- [ ] Read of a fixture story whose `## Files` names a path a text card scopes prints that card; the same agent reading it again prints nothing; a later Edit of that path by the same agent prints nothing for that card.
- [ ] Read of `brief.md`, of a non-story `.md` and of a source file prints nothing.
- [ ] Upgrade of a hive on the `Edit|Write|MultiEdit|NotebookEdit|Bash|WebFetch|WebSearch|Agent|mcp__.*` matcher ends with the new matcher and `defects-inject.sh` wired once; a hand-set matcher stays.
- [ ] Time of one non-story Read through the hook, measured on this machine, is written in `## Implementation notes`.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash tests/telemetry.test.sh --part library`
`bash tests/telemetry.test.sh --part wrapper`
`bash tests/telemetry.test.sh --part upgrade`

## Implementation notes

## Findings
