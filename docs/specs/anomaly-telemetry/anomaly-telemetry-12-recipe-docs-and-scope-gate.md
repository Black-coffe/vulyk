---
story: anomaly-telemetry-12
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: sonnet
tracer: false
wave: 8
blocked_by: [anomaly-telemetry-09, anomaly-telemetry-10]
---

# Fix (round-3 review Majors 2, 3): the public recipe block matches what `publish` prints, and `skills.json` is back under the scope gate

## Goal
Major 2: story 08 changed the PR recipe to fork, `cd`, `base="$(git rev-parse --abbrev-ref HEAD)"`, then per week `git switch "$base"` + the seven lines (11 lines for one week), but `docs/telemetry.md:113-124` still shows the pre-08 nine lines with no `base` line and no `git switch "$base"`, and `:113` says "nine lines". Major 3: story 09 hid `memory/stats/skills.json` from every story's `out_of_scope`, yet the file is not in `is_paperwork_path` and no `cycle.sh` verb stages it, so `ship-check` stage 03 still fails on it and a hand commit (`4a88a0e`) was the only way through - the round-2 Major 7 shape for the other hook-written file. The owner's decision: `skills.json` is NOT cycle-owned; only `memory/stats/anomalies.jsonl` is exempt (story 09). After this story the docs block is the recipe `publish` prints for one week and says how a second week's block differs; `scope-check` counts `skills.json` again; `ship-check` stage 03 passes through exactly `memory/stats/anomalies.jsonl`; a dirty `skills.json` fails stage 03 as any other path (recorded in plan `## Descoped`).

## Requirements
> Раз в неделю логи отправляются в репозиторий VULYK: локально в основной проект, с других машин как pull request.
> В публичном репозитории на GitHub написано, что логи собираются для улучшения VULYK, их можно запушить как pull request, раз в неделю логи чистятся и выходит апдейт.
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.
> owner 2026-09-15: repair the round-3 review's three findings only - bounded Stop-hook scan (record under-threshold subagents so they are never re-measured), docs/telemetry.md recipe brought to story 08's shape, skills.json back under the scope gate - then up to three more rounds

## Files
- docs/telemetry.md
- scripts/scope-check.sh
- scripts/ship-check.sh
- scripts/lib.sh
- tests/cycle.test.sh

## Non-goals
- Do not touch `scripts/telemetry.sh` or `tests/telemetry.test.sh` (story 11 holds them this wave). The recipe text comes from story 08's notes and the suite's ordered-needle case (read only); `bash scripts/telemetry.sh publish --dry-run` may be run against a scratch hive with consent `on` to confirm the shape, never edited.
- Do not widen `is_paperwork_path` or its anchoring (memory/map/scripts.md Gotchas); `lib.sh` is listed only in case the stage-03 pass-through helper lives there - if it does not, leave `lib.sh` untouched and say so.
- Do not make `skills.json` cycle-owned: no `cycle.sh` change, no new verb, no `commit_paperwork` path. Its ship-gate consequence is on the record in plan `## Descoped`, not fixed here.
- Do not change `scope-check`'s exclusion of `memory/stats/anomalies.jsonl` or the story-09 cases that assert it; remove only the `skills.json` half.
- In `docs/telemetry.md` change only the fenced recipe block, its introducing sentence (the "nine lines" count) and the sentence on how a second week's block differs; the detector table, `VULYK_ANOMALY_*` table, `bundle --out` sentence and the "not yet exercised" sentence (story 10) stay.
- Do not fold round-3 Minors 4-11. Minor 8 is satisfied only as a by-product of naming the one pass-through path; do not reword anything else for it.

## Map slice
plan.md `## Contracts` (`publish` PR recipe as amended by story 08 and the seen-list note, "Hook-written log ownership" as amended by this story) and `## Descoped` (new `skills.json` line); `council/round-3/review.md` Majors 2, 3 and Minor 8; story 08 `## Implementation notes` ("Two decisions worth review" (1) - the `base=` line) ; story 09 `## Implementation notes` (stage-03 walk, `scope-check` exclusion, the "hooklog" scratch spec in `tests/cycle.test.sh`); memory/map/scripts.md "Key types / contracts" (gates always exit 0, `is_paperwork_path`).

## Acceptance criteria
- [ ] Major 2: the fenced block in `docs/telemetry.md` is, line for line, what `publish` prints for one week with no local checkout: `gh repo fork ... --clone -- ...`, `cd ...`, `base="$(git rev-parse --abbrev-ref HEAD)"`, `git switch "$base"`, then the seven lines (`git switch -c`, `mkdir -p`, `cp`, `git add`, `git commit`, `git push -u`, `gh pr create`); the introducing sentence gives the real count (11 for one week) and one sentence says a second week repeats from `git switch "$base"` with fork and `cd` printed once, so each PR carries exactly one week. Placeholders (`<slug>`, `<dir>`, `<week>`, `<hive>`, `<bundle>`) match the ones the script substitutes.
- [ ] Major 3, `scope-check`: `memory/stats/skills.json` is no longer excluded - a story naming one file, with `skills.json` dirty in the diff, records `out_of_scope` containing `memory/stats/skills.json`; a story with only `memory/stats/anomalies.jsonl` dirty still records `out_of_scope` `[]` (story 09's case unchanged). Both cases in `tests/cycle.test.sh`.
- [ ] Major 3, `ship-check` stage 03: the pass-through names exactly `memory/stats/anomalies.jsonl` (not "any `memory/stats/*` that passes `is_paperwork_path`"); the report line stays `clean (hook-written stats pending: memory/stats/anomalies.jsonl)`. Suite, same "hooklog" scratch spec: `anomalies.jsonl` alone dirty passes; `skills.json` alone dirty fails with `working tree is not clean`; `council.jsonl` alone dirty fails likewise (story 09's hook+real-dirt case unchanged).
- [ ] `bash tests/cycle.test.sh` green; every pre-existing case unchanged except the story-09 scope case that asserted `skills.json` excluded, which is inverted, not deleted.

## Verification
`bash tests/cycle.test.sh`

## Implementation notes
- `docs/telemetry.md`: fenced recipe now matches `recipe_pr()` in `scripts/telemetry.sh` (read only) - 11 lines for one week, `base="$(git rev-parse --abbrev-ref HEAD)"` + `git switch "$base"` added; "nine lines" -> "eleven lines for one week"; added the second-week-repeats-from-`git switch "$base"` sentence.
- `scripts/scope-check.sh`: the hook-file exclusion loop dropped `memory/stats/skills.json`, keeping only `memory/stats/anomalies.jsonl`.
- `scripts/ship-check.sh` stage 03: replaced the `memory/stats/*` + `is_paperwork_path` case with an exact match on `memory/stats/anomalies.jsonl` only; `is_paperwork_path` is no longer called from this file (still used by `lib.sh`'s `paperwork_only()` and `cycle.sh`'s `open-round`, untouched).
- `scripts/lib.sh`: untouched - the stage-03 pass-through helper is inline in `ship-check.sh`, not in `lib.sh`; `is_paperwork_path` itself was not widened, per Non-goals.
- `tests/cycle.test.sh`: added two "story 12" cases at the end of the hooklog block - `memory/stats/skills.json` dirty+undeclared now shows in `scope-check`'s out_of_scope and fails ship-check stage 03; `memory/stats/council.jsonl` dirty alone also fails stage 03 (it was in `is_paperwork_path`'s whitelist before this story, so it would have wrongly passed through). Story 09's existing cases (anomalies.jsonl pass-through, hook+real-dirt block) left unchanged.
- `scripts/telemetry.sh`, `docs/specs/anomaly-telemetry/journal.md` and `tests/telemetry.test.sh` were already dirty in the working tree from story 11's in-progress work before this story started (per Non-goals, not touched by this story).

## Findings
