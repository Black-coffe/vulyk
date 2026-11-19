# Brief - solo-gate-1118

## Request (verbatim)

> Правку гейта Tier 1 бери в 0.54

Context the owner answered (2026-11-18): a side-agent note on docs-1115 - a Tier 1 docs story ran the full
suite as its round gate (1521 s), and its repair forced a second full run before merge; the owner's 2026-11-17
rule for this repo: a small change gets small checks, the full suite runs once, before merge.

## Asks

Owner's scope answer (2026-11-18): «Только там, где включено (Рекомендую)» - an opt-in switch, on in VULYK, hives
unchanged.

1. At Tier 1-2 the round's test gate runs no full suite: `cycle.sh suite` writes a finished `SUITE: none` log with its reason (the stories' own checks ran at close-story; the full suite runs once before merge), so the full suite runs once per Tier 1-2 spec, at the merge run.
2. The narrow round after a Tier 1-2 repair runs no gate step either (`rerun=` empty, `SUITE: none - narrow repair round`), never `all` because round 1 logged no steps.
3. Tier 3-4 rounds, and a round the owner opened with `--full` at any tier, run the gate as today.
4. The tier is the round's frozen `tier=` (ROUND), not plan.md read again.
5. `lead-review.md` and the docs and command files that describe the round's gate say so; the reviewer treats the Tier 1-2 `none` as expected, not a finding.
6. Opt-in only: the change acts only where the repo's default branch holds a root file `.vulyk-solo-gate` whose content is exactly `merge-only`; missing, empty or any other content is today's behaviour, and a spec branch cannot switch its own gate off. The installer does not ship the file; VULYK's own repo carries it.
