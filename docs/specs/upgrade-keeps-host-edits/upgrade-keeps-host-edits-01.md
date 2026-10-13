---
story: upgrade-keeps-host-edits-01
spec: upgrade-keeps-host-edits
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# The upgrade merges a hive's edits and keeps its deletions

## Goal
`install.sh --upgrade` replaces a framework-owned file only when the hive's copy is a release copy; a project edit is
three-way merged onto the new release (or kept with the new release beside it on a conflict), and a file the hive
deleted is not put back. Every such decision is listed; `/vulyk-update` reads the lists to the owner.

## Requirements
> Полное обновление VULYK (`/vulyk-update`) без предупреждения заменяет местные правки в файлах фреймворка улья, например `maxTurns: 140` в Recall. Так нельзя

## Files
- install.sh
- tests/telemetry.test.sh
- .claude/commands/vulyk-update.md
- docs/adr/005-installer-upgrade-contract.md
- docs/defects/upgrade-overwrites-host-edits.md
- docs/defects/upgrade-overwrites-host-edits.original.fixture
- docs/defects/upgrade-overwrites-host-edits.neighbour.fixture
- docs/defects/README.md

## Non-goals
- Do not touch the constitution path (`constitution-merge` owns it) or `.claude/settings.json` wiring.
- Do not add a flag to force the old replace-everything behaviour.
- Do not resolve a conflict for the owner, in the installer or in `/vulyk-update`.

## Map slice
memory/map/scripts.md (`install.sh - the upgrade contract`); `install.sh` `copy_tree` :104, `retired_edited` :1109,
`PREV` :565, old manifest :1117

## Acceptance criteria
- [ ] In a temp hive upgraded from a recorded previous release: an untouched release copy is replaced
      (`update`); a file whose `maxTurns` the hive raised is merged and keeps the raised value next to the release's
      other changes (`merged edit`); a hive edit on a line the release also changed is kept byte for byte with
      `<f>.vulyk-new` beside it (`kept + new`); an agent file the hive deleted is not re-created (`kept deleted`).
- [ ] With no release clone or no matching tag, a differing file is kept and gets `.vulyk-new`, never replaced.
- [ ] `--check` prints the same four kinds of lines with `would ` and writes nothing; `.vulyk-new` is gitignored.
- [ ] `/vulyk-update` shows merged edits, kept files and kept deletions in plain words before its question.
- [ ] `docs/defects/upgrade-overwrites-host-edits.md` (status block): the owner's words as a quote line, a `check:`
      that fails on each fixture - the original (a hive copy of an agent file with a raised `maxTurns`, synthetic) and
      a neighbour form (a deleted agent) - and passes on the fixed installer; a row in the README table.
- [ ] ADR-005 gets a dated amendment: D2's "replace changed framework-owned files" now means "release copies only".

## Verification
`bash tests/telemetry.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
