---
story: v0-12-0-remainders-10
spec: v0-12-0-remainders
status: todo
returned:
tier: 4
worker: worker-code
tracer: false
wave: 3
blocked_by: [v0-12-0-remainders-07]
---

# The installer keeps a manifest and removes what a release retired

## Goal
ADR-005 D2 built: `install.sh` writes `.claude/vulyk-manifest` (the whole ship set) in the stamp's guarded block; on `--upgrade` it removes a file only when it is in the old manifest, absent from the new ship set and `owned()` (`would remove` in `--check`), prints `leave (yours)` for a non-OWNED dropout and `unlisted (kept)` for every OWNED file of a hive that has no manifest yet, deleting nothing there. The manifest joins `shippable()`'s return-2 arm. `install-smoke` gains D4 assertions 2-6 and 11's manifest half.

## Requirements
> Инсталлер ведёт манифест .claude/vulyk-manifest и при апгрейде удаляет снятые файлы; --check печатает would remove.

## Files
- install.sh
- .github/workflows/ci.yml

## Non-goals
- Never remove a path that fails any of the three conditions, on a fresh install, or on a first upgrade (no old manifest); never compare content (D2 "removed regardless"); never remove directories.
- Do not gitignore the manifest; never list the manifest, the stamp, `CLAUDE*.md` or `AGENTS.md` in it.
- Do not touch `ensure_marked_block`, the D1 deny arm or the constitution branches beyond what story 07 landed; no job other than `install-smoke`.
- Never run against this repository or a real hive; `mktemp -d` only.

## Map slice
`docs/adr/005-installer-upgrade-contract.md` D1 (the manifest's return-2 arm), D2 (the property table - every row is a criterion), D4 items 2, 3, 4, 5, 6, 11 · `recon/install-and-update.md` (`OWNED`/`owned()` `:34-35`, `copy_tree` `:67-87`, stamp block `:418-425`, dry-run line shapes and column alignment) · `recon/tests-ci-hooks-driver.md` §2 (`install-smoke`, planted-sentinel technique) · `plan.md` K6.

## Acceptance criteria
- [ ] Manifest per D2: format, content (shippable-0 paths of this run, copied/updated/skipped alike), exclusions, written on every non-`--check` run; `--check` prints `would write    .claude/vulyk-manifest (<n> paths)`; `shippable()` returns 2 for `.claude/vulyk-manifest`.
- [ ] Removal per D2: after the copy loop, before the new manifest; `remove         <path>` / `would remove   <path>`; `leave (yours)  <path>` for a non-OWNED dropout; `unlisted (kept) <path>` and no deletion when no old manifest exists; a crash between removal and manifest write is harmless on rerun.
- [ ] `install-smoke`: D4 2 (manifest exists, `LC_ALL=C sort -c`, every line an existing file, contains `.claude/agents/worker-code.md`, no `vulyk-version`/`vulyk-manifest`/`docs/specs/`/`docs/adr/0`/`CLAUDE` line), 3 (retire `.claude/agents/retired-smoke.md`: `would remove` leaves file and manifest unchanged, real upgrade deletes and drops it), 4 (`memory/retired-smoke.md` survives, no remove line, dropped from manifest), 5 (`.claude/agents/mine.md` kept, never listed), 6 (no manifest: `unlisted (kept)`, file kept, manifest written without it), 11 (`--upgrade --check` after 3 changes nothing).
- [ ] Hand smoke of D4 2-6 in `mktemp -d`, results in the notes; `bash -n install.sh` passes; set `returned: DONE` in this story's frontmatter before returning.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
