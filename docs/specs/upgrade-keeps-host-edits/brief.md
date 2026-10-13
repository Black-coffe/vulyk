# Brief: upgrade-keeps-host-edits

**Date:** 2026-10-13
**Tier:** 2 - one feature of one module (the installer's upgrade path), no new architecture
**Source:** owner correction, same session as `handoff-cwd`; evidence from upgrading five hives that day
**Escaped from:** none - the replace rule predates the spec system (ADR-005 D2)

## Request (verbatim)

> Полное обновление VULYK (`/vulyk-update`) без предупреждения заменяет местные правки в файлах фреймворка улья, например `maxTurns: 140` в Recall. Так нельзя

## Recon

- `install.sh` `copy_tree` (:104-129): on `--upgrade`, `owned "$f" && ! cmp -s "$SRC/$f" "$DEST/$f"` replaces every
  framework-owned file that differs from the new release - whether it is an older release copy or the project's own
  edit. A path missing in the hive is copied in, even when the project deleted it on purpose.
- What already exists to build on: `PREV` (:565, the installed version), the release clone with every `v*` tag
  (`vulyk-update.sh` keeps it), `retired_edited` (:1109, "differs from what v$PREV shipped", line endings ignored), the
  previous manifest `.claude/vulyk-manifest` (:1117).
- Evidence, by shape (hives named only as the owner named them): Recall tuned `maxTurns` in two agent files and the
  Workflow driver - a dry run showed all three as "would update"; a hive had deleted a worker agent and edited the
  build command and the story template around it - a real upgrade put the agent back and wrote the edits over; a hive
  had patched its handoff launcher (a Windows python stub guard) - overwritten. All three were found by comparing the
  project's committed copy with every release tag and restored by `git merge-file` (base = closest tag, ours = the
  project's, theirs = the new release); two of four merged clean.

## Asks

1. Полное обновление VULYK (`/vulyk-update`) без предупреждения заменяет местные правки в файлах фреймворка улья, например `maxTurns: 140` в Recall. Так нельзя
