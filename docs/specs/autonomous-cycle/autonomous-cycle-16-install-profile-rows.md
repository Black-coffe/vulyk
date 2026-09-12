---
story: autonomous-cycle-16
spec: autonomous-cycle
status: todo
tier: 4
worker: worker-code
tracer: false
wave: 5
blocked_by: [autonomous-cycle-11]
---

# The installer's Profile placeholder carries every row the constitution documents

## Goal
A fresh hive gets the same Profile table `CLAUDE.md` documents — all rows, same order, same `<fill in - …>` hints — including *Client path*, *Release / deploy* and the new *Browser MCP* row the council seats read. The install-smoke CI job proves the blanked block and the source block have the same row count, so the two cannot drift again.

## Requirements
> `install.sh`'s `VULYK:PROFILE` reset placeholder (the block a fresh hive receives) already omitted the *Client path* and *Release / deploy* rows before this spec, and now also omits the new *Browser MCP* row; a fresh install gets a five-row Profile while `CLAUDE.md` documents eight

> the reset placeholder carries every row of the Profile table in `CLAUDE.md` — same order, same `<fill in - …>` hints — and the install-smoke job asserts the row count of the blanked block equals the row count of the source block.

## Files
- install.sh
- .github/workflows/ci.yml

## Non-goals
- Do not parse `CLAUDE.md`'s table at install time to generate the block — the placeholder stays a literal in `install.sh` (`reset_marked_block()` / the PROFILE placeholder text); the CI count check is what keeps it honest.
- Do not touch `shippable()`, `wire_permissions()`, `OWNED`, `ensure_gitignore()` or the `--apply` call (stories 07 and 14).
- Do not change the `VULYK:COMMANDS` placeholder or the marker-line handling.
- Do not run `install.sh` against this repository or any real directory — smoke-test only into a `mktemp -d` target, delete it afterwards, write no log into the repo.

## Map slice
`install.sh` — `reset_marked_block()` (`install.sh:82`) and the PROFILE placeholder it writes (around line 140 per worker-11's note) · `CLAUDE.md` `## Profile` block between `<!-- VULYK:PROFILE:START -->` and `<!-- VULYK:PROFILE:END -->` (the source of truth: eight rows after story 11) · `.github/workflows/ci.yml` job `install-smoke` (the real-install step is where a row-count assertion belongs) · `docs/specs/autonomous-cycle/recon/scout-install.md` §Entry points.

## Acceptance criteria
- [ ] After a fresh install into a `mktemp -d` target, the target's `CLAUDE.md` Profile block has exactly the same number of table rows as the source `CLAUDE.md` Profile block, in the same order, with the *Field* column identical row by row and every *Value* cell a `<fill in …>` placeholder.
- [ ] The `install-smoke` CI job's real-install step counts `^| ` rows between the two PROFILE markers in the source and in the target and fails when they differ; the check is written so a future row added to `CLAUDE.md` but not to `install.sh` turns CI red.
- [ ] `--upgrade` into a target whose Profile was already filled leaves that filled block untouched (the existing behaviour — assert it stays).
- [ ] `bash -n install.sh` passes.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the worker: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- appended by the worker ONLY on a wall: what was tried, best hypothesis -->
