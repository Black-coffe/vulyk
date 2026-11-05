---
story: uncommitted-work-guard-01
spec: uncommitted-work-guard
status: todo
returned:
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
red_verified_at:
---

# Uncommitted-work guard hook

## Goal
A PreToolUse hook `.claude/hooks/git-guard.sh` on `Bash|PowerShell` denies the git verbs that discard work (the plan's
`## Assumptions` list; read-only forms pass). The hook input carries `agent_id` for a subagent, and a subagent is
denied every listed verb with no `git status` call. A main-session verb is denied only when `git status --porcelain`
shows the paths it would discard dirty or untracked, and its reason lists them (cap 10, then `+N more`) with the safe
path: commit them as their own commit, leave them, or run the command yourself in your own terminal. It fails open
on its own error, a missing interpreter or a non-git command. It is wired in this repo's `.claude/settings.json`
and by `install.sh` (`wire_hook`, respecting a removed entry). The SessionStart brief and `/vulyk-status` print one
line naming each enabled plugin whose hooks module mentions `tool.check`, and print nothing when there is none.
Card `docs/defects/work-discarded-by-git-verb.md` with a `check:` that runs the hook on its fixtures.

## Requirements
> 1. Предохранитель: воркерам всегда запрещены git-команды, стирающие работу, главной сессии — если пропадут незакоммиченные файлы (со списком этих файлов), только git, без rm.
> 2. Строка о моде с tool.check — при старте сессии и в /vulyk-status.

## Files
- .claude/hooks/git-guard.sh
- .claude/settings.json
- install.sh
- .claude/hooks/session-start-brief.sh
- .claude/commands/vulyk-status.md
- docs/defects/work-discarded-by-git-verb.md
- docs/defects/work-discarded-by-git-verb.original.fixture
- docs/defects/work-discarded-by-git-verb.neighbour.fixture
- docs/defects/INDEX.md
- docs/hooks-reference.md
- tests/maintenance.test.sh

## Non-goals
- No `rm` / `Remove-Item` parsing (owner: «только git, без rm»).
- No env switch an agent could set; no `ask` decision; no model call.
- Do not touch `worker-code.md`'s prose rule; it stays as the explanation.

## Map slice
memory/map/scripts.md (install.sh upgrade contract, `wire_hook`/`unwire_hook`); docs/hooks-reference.md

## Acceptance criteria
- [ ] Subagent input (`agent_id` set) with `git stash`, `git checkout -- f`, `git reset --hard`, `git clean -fd` -> deny; `git stash list`, `git checkout -b x`, `git status` -> no decision.
- [ ] Main session, tree with a dirty `memory/stats/skills.json`: `git checkout -- memory/stats/skills.json` -> deny naming that file (the original case); the same with a clean tree -> no decision (the neighbour).
- [ ] PowerShell tool input with `git stash` from a subagent -> deny.
- [ ] Broken JSON or no interpreter -> exit 0, no output.
- [ ] `bash scripts/defects-check.sh docs/defects/work-discarded-by-git-verb.md` fails on the fixtures before the hook exists (red) and passes after.
- [ ] A fake plugin dir whose hooks module says `tool.check` gives one brief line; none gives no line.

## Verification
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh docs/defects/work-discarded-by-git-verb.md`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
