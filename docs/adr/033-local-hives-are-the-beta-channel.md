# ADR-033: Local hives are the beta channel, canaries first, nothing pushed

- Status: proposed
- Date: 2026-11-12
- Spec: docs/specs/local-beta-rollout

## Context
The owner's request (brief.md, translated summary of the verbatim quote): every improvement merged to the local
VULYK main rolls out automatically to every local hive, to collect feedback and see each change in practice; only
after the owner decides it is fine does it go to the public repository, so the public VULYK does not suffer.

plan.md `## Assumptions`, verbatim:

> Dev numbering: `X.Y.Z-dev.N` -> `X.Y.Z-dev.<N+1>`; a plain `X.Y.Z` -> `X.<Y+1>.0-dev.1`. The public number is
> chosen at publish time, on the owner's word. The step tags the dev build locally (`v<version>`, so the next
> upgrade knows what a hive came from) and pushes nothing.

(The plan first said "nothing is tagged"; round 1 review found that install.sh needs the local tag, and the repair
added it: `docs/specs/local-beta-rollout/council/round-1/review.md`, major 2.)

> Canary first (the owner chose «Канарейка, потом все (Рекомендую)» on 2026-11-12, after a side-agent warning that a
> bad change would land in every hive at once; option text is the agent's): two registry hives marked ` | canary`, of
> different shape, are upgraded and smoke-tested with one of their own test rows; only on green do the others follow,
> in the same session. A red canary is reverted and the rest are held with its failure as the reason.

> Registry: `${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}`, private, never in the repo. [...] The date is the day the hold
> ends, at most 7 days ahead. An expired hold is red, so a hold cannot become the new "later".

plan.md `## Plan deltas` records only briefing, branch, council and ship bookkeeping; the decisions live in
`## Assumptions`.

## Options
None recorded - the plan states the chosen shape only. The canary choice was made in an option window whose other
options are not recorded.

## Decision
Every change merged to local main is rolled out as a local dev build (`-dev.N`) to every registered local hive.
Two canary hives of different shape are upgraded and smoke-tested first; the rest follow only on green. The rollout
step bumps `VERSION` and the mod's `plugin.json` together and tags the build only locally; it never pushes. The
public version number is chosen at publish time on the owner's word.
Deciding factors as recorded: the public VULYK must not carry untested changes (owner), and a bad change must not land
in every hive at once (side-agent warning the owner accepted).

## Consequences
Not recorded.

## Invariants created
- The rollout step pushes nothing and publishes nothing; its only tag is the local `v<version>` of the dev build.
  Publishing is a separate act on the owner's word.
- Canaries are upgraded and green before any other hive is upgraded; a red canary is reverted and every other hive
  is held with its failure as the reason.
- A hive lagging the local version without a live hold is red; a hold carries a reason and an end date at most 7
  days ahead, and an expired hold is red.
- The hive registry is private and never committed to the repo; with no registry the step skips by name, not fails.

## Revisit when
Not recorded.
