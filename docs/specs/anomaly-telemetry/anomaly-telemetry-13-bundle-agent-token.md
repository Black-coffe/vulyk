---
story: anomaly-telemetry-13
spec: anomaly-telemetry
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 9
blocked_by: [anomaly-telemetry-11]
---

# Fix (round-4 opus seat, ask 3): the bundle keeps the `agent` token when `model` is empty

## Goal
`bundle_emit` splits the local row into fields with `while IFS=$'\t' read -r ts code value threshold vulyk tier model agent`; tab is IFS whitespace, so two adjacent tabs collapse and an empty `model` shifts `agent` into `model`'s slot and off the end. `detect_agents` never passes `--model`, so every real `agent_prefix_high` / `agent_empty` row leaves the hive as `"model":"","agent":""` - the one dimension that says which caste is the redundancy (a `cycle-clerk` at 55k vs a `worker-code` at 55k, A12) never reaches the bundle, while README.md and `docs/telemetry.md` promise it does. Reproduced by the seat: `record agent_empty 3 0 --agent worker-code --ref agent:custom2` then `bundle --week <w>` prints `"agent":""`; the same row with `--model sonnet` bundles `"agent":"worker-code"`. After this story a bundle row carries every local field position-for-position regardless of which string fields are empty, and the suite proves it for the empty-`model` and empty-`agent` cases.

## Requirements
> Логи максимально обезличены: контекстные аномалии, перебор по времени, избыточность VULYK, никаких личных файлов.
> только коды и числа, хайв как хэш: в строке только код аномалии из фиксированного списка, число, порог, версия VULYK, тир, алиас модели, неделя, и хэш хайва (sha256 от пути, обрезанный, необратимый). Свободного текста в отправляемом файле нет вовсе.

## Files
- scripts/telemetry.sh
- tests/telemetry.test.sh

## Non-goals
- Do not change either row schema, the key order, the enum, the agent token set or what `check` rejects (`## Contracts`); the fix is in how `bundle` reads a local row, not in what it writes.
- Do not make `detect_agents` pass `--model`: an empty `model` is a legal value of the local row and the bundle must survive it. Mapping `measure`'s model id to a ladder alias is not this story.
- Do not touch `record`, `scan`, `detect_agents`, `publish`, `inbox`, `handoff.py`, the hook, `docs/telemetry.md` or README.md (its example is correct once the bundle is; if the worker finds the docs example itself wrong, say so in `## Implementation notes`, do not edit).
- Do not fold round-4 review Majors 1-2 or Minors 3-10 - the Queen routes them; the review verdict was PASS.
- Do not rewrite the suite's existing bundle/check cases; add beside them.

## Map slice
plan.md `## Contracts` ("Local row", "Bundle row", `bundle` verb, "Agent token set"); `council/round-4/opus.md` ASK 3 (the reproduction and the `printf 'a\t\tb\n' | read -r x y z` diagnosis); story 01 `## Implementation notes` (`bundle_emit` shape) and story 11 notes (the heredoc-backslash trap when patching this suite: build `\t` with `chr(92)`); memory/map/scripts.md "Key types / contracts" (`lib.sh`, `jq -c` row writers).

## Acceptance criteria
- [ ] `bundle` produces its 10-key row from the local row without a whitespace-IFS split of tab-separated fields: either one `jq` pass that maps the local object to the bundle object directly (preferred - one spawn per file, no shell field parsing), or a field separator that bash cannot collapse. Every string field may be empty independently and every other field still lands in its own key.
- [ ] Reproduction closed: a local row `agent_empty`, `--agent worker-code`, no `--model`, bundles as `"model":"","agent":"worker-code"`; a local row with `--model sonnet` and no `--agent` bundles as `"model":"sonnet","agent":""`; a row with both empty bundles both empty; a row with both set is unchanged from today. `check` passes the resulting file in all four cases.
- [ ] `publish --dry-run` and `bundle --out` on the same fixture produce the identical rows (both call the same emitter; no second parser).
- [ ] Suite: one new case with the four rows above in one week, asserting the exact `model`/`agent` pair per row by `jq` on the bundle output and `check` exit 0; every pre-existing case unchanged and green.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes
- scripts/telemetry.sh `bundle_emit`: the local row now travels as US-separated (0x1f) fields, not `@tsv`, and the loop reads with `IFS=$(printf '\037')`. US is not IFS whitespace, so bash cannot collapse a run of separators and every empty string field keeps its own slot. jq strips US from every value first (beside the quote, backslash, tab and line breaks `sanitize` already removes), so a hand-edited local row cannot inject a separator.
- Tradeoff: chose the non-collapsible separator over the "one jq pass to the bundle object" variant because the week filter is `week_of`, which shells out to `date` (GNU then BSD); doing it inside jq would mean `strftime("%G-W%V")`, which is not portable across jq builds on Windows. Same spawn count as before (one jq per file), the shell loop and all its set checks stay.
- Verified the bug was real, not assumed: the same fixture row (`--agent worker-code`, no `--model`) bundles as `"agent":""` on HEAD's script and `"agent":"worker-code"` after the change.
- tests/telemetry.test.sh: case 18 added at the end (before the summary) so no existing case's `$LOG` state is disturbed; four rows in one week, exact `model`/`agent` pair per row, `check` exit 0, and `publish --dry-run`'s own bundle file byte-compared to `bundle --out`.
- Did not read or judge the README/docs examples (non-goal); no doc claim was checked.

## Findings
