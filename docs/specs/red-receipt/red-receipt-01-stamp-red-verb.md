---
story: red-receipt-01-stamp-red-verb
spec: red-receipt
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: no red receipt
red_verified_at: 2026-10-28T10:24:55Z 8f8af99eae436c749162e49b1548e36f65c50841cd7f38a889ae6dbb97c194ae
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
- tests/cycle.test.sh: new `red` part (last in PARTS; gate cases last so a red run's tail ends on the `no red receipt` refusal). `--part red` alone: 42-51 s on this box.
- scripts/lib.sh: `verify_path_tokens` (lifted from wave-check's verify-gap tokeniser), `sealed_tests`, `sha256_tool`, `set_hash`.
- scripts/cycle.sh: close-story's cell check and runner became `verify_cells_check <verb>` and `verify_run` (stop-at-first mode for close-story, run-all-once capture mode for stamp-red); `fm_raw` (whole frontmatter value: red_reason/red_verified_at hold colons), `red_sets`, `red_hash`, `red_gate`, `cmd_stamp_red`, dispatch `stamp-red`; `cmd_repair` prints `red: required` + `red_reason:` only when a done story is marked.
- scripts/wave-check.sh: tokeniser now calls lib.sh `verify_path_tokens`; `red-no-test` / `red-value` lines.
- Order kept: test written, stamp-red only, stamped (the full run failed with `no red receipt` in its tail), then gate, repair, wave-check; the test was not touched after the stamp.
- Surprise: the first stamp's awk printed the frontmatter out of order (red_reason/red_verified_at above `story:`); fixed in cycle.sh (`infm { print; next }`) and the three lines of this story's own frontmatter moved back by hand - the receipt's hashes, tail and timestamp are the stamp's own. The `red` part does not assert frontmatter order (sealed now; see CONCERNS).
- Impl set = `## Files` entries minus sealed minus the story file, expanded with `git ls-files -co --exclude-standard` plus literal entries kept while missing (so a not-yet-created file still counts as a change when it appears).

## Findings

## Red receipt
- command: bash tests/cycle.test.sh
- exit: 1
- tests: 8f8af99eae436c749162e49b1548e36f65c50841cd7f38a889ae6dbb97c194ae (tests/cycle.test.sh)
- impl: 2e3c0b66a9538f7467aea67abdf3607489b216497027e08ccee4414820d28283
- stamped: 2026-10-28T10:24:55Z

```
  ok    the template story closes and commits, no receipt asked
red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes
  ok    red-12 stamped
::error::test edit: exit=4 {"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"bash tests/red.sh"}
::error::no change: exit=4 {"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"bash tests/red.sh"}
  ok    receipt + changed implementation + green: closed, the receipt in the commit
red-receipt: close-story on a marked story that was never stamped
::error::unstamped story: exit=0, head moved: story(red-11): Red fixture 11
::error::the refusal names stamp-red and the story - expected '"error":"no red receipt: run cycle.sh stamp-red docs/specs/red/red-11.md after writing the failing test"' in:
        {"ok":true,"verb":"close-story","exit":0,"next":"briefed","status":{"spec":"docs/specs/red","slug":"red","stage":"01-spec","next":"briefed","briefed":false,"approved":false,"branch":null,"head":"24e59f1","pack":"22e976cff899","stories":{"todo":10,"in-progress":0,"done":3,"blocked":0},"wave":1,"wave_stories":[{"file":"docs/specs/red/red-01.md","story":"red-01","worker":"worker-code","model":"","repeat":1}],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
```
