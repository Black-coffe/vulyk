# ADR-034: A busy hive is held, never upgraded; one green canary carries the rollout

- Status: proposed
- Date: 2026-11-12
- Spec: docs/specs/post-052-tails
- Amends: ADR-033, invariant "Canaries are upgraded and green before any other hive is upgraded; a red canary is
  reverted and every other hive is held with its failure as the reason." ADR-033's accepted text is not edited.

## Context
ADR-033 was accepted "as is" (brief.md `## Answers` 4) before two later owner decisions in the same spec changed the
rollout it describes.

plan.md `## Assumptions`, verbatim (lines 18-28):

> Hold re-check (ask 7): step 2a re-checks every live hold on every ship, and before upgrading ANY hive (held or
> not) asks `bash scripts/hives-behind.sh --busy <hive>`. Busy = a `docs/specs/*/DRIVER` file, or a transcript under
> `<root>/projects/<slug>/*.jsonl` written in the last 60 minutes, roots `${CLAUDE_CONFIG_DIR:-~/.claude}` plus every
> `~/.claude*` dir (a second account), slug = the hive path with `:`, `/`, `\`, `_`, `.` turned into `-`. No
> transcript dir found under any root = `unknown`, treated as busy (a missing input is never a pass). Output one line,
> `idle` / `busy <reason>` / `unknown <reason>`, exit 0 / 1 / 1. A busy or unknown hive gets a hold with that reason
> (date <= 7 days); an idle held hive on its ship branch with a clean tree has its hold removed and is upgraded.
> Right before the hive commit the check and `git status --porcelain` run again: a path the upgrade did not write, or
> a busy verdict, stops that hive with no commit and a line to the owner. [...]

> Known gap (owner chose it knowingly): an open session silent for over 60 minutes is not seen.

> 2026-11-12 revision: ask 7 widened after a side agent's note (clean tree is not an idle hive); the owner picked
> «Три признака, сомнение = пауза (Рекомендую)». [...]

plan.md `## Plan deltas`, verbatim (line 61):

> 2026-11-12, repair round 1: a side agent noted that a busy canary (held, so never green) would stop the whole
> rollout, and the Queen had settled it only in story 01's notes. Owner chose «Хватит одной свободной (Рекомендую)»:
> one upgraded green canary is enough when the other is busy; the busy one is held and goes first next ship; the
> owner is told the build was smoke-tested on one hive shape; both busy = every other hive held and the canary
> sessions to close named. Rejected: retry for an hour, keep the stall, a stand-in canary. [...]

plan.md `## Plan deltas`, verbatim (line 62):

> 2026-11-12, after story 01 closed: a side agent noted that a session opened in a hive subfolder writes its
> transcript under `<slug>-<rest>`, which `--busy` never reads, so the hive looks idle. New story `post-052-tails-03`
> (wave 3, red: required) reads `<slug>-*` folders and counts one only when a fresh transcript's `cwd` is the hive or
> below it; an unreadable `cwd` is busy. Rejected: a bare prefix match (a sibling hive such as `X:/Acme_co` would hold
> `X:/Acme`). Within ask 7, no ask change.

(Option texts are the agent's; the owner picked them.)

## Options
Busy guard: none recorded beyond the chosen «Три признака, сомнение = пауза» - the other options of that window are
not recorded.

Busy canary (line 61):
1. One green canary is enough; the busy one is held and goes first next ship - chosen.
2. Retry for an hour - rejected; reason not recorded.
3. Keep the stall - rejected; reason not recorded.
4. A stand-in canary - rejected; reason not recorded.

Subfolder sessions (line 62):
1. Read `<slug>-*` folders, count one only when the transcript's `cwd` is the hive or below - chosen.
2. A bare prefix match - rejected: a sibling hive such as `X:/Acme_co` would hold `X:/Acme`.

## Decision
Before any hive is upgraded, and again right before its commit, step 2a asks whether the hive is busy (DRIVER file,
or a session transcript written in the last 60 minutes, including sessions opened in a hive subfolder matched by
`cwd`). Busy or unknown means a hold with the reason, never an upgrade. Every ship re-checks every live hold.
A busy canary is held, not red: one canary that took the build and is green carries the rollout; the owner is told
only one hive shape was smoke-tested; with both canaries busy every other hive is held and the canary sessions to
close are named.
Deciding factors as recorded: a clean tree is not an idle hive (side-agent note, owner accepted); a busy canary would
otherwise stop the whole rollout (side-agent note, owner accepted).

## Consequences
Not recorded, except the known gap the owner chose: an open session silent for over 60 minutes is not seen.

## Invariants created
- No hive is upgraded without an `idle` verdict from `hives-behind.sh --busy`; `busy` and `unknown` both hold the
  hive with that reason (a missing input is never a pass).
- The busy check and `git status --porcelain` run again right before the hive commit; a path the upgrade did not
  write, or a busy verdict, stops that hive with no commit and a line to the owner.
- Every ship re-checks every live hold; an idle held hive on its ship branch with a clean tree has its hold removed
  and is upgraded.
- Subfolder sessions are matched by the transcript's `cwd` being the hive or below it, never by a bare path prefix;
  an unreadable `cwd` is busy.
- Amends ADR-033: a busy canary is held, not red. At least one canary upgraded and green is required before any
  other hive is upgraded; a held canary goes first next ship; with no canary taking the build, every other hive is
  held. A red canary still reverts and holds the rest as ADR-033 states.

## Revisit when
Not recorded.
