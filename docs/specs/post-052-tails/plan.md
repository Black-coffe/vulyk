# Tails after 0.52.0-dev.1 (plan)

**Tier:** 2 · **Spec slug:** `post-052-tails` · **Brief:** [brief.md](brief.md)
**Model profile:** opus-builds
**Governed by:** ADR-033 (local hives are the beta channel), card `public-release-per-change`, `memory/map/README.md` (~80-line slice cap)
**Depends on:** local-beta-rollout, shipped as 0.52.0-dev.1 (4e91beef, local tag), ba53f294 (ADR-033 proposed, map slices)

## Goal
Close the round-2 review minors and the descoped line of local-beta-rollout, and stop held hives from sitting out
whole releases. `/vulyk-ship` says truthfully that its only tag is the local dev build's; the impossible-day test
fails without the real-day rule; `/vulyk-status` names lagging hives in the VULYK source; step 2a re-checks every hold
on every ship. The map gets back the ADR-032 bullet, `scripts.md` is split into slices within the cap, and ADR-033
becomes accepted on the owner's grill answer.

## Assumptions
- The status line runs only where `install.sh` and `VERSION` sit at the root and the registry exists (the same guard
  as ship step 2a); it prints the `hives-behind:` summary line plus every `RED` line.
- Hold re-check (ask 7): step 2a re-checks every live hold on every ship, and before upgrading ANY hive (held or
  not) asks `bash scripts/hives-behind.sh --busy <hive>`. Busy = a `docs/specs/*/DRIVER` file, or a transcript under
  `<root>/projects/<slug>/*.jsonl` written in the last 60 minutes, roots `${CLAUDE_CONFIG_DIR:-~/.claude}` plus every
  `~/.claude*` dir (a second account), slug = the hive path with `:`, `/`, `\`, `_`, `.` turned into `-`. No
  transcript dir found under any root = `unknown`, treated as busy (a missing input is never a pass). Output one line,
  `idle` / `busy <reason>` / `unknown <reason>`, exit 0 / 1 / 1. A busy or unknown hive gets a hold with that reason
  (date <= 7 days); an idle held hive on its ship branch with a clean tree has its hold removed and is upgraded.
  Right before the hive commit the check and `git status --porcelain` run again: a path the upgrade did not write, or
  a busy verdict, stops that hive with no commit and a line to the owner. Tests use `VULYK_SESSION_ROOTS`
  (space-separated roots) to point at fixture dirs. The first pass is this spec's own ship, before 2026-11-19.
- Known gap (owner chose it knowingly): an open session silent for over 60 minutes is not seen.
- 2026-11-12 revision: ask 7 widened after a side agent's note (clean tree is not an idle hive); the owner picked
  «Три признака, сомнение = пауза (Рекомендую)». Story 01 now changes `scripts/hives-behind.sh` and is `red: required`.
- Map files are written by `drone-docs` (the constitution gives `memory/memory.md` and the map to it and the
  librarian); the Queen dispatches it in story 02 and checks the result. `agents-and-commands.md` (134 lines) and
  `cycle.md` (154) stay over the cap: not asked.
- One new check in `tests/maintenance.test.sh` keeps every `memory/map/scripts*.md` slice at <= 80 lines, so the split
  cannot drift back unseen.
- ADR-033's Status line follows ADR-032's form: `accepted (<approval date>, owner: Andrei, ...)`.
- plan.md "Nothing is tagged" (round-2 minor 3) is already fixed in ba53f294: no work.

## Stories

**Wave 1**
- `post-052-tails-01` — ship description, impossible-day test, `/vulyk-status` lagging-hives line, `hives-behind.sh --busy` + step 2a hold re-check and busy guard, CHANGELOG (red: required)

**Wave 2**
- `post-052-tails-02` — map: ADR-032 bullet back, `scripts.md` split into <= 80-line slices + cap check; ADR-033 accepted

## Contracts
- none

## Integration gate
`bash tests/full-suite.sh`

## Descoped

*(empty)*

## Plan deltas
- 2026-11-12, story 02 mid-build: three slices of 80 lines could not hold the scripts map without dropping facts (drone-docs fit only by joining bullets into lines up to 920 chars; rewrapped, the other-scripts slice was ~135 lines). Owner chose «4 файла, строка до 130 знаков (Рекомендую)»: ask 5 now reads 4 slices (`scripts-checks.md` added) and lines <= 130 chars, checked by the maintenance test. Rejected: compressing wording (facts lost), leaving one slice over the cap.

**Approved:** Andrei, 2026-11-12 («Одобряю, собирай (Рекомендую)»)
**Branch:** vulyk/post-052-tails
