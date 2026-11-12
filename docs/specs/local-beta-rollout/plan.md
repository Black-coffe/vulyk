# Local beta rollout to every local hive (plan)

**Tier:** 1 · **Spec slug:** `local-beta-rollout` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** card `public-release-per-change`, card `upgrade-overwrites-host-edits`, Law 6 (a repeated correction gets a failing check)
**Depends on:** 0.51.0 (local, unpublished), prompt-leaks-rules (Unreleased)

## Goal
The local hives become VULYK's beta channel by default. A private registry lists them, and a hive can carry a hold
with a reason and an end date. `scripts/hives-behind.sh` compares each registered hive's installed version with the
local `VERSION` and goes red on a hive that lags with no live hold. Its `--check` form judges a state file, and that
form is the card's check, with fixtures. In the VULYK source repo, `/vulyk-ship` gains a step after the local merge:
- bump the local dev build;
- upgrade every registered hive from the local clone, merging host edits;
- commit in each hive, never push;
- hold the hives that cannot take it, with the reason;
- end on a green `hives-behind.sh`.

## Assumptions
- Registry: `${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}`, private, never in the repo. One hive per line: `<path>`, or
  `<path> | hold <YYYY-MM-DD> <reason>`. The date is the day the hold ends, at most 7 days ahead. An expired hold is
  red, so a hold cannot become the new "later".
- Dev numbering: `X.Y.Z-dev.N` -> `X.Y.Z-dev.<N+1>`; a plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`. The public number is
  chosen at publish time, on the owner's word. Nothing is tagged or pushed by the step.
- The step runs only where `install.sh` and `VERSION` sit at the repo root (the VULYK source). In a hive, or with no
  registry, it prints one named skip line and the ship goes on. The default path needs no personal file.
- Canary first (the owner chose «Канарейка, потом все (Рекомендую)» on 2026-11-12, after a side-agent warning that a
  bad change would land in every hive at once; option text is the agent's): two registry hives marked ` | canary`, of
  different shape, are upgraded and smoke-tested with one of their own test rows; only on green do the others follow,
  in the same session. A red canary is reverted and the rest are held with its failure as the reason.
- A hive is upgraded only when it is on the branch it ships from and `git status --porcelain` is empty. Otherwise it
  gets a hold with the reason. The upgrade's `.vulyk-new` files are merged by hand before the hive commit.

## Stories

**Wave 1**
- `local-beta-rollout-01` — hives-behind.sh + test + card check and fixtures + the ship step + CHANGELOG

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped
- A `/vulyk-status` or SessionStart line for lagging hives: the ship step runs the check on every ship, which is
  every change. Add the line if a lag is still missed in practice.

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-11-12
**Branch:** vulyk/local-beta-rollout
**Council:** ESCALATE round 1, 2026-11-12, at 5d232ff3, pack 3efc00cf5778
**Council:** GREEN round 2, 2026-11-12, at b8b80027, pack 96bc00f4a00a

## Needs a human
- reason: ceiling · round 1 · 2026-11-12
- ask 1: BLOCK by the reviewer - see docs/specs/local-beta-rollout/council/round-1/review.md
- seats: docs/specs/local-beta-rollout/council/round-1/
**Shipped:** 0.52.0-dev.1, 2026-11-12, at 4e91beef - merged to main (local), rolled out to 5 local hives (2 canaries green), 10 held; publish pending
