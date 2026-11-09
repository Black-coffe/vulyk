---
story: mass-audit-fixes-04
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: hook command quotes the project dir
red_verified_at: 2026-11-09T13:02:00Z 4621326c9bc021dc41a8b4e0b122295796e08ebd2a9a53ca1fb960f01dbde65f
---

# install.sh wires every hook into an existing settings.json, quoted, with its timeout

## Goal
A hive that already has `.claude/settings.json` gets every hook VULYK's own `settings.json` ships
(`session-start-brief.sh`, the five `handoff.sh` events, `context-guard.sh`, `skill-usage-counter.sh`, in
addition to the nine wired today), each logged as `wire <event> <name>` or `kept <event> <name>`; a SessionEnd
entry carries `"timeout": 30`, and `--upgrade` adds it to an existing SessionEnd entry that lacks one. Every
hook command, in `.claude/settings.json` and in every entry `install.sh` writes (the `REL` matcher and the
`by_hand` template), is `"$CLAUDE_PROJECT_DIR"/.claude/hooks/<name>.sh [arg]`, so a hive under a path with a
space runs its hooks; `py_wire`'s sibling matcher accepts both heads and `--upgrade` rewrites an old-form entry
in place (`rewire <name>`). JSON `install.sh` writes is UTF-8 with `ensure_ascii=False`, LF line endings and a
trailing newline. Asks 6 and 11; private audit (2026-11-08) findings I2, S1/P1, P7; contributor limit (2) of
P10-03. Marked red: a config write that must reach live hives.

## Requirements
> 6. P10-03 extended: `install.sh --upgrade` gives existing hives' SessionEnd hooks their `timeout`, as part of the I2 fix (install into an existing `settings.json` wires every hook and says so).
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- install.sh
- .claude/settings.json
- tests/telemetry.test.sh

## Non-goals
- Do not touch `shippable()`, `owned()`, the removal loop, `copy_tree`, `shipped_blobs`, the mod install or the
  `top-model.sh --apply` call: story 11 (wave 3) owns those parts of `install.sh`.
- Do not change which events a hook runs on, and do not remove an entry the owner deleted (a missing entry on
  a hive that had the version shipping it stays the owner's choice, as `git-guard.sh` does today).
- Do not edit `docs/hooks-reference.md` (story 13).
- Mind the CR-byte trap: edit `install.sh` with Edit, never through a Python text-mode rewrite.

## Map slice
`memory/map/scripts.md` → install.sh - the upgrade contract, Gotchas; `memory/map/cycle.md` is not needed.

## Acceptance criteria
- [ ] `bash install.sh <repo with {"permissions":{"allow":[]}}> --telemetry off` wires the same 17 entries a
  fresh install copies, prints one `wire`/`kept` line per hook, and `--check` prints `would wire` for each.
- [ ] After the install, every `hooks.*[].hooks[].command` in the hive's `settings.json` starts with
  `"$CLAUDE_PROJECT_DIR"/.claude/hooks/`; `--upgrade` on a hive wired in the old form rewrites each entry and
  logs `rewire`; a second `--upgrade` changes nothing.
- [ ] One wired hook runs through `sh -c "<command>"` with `CLAUDE_PROJECT_DIR` set to a path containing a
  space and exits 0 (the failing-test label contains `hook command quotes the project dir`).
- [ ] Every SessionEnd entry has `timeout` >= 10 after a fresh install and after `--upgrade` of a hive whose
  SessionEnd entries had none.
- [ ] A hive `settings.json` holding a Cyrillic permission rule keeps it readable after install, and the file
  ends with a single LF and has no CR bytes.
- [ ] `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` is clean; `bash scripts/portability-check.sh
  install.sh` is clean.

## Verification
`bash tests/telemetry.test.sh --part wiring && bash tests/telemetry.test.sh --part install`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
- `install.sh` py_wire: REL is `"$CLAUDE_PROJECT_DIR"/.claude/hooks/`; the old plain head is excluded from sibling templates too; a new SessionEnd entry gets `"timeout": 30`.
- `install.sh` wire_hook: an already-wired hook prints `kept ...` (real run, --check, no-python path); `by_hand` is quoted and carries the SessionEnd timeout.
- `install.sh` new `wire_shipped` wires the 8 missing hooks under git-guard's rule (only when v$PREV did not ship the script), so an owner's removal stays.
- `install.sh` new `fix_hooks` pass: rewires plain-form entries of scripts this release ships (`rewire`), adds timeout 30 to SessionEnd entries lacking one (`timeout`); owner hooks and wrappers untouched.
- Every json.dump in install.sh: `ensure_ascii=False`, `newline='\n'`, trailing LF.
- `.claude/settings.json`: all 17 commands quoted.
- `tests/telemetry.test.sh` wiring part: 17-entry install into `{"permissions":{"allow":[]}}`, --check, space-path sh -c run, old-form upgrade (rewire, timeout, Cyrillic, LF); existing absent-needles narrowed for the new `kept` lines; wrapper plain case expects the quoted head.
- Surprise: a heredoc inside `$(...)` fails portability-check (bash 3.2); fix_hooks writes python output to a mktemp file.

## Findings

## Red receipt
- command: bash tests/telemetry.test.sh --part wiring && bash tests/telemetry.test.sh --part install
- exit: 1
- tests: 4621326c9bc021dc41a8b4e0b122295796e08ebd2a9a53ca1fb960f01dbde65f (tests/telemetry.test.sh)
- impl: 0da64f88baf8b31d0df06daad701515004f360ec0d4bd52a199d4c9a55f426fd
- stamped: 2026-11-09T13:02:00Z

```
::error::fresh install: every hook command quotes the project dir - expected [0], got [17]
::error::fresh install: hook command quotes the project dir - exit 126 from sh -c: $CLAUDE_PROJECT_DIR/.claude/hooks/defects-inject.sh
::error::install into an owner's settings.json: hook command quotes the project dir - exit 126 from sh -c: $CLAUDE_PROJECT_DIR/.claude/hooks/defects-inject.sh
          write          .claude/vulyk-manifest (102 paths)
        
        Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched.
        If the constitution changed this release, the note above says by how much and how to migrate.
  ok    and no second unwiring
  ok    and no second rewire
  ok    and no second timeout
  ok    --check reports no wiring for an already-wired hook
  ok    --check reports no unwiring once it is done
telemetry.test.sh: 47 checks, 19 failed
```
