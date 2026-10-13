# An upgrade carries a hive's own edits and deletions in framework files (plan)

**Tier:** 2 · **Spec slug:** `upgrade-keeps-host-edits` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-005 (installer upgrade contract, D2 framework-owned trees), Law 6
**Depends on:** `constitution-merge` merged first (shared `install.sh`, `scripts/vulyk-update.sh`,
`.claude/commands/vulyk-update.md`, `tests/telemetry.test.sh`, ADR-005); builds before `handoff-ownership`

## Goal
`install.sh --upgrade` stops writing over what a hive decided. For each framework-owned file that differs from the new
release, the installer first asks whether the hive's copy is a release copy (it equals what some release shipped: the
`v$PREV` tag, else any `v*` tag in the release clone, line endings ignored). A release copy is replaced as today. A
project edit is merged onto the new release with a three-way merge (base = the release copy it was edited from, ours =
the hive's, theirs = the new one): a clean merge is written and listed as "merged your edit"; a conflict keeps the
hive's file untouched, writes the new release beside it as `<file>.vulyk-new`, and is listed loudly. A path the
previous install shipped (old manifest) that the hive no longer has stays deleted and is listed as "kept deleted".
`--check` prints the same plan. `/vulyk-update` shows the three lists in plain words before asking.

## Assumptions
- The base comes from the release clone `vulyk-update.sh` already keeps; without a clone or tags, a differing file is
  treated as a project edit with no base: kept, new release beside it as `.vulyk-new`, listed (never a silent replace).
- Conflicts are not resolved by the installer or the Queen silently: the owner sees each one (owner rule of
  2026-10-08 on the constitution, extended by this brief to every framework file).
- A `.vulyk-new` file is gitignored (`ensure_gitignore`), so it never gets committed by accident.
- Hooks wiring in `.claude/settings.json` keeps its current merge path (`py_wire`); out of scope.
- The tests join `tests/telemetry.test.sh`, the installer's suite (the constitution is at its byte cap, no new
  `## Commands` row).

## Stories

**Wave 1**
- `upgrade-keeps-host-edits-01` — `copy_tree` decides release copy / project edit / deleted, merges or keeps beside;
  the plan in `--check`; `/vulyk-update` reads it out; ADR-005 amendment; the Law 6 card earns its check

## Contracts
- Upgrade output lines (stable, the test greps them): `  update         <f>` (release copy replaced),
  `  merged edit    <f>` (project edit carried by a clean merge), `  kept + new    <f> -> <f>.vulyk-new` (conflict),
  `  kept deleted   <f>`; `--check` prints the same with `would ` in front.

## Integration gate
`bash tests/telemetry.test.sh` · `bash tests/maintenance.test.sh` · `bash scripts/defects-check.sh` ·
`git ls-files '*.sh' | xargs -n1 bash -n`

## Next circle
- A hive's handoff launcher patch worth taking upstream: `.claude/hooks/handoff.sh` finds `python3` with `command -v`,
  but on Windows that can be the Microsoft Store stub in WindowsApps, which exits 49 and breaks the hook's fail-open;
  check by running `"$PY" -c ''` before `exec`.

## Descoped

*(empty)*

## Plan deltas

**Approved:** <owner, date - the approval stop>
**Briefed:** <written by scripts/cycle.sh briefed>
**Branch:** <written by /vulyk-build before wave 1>
**Checked:** <written by scripts/human-check.sh after the owner has looked>
**Council:** <written by scripts/cycle.sh judge/escalate>
**Shipped:** <written by scripts/ship-check.sh --record>
