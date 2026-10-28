---
story: red-receipt-03-docs
spec: red-receipt
status: done
returned: DONE
tier: 3
worker: worker-code
model: haiku
wave: 2
blocked_by: [red-receipt-01-stamp-red-verb]
---

# ADR-025, the cycle page, the command reference and the CHANGELOG record the red receipt

## Goal
`model: haiku`: routine - every decision, message and bypass is already fixed in plan.md `## Contracts`,
`## Assumptions` and `## Rejected`; this story transcribes them into the four documents, in the shape each already
has, and invents nothing. Read story 01's `## Implementation notes` for a message that changed in the build.

- `docs/adr/025-red-receipt.md` (same layout as ADR-024): Status accepted; Context (the request's three sentences:
  verify-gap is static, a test and its code land in one wave, the council saw green tests on broken code twice);
  Decision - D1 the mark `red: required` by the planner's critical list, absent = today; D2 `red_reason` and
  `stamp-red` (what it refuses, what it writes, same runner and budget as close-story); D3 the close-story gate's
  three refusals; D4 repair inherits the mark; D5 wave-check `red-no-test` / `red-value`; D6 the prompt order and
  the two prohibitions; Named bypasses (card `safeguard-bypassable-or-late`): the planner not marking (visible in
  plan.md), break-the-code-stamp-restore (forbidden in the prompts, the reviewer reads the tail, not script-closed),
  the Queen's solo discipline (same gate, no driver), the bootstrap exception for the verb's own story; Rejected:
  H2 FAIL_TO_PASS worktree, a waiver field, git-history detection, mutation testing, a script mock ban; Consequences:
  a stamp costs one verification run («за секунду» is tokens, not seconds), a test edit after green needs the Queen
  (`NEEDS_CONTEXT`, re-stamp against the baseline), pre-existing stories in every hive are unmarked.
- `docs/cycle.md`: stage 04 row - a `red: required` story first proves its test red with `cycle.sh stamp-red`
  (receipt in the story file), then closes as today; "What invalidates a confirmation" table gains one row: a
  sealed test edited after the receipt reopens stage 04 (artifact `red_verified_at`, cure: re-stamp).
- `docs/command-reference.md`: the `/vulyk-build` solo paragraph gains one sentence: on a `red: required` story the
  Queen runs `cycle.sh stamp-red <file>` after the test and before the code; `close-story` refuses without it.
- `CHANGELOG.md` `## [Unreleased]`: an `### Added (spec \`red-receipt\`)` block in the 0.39.0 style - the verb, the
  gate, the inheritance, the prompts, the template, and one line for hive owners: existing stories are unmarked,
  the planner marks from now on.

## Requirements
> 1. `cycle.sh stamp-red <story-file>` за секунду и 0 токенов убеждается, что команда из ## Verification реально падает, и пишет однострочный штамп red_verified_at.
> 4. Без новых агентов.
> 7. (horizon) stamp-red принимает красный только с ожидаемым текстом падения и пишет квитанцию с хешем теста. close-story отказывает без квитанции или если тест правили после неё.

## Files
- docs/adr/025-red-receipt.md
- docs/cycle.md
- docs/command-reference.md
- CHANGELOG.md

## Non-goals
- Do not edit `memory/map/` (drone-docs at ship), `docs/wiki/`, CLAUDE.md, `VERSION`, prompts, scripts or tests.
- Do not describe H2 as a future plan: it is declined and recorded only under Rejected.
- Do not state a number (part time, suite time) that story 01's notes do not carry.

## Map slice
memory/map/cycle.md `## Verbs`, `## Repair (ADR-013 D4)`; memory/map/agents-and-commands.md `## Commands`
(`/vulyk-build` solo).

## Acceptance criteria
- [ ] ADR-025 names every message of the verb and the gate verbatim from plan.md `## Contracts`, all four bypasses,
      and the five rejected options with a reason each.
- [ ] `docs/cycle.md` stage 04 row and the invalidation table mention the receipt; nothing else on the page moves.
- [ ] `docs/command-reference.md` `/vulyk-build` names `stamp-red` on the solo path in one sentence.
- [ ] CHANGELOG `## [Unreleased]` has the block; `## [0.39.1]` is untouched.
- [ ] `bash scripts/defects-check.sh docs/adr/025-red-receipt.md` exits 0.

## Verification
`bash scripts/defects-check.sh docs/adr/025-red-receipt.md`
`bash tests/maintenance.test.sh`

## Implementation notes
- docs/adr/025-red-receipt.md: new; layout as ADR-024 with `## Options` listing the five declined proposals (reasons from horizon.md, the plan's Rejected for the three it carries) and `## Named bypasses` for the four bypasses.
- docs/cycle.md: stage 04 row names the receipt; one invalidation row added at the end of the table; nothing else moved.
- docs/command-reference.md: one sentence in the `/vulyk-build` solo paragraph naming `stamp-red`.
- CHANGELOG.md: `### Added (spec \`red-receipt\`)` under `## [Unreleased]`; `## [0.39.1]` untouched.
- Surprise: plan.md's Rejected carries three options; the other two (mutation testing, mock ban) reasons come from horizon.md's table.
- `bash scripts/defects-check.sh docs/adr/025-red-receipt.md` exits 0 (GREEN: 2 blocking checks).

## Findings
