---
story: constitution-merge-03
spec: constitution-merge
status: todo
returned:
tier: 2
worker: worker-code
model: opus            # judgment-heavy: the procedure is the Queen's semantic merge, the owner-facing summary and
                       # the conflict rules; a wrong word here loses a hive's rules
wave: 3
blocked_by: [constitution-merge-02]
---

# /vulyk-update studies the hive's constitution and merges the release into it

## Goal
`/vulyk-update` steps 3-6 become the merge. When the release's constitution differs from the hive's base: read the
hive's constitution whole; run `constitution-merge.sh draft`; resolve each conflict marker by showing the owner two
plain lines ("your rule" / "what VULYK proposes") with the project's version as the default; read the `restore:` lines
and offer them back; adapt only for consistency (a project rule that now contradicts a new framework rule is a conflict,
never a silent edit). Then one plain summary - what lands from VULYK, what stays the project's, what comes back from a
backup, what is superseded and why - and one question. On yes: keep `<name>.pre-<version>.md`, write the merged file,
run `constitution-merge.sh check` with the superseded list the owner saw; exit 1 means stop and repair, never report
success. README, getting-started, command-reference, faq, token-economy and ADR-013 stop naming replace.

## Requirements
> при обновлении Wulic обязательно изучает текущие правила, конструкцию, инструкцию и во время обновления адаптирует, чтобы была консистентность, единство
> чтобы не потерялся смысл, сенс, логика и правила того проекта, в который заходит Wulic

## Files
- .claude/commands/vulyk-update.md
- README.md
- docs/getting-started.md
- docs/command-reference.md
- docs/faq.md
- docs/token-economy.md
- docs/adr/013-light-vulyk.md
- tests/constitution.test.sh

## Non-goals
- Do not let the procedure rewrite a project rule's wording "for style": only conflicts and contradictions change text,
  and only with the owner's answer.
- Do not upgrade any hive in this spec; hives get it at their next `/vulyk-update`.
- Do not touch the memory map (drone-docs at ship).

## Map slice
memory/map/agents-and-commands.md - /vulyk-update

## Acceptance criteria
- [ ] `vulyk-update.md` names: study first, draft, conflicts with project default, restore from `CLAUDE.pre-*.md`,
      one summary, write only on yes, backup kept, `check` after the write and its exit 1 as a stop.
- [ ] No owner-facing doc recommends or names `--constitution replace`, except as removed (CHANGELOG, ADR history).
- [ ] The defect card's `## Never` lines match what the procedure forbids.
- [ ] `tests/constitution.test.sh` guards the text: `vulyk-update.md` names `constitution-merge.sh check` after the
      write, and no owner-facing file above recommends `--constitution replace`.

## Verification
`bash tests/constitution.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes

## Findings
