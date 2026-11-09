---
story: mass-audit-fixes-13
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 4
blocked_by: [mass-audit-fixes-02, mass-audit-fixes-05, mass-audit-fixes-06, mass-audit-fixes-07, mass-audit-fixes-08, mass-audit-fixes-10]
---

# The paperwork follows the code: ADR-032 accepted, ADR-025/001 amended, prose and the constitution updated

## Goal
Every document that described the old behaviour now describes the shipped one. `docs/adr/032-story-trust-from-
git.md` goes to `Status: accepted`. `docs/adr/025-red-receipt.md`: D3 reads `red:` from the approved version;
the Consequences bullet on the stash escape points to ADR-032 D5 (`stamp-red --baseline`); the mark-deletion
bypass is named. `docs/adr/001-cycle-state-contract.md` D1: "accept either" is amended to the D4 rule.
`docs/cycle.md` and `docs/hooks-reference.md`: the new verbs and exits, the block-card gate, the quoted hook
command form, the git-guard header's updated coverage, and the three accepted costs (O2, O7, O8) with their
measurements. `CLAUDE.md`: a `| Handoff | \`bash tests/handoff.test.sh\` |` row in `## Commands`, the
*Models and effort* gap note lists the same-family cases story 06 documented, and wording is trimmed to stay
under 7168 bytes without changing a rule. `.claude/agents/lead-review.md` drops "cannot occur" and asks for
the receipt check as before. `.claude/agents/worker-code.md` step 6 maps the new exit-4 texts (`story blocks
differ`, `defect card <ref> fails`, `no approved version`) to NEEDS_CONTEXT. `.claude/commands/vulyk-build.md`
and `vulyk-plan.md` commit a changed story as `vulyk(<slug>): revised <story-id>`, name `briefed --go` as the
`--go` path, and name `stamp-red --baseline` as the Queen's escape after `/vulyk-pause`. `CITATION.cff`
version and date follow `VERSION`, and `.claude/commands/vulyk-ship.md` bumps it with VERSION (I9). Asks 10
(row), 12, 14, 11 (I5, I7, I9).

## Requirements
> 10. Handoff: a `/clear` dump never repoints `index.json` away from an enriched handoff; `tests/handoff.test.sh` gets a `## Commands` row; `handoff.sh` honours `$VULYK_PY`.
> 12. close-story reads `## Verification`, `## Files` and `red:` from the story's approved version in git and refuses when the working copy differs in them; a story marked done without close-story's own commit is not closed.
> 14. `cycle.sh` refuses to open the build of a Tier 2-4 plan without the owner's `**Approved:**` or an explicit `--go`, records the `--go`, and the pre-release check requires the same.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- docs/adr/032-story-trust-from-git.md
- docs/adr/025-red-receipt.md
- docs/adr/001-cycle-state-contract.md
- docs/cycle.md
- docs/hooks-reference.md
- CLAUDE.md
- .claude/agents/lead-review.md
- .claude/agents/worker-code.md
- .claude/commands/vulyk-build.md
- .claude/commands/vulyk-plan.md
- .claude/commands/vulyk-ship.md
- CITATION.cff

## Non-goals
- Do not change any script: a prose line that does not match a shipped verb or flag is a finding for
  `prompt-check`, not a reason to edit `cycle.sh`.
- Do not touch `docs/model-cascade.md` (story 06 wrote it) or `docs/defects/README.md` (story 01).
- Do not add a Law or change a rule in `CLAUDE.md`; trims are wording only, and the row and the gap note are
  the only additions.
- Do not describe how the old gates could be bypassed; describe the new behaviour (public repo).
- Do not write `memory/map/*` or `memory/memory.md`: `drone-docs` refreshes the map after the merge.

## Map slice
`memory/map/cycle.md` → whole file (it is the contract these docs restate); `memory/map/agents-and-commands.md`
→ Agents (worker-code, lead-review), Commands (`/vulyk-plan`, `/vulyk-build`, `/vulyk-ship`).

## Acceptance criteria
- [ ] `CLAUDE.md` is under 7168 bytes with the `Handoff` row present (`--part bsd` holds the cap), and
  `bash tests/handoff.test.sh` is now a `## Commands` cell with no `round-only` mark.
- [ ] `bash scripts/prompt-check.sh --touched <the agent and command files above>` reports no `error`: every
  `cycle.sh <verb>` and `--flag` named in the prose exists in the dispatcher.
- [ ] ADR-032 reads `Status: accepted`; ADR-025 and ADR-001 carry a dated amendment line each pointing at
  ADR-032; `lead-review.md` has no "cannot occur".
- [ ] `docs/cycle.md` lists the new exits of `close-story`, `stamp-red`, `briefed`, `branch` and ship-check
  stage 02 in the same shape as the existing rows.
- [ ] `CITATION.cff` `version` equals `VERSION` and `date-released` is today's; `vulyk-ship.md` names the bump.
- [ ] `docs/hooks-reference.md` shows the quoted hook form and the three accepted costs with the measured
  numbers from the private audit, no paths into it.

## Verification
`bash tests/cycle.test.sh --part bsd`
`bash tests/maintenance.test.sh`

## Implementation notes

## Findings
