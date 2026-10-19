---
story: rules-tree-02
spec: rules-tree
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
---

# Constitution: Law 6 for three branches, the lessons line, one always-loaded rules file

## Goal
After this story the constitution's Law 6 names the three branches (never / allowed / how-to) and the debt rule for
never and how-to only; a new line under `## Where things live` sends a lesson about the project's code or process to
`docs/defects/` and leaves auto-memory for the personal. Both are paid for with trims: `CLAUDE.md` stays within 7168
bytes and 120 lines (CRs stripped) and `tests/maintenance.test.sh` stays green, including its check of the shipped
render. `.claude/rules/always.md` exists: no `paths:` frontmatter, so it loads in every session, capped at 40 lines by
a new constant in `tests/maintenance.test.sh`; `.claude/rules/README.md` and the `docs/memory-system.md` layers table
describe the split (path rules on touch, `always.md` always, cards by the hook before an action).

## Requirements
> 12. Строка конституции: урок про код и процесс проекта — в `docs/defects/`, в авто-память — только личное.
> 4. Область карточки = файлы + команды + инструменты (действия: отправка, публикация, браузер); правила, ни к чему не привязанные, — один всегда загружаемый файл в `.claude/rules/`, не длиннее ~40 строк.
> 3. Повтор по «Нельзя» и «Как надо» — долг, красный до проверки кодом; повтор по «Можно» — счётчик в витрине и /vulyk-status.

## Files
- CLAUDE.md
- .claude/rules/always.md
- .claude/rules/README.md
- docs/memory-system.md
- tests/maintenance.test.sh
- install.sh

## Non-goals
- Do not reword any Law but 6 and do not drop a Profile or Commands row other than the proposed trims below without
  reporting it; Laws 1-5 are the owner's wording.
- Do not edit `install.sh` unless `render_constitution` (`install.sh:329`) carries its own copy of the Laws text; if the
  render is produced from `CLAUDE.md`, leave `install.sh` untouched and say so in `## Implementation notes`.
- Do not fill `always.md` with rules invented for this story: a 3-line header plus any rule text that today sits in a
  `.claude/rules/*.md` file without `paths:` (if none, the header only).
- Do not touch `docs/defects/README.md` (story 01) or the global `~/.claude/CLAUDE.md`.

## Map slice
- docs/specs/rules-tree/scout-distribution.md: Budget (`CONSTITUTION_MAX_BYTES=7168`, `MAX_LINES=120`, CRs stripped
  `:35`, checked on `CLAUDE.md :81` and the shipped render `:84-88`), Constitution (`render_constitution :329`,
  `print_migrate_hint :469`), `.claude/rules` not OWNED, `docs/memory-system.md` layers row `:4-12`.
- docs/specs/rules-tree/plan.md `## Contracts`: Constitution, Always-loaded rules file.

## Acceptance criteria
- [ ] Law 6 reads as the plan's Constitution contract (three branches; debt for a repeated never or how-to only); the
      new lessons line is under `## Where things live`; `vulyk-evolve.md:83`'s reference "(Law 6)" still holds.
- [ ] `tr -d '\r' < CLAUDE.md | wc -c` ≤ 7168 and line count ≤ 120; `bash tests/maintenance.test.sh` green, including
      the shipped-render check. Trims, in this order until the budget holds, each named in `## Implementation notes`
      with bytes before/after: (1) the dead `| Merge tests | bash tests/constitution.test.sh |` row (the file does not
      exist); (2) the `> VULYK's own rows: ...` blockquote under `## Commands`; (3) tighten the `## Compact
      instructions` paragraph; (4) tighten the `## Secrets` lines. Stop at the first that pays.
- [ ] `.claude/rules/always.md` exists with no frontmatter and ≤ 40 lines; `tests/maintenance.test.sh` has
      `RULES_ALWAYS_MAX_LINES=40` and a case that fails on a 41-line path-less rules file and passes on the shipped one
      (README.md, which has `paths:`, is exempt).
- [ ] `.claude/rules/README.md` says: rules bound to files keep `paths:`; rules bound to nothing go to `always.md`
      (≤40 lines); a project rule about code or process is a card in `docs/defects/`, not a rules file.
- [ ] `docs/memory-system.md` layers table: the "Path rules" row says `on touch; always.md always`; a new row
      `Defect cards | docs/defects/**/*.md | by the PreToolUse hook before a matching action, narrowest scope first |
      the session, on the owner's words`.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- CLAUDE.md: Law 6 reworded to the plan's Constitution contract; lessons line added as the last line of `## Where things live`. Before: 7160 B / 109 lines; after the two additions: 7306 B / 110 lines.
- Trim (1) dead `| Merge tests | bash tests/constitution.test.sh |` row: 7306 -> 7254 B (still over).
- Trim (2) `> VULYK's own rows: ...` blockquote and its blank line: 7254 -> 7159 B, 107 lines. Budget holds; trims 3-4 not taken. Shipped render 6356 B / 94 lines.
- install.sh untouched: the render takes its Laws from `$SRC/CLAUDE.md` and only swaps the marked blocks; no placeholder moved.
- `.claude/rules/always.md`: 3-line header only; no existing rules file lacks `paths:` (README.md has it).
- `.claude/rules/README.md`: one paragraph on the split (paths: / always.md / docs/defects cards).
- `docs/memory-system.md`: Path rules row `on touch; always.md always`; new Defect cards row as specified.
- `tests/maintenance.test.sh`: `RULES_ALWAYS_MAX_LINES=40`, `rules_always_over` (frontmatter-only `paths:` lookup), fixture case (41-line path-less file red, padded README with paths: exempt) and a check on the shipped `.claude/rules`.
- `vulyk-evolve.md:83` "(Law 6)" still points at the debt/check law.

## Findings
