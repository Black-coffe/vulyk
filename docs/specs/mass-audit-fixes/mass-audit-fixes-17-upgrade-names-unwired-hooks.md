---
story: mass-audit-fixes-17
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 4
blocked_by: [mass-audit-fixes-11]
red: required
red_reason: an unwired shipped hook is not named on upgrade
---

# `--upgrade` names every shipped hook the hive does not wire

## Goal
Story 04 made `install.sh` wire every shipped hook into an existing `settings.json` only when the previous
release did not ship that script (`wire_shipped`); on `--upgrade` a hook that is missing from a hive's settings
is read as the owner's choice and passed over in silence. A hive that lost hooks to the old installer bug keeps
running without them, and nobody is told. After this story `--upgrade` (and `--check`) prints one line per hook
this release ships that the hive's `settings.json` does not wire: `unwired <event>: <script> - to wire it: <command>`,
where `<command>` is a real, copy-pasteable `install.sh` invocation that wires only that hook. It never wires one
unasked: a hook the hive owner removed on purpose stays removed. Ask 18. Blocked by story 11 (same files).

## Requirements
> 18. (Added by the owner mid-build on 2026-11-09, choice «Сказать + раскатка (Рекомендую)».) `install.sh --upgrade` names every hook this release ships that the hive's `settings.json` does not wire, one line each with the command that wires it, and never wires it unasked; at rollout the Queen wires, per hive, the hooks the old installer bug dropped.

## Files
- install.sh
- tests/telemetry.test.sh

## Non-goals
- Do not change what `wire_shipped` or `fix_hooks` wire on their own today (story 04): this story only adds the
  report and the one-hook wiring command it names.
- Do not wire any hook during `--upgrade` that the hive's settings lack; the rollout step is the Queen's, not code.
- Do not edit `tests/telemetry.test.sh` outside the `install` and `install-xp` parts.

## Map slice
`memory/map/scripts.md` → `install.sh` (upgrade, settings wiring).

## Acceptance criteria
- [ ] `--part install-xp`: a hive whose `settings.json` lacks two shipped hooks gets exactly two `unwired` lines
  on `--upgrade` and on `--check`, and its `settings.json` is unchanged after both (the failing label contains
  `an unwired shipped hook is not named on upgrade`). Original case: a hive that lost hooks to the pre-0.50 wiring.
- [ ] Running the printed command wires that one hook and nothing else; a second `--upgrade` prints no line for it.
- [ ] Neighbour form: a hive that wires every shipped hook prints no `unwired` line; a hook wired in the wrapper
  form (`bash -c`, `${CLAUDE_PROJECT_DIR}`) counts as wired.
- [ ] `bash scripts/portability-check.sh install.sh` is clean.

## Verification
`bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part install`

## Implementation notes

## Findings
