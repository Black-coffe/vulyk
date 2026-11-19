---
story: tails-1115-12
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 3
blocked_by: []
red: required
red_reason: a direct call inside a quoted command substitution is exact
red_verified_at: 2026-11-17T12:08:22Z 174dcb9fab7c06d44293526db2258c8b6777ac8926371789a9be717796c9d031
---

# Test pick-up: a direct call inside "$(...)" is exact, a lib.sh source is not a call of every script it wraps

## Goal
Two gaps of `symbol-map.py`'s `exact` edges, found by the narrow-repair-1115 council (round 2, ask 5 and the review
minors). The rule stays the owner's 2026-11-15 «тесты exact»: a test is picked only when it sources, imports or runs
a file, never for a mere mention.
1. A test that runs a script only inside a quoted command substitution (`out="$(bash scripts/trace-check.sh x)"`) is
   an `exact` test of that script. Today six of 52 scripts and hooks miss it: `scripts/trace-check.sh`,
   `scripts/defects-check.sh`, `scripts/suite-parts-check.sh`, `scripts/hives-behind.sh`,
   `.claude/hooks/context-guard.sh`, `.claude/hooks/top-model-brief.sh`.
2. The "via a bash wrapper" rule (scripts/symbol-map.py, near line 445 of 2b3594ac) makes every test that sources
   `scripts/lib.sh` an `exact` test of `scripts/run-capped.py` (2 exact tests at d5ba99ad, 14 at 2b3594ac). Sourcing
   `lib.sh` alone is not a call of the scripts `lib.sh` runs; a test that calls the wrapper's function, or runs the
   script itself, still is.

Marked red: a parser rule that decides which tests a story runs.

## Requirements
> 11. Test pick-up stays exact (direct calls only, owner 2026-11-15 «тесты exact»), and a direct call written inside a quoted command substitution (`"$(bash scripts/x.sh ...)"`) counts as one; a test that only sources `scripts/lib.sh` is not an exact test of every script `lib.sh` runs. The substitution rule is checked on the three scripts a test runs that way (trace-check.sh, defects-check.sh, suite-parts-check.sh); three scripts that miss an exact test for other causes are out of this spec (owner, 2026-11-17).
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
- scripts/symbol-map.py
- tests/symbol-map.test.sh

## Non-goals
- No `textual` hit becomes `exact`; a test that only reads a `.md`, `.js` or card file stays out (owner's choice).
- The output of `--exact`, `--story` and `--scope` changes only by the edges above; caps and section order stay.
- Do not touch `scripts/symbol-map.sh`, `scripts/cycle.sh` or any story of another spec.
- `tests/symbol-map.test.sh` is story 09's file in wave 4: add cases only, near the `--fill-tests` cases; do not
  touch the trace-autopsy speed check (story 09 replaces it).

## Map slice
`memory/map/scripts-checks.md` → Entry points (`symbol-map.sh`), Tests.

## Acceptance criteria
- [ ] `bash scripts/symbol-map.sh --exact scripts/trace-check.sh` lists the tests that run it inside `"$(...)"` as
  `exact`. The label contains `a direct call inside a quoted command substitution is exact`. Neighbours: single
  quotes around the whole command (`'bash scripts/x.sh'` as data, never run) stay `textual`; backtick substitution
  is `exact`; a variable path (`bash "$HERE/x.sh"`) keeps today's answer.
- [ ] A fixture test that only sources `scripts/lib.sh` is not an `exact` test of `scripts/run-capped.py`; one that
  calls the `lib.sh` function wrapping it, or runs `run-capped.py` itself, is.
- [ ] `--fill-tests` on a fixture story naming `scripts/trace-check.sh` adds the test that runs it in `"$(...)"`
  and its row.
- [ ] The three scripts run inside `"$(...)"` (trace-check.sh, defects-check.sh, suite-parts-check.sh) each list at
  least one `exact` test in this repo (owner, 2026-11-17: «Сузить до трёх (Рекомендую)»); `scripts/run-capped.py` lists no
  more exact tests than the tests that call it; the notes give both counts.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/symbol-map.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change. -->
- scripts/symbol-map.py: `subst_bodies`/`segments` scan each `$( )` and backtick body outside single quotes with the same runner rule; `sh_edges` keeps per-line targets and the sourced-and-never-run set.
- scripts/symbol-map.py: the via-wrapper rule now skips a file that only sources the wrapper unless the wrapper runs p at top level or the file calls a wrapper function reaching p (transitive inside the wrapper: `run_capped` -> `run_capped_as`).
- tests/symbol-map.test.sh: new block "quoted command substitution, sourced wrappers" after the bash-run cases. Red on HEAD: the substitution case, the lib.sh case, the fill-tests case, the six-scripts loop (6 lines), the run-capped.py check. The single-quote textual check is a neighbour guard that passes on HEAD by design.
- Counts: `scripts/run-capped.py` exact tests 14 -> 5 (council, cycle direct; full-suite.sh, intake, telemetry via lib.sh, each calls run_capped/capped_by). trace-check.sh 2, defects-check.sh 2, suite-parts-check.sh 3 exact tests now.
- Not closed: hives-behind.sh, context-guard.sh and top-model-brief.sh still have 0 exact tests (see Findings).
- Queen's (b) applied: the this-repo loop in tests/symbol-map.test.sh now asserts the three substitution scripts only; suite 146 checks, 0 failed. Next circle, the other three: hives-behind.sh (`;`-joined assignment, maintenance.test.sh:2007), top-model-brief.sh (path passed to a test-local `run()`, model-profile.test.sh:194), context-guard.sh (single-quoted data read from settings.json, maintenance.test.sh:440).
- CHANGELOG: symbol-map: a script run inside a quoted command substitution or backticks is an exact test target; sourcing a wrapper is a call only of what its top level or a called function runs.

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy. -->
- NEEDS_CONTEXT (builder): the story says all six scripts miss an exact test because a test runs them inside `"$(...)"`.
  That holds for trace-check.sh, defects-check.sh and suite-parts-check.sh. Those three are exact now. It does not
  hold for the other three, so the acceptance line "the six scripts above each list at least one exact test" cannot
  be met by this story's rule:
  - `scripts/hives-behind.sh`: tests/maintenance.test.sh:2007 sets `HB="$SRC/scripts/hives-behind.sh"; HR=...; mkdir ...`
    on one line, and the path-variable rule (narrow-repair-1115-06 ASSIGN) only takes a line that holds a single
    assignment. Then `hb() { ... bash "$HB" ...; }` is not resolved.
  - `.claude/hooks/top-model-brief.sh`: tests/model-profile.test.sh:194 calls `run "$HIVE" "$SRC/.claude/hooks/top-model-brief.sh"`,
    and the test's own `run()` does `bash "$s"`. This is a path passed to a local helper function, not a runner word.
  - `.claude/hooks/context-guard.sh`: tests/maintenance.test.sh:440 runs a command it reads from settings.json via
    `grep 'context-guard.sh'`. The path is only single-quoted data, which this story's neighbour rule says stays textual.
  Question: (a) widen the story with two new rules: a `;`-separated assignment counts, and a path passed to a test-local
  function whose body runs `bash "$<n>"`/`"$s"` counts. Leave context-guard.sh textual and cut it from the acceptance
  line. Or (b) cut the acceptance line to the three substitution scripts. My recommendation is (b): the story's rule is
  met and the other two rules are new parser surface. The test loop in tests/symbol-map.test.sh currently asserts all six,
  so it is 3 red lines until this is decided.

## Red receipt
- command: bash tests/symbol-map.test.sh
- exit: 1
- tests: 174dcb9fab7c06d44293526db2258c8b6777ac8926371789a9be717796c9d031 (tests/symbol-map.test.sh)
- impl: 8c80f27bffdab238ad3068df77b7cfe589d51cc59babdba7088738e6b71f4e06
- stamped: 2026-11-17T12:08:22Z

```
::error::a direct call inside a quoted command substitution is exact (backticks too, a variable path kept, a single-quoted command never) - expected ' exact tests/bt.test.sh| exact tests/dq.test.sh| exact tests/var.test.sh|', got ' exact tests/var.test.sh|'
::error::fill-tests: a direct call inside a quoted command substitution is exact, its test and row join the story - expected '> - tests/bt.test.sh|> - tests/dq.test.sh|> - tests/var.test.sh|> `bash tests/bt.test.sh`|> `bash tests/dq.test.sh`|> `bash tests/var.test.sh`|', got '> - tests/var.test.sh|> `bash tests/var.test.sh`|'
::error::this repo: a direct call inside a quoted command substitution is exact - scripts/trace-check.sh has no exact test
  ok    trace-autopsy: no repo frame says so
  ok    trace-autopsy: a build without src/ resolves by its two-part tail
  ok    trace-autopsy: no repo frame still names the ambiguous candidates
  ok    trace-autopsy: twelve frames fit in 8 lines (<= 15)
  ok    trace-autopsy: the overflow folds into a last '... N more' line
  ok    trace-autopsy: no argument exits 2
  ok    trace-autopsy: a brief outside any git repo exits 2
  ok    trace-autopsy: /vulyk-plan step 2 runs it
  ok    trace-autopsy: /vulyk-plan step 2 names autopsy.md
symbol-map.test.sh: 146 checks, 7 failed
```
