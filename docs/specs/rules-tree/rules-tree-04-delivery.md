---
story: rules-tree-04
spec: rules-tree
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [rules-tree-01]
---

# Delivery: tool scope, 12-line budget, narrowest scope first, How-to and Allowed lines

## Goal
After this story `.claude/hooks/defects-inject.sh` reads cards through `defects_lib.py` (its private "kept identical"
parser block is gone), matches `tool:<regex>` entries against `tool_name` for any tool the matcher sends (file-path and
command matching unchanged for the Edit family and Bash), delivers at most `DEFECTS_INJECT_LINES` (default 12) lines
after the header, orders cards narrowest scope first then freshest dated line, prints `✗` Never, `→` How-to and `✓`
Allowed lines (with the card's `exception:` ref), uses the card's real path (`docs/defects/<area>/<id>.md`) for "read ..." lines,
and folds what does not fit into one `+N cards: ...` line. Block-with-check and revoked cards are still skipped;
dedup per session/agent and `reset` after compaction are unchanged.

## Requirements
> через три дня на той же самой задаче он сделал по-другому. Claude сделал по-другому. Вот такие моменты критически опасны, их нужно избегать.
> 5. Доставка: не больше ~12 строк на одно действие; первой — самая узкая область, затем свежая цитата; остальное одной строкой.
> 4. Область карточки = файлы + команды + инструменты (действия: отправка, публикация, браузер); правила, ни к чему не привязанные, — один всегда загружаемый файл в `.claude/rules/`, не длиннее ~40 строк.

## Files
- .claude/hooks/defects-inject.sh
- tests/inject.test.sh

## Non-goals
- Do not edit `.claude/settings.json` or `install.sh`: the widened PreToolUse matcher is wired by story 05; test the
  tool branch by feeding the hook a `tool_name` payload directly.
- Do not change `defects_lib.py`; a missing function is `NEEDS_CONTEXT`.
- Do not inject block-with-check cards ("the gate speaks"), and do not add a per-prompt recall or any state beyond the
  existing dedup file.
- Do not keep the 4000-char budget beside the line budget: lines replace chars.

## Map slice
- docs/specs/rules-tree/scout-machinery.md: Gotcha 4 (matching `221-238`, glob_rx, dedup state `:199 :251 :285`, reset
  `200-217`, output shape `:274-276`, BUDGET `:31`), Gotcha 3 (`never_lines 181-190`), Tests (inject.test.sh payload
  helpers `edit`/`bashcall`, `expect*`, latency median ≤200 ms, python3 stub).
- docs/specs/rules-tree/plan.md `## Contracts`: Delivery, Scope, Sections, `defects_lib.py`.

## Acceptance criteria
- [ ] A payload with `tool_name: WebFetch` matches a card whose `paths:` has `tool:WebFetch`; `tool_name:
      mcp__chrome-devtools__click` matches `tool:mcp__chrome-devtools__.*`; a glob-only card does not match a non-file
      tool; `tool:` entries also match on Edit/Bash calls.
- [ ] Twelve-line budget: with cards whose lines sum to more than 12, the output is header + ≤12 lines + one `+N
      cards: <ref>, …` line; `DEFECTS_INJECT_LINES=3` shrinks it; the folded cards are recorded as shown (today's
      listed-only behaviour).
- [ ] Order: a card matched on `src/pay/stripe.py` prints before one matched on `src/**`; equal specificity → the card
      with the newer dated line first; a `cmd:`/`tool:` entry ranks by its literal characters.
- [ ] A How-to line prints as `→ …`, an Allowed line as `✓ …` with the card's `exception: <ref>` shown; a card with none of the
      three prints `read docs/defects/<area>/<id>.md`.
- [ ] A foldered card is discovered and printed with ref `<area>/<id>`; a flat library's output is unchanged for
      Never-only cards (existing `tests/inject.test.sh` cases pass).
- [ ] `tests/inject.test.sh` gains failing-first cases: tool match (two shapes), budget and overflow line, env
      override, order (narrow first, then freshest), How-to/Allowed rendering, foldered card; latency case still green.
- [ ] The prohibition wins when unlinked (ask 2): when a matched permissive card overlaps a matched prohibitive card
      and its `exception:` does not name it, its `✓` lines are not printed; one line says
      `✓ withheld: <ref-allowed> conflicts with <ref-never> (no exception:)`. A linked pair prints both.

## Verification
`python -m py_compile .claude/hooks/*.py`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- `.claude/hooks/defects-inject.sh`: private parser block, `glob_hits`, `never_lines` and `BUDGET` removed; cards come from `defects_lib` (imported from the hook's own dir), matching is `scope_matches` per entry.
- Edit family (Edit|Write|MultiEdit|NotebookEdit) feeds file_path/notebook_path, Bash feeds the command; any other tool feeds neither, so only `tool:` entries can match it.
- Budget: card-granular; once a card does not fit, it and every later card fold into `+N cards: <ref>, ...`; a first card larger than the budget is truncated, not folded, so the narrowest card always shows.
- Order key: max specificity of the card's matched entries, then newest date over Owner quotes + Allowed lines, then ref.
- Withheld rule uses the gate's overlap test (identical entry, or glob vs glob as path; same as `scopes_overlap` in defects-check.sh) among matched live prohibitive cards, including already-shown and block cards; a plain both-matched test withheld everything under a broad `tool:Edit` card.
- `✓` lines carry ` (exception: <ref>)` per line; dedup state now keys by ref (identical to id for flat libraries).
- `tests/inject.test.sh`: the old "Allowed lines are not injected" and 4000-char cases replaced by the ✓ rendering and 12-line cases; new hive2 fixture covers tool scope, order, How-to/Allowed/withheld, read-path, foldered cards.

## Findings
