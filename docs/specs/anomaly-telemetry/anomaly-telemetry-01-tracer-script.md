---
story: anomaly-telemetry-01
spec: anomaly-telemetry
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: true
wave: 1
blocked_by: []
---

# Tracer: `scripts/telemetry.sh` - enum, both schemas, record/bundle/check/consent/publish, test suite

## Goal
One script owns anomaly telemetry end to end: a `record` appends a local row to `memory/stats/anomalies.jsonl`, `bundle` turns a week of local rows into anonymized rows of codes and numbers only, `check` validates a bundle against the fixed schema, `consent` reads the Profile row, and `publish` prints (never runs) the command that carries the bundle into the VULYK repo. The new stats file counts as paperwork, the new test suite is a `## Commands` row, and every later story builds against this contract.

## Requirements
> Все терминалы Claude Code с VULYK мониторят аномалии и ведут файл логирования.
> Логи максимально обезличены: контекстные аномалии, перебор по времени, избыточность VULYK, никаких личных файлов.
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.
> если репозиторий VULYK лежит на этой машине, кладёт его туда в telemetry/inbox/ и печатает команду коммита; иначе печатает готовую команду gh pr create в публичный репозиторий. Ничего не отправляет само.

## Files
- scripts/telemetry.sh
- scripts/lib.sh
- tests/telemetry.test.sh
- CLAUDE.md

## Non-goals
- No `scan` verb and no detectors - story 02. `record` is the only writer here; leave a clearly named `scan` stub that exits 0 with "not implemented" so hooks wired later fail open.
- No hook, no `settings.json` change, no python.
- No edit to `/vulyk-evolve` or any command file - story 03.
- No README, docs page, CHANGELOG, CI job - story 04. No Profile row in `CLAUDE.md` - story 05; this story touches `CLAUDE.md` only to add one `## Commands` row.
- Do not copy the bundle into `~/.vulyk/src` (plan A1). Do not call `git push`, `git commit` or `gh` anywhere, not even behind a flag.
- Do not widen `is_paperwork_path()` beyond the one literal `memory/stats/anomalies.jsonl` entry, anchored like the existing five.
- Do not hard-code the agent token set: `agents` derives it from `.claude/agents/*.md` basenames at runtime (plan A12).

## Map slice
memory/map/scripts.md (`lib.sh` exports, gates' exit-0 convention, the `## Commands` whitelist gotcha); plan.md `## Contracts` in full and A12; recon/hooks-and-stats.md §4-5; recon/weekly-and-publish.md Answers 3 and 5.

## Acceptance criteria
- [ ] `bash scripts/telemetry.sh enum` prints the eight codes from the plan's enum, one per line, nothing else; `agents` prints the `.claude/agents/*.md` basenames plus `other`, one per line.
- [ ] `record context_high 150000 140000 --ref session:x` appends exactly one local row with the 12 keys in contract order (`agent` empty); a second identical call appends nothing; `--agent cycle-clerk` lands as given, `--agent worker-01-core` lands as `other`; an unknown code exits 1 with a one-line stderr message and writes nothing.
- [ ] `bundle` on a fixture log whose rows carry `spec`, `story` and a `ref` containing a path and an email emits rows with exactly the 10 bundle keys; the output contains none of the fixture's spec slug, story id, path, or email, and no `/`, `\`, `@`.
- [ ] `check` accepts `bundle`'s own output and rejects, each with `<file>:<line>: <reason>` on stderr and exit 1: an extra key, an unknown code, an `agent` outside the token set, a string containing `/`, a `hive` that is not 12 hex.
- [ ] `consent` prints `off` when the Profile has no `Telemetry` row, `on`/`off` from the row's first token (with or without backticks).
- [ ] `publish` with consent `off` prints the one-line "nothing to send" and creates no file. With consent `on` and `VULYK_LOCAL` pointing at a fixture repo containing `telemetry/inbox/`, it copies the bundle to `telemetry/inbox/<week>/<hive>.jsonl` and prints a commit command; without a local repo it prints a `gh pr create` recipe. A PATH shim `git`/`gh` in the test records every invocation and the test asserts `push`, `commit` and `pr` never appear.
- [ ] `is_paperwork_path memory/stats/anomalies.jsonl` returns true; `memory/stats/other.jsonl` stays false.
- [ ] `CLAUDE.md` `## Commands` has a new row `| Anomaly telemetry contract tests | \`bash tests/telemetry.test.sh\` |`; no other line of `CLAUDE.md` changes.
- [ ] `tests/telemetry.test.sh` follows `tests/council.test.sh`'s shape (temp fixture repo, no model calls, non-zero on any failed assertion, one summary line), runs `bash -n` over `scripts/telemetry.sh` and `scripts/lib.sh` as its first case, and leaves clearly marked sections for detectors (story 02) and install (story 05).

## Verification
`bash tests/telemetry.test.sh`

## Tracer
Cut the thinnest slice through every layer: one `record` row -> one `bundle` row -> `check` green -> `publish --dry-run` prints a command. Schemas, dedupe and the anonymization guard are the contract stories 02-05 build on; if the slice changes the contract, report it in the INTERFACES line, do not improvise.

## Implementation notes

## Findings
