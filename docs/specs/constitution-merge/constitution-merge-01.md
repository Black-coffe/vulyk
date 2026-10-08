---
story: constitution-merge-01
spec: constitution-merge
status: todo
returned:
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# A script that knows the project's own lines, drafts the merge, and proves nothing was lost

## Goal
`scripts/constitution-merge.sh` exists with the four subcommands of plan.md `## Contracts`, plain bash plus
`git merge-file`, no model. `tests/constitution.test.sh` covers it in seconds, with a synthetic release history. The
owner's correction is the first VULYK defect card, `docs/defects/upgrade-drops-host-constitution.md`, `status: block`,
`check: bash scripts/constitution-merge.sh check-fixture <arg>`, failing on two fixtures: the original shape (a replace
dropped a whole project section) and a neighbour (a merge kept every section but took the release's wording of a
passage the project had rewritten).

## Requirements
> чтобы не потерялся смысл, сенс, логика и правила того проекта, в который заходит Wulic
> при обновлении Wulic обязательно изучает текущие правила, конструкцию, инструкцию и во время обновления адаптирует, чтобы была консистентность, единство

## Files
- scripts/constitution-merge.sh
- tests/constitution.test.sh
- docs/defects/upgrade-drops-host-constitution.md
- docs/defects/upgrade-drops-host-constitution.original.fixture
- docs/defects/upgrade-drops-host-constitution.neighbour.fixture
- .github/workflows/ci.yml

## Non-goals
- No model call and no network in the script: the Queen's judgment lives in `/vulyk-update` (story 03).
- Do not copy any real hive's constitution into a fixture (private text in a public repo).
- Do not touch `install.sh` here (story 02).

## Map slice
memory/map/scripts.md - lib.sh helpers, defects-check.sh; docs/defects/README.md - the card format

## Acceptance criteria
- [ ] `host-lines` drops every line any release contains, keeps project lines, ignores blank lines and trailing
      whitespace and CRLF.
- [ ] `draft` with a base merges a framework edit and a project section cleanly (exit 0); the same passage edited on both
      sides gives exit 1 with conflict markers; a sibling `CLAUDE.pre-*.md` yields `restore:` lines for its project
      lines only, never for old framework text.
- [ ] `check` exits 1 on a dropped project line, 0 when it is listed in `--superseded`, 0 on a clean merge.
- [ ] The card is an earned `block`: `tests/constitution.test.sh` runs `bash scripts/defects-check.sh` and asserts
      the check fails on both fixtures.
- [ ] CI runs `bash tests/constitution.test.sh` (its `## Commands` row was added at plan time).

## Verification
`bash tests/constitution.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
