# Brief: handoff-cwd

**Date:** 2026-10-13
**Tier:** 1 - one module (the session handoff: its command and its hook), a clear bug fix
**Source:** owner bug report with a screenshot; split out of `handoff-ownership` on the owner's word after a three-model
plan review (Fable 5.1, Opus 5.5, Sonnet 5.5 - `docs/specs/handoff-ownership/plan-review/`), so the fix ships as a
patch instead of waiting behind `constitution-merge`
**Escaped from:** none - both relative injections predate the spec system (`cf10a7c` v0.3.0 `handoff.sh dump`, `a3d824a` v0.9.1 `scripts/state.sh`)

## Request (verbatim)

> [Image #1] Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?

The screenshot, as text:

> /vulyk-handoff
>   Shell command failed for pattern "!`bash scripts/state.sh`": [stderr]
>   bash: scripts/state.sh: No such file or directory

The owner's word on the split, 2026-10-13, answering "Как поступаем с планом после рецензий?":

> Разделить и править (Рекомендую)

## Reproduction

Host `E:/Projects/AI`, sessions `465c0602` (2026-10-12 17:54Z) and `cf1d2449` (2026-10-13 13:14Z): the session `cwd`
at the failing `/vulyk-handoff` is a subfolder of the hive (`docs/specs/<client>/...`), reached through the model's own Bash
`cd /e/Projects/AI/docs/specs/<client>/... && ...`. Claude Code 2.1.296 keeps a `cd` that stays inside the project.
The same drift happened in the planning session itself (`cd` into `docs/specs/handoff-ownership/plan-review`).

## Recon

Full recon: `docs/specs/handoff-ownership/brief.md` `## Recon` and the three reviews in its `plan-review/`. What this
fix rests on:
- `.claude/commands/vulyk-handoff.md:9,13` are the only `!` injections in VULYK's commands and skills, both relative.
- Claude Code substitutes `${CLAUDE_PROJECT_DIR}` (the project root, `C:/...`) and `${CLAUDE_SESSION_ID}` in a command's
  body before its injections run, and `${CLAUDE_PROJECT_DIR}` in `allowed-tools` (probed headlessly by the planner and
  by the Opus reviewer; a path with a space works).
- `handoff.py` `project_root()` falls back to `os.getcwd()`; `dump` looks the transcript up as the newest `.jsonl`
  under the slug of `os.getcwd()` (`:1000-1003`, `newest_transcript_for_cwd` `:420`). From a drifted cwd: wrong folder,
  no transcript; in a hive with parallel sessions: possibly another session's transcript. Claude Code also cuts slugs
  over 200 characters and adds a hash.
- `handoff.py:704` and the owner's `~/.claude/hooks/context_guard.py:653` name handoffs by the same pattern
  `%Y%m%d-%H%M%S-<sid8>.md` in the same `<hive>/.claude/handoff/`: two dumps in one second overwrite each other.
- Python on Windows ignores `HOME` in `expanduser` (`handoff.py:53-54`); `tests/handoff-window.test.py:75` sets
  `USERPROFILE` too.
- `scripts/defects-check.sh:262` runs every `block` card's check on whatever `<arg>` the gate gets, regardless of
  `paths:`; the binary recognises both injection forms, `` !`cmd` `` and a fenced ```` ```! ```` block.

## Asks

1. Пытаюсь сделать в проектах work handoff и получаю ошибки. Ты можешь разобраться, в чём проблема, почему так выходит и как это побороть?
