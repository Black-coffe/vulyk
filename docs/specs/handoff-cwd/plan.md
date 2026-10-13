# /vulyk-handoff runs from any folder of the hive (plan)

**Tier:** 1 · **Spec slug:** `handoff-cwd` · **Brief:** [brief.md](brief.md)
**Governed by:** Law 6 (the owner's bug becomes a defect card with a failing check); `docs/defects/README.md`
**Depends on:** v0.26.0 (48a1350); shares no file with `constitution-merge`

## Goal
`/vulyk-handoff` stops depending on the folder the session's shell drifted into. Its two injections name their scripts
through `${CLAUDE_PROJECT_DIR}` and pass `${CLAUDE_SESSION_ID}` to the dump, which then reads exactly this session's
transcript (found by its file name, whatever the project folder's slug), writes into the hive the hook lives in, and
never overwrites a handoff file that is already there (the owner's global hook names its files the same way). A defect
card makes the class checkable: a command or skill whose `!` injection names a script by a relative path fails the
gate, in both injection forms.

## Assumptions
- The quoted `allowed-tools` form `Bash(bash "${CLAUDE_PROJECT_DIR}/...":*)` matches in default permission mode:
  probed 2026-10-13 with `claude -p --setting-sources project --permission-mode default` (the owner's user settings
  carry `defaultMode: bypassPermissions`, which every earlier probe inherited). A control command with the same
  injection and no grant failed `Shell command permission check failed ... requires approval`; the fixed
  `/vulyk-handoff` ran both injections and wrote the handoff. Not probeable headlessly: a `cd` that survives between
  turns - the owner's look covers it (a hive in default mode, ask for `cd docs`, then `/vulyk-handoff`).
- Found by that probe, out of scope: in default mode the enrichment `Edit` of `.claude/handoff/*.md` is a Claude Code
  `safetyCheck` ("a sensitive file") that `allowed-tools: Edit` does not cover - one approval prompt per handoff in an
  interactive session, a refusal under `-p`. Same for the owner's global `/handoff`. Next circle.
- `dump` without a session id (an old command file, a manual run) keeps today's lookup, rooted at the hive instead of
  the cwd.
- A `cd` into a worktree under `.claude/worktrees/` makes `state.sh` snapshot that worktree (it roots itself with
  `git rev-parse` from the cwd); out of scope, noted for the record (Opus review).
- Ships as patch 0.26.1, ahead of `constitution-merge` (0.27.0) and `handoff-ownership` (0.28.0).

## Stories

**Wave 1**
- `handoff-cwd-01` — the command, `handoff.py dump`, `scripts/injection-check.sh`, the defect card with its fixtures and
  README row, the cases in `tests/maintenance.test.sh`

## Contracts
- `handoff.sh dump [<session-id>]` -> line 1 the handoff path, line 2 the context size (unchanged); with a session id the
  transcript is `<claude-config>/projects/*/<session-id>.jsonl`.
- `scripts/injection-check.sh <file>` -> exit 1 naming each `!` injection (inline or fenced) in a command, skill or
  `.fixture` file whose script path is relative; exit 0 for any other file and for a clean one.

## Integration gate
`bash tests/maintenance.test.sh` · `bash scripts/defects-check.sh` · `git ls-files '*.sh' | xargs -n1 bash -n` ·
`python -m py_compile .claude/hooks/*.py`

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - the approval stop>
**Briefed:** via mini-brief, Andrei, 2026-10-13
**Branch:** vulyk/handoff-cwd
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
