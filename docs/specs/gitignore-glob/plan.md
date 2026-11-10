# install.sh writes the .gitignore patterns; the Fable council seats finish their work (plan)

**Tier:** 1 · **Spec slug:** `gitignore-glob` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-005 (installer upgrade contract), ADR-015 (model ladder: the seats run on the profile's seat family)
**Depends on:** 0.50.2

## Goal
`ensure_gitignore` stops glob-expanding its wanted list (`set -f` around both loops), so every hive gets
`docs/specs/*/DRIVER`, `docs/specs/*/PAUSE` and `*.vulyk-new` as written, from any working directory. The two blind
council seats (`council-opus`, `council-haiku`), which run on Fable at medium or unset effort in opus-builds, carry
Anthropic's "# Finishing work" text from "Prompting Claude Fable 5.2", adapted to a seat: an ordinary obstacle is
diagnosed and worked through before an ask is marked `N/A - why: environment`.

## Assumptions
- The guide's text goes in near-verbatim, with "the user asked for" read as "the asks you were given"; its closing line
  (it does not override confirmation on risky actions) stays.
- The seats' effort is not raised: that is a cost decision, left to the Fable 5.2 spec.
- Hives already carrying a stray `docs/specs/<slug>/DRIVER` line are cleaned by hand during the rollout, not by the installer.

## Stories

**Wave 1**
- `gitignore-glob-01` — `set -f` in ensure_gitignore and its test; the finishing-work text in the two seats

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas
**Briefed:** via mini-brief, Andrei, 2026-11-10
