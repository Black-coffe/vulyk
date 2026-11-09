---
story: mass-audit-fixes-17
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 4
blocked_by: [mass-audit-fixes-11]
red: required
red_reason: an unwired shipped hook is not named on upgrade
red_verified_at: 2026-11-09T15:01:44Z 1a0eb38508cdea3a3ffd2555f1040545b3aaf1e43959160e7571c85b0544ce2b
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
- install.sh: `SHIPPED_HOOKS` table (wire_shipped hooks + git-guard.sh), `report_unwired` (py_wire --dry; grep without python), `--wire <event>:<script>` flag that wires one table entry through wire_hook and exits.
- install.sh: wire_shipped and the git-guard block call report_unwired on the path that used to skip in silence; what they wire is unchanged.
- Only hooks the release can skip are reported; always-wired hooks (wire_hook) are wired by the run itself, so --check keeps its "would wire" line for them.
- tests/telemetry.test.sh (install-xp): hive pinned at 0.49.0 (a tag that shipped every hook), two hooks dropped, one rewritten to the bash -c ${CLAUDE_PROJECT_DIR} form; neighbour all-wired hive.
- Test fix before green: the fixture dir `hive-xp-unwired` put "unwired " into the upgrade header (count 3); renamed to `hive-xp-lost`, count anchored to `^  unwired `; implementation reverted, red re-stamped, re-applied.
- Surprise: a Python edit through a bash heredoc turned `\n` into real newlines in printf strings; fixed with Edit.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part install-xp && bash tests/telemetry.test.sh --part install
- exit: 1
- tests: 1a0eb38508cdea3a3ffd2555f1040545b3aaf1e43959160e7571c85b0544ce2b (tests/telemetry.test.sh)
- impl: 568c3e406e6865bafb21cba0681e894065653c4036f34d8fb3787eb08a50c007
- stamped: 2026-11-09T15:01:44Z

```
::error::an unwired shipped hook is not named on upgrade: two unwired lines on --upgrade and on --check - expected [2 2], got [0 0]
          Every story '## Verification' line also runs under a 300 s cap (VULYK_VERIFY_TIMEOUT above 300 acts as 300):
          cut any row over ~210 s into --part rows before this hive takes this release. Your constitution is not edited.
          stamp          .claude/vulyk-version = 0.49.0
          write          .claude/vulyk-manifest (99 paths)
          kept: model = opus (yours)
        
        Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched.
        If the constitution changed this release, the note above says by how much and how to migrate.
  ok    a hive that wires every shipped hook: no unwired line
telemetry.test.sh: 57 checks, 7 failed
```
