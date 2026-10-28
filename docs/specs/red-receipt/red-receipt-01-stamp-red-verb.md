---
story: red-receipt-01-stamp-red-verb
spec: red-receipt
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: no red receipt
---

# `cycle.sh stamp-red`, the close-story gate, repair inheritance, wave-check report, the `red` test part

## Goal
`cycle.sh stamp-red <story> [--stamp <S>]` exists and refuses every wrong red; `close-story` on a `red: required`
story refuses without a receipt, after a sealed-test edit, or with no implementation change; `cycle.sh repair`
passes the mark on; `wave-check.sh` reports `red-no-test` and `red-value`; `tests/cycle.test.sh` gains a `red`
part whose fixtures are this story's own red test. Contracts: plan.md `## Contracts` (frontmatter, sealed set and
hashes, verb messages, gate messages, wave-check lines, repair printf) - the message strings there are literal, the
prompts of wave 2 quote them.

This story is itself marked (dogfood) under the bootstrap exception in plan.md `## Assumptions`. Order of work:
1. write the whole `red` part of `tests/cycle.test.sh` (every fixture below; each assertion prints
   `expected <text>` on failure, so the stamp's output tail carries the reason);
2. implement only the `stamp-red` verb (dispatch at cycle.sh:~3150, `fm_field` :230, `sed_inplace` :118, the
   runner factored out of `cmd_close_story` :2050-2190 and called from both verbs; `verify_of` :1884);
3. `bash scripts/cycle.sh stamp-red docs/specs/red-receipt/red-receipt-01-stamp-red-verb.md --stamp <S>`: the
   close-story gate fixtures fail with `no red receipt` in the output - the stamp lands;
4. the close-story gate, `cmd_repair` (:2848, the printf at ~2921), the shared helper in `lib.sh`, `wave-check.sh`;
5. `close-story`. Do not touch the test after step 3: a re-stamp needs a red, and the gate is then green.

## Requirements
> 1. `cycle.sh stamp-red <story-file>` за секунду и 0 токенов убеждается, что команда из ## Verification реально падает, и пишет однострочный штамп red_verified_at.
> 2. Порядок работы: тест → stamp-red → код → зелёный. close-story закрывает критичную историю, только если видит штамп.
> 6. История ремонта наследует метку критичной истории, которую чинит.
> 7. (horizon) stamp-red принимает красный только с ожидаемым текстом падения и пишет квитанцию с хешем теста. close-story отказывает без квитанции или если тест правили после неё.
> именно по нужной причине, а не из-за синтаксиса

## Files
- scripts/cycle.sh
- scripts/lib.sh
- scripts/wave-check.sh
- tests/cycle.test.sh

## Non-goals
- Do not change close-story's behaviour for a story without `red: required` - no new branch runs for it, and the
  `cmd_repair` printf stays byte-identical when no unioned story is marked.
- Do not add a `Cycle part` row to CLAUDE.md, a telemetry code, a `cycle-clerk` verb, a driver change, or a waiver
  field; do not edit prompts, templates or docs (wave 2).
- Do not copy the verification runner into the new verb: one function, two callers.
- Do not re-run the test in a worktree (H2, declined) and do not try to detect mocks.
- Never break `scripts/cycle.sh` to make the stamp red; never stash, checkout or reset.

## Map slice
memory/map/cycle.md `## Verbs`, `## Repair (ADR-013 D4)`, `## Tests`; memory/map/scripts.md `## Entry points`
(lib.sh, wave-check.sh, redact.sh), `## Gotchas` (anchored string matches, `timeout 5 true` probe).

## Acceptance criteria
- [ ] `stamp-red` refuses (exit 4, story file unchanged) in each case: unmarked story; empty `red_reason`; no
      sealed test; `## Files` holding only sealed tests; every line exits 0; a line exits 126 or 127 (a test with a
      syntax error or a missing runner); the failing output lacks `red_reason`; timeout 124.
- [ ] `stamp-red` on a test that fails with the declared text writes `red_verified_at: <ts> <sha256>` and the
      `## Red receipt` section (command, exit, tests hash + paths, impl hash, stamped, <= 10 redacted tail lines);
      a second stamp replaces both, leaving one section; the last stdout line is the JSON of the contract.
- [ ] `stamp-red` reuses close-story's cell check: a `round-only` row is exit 2 with the existing message.
- [ ] `close-story` on a marked story: no receipt -> exit 4 `no red receipt...`; a sealed test edited after the
      stamp -> exit 4 `test changed after red receipt: re-run stamp-red`; implementation files identical to the
      receipt's hash -> exit 4 `no implementation change since red receipt`; receipt + changed implementation + green
      verification -> closes and commits the story file with the receipt in it.
- [ ] An unmarked story built from `templates/story.md` closes exactly as before (the existing `close` part still
      passes; one fixture in the `red` part says so explicitly).
- [ ] `cycle.sh repair` after a RED round whose unioned story is marked writes `red: required` and an empty
      `red_reason:` into the repair story; with no marked story the frontmatter is unchanged.
- [ ] `wave-check.sh` prints `red-no-test: <story>` for a marked story whose verification names no `## Files` path,
      `red-value: <story> <value>` for `red: yes`, and nothing new for unmarked stories.
- [ ] `bash tests/cycle.test.sh --list-parts` lists `red`; the part runs alone in under 180 s on this box
      (time in `## Implementation notes`).
- [ ] This story's own `## Red receipt` shows `no red receipt` in its tail.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/cycle.test.sh`

## Implementation notes

## Findings
