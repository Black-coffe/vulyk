# Uncommitted-work guard, diff before ACCEPTED, quotes are not corrections (plan)

**Tier:** 2 · **Spec slug:** `uncommitted-work-guard` · **Brief:** [brief.md](brief.md)
**Governed by:** study `docs/specs/claude-code-mods-9/report.md` (C1-C4 and the cross-model grill), ADR-021 (rules tree,
cards), ADR-025 (red receipt), card `safeguard-bypassable-or-late`, card `shell-needs-gnu-or-bash4`
**Depends on:** 0.47.0 (`e00bab6`)

## Goal
VULYK stops losing uncommitted work to git. A new PreToolUse hook on `Bash|PowerShell` denies the git verbs that
throw away work: always for a subagent, and for the main session only when the paths the verb would discard are
dirty or untracked, naming them. `/vulyk-status` and the SessionStart brief name any enabled mod that handles
`tool.check`, because on a personal login such a mod can lift a hook's block. Before the owner's ACCEPTED, the
pack's diff is in the reply as text. Correction words inside a quote no longer count as the owner's correction.
`docs/pulse.md` says which mods fight pulse for the same rows.

## Assumptions
- **The verb list** comes from the study and the grill:
  - `stash`, with or without `-u`, plus `drop` and `clear`;
  - `checkout .`, `checkout -f`, and `checkout [<ref>] -- <path>`;
  - `restore`, worktree form;
  - `reset --hard`;
  - `clean -f`;
  - `switch -f` and `--discard-changes`;
  - `branch -D`;
  - `worktree remove --force`.

  The read-only forms pass: `stash list` and `stash show`, soft and mixed `reset`, `checkout -b`, `clean -n`, and
  `restore --staged` on its own. A subagent with a git verb whose arguments cannot be read is denied.
- **What is not covered**, named in the hook header and `docs/hooks-reference.md`:
  - `rm` and `Remove-Item` (the owner chose "только git");
  - `bash -c`, scripts and aliases;
  - a mod that answers `tool.check`.
- **Failure mode.** The hook fails open on its own crash, on a missing interpreter, or on a non-git command,
  which matches the platform default and `defect-intake.sh`. That is a named bypass, not a silent one.
- **Agents get no env off-switch.** The owner turns the guard off per hive the same way as other hooks: by
  removing the entry from `.claude/settings.json`, which `install.sh` respects like `unwire_hook`. Whether the
  owner's `!` mode skips PreToolUse is not known, and the refusal text tells him to run the command in his own
  terminal.
- **Detecting a `tool.check` mod.** A grep for `tool.check` in the hooks modules of the plugins enabled in the
  user and project settings. It is a heuristic and is described as one.
- **No card for the 2026-11-03 diff lesson.** No verbatim owner words for it exist in the repo. Story 02 changes
  the procedure and the script.
- **The guard's own card**, `work-discarded-by-git-verb`, has `## Owner quotes` empty. It describes the two
  incidents by shape, since the repo is public. Its `check:` is the hook run on fixture inputs.
- **No new `## Commands` row:** `CLAUDE.md` is at its byte cap. Guard tests go in `tests/maintenance.test.sh`,
  which already holds the hooks.

## Stories

**Wave 1** (the Queen builds them in order)
- `uncommitted-work-guard-01-guard` — the hook, its wiring, the `tool.check` line in the brief and status, the card
  with a failing check, and tests (`red: required`)
- `uncommitted-work-guard-02-diff-before-accepted` — `human-check.sh --show` and the reply-text rule in `/vulyk-build`
- `uncommitted-work-guard-03-quotes-and-pulse` — intake routes quoted correction words to "are these your words?",
  plus the pulse coexistence note

## Contracts
none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas

<!--
The lines below are the cycle's confirmation markers (docs/cycle.md); each placeholder is replaced by
the command or script that owns it, and scripts/ship-check.sh reads them all. Approved is the owner's
word, the stop at Tier 2-4; Briefed is written by `cycle.sh briefed` instead, at Tier 1 ("via
mini-brief"), with `--go`, or in no-question mode ("assumed"). Either closes stage 02. Council and
Checked close stages 04+05 together: a GREEN council row is enough on its own, and Checked is the
owner's override in either direction, newest timestamp wins. No line of this comment may start with
a marker: the scripts read the first line that does.

There is no default tier: `cycle.sh open-round` refuses to open a round while the `**Tier:**` line above
is missing or unparsable.
-->
**Approved:** Andrei, 2026-11-05
**Briefed:** <written by scripts/cycle.sh briefed - stage 01+02 on the straight-through path (--go, Tier 1): "via grill, <owner>, <date>" (or "via grill (assumed)" / "via mini-brief"). Alternative to **Approved:** above.>
**Branch:** vulyk/uncommitted-work-guard
**Checked:** <written by scripts/human-check.sh after the owner has looked - stage 05, and the override for stage 04+05. /vulyk-ship refuses without either this or a GREEN **Council:** line.>
**Council:** <written by scripts/cycle.sh judge/escalate - stages 04+05: "<GREEN|RED|ESCALATE|STALE> round <N>, <date>, at <sha7>, pack <fp12>[ - red: 2,5]", appended once per round.>
**Shipped:** <written by scripts/ship-check.sh --record - stage 06: the published version, and where>
