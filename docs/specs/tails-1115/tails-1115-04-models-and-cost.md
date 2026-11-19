---
story: tails-1115-04
spec: tails-1115
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 2
blocked_by: [tails-1115-01]
red: required
red_reason: a model one version behind the newest is below the floor
red_verified_at: 2026-11-17T09:50:16Z de39bf64a6f3b330442947f44196e7ca2cc49b48e5d77f2f456b8a4784741550
---

# The model floor follows the newest version, the cost tables know it, the gate model knows every plan

## Goal
Four tails where a version or a plan name is written into code (private
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`, items T61, T62, T64, T76).
1. T61: `lib.sh` `model_floor` names the newest version of each family; a pin one version behind reads as below
   the floor in `model_below_floor` and in `top-model.sh --floor`.
2. T62: `scripts/token-report.py` and the pulse mod's `core.ts` price a model by its family and take the cache-read
   price for every version of it, so the newest version is not costed at the uncached rate. Prices come from
   `cc-facts.md` F13, never from memory.
3. T64: `model_version` knows every family name F2 confirms; where the effort cascade is reported, a set
   `CLAUDE_CODE_EFFORT_LEVEL` is named as the value that wins (F3).
4. T76: `top-model.sh` has a branch for every plan F12 confirms, so a known plan no longer reads as unknown.

Each of T64 and T76 follows its fact: `not confirmed` means no code change and one notes line with the source.
Marked red: the floor branch decides whether a dispatch is allowed.

## Requirements
> 5. The hook, telemetry, token-report, prompt-check and model-floor tails in tails.md are fixed; a fallback never runs a model below the floor (pause instead).
> 9. A claim about Claude Code behaviour that a fix rests on is checked against the official docs first; an item whose premise does not hold is closed as not-a-defect with the source named.
> 10. Every fix that code can check gets a failing test with the original case and a neighbour form; all suites green.

## Files
<!-- Functions: lib.sh model_floor, model_below_floor, model_version. Not touched: state_get, state_put and the
rest of the run-state helpers (guards-1115); commands_lint and the header (story 01). -->
- scripts/lib.sh
- scripts/top-model.sh
- scripts/token-report.py
- .claude/mods/vulyk-pulse/hooks/core.ts
- tests/model-profile.test.sh
- tests/mods.test.sh
- tests/token-report.test.sh

## Non-goals
- Do not change the routing by family, the profiles or which agent runs on which family (ADR-015, ADR-020).
- Do not edit the driver, the installer's model pin (story 06) or `.claude/settings.json`.
- `VULYK_MODEL_FLOOR` keeps overriding the floor; `model_below_floor` keeps failing closed on a name it cannot read.
- No doc edit: the pages that still name the old floor go to story 11 through `DOCS:` lines.
- A version literal met in a file outside `## Files` (the driver, a hook, another test) is `NEEDS_CONTEXT`,
  naming file and line.
- Do not bump the pulse mod's `plugin.json`: the ship step does.
- `tests/token-report.test.sh` has no row in `## Commands`; its new case runs at the round gate. Say in the notes
  that you ran it once by hand and what it printed.

## Map slice
`memory/map/scripts.md` → Entry points (`lib.sh` model floor, `model-profile.sh`, `top-model.sh`);
`memory/map/scripts-checks.md` → Entry points (`token-report.py`); `docs/pulse.md` (cost line).

## Acceptance criteria
- [ ] `tests/model-profile.test.sh`: the version just behind the newest of the gate family is below the floor and
  `top-model.sh --floor` exits 1 with `below floor` for a pin on it; the newest passes. The label contains
  `a model one version behind the newest is below the floor`. Neighbours: the same for one other family; an
  unreadable name still fails closed; `VULYK_MODEL_FLOOR` still wins.
- [ ] `tests/token-report.test.sh`: a transcript of the newest version with cache reads is costed at the
  cache-read price of F13. Neighbour: a version the table has never seen, of a known family, takes that family's
  prices, and an unknown family is reported as unpriced, not as zero.
- [ ] `tests/mods.test.sh`: the pulse cost for the same two inputs agrees with `token-report.py`.
- [ ] F2 `confirmed`: `model_version` reads each confirmed family name; a test row per name. F3 `confirmed`: with
  the variable set, the effort report says the variable wins; unset, the output is as today.
- [ ] F12 `confirmed`: each confirmed plan has a branch and a test row; an unknown plan still reads as unknown
  and says so.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/model-profile.test.sh`
`bash tests/mods.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per item and a `DOCS: <file> - <sentence>` line for each doc sentence story 11 must change (the floor version in
README.md, docs/faq.md, docs/getting-started.md, docs/model-cascade.md). -->
- `scripts/lib.sh`: `model_floor` fable line 5.1 -> 5.2; `model_version` reads `mythos` too (F2: BIN alias list; F13 PRICE names Claude Mythos 5.2). No floor line for mythos, so it is never below (as any family with no line).
- `scripts/top-model.sh`: an `*ultra*` organizationType branch (PLAN `ultra`, premium, gate fable) and an `*ultra*` rate tier under Max (DETAIL `Ultra`); `--explain` prints an `effort    :` line only when `CLAUDE_CODE_EFFORT_LEVEL` is set and not `auto`/`unset` (F3).
- F12: Pro, Max, Ultra, Team, Enterprise each have a branch and a test row; Free is on claude.com/pricing only, not in the docs, so no branch. The real organizationType of an Ultra account is not documented (F12): `claude_ultra` is a guess, this account reads `claude_max`/`max_20x`.
- `scripts/token-report.py` + `core.ts`: READ_RATES by family, (major, minor, share) newest first, from F13; an unnamed version takes the nearest version below it (newest above all, oldest below all); an unknown family reads at 0.1 and is listed under JSON `unpriced` and a table line (not zero).
- Sonnet stays at 0.1 though F13 says 0.05 for Sonnet 5.5: the weights pin in `core.test.ts` (outside `## Files`) holds 0.1, and both it and mods.test.sh would turn red.
- "an unreadable name still fails closed" read as an unreadable floor line (`VULYK_MODEL_FLOOR='fable x.y'`) and a malformed `cc>=`: an unreadable model ID is "never below" by the function's own contract, unchanged.
- `tests/mods.test.sh` runs core.ts `weigh()` itself through `node --experimental-strip-types` (bun as fallback, exit 2 with neither).
- `tests/token-report.test.sh` (no `## Commands` row) run once by hand: `token-report.test.sh: 63 checks, 0 failed`. `tests/telemetry.test.sh --part scan` (floor cases) also run: 174 checks, 0 failed.
- New cases red on HEAD: model-profile floor part (fable 5.1 below 5.2 x3, `fable>=5.2`, unreadable override keeps 5.2, mythos, effort line, Ultra x4); token-report (fable-5-2, fable-5-3, opus-6, unpriced x3); mods (fable 5.2/5.3 at 4050). Neighbours that pass on HEAD by design: newest fable/opus on the floor, opus 5 below, malformed cc>=, VULYK_MODEL_FLOOR wins, the four old family rows, unset/auto effort, Pro/Max/Team/Enterprise/unknown plan, Fable 5 at 0.1, the unknown family's 210.
- CHANGELOG: The model floor follows the newest Fable: `fable 5.2`, so a pin to Fable 5.1 reads as below the floor (T61).
- CHANGELOG: token-report and the pulse price cache reads by model family and version from the published prices, so Fable 5.2 is no longer costed at the uncached rate, and an unknown family is listed as unpriced (T62).
- CHANGELOG: `model_version` reads Mythos IDs; `top-model.sh --explain` names a set `CLAUDE_CODE_EFFORT_LEVEL` as the effort that wins (T64).
- CHANGELOG: `top-model.sh` knows the Ultra plan, so it no longer reads as unknown and hands the gate to Fable (T76).
- DOCS: README.md - line 27 and line 133: the floor reads `fable 5.2 · opus 5.5 · sonnet 5.5 · haiku 5.5`.
- DOCS: docs/faq.md - line 20: the floor reads `fable 5.2 · opus 5.5 · sonnet 5.5 · haiku 5.5`.
- DOCS: docs/model-cascade.md - line 274: the floor line reads `fable 5.2 · opus 5.5 · sonnet 5.5 · haiku 5.5 cc>=2.1.293`.
- DOCS: docs/getting-started.md - line 42: "Opus 5.5 and Fable 5.1" names the current Fable (5.2) if the sentence is about today's models.
- DOCS: docs/pulse.md - the cost line: cache reads are weighed by family and version (0.025 Fable 5.1+, 0.05 Opus 5.5+, 0.1 otherwise).

## Findings

## Red receipt
- command: bash tests/model-profile.test.sh
- exit: 1
- tests: de39bf64a6f3b330442947f44196e7ca2cc49b48e5d77f2f456b8a4784741550 (tests/model-profile.test.sh, tests/mods.test.sh)
- impl: 5587748d034cc1def985f3c2996dc79e90fa04b27edc6c55c213cfcff285afa9
- stamped: 2026-11-17T09:50:16Z

```
::error::a model one version behind the newest is below the floor: claude-fable-5-1 against fable 5.2 - expected [fable 5.1 5.2], got [ok]
::error::a model one version behind the newest is below the floor: --floor exits 1 on a gate pin to claude-fable-5-1 - expected [1], got [0]
::error::a model one version behind the newest is below the floor: --floor names the gate pin - expected 'below floor: gate model (env) = claude-fable-5-1 is fable 5.1, floor 5.2' in:
        profile   : /tmp/tmp.Qu9MSK5fKJ/ultra.json
        second reviewer (Tier 4): opus
        dispatched for: the Tier 4 lead-review (beside the second reviewer), lead-architect, a Tier 4 queen-planner, a missed story's retry; lead-review at Tier 1-3 runs on its frontmatter (opus)
        gate: the Tier 4 review, the Tier 4 planner, lead-architect (Tier 4, or a story missed twice), a missed story's retry. A hive's own judge: bash scripts/model-profile.sh --role seat, and pass --effort explicitly.
        queen session: not pinned - the session starts on the account default (Opus since Claude Code 2.1.280). Run: bash scripts/top-model.sh --apply
  ok    plan Team
  ok    plan Enterprise
  ok    an unknown plan still reads as unknown
  ok    and says so
model-profile.test.sh: 11 of 121 checks failed
```
