---
story: cross-platform-09
spec: cross-platform
status: todo
returned:
tier: 3
worker: worker-code
model: opus
wave: 5
blocked_by: []
red: required
red_reason:
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

## Implementation notes

## Findings
