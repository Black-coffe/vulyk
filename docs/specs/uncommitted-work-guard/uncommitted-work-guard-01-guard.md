---
story: uncommitted-work-guard-01
spec: uncommitted-work-guard
status: done
returned: DONE
tier: 2
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: git-guard: a subagent's git stash is denied
red_verified_at: 2026-11-05T21:39:28Z d293da66ba70066e81c62f57dabdd2b0ee0d7bc149091f0e2b1614a5e38a08aa
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
- `.claude/hooks/git-guard.sh`: bash wrapper + Python half in one file (the `defect-intake.sh` pattern); stdin read with
  the `read -d ''` builtin, so an empty PATH exits 0 in silence. Commands are cut with `shlex` (punctuation `;&|()`,
  PowerShell escape `` ` ``); git counts only at a command position (after `VAR=x`, `&`, `env`...), global `-C` is followed.
- Main session: `git -c core.quotePath=false -C <cwd> status --porcelain --untracked-files=all -- <paths>`; tracked
  entries count for stash/checkout/restore/reset/switch, untracked for `clean -f` and `stash -u`. `stash drop/clear`
  and `branch -D` lose a stash or commits, not tree files: denied to subagents only (named in the header).
- `checkout <x>` with one positional counts as a path only when it exists under the call's cwd; a branch switch passes.
- `--check <file>`: the card's check; a `porcelain` field in the fixture stands in for `git status`. A missing hook
  makes the gate red (bash exits 127), which is what the red receipt saw.
- Brief: the `tool.check` line is bash only (grep of enabledPlugins = true in user + project settings, install paths
  from `installed_plugins.json`, `grep -r tool.check <path>/hooks`); `/vulyk-status` step 7 greps it out of the brief.
- `install.sh`: wired only when `v$PREV` did not ship `git-guard.sh`, so an owner's removal survives later upgrades.
- Surprise: none of the telemetry `library` part's wiring checks moved (part re-run green, 20 checks).

## Findings

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: d293da66ba70066e81c62f57dabdd2b0ee0d7bc149091f0e2b1614a5e38a08aa (docs/defects/work-discarded-by-git-verb.md, tests/maintenance.test.sh)
- impl: 6be439ae7c05833ea935f5d9f5fe80b948c7cc25f033b65b8a2897788186c6a4
- stamped: 2026-11-05T21:39:28Z

```
::error::git-guard: a subagent's git stash is denied - expected '"deny"' in:
::error::git-guard: --check passed the neighbour fixture
::error::git-guard: --check failed on the card itself
--- git guard: a mod with tool.check
::error::git-guard: an enabled mod with tool.check gets a brief line - expected 'fakemod@local' in:
        [VULYK] no map yet - run /vulyk-bootstrap or /vulyk-map | start at memory/memory.md
        [VULYK] litopys (session chronicle plugin) is not installed here. Ask the owner once: install (`claude plugin marketplace add Black-coffe/litopys --scope project` then `claude plugin install litopys@litopys --scope project`) or decline (then add Profile row `| Chronicle | none (declined <date>) |`).
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
maintenance.test.sh: 362 checks, 55 failed
```
