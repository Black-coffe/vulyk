---
story: cross-platform-09
spec: cross-platform
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: []
red_reason: names rule heredoc-in-subst
red_verified_at: 2026-10-29T11:45:34Z fbd2114d3c947ff6d4e697f29e054c5899bd5fd8cf5a8210e0b3913dd8534e73
---

# The gate learns what CI found; CI fails fast and shows why

## Goal
(1) `scripts/portability-check.sh` gets two rules for the classes the macOS CI found that a grep can see: `paste-s`
(`paste -s...` with no file operand) and `case-in-subst` (a `case ... in` whose pattern line ends in `)` inside a
multi-line `$( ... )`, the bash 3.2 parse bug of `scripts/trace-check.sh:127`). Each rule: a failing fixture (the
original case) and a neighbour form, in the card `docs/defects/shell-needs-gnu-or-bash4.md`. A newline inside `awk -v`
cannot be seen statically: the card names it as a How-to line (pass multi-line values through `ENVIRON`), no rule. Story
07 fixes the product sites in parallel, so the tree run may still hit them while 07 is open: report any remaining tree hit
under `## Findings`, never mark it `# portable:`. (2) CI: the `full-suite` job gets `timeout-minutes: 90` and a capped
`VULYK_SUITE_TIMEOUT` (e.g. 2400) instead of `0`, so a hang ends as a named `TIMEOUT` with the runner's log tails rather
than a 6 h cancel with none; `install-smoke` gets `timeout-minutes: 30`.

Evidence (Queen, 2026-10-29): owner REJECTED after GREEN round 2 (plan.md `**Checked:**`); CI run 40787799947 on 9ca42a6 and the probe run 40857869190 (branch `ci-probe/mac-logs`, macOS only, `VULYK_SUITE_TIMEOUT=1500`). macOS: 21 suites FAIL, 3 TIMEOUT.

## Requirements
> 4. Статический гейт `scripts/portability-check.sh` с карточкой дефекта и фикстурами.
> 5. Джоба `macos-latest` в `.github/workflows/ci.yml`.

## Files
- scripts/portability-check.sh
- docs/defects/shell-needs-gnu-or-bash4.md
- docs/defects/shell-needs-gnu-or-bash4.paste-s.fixture
- docs/defects/shell-needs-gnu-or-bash4.case-in-subst.fixture
- tests/maintenance.test.sh
- .github/workflows/ci.yml
- docs/defects/INDEX.md
- docs/defects/shell-needs-gnu-or-bash4.heredoc-in-subst.fixture
- scripts/defects-check.sh

## Non-goals
- No product script or other suite.

## Acceptance criteria
- [ ] The two new rules each fail on their fixture and pass on the neighbour form (tests in `tests/maintenance.test.sh`,
      written and stamped red first).
- [ ] `bash scripts/defects-check.sh` GREEN with the new fixtures.
- [ ] `ci.yml`: the timeouts above; nothing else in the jobs changes.

## Verification
`bash tests/maintenance.test.sh`
`bash scripts/defects-check.sh`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
- scripts/portability-check.sh: rule `paste-s` (tokenises the words after `paste`, `-d` takes the next word when bare; `-`
  or any non-flag word is an operand); rule `case-in-subst` in `scan()`: a `$( )` frame now counts open `case`s, and a `)`
  with no open paren while a case is open is the hit. Unquoted `$(` now opens a frame too (before, only `"$(`), so a
  multi-line unquoted substitution is tracked; the tree run shows no other rule changing.
- Fires on a one-line `$(case x in a) ...;; esac)` as well as multi-line: Docker bash:3.2 fails on both
  (`syntax error near unexpected token newline`), so the rule follows the parser, not the story's "multi-line".
- Fixtures: paste-s = tests/model-profile.test.sh:137 at HEAD + a `-s -d ' '` neighbour; case-in-subst =
  trace-check.sh:117 + cycle.sh:2079 (a second real site, confirmed under Docker bash:3.2).
- Card: fixtures list, one Never bullet for both rules, a `## How-to` for `awk -v` with a newline (ENVIRON).
- ci.yml: full-suite `timeout-minutes: 90` + `VULYK_SUITE_TIMEOUT=2400`; install-smoke `timeout-minutes: 30`. The job
  display name still says "uncapped" (left: renaming changes the check name).
- Relaunch after the Queen's ruling: tests for `heredoc-in-subst` added to maintenance.test.sh and re-stamped red
  (red_reason now `names rule heredoc-in-subst`) before any implementation edit.
- scripts/portability-check.sh: rule `heredoc-in-subst` - a heredoc opened while a `$( )` frame is open, reported on
  its opening line only when its body holds `'` `"` `` ` `` or `(`. Narrowed from "every heredoc in `$( )`" because
  Docker bash:3.2 parses a body without them (scripts/telemetry.sh:891, `$list`), and that product line would
  otherwise be a tree hit; probes: lone `'`, `"`, `(` fail; balanced `print(1)` passes but is still a hit (conservative).
- scripts/defects-check.sh: python call moved into `read_cards()`, `plan="$(read_cards)"`; gate and `--audit` output
  byte-identical to HEAD's script (diffed); `bash -n` under Docker bash:3.2 is clean for it and every
  scripts/tests/.claude `.sh` file.
- Fixture heredoc-in-subst: original = defects-check.sh's `plan="$(` with its real `card's` comment line; neighbour =
  unquoted `$(` on its own line, `cat <<END` with `it's`. Both fail `bash -n` under bash:3.2 and both are gate hits.
- Card: fixtures list + a Never bullet; docs/defects/INDEX.md regenerated with `bash scripts/defects-index.sh`.

## Findings
- Tree hits (story 07's files, not marked `# portable:`): `scripts/cycle.sh:2079` and `scripts/trace-check.sh:117`,
  both `case-in-subst`. Until 07 fixes them, maintenance.test.sh "the tree exits 0" is red, so close-story cannot pass.
  Relaunch 2026-10-29: with 07's uncommitted edits in the tree, portability-check is clean and maintenance.test.sh is
  301/0; the tree hits are gone (pending 07's commit).
- `docs/defects/INDEX.md` must be regenerated (`bash scripts/defects-index.sh`): the new Never and How-to lines make
  `defects-check.sh` RED `index stale`. INDEX.md is not under `## Files`; add it (or let the Queen regenerate it).
  Still open on relaunch: defects-check.sh is RED `index stale` (both fixtures pass their check), and this is the
  only thing between the story and close-story. Not regenerated here: it would be an edit outside `## Files`.
  Resolved by the Queen's ruling below: regenerated.
- close-story exit 4 `test changed after red receipt: re-run stamp-red`: `scripts/defects-check.sh` is both under
  `## Files` and a `## Verification` line, so lib.sh `sealed_tests` seals it with tests/maintenance.test.sh. The
  receipt (11:45:34Z) sealed the pre-fix script; the ruling's `read_cards()` fix edited it afterwards. stamp-red
  cannot be re-run: everything is green now, and re-breaking the gate to get a red is a staged break. Everything else
  passes (maintenance 304/0, defects-check GREEN, scope 9/9). Needs a Queen call: re-stamp the receipt over the
  current tree, or take the defects-check.sh edit out of this story (the verification line or the file).

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: fbd2114d3c947ff6d4e697f29e054c5899bd5fd8cf5a8210e0b3913dd8534e73 (scripts/defects-check.sh, tests/maintenance.test.sh)
- impl: 27861f36d0c418423a62d36a2f9b4254c201f16bd247780229b4dfdf6f87f051
- stamped: 2026-10-29T11:45:34Z

```
        exit=0;
  ok    portability-check: the heredoc in a function called from $( ) is not a hit
  ok    portability-check: a # portable: line is counted as allowed
  ok    portability-check: |& inside a Python heredoc body is not a hit
  ok    portability-check: the line after the heredoc is read again
  ok    portability-check: timeout in an .md sentence outside backticks is not a hit
  ok    portability-check: the bare python cell of CLAUDE.md:76 is a hit
  ok    portability-check: a missing named file exits 2
  ok    portability-check: nothing to scan exits 2
maintenance.test.sh: 304 checks, 2 failed
```

**Owner's choice, 2026-10-29: «Снять отметку red с 09 (Рекомендую)».** The `red: required` mark is removed. The receipts of
11:04:46Z and 11:45:34Z (frontmatter `red_verified_at`, kept as the record) proved the tests red before the implementation;
the only sealed file changed after them is `scripts/defects-check.sh`, a gate script the Queen's ruling put in both
`## Files` and `## Verification`, so `sealed_tests` read it as a test. Framework defect for the next circle: the receipt
seals any `## Files` path named in `## Verification`, not only tests. Close the story as it stands.
