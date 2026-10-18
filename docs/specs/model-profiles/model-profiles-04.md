---
story: model-profiles-04
spec: model-profiles
status: todo
returned:
tier: 3
worker: worker-code
wave: 2
blocked_by: [model-profiles-01, model-profiles-02]
---

# ADR-020 and the docs describe the three profiles; CHANGELOG 0.30.0

## Goal
A new `docs/adr/020-model-profiles.md` amends ADR-015. It covers:
- today's ladder becomes the `sonnet-builds` profile, still the default;
- `opus-builds` and `economy` with their role tables;
- `model: haiku` for routine stories in those two profiles;
- the rule "the family that builds never judges" holds in every profile, which is why Fable judges under `opus-builds`
  (both blind seats included) and the Tier 4 second reviewer is `sonnet`;
- the accepted gap: under `economy` the second reviewer is the builders' family;
- one file per machine, untouched by the installer;
- one rejected alternative, taken from plan.md.

ADR-015 gets a dated status line pointing to ADR-020. `docs/model-cascade.md` gets a "Model profiles" section: the role
table, the resolver, how the gate order now reads, and how to change the profile. The README's ladder paragraph names the
three profiles and `/vulyk-models`. `docs/command-reference.md` lists `/vulyk-models`. `CHANGELOG.md` gets a 0.30.0 entry.

## Requirements
> 8. Выходит минорным релизом 0.30.0.
> 3. Вариант «Как сейчас»: Sonnet пишет, Opus судит, Fable на воротах.
> И пишем, что можно это распределение поменять.

## Files
- docs/adr/020-model-profiles.md
- docs/adr/015-sonnet-execution-rung-and-model-floor.md
- docs/model-cascade.md
- README.md
- docs/command-reference.md
- CHANGELOG.md

## Non-goals
- Do not bump `VERSION` or write a release commit or tag: `/vulyk-ship` does.
- Do not edit `CLAUDE.md` (story 01 owns its byte-neutral pointer).
- No benchmark or price figures that are not already in ADR-015 or `docs/model-cascade.md`. No figure is written from
  memory; a line that needs one says where it comes from.
- Use no host folder or client names in examples. This is a public repo.
- Do not rewrite ADR-015's decisions. Add only an amendment line under its Status.

## Map slice
docs/adr/015-sonnet-execution-rung-and-model-floor.md (whole); docs/model-cascade.md (enforcement 16-24, plan->gate table
48-53, ladder table 128-133, retry 163-166); plan.md `## Contracts`, `## Assumptions`, `## Rejected alternative`; the
`model-profiles-01`/`-02` `## Implementation notes` for what really landed

## Acceptance criteria
- [ ] ADR-020 states the three profiles with the same role table as plan.md's `## Contracts`, corrected by any
      `## Plan deltas` entry. It names the profile file's path and the fail-open rule, and states that the installer
      and upgrades never write it.
- [ ] ADR-015's Status carries a 2026-10-18 amendment line pointing to ADR-020.
- [ ] `docs/model-cascade.md`'s gate-order text matches `top-model.sh`'s order: env, constitution, profile, plan,
      `opus`.
- [ ] README and `docs/command-reference.md` name `/vulyk-models`, its voice triggers in short, and that the choice can be
      changed any time.
- [ ] CHANGELOG 0.30.0 lists the resolver, the quiz, the first-run line, the driver arguments, and ADR-020.

## Verification
`none — reviewed by lead-review`

## Implementation notes

## Findings
