---
story: rules-tree-06
spec: rules-tree
status: todo
returned:
tier: 4
worker: worker-code
wave: 2
blocked_by: [rules-tree-01]
---

# `/vulyk-gc memory`: one-off triage of private memory into cards, plus the paperwork

## Goal
After this story `/vulyk-gc memory` is a mode of the existing command: `scripts/memory-triage.sh` lists this project's
private auto-memory files (path, type, first heading) and the main session sorts them into three heaps (card /
personal, stays / delete), shows the owner one list and asks once; on yes it writes the cards retold under a `## Source`
line and never as an owner quote, deletes the moved and the dropped files from private memory together with their
`MEMORY.md` lines, and runs `bash scripts/leak-check.sh` on the new cards before they are committed. The CHANGELOG
carries the `[Unreleased]` entry for the whole spec, and ADR-014, ADR-018 and ADR-019 each carry one amendment line
pointing at ADR-021.

## Requirements
> Нужно, чтобы они максимально дружили, максимально друг друга дополняли, чтобы это не был конфликт и не была еще одна библиотека сверху существующей библиотеки.
> 11. Разовый разбор приватной памяти в карточки — режим `/vulyk-gc`: в карточку / личное / удалить, одобрение одним списком, без фальшивых цитат, перенесённое удаляется из приватной памяти.

## Files
- .claude/commands/vulyk-gc.md
- scripts/memory-triage.sh
- tests/maintenance.test.sh
- CHANGELOG.md
- docs/adr/014-defect-library.md
- docs/adr/018-*.md
- docs/adr/019-*.md

## Non-goals
- Do not run the triage on this machine's memory as part of the story: the mode is built, not executed (the pilot on
  two hives is release work).
- Do not let the script delete or write anything: it lists; the session acts after the owner's yes.
- Do not dispatch `librarian` for this mode (it has no shell and cannot read `~`); the main session does the work.
- Do not write ADR-021 or edit its text; only the one-line "amended by ADR-021 (rules-tree)" notes on the three older
  ADRs, and only if the architect has not already added them.
- Do not bump `VERSION` or date the CHANGELOG entry: `/vulyk-ship` does.

## Map slice
- memory/map/agents-and-commands.md: `/vulyk-gc` (`:82-85`), `librarian` (`:36-38`, no shell).
- docs/specs/rules-tree/scout-distribution.md: `/vulyk-gc` and private memory (nothing touches
  `~/.claude/projects/<slug>/memory` today; triage must run in the main session).
- docs/grill/2026-10-19-rules-tree.md Q18/A18 and the Risk register (client data in a hive's git → filter personal,
  leak-check before push).
- docs/specs/rules-tree/plan.md `## Contracts`: Memory triage; `## Stories` for the CHANGELOG content.

## Acceptance criteria
- [ ] `bash scripts/memory-triage.sh` with no argument resolves `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects/<slug>/
      memory` with `<slug>` = repo root path, `[:/\\]` → `-`; an explicit directory argument overrides; prints TSV
      `path<TAB>type<TAB>first heading` per `*.md` except `MEMORY.md`/`memory.md` (`type` from a `type:` frontmatter
      line, else `-`); absent dir → `no private memory: <dir>`, exit 0; writes nothing.
- [ ] `tests/maintenance.test.sh` gains a failing-first case: a scratch `CLAUDE_CONFIG_DIR` with three memory files
      (one `type: feedback`, one without frontmatter, one `MEMORY.md`) lists two rows with the right types; an absent
      dir prints the `no private memory` line and exits 0.
- [ ] `.claude/commands/vulyk-gc.md`: `argument-hint: [memory]`; the `memory` mode is a numbered protocol: run the
      script; read each file; propose three heaps in one table (file → heap, and for the card heap the target
      `docs/defects/<area>/<id>.md`, branch, retold line); one AskUserQuestion with the recommended list first; on yes
      write the cards (no `## Owner quotes` line, `## Source` per the contract), delete the moved and dropped files and
      their index lines, run `bash scripts/leak-check.sh` on each new card, run `bash scripts/defects-index.sh`, commit
      `chore(defects): memory triage`; on no or a changed list, redo the table; personal files are never opened by a
      subagent and never quoted in the commit.
- [ ] CHANGELOG `[Unreleased]` entry: areas and three branches, `tool:` scope, 12-line delivery, the three new gate
      findings and the Allowed counter, INDEX.md and `defects-index.sh`, capture channels (phrase, paste, window,
      side-agent), `always.md`, Law 6 and the lessons line, `/vulyk-gc memory`, ADR-021.
- [ ] ADR-014, ADR-018, ADR-019 each have one amendment line (date, "amended by ADR-021: rules-tree") in their status
      block.
- [ ] Moved lessons leave private memory (ask 11): the `/vulyk-gc memory` protocol, after the owner approves the list,
      deletes each moved file from `~/.claude/projects/<slug>/memory/` and its line from that `MEMORY.md`, and reports the
      count; `scripts/memory-triage.sh --index-lines <MEMORY.md> <file>...` prints the index lines that name the given
      files (so the session deletes exactly those), with a `tests/maintenance.test.sh` case on a scratch memory dir.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
