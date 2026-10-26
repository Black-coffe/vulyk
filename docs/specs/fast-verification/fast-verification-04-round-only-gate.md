---
story: fast-verification-04
spec: fast-verification
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [fast-verification-01, fast-verification-02]
---

# `round-only` rows: wave-check reports them, close-story refuses them

## Goal
`lib.sh` can tell whether a verification segment sits in a `## Commands` row whose Purpose cell carries
`round-only`. `wave-check.sh` reports such a story before any wave builds (`verify-round-only`), and `close-story`
refuses to run it with exit 2 `verification is round-only: <segment>`, so the worker returns NEEDS_CONTEXT instead of
burning three retries. Existing readers (`command_cells`, `command_cell_exists`) are untouched.

## Requirements
> 4. Медленные строки таблицы команд помечены «только для раунда»; историю, назвавшую такую строку, ловит проверка плана до сборки, а close-story отказывается её запускать.

## Files
- scripts/lib.sh
- scripts/wave-check.sh
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh

## Non-goals
- Do not touch `cycle.sh` outside the close-story verification block (`:1957-1991`): record-seat and judge belong
  to story 06, next wave.
- Do not edit `CLAUDE.md` (its rows and mark landed in story 01) or any template/agent text (story 05).
- Do not change `command_cells` / `command_cell_exists`, the placeholder rule, or the 540 s `VULYK_VERIFY_TIMEOUT`.
- Do not add a flag that bypasses the refusal.

## Map slice
memory/map/scripts.md `## Entry points` (`lib.sh`, `wave-check.sh`), `## Gotchas` (anchored string matches);
memory/map/cycle.md `## Verbs` (`close-story`); scout-plumbing.md `## Entry points`, `## Gotchas` (ask 4 lines).

## Acceptance criteria
- [ ] `command_cell_round_only <constitution> <cmd>` exists in `lib.sh` per the plan's contract: exit 0 iff the
      command matches (exact or `<placeholder>`, the `command_cell_exists` rule) the Command cell of a row whose
      Purpose cell contains the token `round-only`; found in both a marked and an unmarked row = round-only.
- [ ] `wave-check.sh` reports `verify-round-only: <story> <segment>` for each offending segment, counted in
      PROBLEMS, header code documented beside `verify-cell` (`:31-33`); still exits 0.
- [ ] `close-story` checks round-only after the cell check and before running anything: `emit false close-story 2
      error "verification is round-only: <segment>"`, exit 2, nothing run, nothing committed, status untouched.
- [ ] `tests/cycle.test.sh` (next to `:346-363`): a fixture constitution with a marked row; a story naming it is
      reported `verify-round-only`, a story naming the unmarked `--part` row is not. This is the test that fails
      when the reader or the report breaks.
- [ ] `tests/council.test.sh` part `verbs` (next to `:1488-1505`): close-story on a story whose verification names
      the marked row exits 2 with the message and runs nothing; the neighbour form - the same command text present
      in a marked and an unmarked row - is also refused; a `--part x` placeholder match against an unmarked row
      still runs.

## Verification
`bash tests/cycle.test.sh && bash tests/council.test.sh --part verbs`

## Implementation notes
- scripts/lib.sh: `command_cell_round_only` copies only the marked rows (Purpose cell holds the `round-only` token) into a temp table and asks the unchanged `command_cell_exists`, so exact/placeholder matching is the one rule; a command also in an unmarked row still matches = round-only.
- scripts/wave-check.sh: a segment that is a cell gets the round-only test (`verify-round-only: <story> <segment>`, counted by `report`); header documents the code below `verify-cell`.
- scripts/cycle.sh: inside the close-story cell loop, each whole-line cell or segment that passed the cell check is then refused if round-only (exit 2, before the run block); nothing else in cycle.sh touched.
- tests/cycle.test.sh: `wro` fixture via a CLAUDE.vulyk.md sidecar - marked row and marked+unmarked text reported, unmarked `--part` row not, no verify-cell.
- tests/council.test.sh part verbs: `cstoryro` after cstory4 - marked row and neighbour form refused (no file touched, status todo, HEAD unchanged); `--part x` on an unmarked row closes.
- Decision: a temp file rather than process substitution, because `command_cells` gates on `[ -f ]`, which a /dev/fd path fails.

## Findings
