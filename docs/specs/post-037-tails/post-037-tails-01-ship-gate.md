---
story: post-037-tails-01
spec: post-037-tails
status: done
returned: DONE
tier: 3
worker: worker-code
wave: 1
blocked_by: []
---

# Ship gate: an ACCEPTED override is current only when the pack and the commit still match

## Goal
After this story `scripts/ship-check.sh` prints `NOT READY` for the 0.37 case: a GREEN council row, a newer `human.jsonl` ACCEPTED row, then a code commit. One function in `scripts/lib.sh`, `verdict_stale <spec-dir> <head-sha> <pack-fp>`, holds the pack/commit staleness rule; the council branch of `ship-check.sh` (an ACCEPTED human row newer than the council row), its no-council branch and `scripts/human-check.sh --check` all call it instead of carrying their own copy. Behaviour elsewhere is unchanged: a REJECTED row is `not ok`, a paperwork-only range (`paperwork_only`: `VERSION`, `CHANGELOG.md`, spec paperwork, ledgers) after ACCEPTED stays current, so `/vulyk-ship`'s release-paperwork commit does not stale the gate.

## Requirements
> 1. `scripts/ship-check.sh` no longer prints READY when code changed after the owner's `**Checked:** ACCEPTED`: stage 05 applies the same pack/commit staleness rule as `scripts/human-check.sh --check`, with a failing test on the 0.37 case (ACCEPTED, then a code commit, under a GREEN council row).

## Files
- scripts/lib.sh
- scripts/ship-check.sh
- scripts/human-check.sh
- tests/cycle.test.sh

## Non-goals
- Do not change what counts as paperwork (`is_paperwork_path`) or the pack fingerprint (`pack_fingerprint`); the function composes them.
- Do not touch the REJECTED path, the council-row verdict parsing, stages 01-03 or 06, `--record`, or `scripts/acceptance-log.sh`.
- Do not make `human-check.sh` write anything new; `--check` keeps its printed words (`CURRENT` / `STALE (pack)` / `STALE (commit)` as it prints them today), only computed by the shared function.
- Do not add a `docs/defects/` card or touch `CLAUDE.md`, `docs/cycle.md`, `.claude/commands/vulyk-ship.md` (story 04's file).
- Do not rename or reorder the other `lib.sh` functions: `scripts/telemetry.sh` sources it and story 02 edits that file in this wave.

## Map slice
`memory/map/scripts.md`: `## Entry points` (`lib.sh` sourced-only functions `pack_fingerprint`, `is_paperwork_path`, `paperwork_only`, `marker`; `ship-check.sh <spec-dir> / --record`; `human-check.sh`), `## Key contracts` (`is_paperwork_path` whitelist), `## Gotchas` (security-relevant string matches stay anchored), `## Tests` (`cycle` has 7 parts, `--part <topic>`). Contract `verdict_stale` in `docs/specs/post-037-tails/plan.md` `## Contracts`.

## Acceptance criteria
- [ ] `verdict_stale <spec-dir> <head-sha> <pack-fp>` exists in `scripts/lib.sh`: prints `CURRENT` (exit 0), `STALE (pack)` or `STALE (commit)` (exit 1); pack is tested before commit; a `<head-sha>..HEAD` range that is `paperwork_only` is `CURRENT`.
- [ ] `tests/cycle.test.sh --part ship` gains a case that fails on the 0.37 `ship-check.sh` and passes after: a spec with a GREEN `**Council:**` row and council.jsonl row, an ACCEPTED human row with a later timestamp at HEAD, then one commit touching a non-paperwork file -> stage 05 `not ok` carrying `STALE (commit)`, final line `NOT READY`, exit non-zero as the other NOT READY cases exit.
- [ ] A sibling case: same setup, then a commit touching only `VERSION` and `CHANGELOG.md` -> still `READY`.
- [ ] A sibling case: same setup, then a story file added or removed (pack changes) -> `STALE (pack)`, `NOT READY`.
- [ ] `ship-check.sh`'s no-council branch and `human-check.sh --check` give the same answers as before on the existing `--part ship` cases, now through `verdict_stale`; no copy of the pack/commit comparison remains in either script.
- [ ] `git diff --stat` touches only the four files under `## Files`.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
- scripts/lib.sh: `verdict_stale` added after `marker()` (no reorder); resolves both shas with `rev-parse --verify` so short/full heads compare equal; an empty or `-`-led head is `STALE (commit)` without reaching git.
- scripts/ship-check.sh: council branch parses the human row's `pack`/`head`; an ACCEPTED override is `ok` only when `verdict_stale` is CURRENT, else 05 `OPEN` naming the STALE word and 04 falls back to the council row alone. No-council branch now calls `verdict_stale`; messages unchanged.
- scripts/human-check.sh: `--check` pack/commit comparison replaced by `verdict_stale`; printed words unchanged.
- tests/cycle.test.sh: new `gate-demo` block in `--part ship` (code commit -> STALE (commit)/NOT READY, VERSION+CHANGELOG -> READY, new story -> STALE (pack)/NOT READY); run against the HEAD (0.37) scripts the two STALE cases fail (5 errors), with the new scripts all 45 pass.
- ship-check.sh always exits 0 (header contract); "exit non-zero as the other NOT READY cases exit" read as "the same as they do", so exit status unchanged.

## Findings
