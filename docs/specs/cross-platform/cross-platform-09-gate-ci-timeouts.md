---
story: cross-platform-09
spec: cross-platform
status: todo
returned: NEEDS_CONTEXT
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason: names rule case-in-subst
red_verified_at: 2026-10-29T11:04:46Z 4811294c10358e3713ff6ae6a7ca1332e198f1a88976e403c5f5a0e36f380da4
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

## Findings
- Tree hits (story 07's files, not marked `# portable:`): `scripts/cycle.sh:2079` and `scripts/trace-check.sh:117`,
  both `case-in-subst`. Until 07 fixes them, maintenance.test.sh "the tree exits 0" is red, so close-story cannot pass.
  Relaunch 2026-10-29: with 07's uncommitted edits in the tree, portability-check is clean and maintenance.test.sh is
  301/0; the tree hits are gone (pending 07's commit).
- `docs/defects/INDEX.md` must be regenerated (`bash scripts/defects-index.sh`): the new Never and How-to lines make
  `defects-check.sh` RED `index stale`. INDEX.md is not under `## Files`; add it (or let the Queen regenerate it).
  Still open on relaunch: defects-check.sh is RED `index stale` (both fixtures pass their check), and this is the
  only thing between the story and close-story. Not regenerated here: it would be an edit outside `## Files`.

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 4811294c10358e3713ff6ae6a7ca1332e198f1a88976e403c5f5a0e36f380da4 (tests/maintenance.test.sh)
- impl: 363e4d4182bf006ed2efec8c35f158638e17c0481ae55c23684954477494cccf
- stamped: 2026-10-29T11:04:46Z

```
        exit=0;
  ok    portability-check: the (pat) form inside a multi-line $( ) is not a hit
  ok    portability-check: a # portable: line is counted as allowed
  ok    portability-check: |& inside a Python heredoc body is not a hit
  ok    portability-check: the line after the heredoc is read again
  ok    portability-check: timeout in an .md sentence outside backticks is not a hit
  ok    portability-check: the bare python cell of CLAUDE.md:76 is a hit
  ok    portability-check: a missing named file exits 2
  ok    portability-check: nothing to scan exits 2
maintenance.test.sh: 301 checks, 9 failed
```

**Queen's ruling, 2026-10-29 (after NEEDS_CONTEXT, and story 07's leftover):** `## Files` gains `docs/defects/INDEX.md`
(regenerate it with `bash scripts/defects-index.sh` after the card edits), `scripts/defects-check.sh` and one more fixture.
Story 07 found that bash 3.2 cannot parse `scripts/defects-check.sh` (a `<<'PY'` heredoc inside `plan="$( ... )"`, lines
82-332: «unexpected EOF while looking for matching `''»), so every `tests/defects.test.sh` case fails on macOS. Fix it the
way 07 tested in a container: the python call in a function (`read_cards() { ... <<'PY' ... PY }`, `plan="$(read_cards)"`),
same output. The gate gets a third rule of the same bash 3.2 class, `heredoc-in-subst` (a `<<` heredoc opened inside a
multi-line `$( ... )`), with the original case and a neighbour form as fixture and tests. Story 07 is committed (a8776c5),
so the tree run is expected clean; check it under Docker `bash:3.2` too.
