---
story: handoff-cwd-01
spec: handoff-cwd
status: todo
returned:
tier: 1
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# /vulyk-handoff runs from any folder of the hive

## Goal
A session whose shell cwd drifted into a subfolder of the hive runs `/vulyk-handoff` cleanly: the build-state view
regenerates, and the handoff lands in the hive's own `.claude/handoff/` with this session's transcript behind it,
without overwriting a file already there. A defect card catches the class from now on.

## Requirements
> [Image #1] Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?
> /vulyk-handoff
> Shell command failed for pattern "!`bash scripts/state.sh`": [stderr]
> bash: scripts/state.sh: No such file or directory
> Разделить и править (Рекомендую)

## Files
- .claude/commands/vulyk-handoff.md
- .claude/hooks/handoff.py
- scripts/injection-check.sh
- tests/maintenance.test.sh
- docs/defects/README.md
- docs/defects/command-injection-follows-cwd.md
- docs/defects/command-injection-follows-cwd.original.fixture
- docs/defects/command-injection-follows-cwd.fenced.fixture
- docs/defects/command-injection-follows-cwd.bare.fixture

## Non-goals
- Do not teach `handoff.py` the folder split (`subproject_globs`), and do not touch the owner's `context_guard.py`.
- Do not touch `scripts/state.sh` or `handoff.sh`: both already find their own paths.
- Do not change what the hook modes (`stop`, `prompt`, `precompact`, `sessionend`, `sessionstart`) take as their root:
  Claude Code gives them `CLAUDE_PROJECT_DIR`. Only the shell-invoked `dump` / `status` path changes, plus the
  no-overwrite rule where the file is written.
- Do not rewrite other commands' prose that tells the Queen to run `bash scripts/...`: model Bash calls recover from an
  error, injections abort the command.

## Map slice
memory/map/agents-and-commands.md (`vulyk-handoff`); memory/map/scripts.md (`state.sh`)

## Acceptance criteria
- [ ] `vulyk-handoff.md` runs `bash "${CLAUDE_PROJECT_DIR}/scripts/state.sh"` and
      `bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/handoff.sh" dump "${CLAUDE_SESSION_ID}"`; each injection starts with
      a prefix its `allowed-tools` names verbatim (a test checks it).
- [ ] `handoff.py dump <sid>` run from a subfolder of a temp hive, `CLAUDE_PROJECT_DIR` unset, `HOME` and `USERPROFILE`
      pointed at a temp home, writes into `<hive>/.claude/handoff/` and reads `<home>/.claude/projects/<any>/<sid>.jsonl`
      even when that folder's name is not the hive's slug; the same case fails on today's code.
- [ ] Without a session id, `dump` roots the transcript lookup at the hive, not at the cwd.
- [ ] A dump whose file name already exists in `.claude/handoff/` writes a new file beside it and changes nothing in
      the old one.
- [ ] `docs/defects/command-injection-follows-cwd.md`: a `block` card, the owner's words as a `2026-10-13 · ` quote line,
      `check: bash scripts/injection-check.sh <arg>`, three fixtures - the original (the old `vulyk-handoff.md`
      injections), a fenced ```` ```! ```` block, a bare `` !`scripts/state.sh` `` with no interpreter - and `paths:`
      covering `.claude/commands/*.md` and `.claude/skills/**/SKILL.md`; a row in the README `## Cards` table.
- [ ] `injection-check.sh` exits 0 on the card file itself and on every `.claude/commands/*.md` and
      `.claude/skills/*/SKILL.md` of this repo (the test loops over them); `bash scripts/defects-check.sh` is green with
      the card earned.

## Verification
`bash tests/maintenance.test.sh`
`python -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
