# Anomaly telemetry

VULYK can log local anomalies - the failure shapes that cost a session tokens or a build a
retry - and, only if you opt in, contribute an anonymized weekly bundle back to the VULYK
project so `/vulyk-evolve` has real data instead of guesses. Off by default. This page is the
full contract; `scripts/telemetry.sh` is the one script that implements it.

## What gets logged locally

Every hive that installed VULYK writes local rows to `memory/stats/anomalies.jsonl` (committed
paperwork, like the other `memory/stats/*.jsonl` series) whenever `scripts/telemetry.sh scan`
sees one of eight anomaly codes. This happens regardless of the telemetry consent setting - it
is local history, not a send.

| code | detector | value | threshold / env var |
|---|---|---|---|
| `context_high` | main-thread context size above threshold | tokens | `VULYK_TELEMETRY_CONTEXT_HIGH` |
| `agent_prefix_high` | a subagent's first-turn `input + cache_creation_input_tokens` above threshold | tokens | `VULYK_TELEMETRY_AGENT_PREFIX_HIGH` |
| `agent_empty` | a subagent transcript whose last assistant entry has no text block (cap death / empty return) | assistant entries | 0 |
| `council_rounds_high` | max `round` per spec in `council.jsonl` at or above threshold | rounds | `VULYK_TELEMETRY_COUNCIL_ROUNDS_HIGH` |
| `stage_long` | gap between two consecutive `journal.md` lines above threshold | hours (integer) | `VULYK_TELEMETRY_STAGE_LONG` |
| `driver_refused` | `/vulyk-build` refused (no `Workflow`, no `--fallback`; by-name call threw) | 1 | 0 |
| `driver_relaunched` | `/vulyk-resume` relaunched the driver fresh | 1 | 0 |
| `scope_breach` | a `scope.jsonl` row with non-empty `out_of_scope` | out-of-scope path count | 0 |

Print the same list yourself with `bash scripts/telemetry.sh enum`. The thresholds' current
defaults are v1 calibration, not measured facts - each row above names the env var that
overrides it, and every local row records the threshold it was checked against.

### The agent token

`agent_prefix_high` and `agent_empty` rows carry an `agent` token: the basename of a
`.claude/agents/*.md` file (a framework agent name, e.g. `worker-code`, `council-sonnet`), or
`other` when the subagent's `agentType` is not one of those - never the free-form dispatch
`name`, which is owner-chosen text and could carry a story name. Print the current set with
`bash scripts/telemetry.sh agents`. Every other code carries an empty `agent`.

### The local row - 12 keys

```
{"v":1,"ts":"2026-09-15T10:00:00Z","code":"agent_prefix_high","value":58000,"threshold":50000,
 "vulyk":"0.13.3","tier":3,"model":"sonnet","agent":"worker-code","spec":"anomaly-telemetry",
 "story":"anomaly-telemetry-04","ref":"agent:worker-code-01.jsonl"}
```

`spec`, `story` and `ref` stay home - they exist only to make the local row useful for your own
debugging and to dedupe repeat scans (`ref` is the idempotency key: a repeat `record` with the
same `code` and `ref` appends nothing). None of the three ever leaves the machine: the bundle
row below drops them.

## What a bundle contains - and what never leaves the machine

`scripts/telemetry.sh bundle` turns one ISO week of local rows into bundle rows with exactly
10 keys, codes and numbers only:

```
{"v":1,"code":"agent_prefix_high","value":58000,"threshold":50000,"vulyk":"0.13.3","tier":3,
 "model":"sonnet","agent":"worker-code","week":"2026-W38","hive":"a1b2c3d4e5f6"}
```

`week` is the ISO week (`date -u +%G-W%V`); `hive` is the first 12 hex of a sha256 of the repo's
own toplevel path - stable per machine, not reversible to an address. `ts`, `spec`, `story` and
`ref` are dropped before the bundle is written; they never exist in a bundle row.

**Never included, in any row that leaves the machine:** file paths, story or spec slugs,
dispatch names, emails, free text, or file contents. `scripts/telemetry.sh check <file>...`
enforces this mechanically - it rejects a non-object line, a key set other than the 10 bundle
keys, a `code` outside the enum, non-numeric `value`/`threshold`, a `tier` outside 0-4, a
`model` outside `fable|opus|sonnet|haiku|""`, an `agent` outside the agent token set, a `week`
that is not `^\d{4}-W\d{2}$`, a `hive` that is not `^[0-9a-f]{12}$`, a `vulyk` that is not a
semver, and - the anonymization guard - **any string value containing `/`, `\`, `@` or
whitespace**. A bundle that fails `check` is never copied anywhere.

## Consent

Telemetry is **off by default**. `scripts/telemetry.sh consent` reads the `Telemetry` row in
the hive's `CLAUDE.md` Profile table:

```
| Telemetry | off - anonymized weekly anomaly bundle (codes and numbers only, docs/telemetry.md); on = /vulyk-evolve prints the send command, never sends |
```

Only the value cell's first token (`on` or `off`) is read. `install.sh` asks the question once,
on a fresh install and on `--upgrade`, over `/dev/tty` (never a stdin a pipeline may be
consuming) - a short explanation followed by `Enable telemetry? [y/N]` - and writes the answer
into that row. The same install can be driven non-interactively with
`install.sh --telemetry on|off|ask` or the `VULYK_TELEMETRY` env var; no terminal reachable
means no prompt and the row stays (or becomes) `off`.

## Sending a bundle - always a pull request, never automatic

`scripts/telemetry.sh publish [--week YYYY-Www] [--dry-run]` never runs `git push`, `git commit`
or `gh` itself - it only prints a copy-pasteable command for you to run. With consent `off` it
prints `telemetry: off (Profile row Telemetry) - nothing to send` and exits 0. With consent
`on` it writes the week's bundle to `.vulyk/telemetry/<week>-<hive>.jsonl`, runs `check` on it,
then decides where a copy goes by this order (A1):

1. `VULYK_LOCAL` env, if it points at a git worktree that has `telemetry/inbox/` - an explicit
   local VULYK checkout.
2. Else, the hive itself, when it *is* the VULYK checkout (its `origin` remote URL contains the
   configured origin slug: `VULYK_REPO` env, else `.claude/vulyk-origin`, else
   `Black-coffe/vulyk`).

When one of those matches, the bundle is copied to
`<repo>/telemetry/inbox/<week>/<hive>.jsonl` and the script prints the local commit recipe
(`git add`, `git commit`, `git push`). When neither matches - the common case, a hive on a
different machine from the VULYK checkout - it prints the fork-to-pull-request recipe instead,
nine lines that end in an open PR when pasted as they are:

```
gh repo fork 'Black-coffe/vulyk' --clone -- 'vulyk-telemetry'
cd 'vulyk-telemetry'
git switch -c 'telemetry/<week>-<hive>'
mkdir -p 'telemetry/inbox/<week>'
cp '<bundle>' 'telemetry/inbox/<week>/<hive>.jsonl'
git add 'telemetry/inbox/<week>/<hive>.jsonl'
git commit -m 'telemetry(<week>): <hive>'
git push -u origin 'telemetry/<week>-<hive>'
gh pr create --repo 'Black-coffe/vulyk' --head 'telemetry/<week>-<hive>' --title 'telemetry(<week>): <hive>' --body 'An anonymized weekly anomaly bundle - codes and numbers only.'
```

`<bundle>` is the `.vulyk/telemetry/<week>-<hive>.jsonl` path the run just wrote, and the repo
slug is the one A1 resolved. Every path is single-quoted, so a checkout or bundle path holding
a space, a `#` or an `&` pastes and runs unchanged. Either way, a human reads the printed block
and runs it themselves - `publish` prints, it never executes `git`, `gh` or a clone.

With no `--week`, both `publish` and `bundle` cover **the previous ISO week and the current
one**, so a weekly run early in a week still carries the week it is reporting on; a week with
no rows is skipped silently, each week that has rows gets its own
`.vulyk/telemetry/<week>-<hive>.jsonl`, its own inbox path and its own recipe. `--week
YYYY-Www` selects exactly one week.

## The CI check

Every pull request into `telemetry/inbox/` runs `bash scripts/telemetry.sh check` over every
`telemetry/inbox/**/*.jsonl` file in the CI `telemetry-inbox` job. A file that fails any of the
`check` rules above fails the job, so no bundle carrying a path, a slug or a free-text field
merges.

## The weekly cycle

`/vulyk-evolve`, run in the VULYK repo, reads the week's rows across `telemetry/inbox/` as part
of its diagnosis, then clears the directory - distilled and cleared weekly, feeding the next
release. This step has never been run against real data yet; this page describes what it does,
not a measured result.

## `telemetry/` is VULYK-repo-only

`telemetry/` is never installed into a hive - `install.sh`'s `copy_tree` does not walk it, by
design. It exists only at the top of the VULYK repository itself; a hive's own anomaly history
lives in its own `memory/stats/anomalies.jsonl`, and a `publish` run is the only bridge between
the two.
