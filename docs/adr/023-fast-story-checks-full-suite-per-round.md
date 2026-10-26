# ADR-023: Fast story checks, one full suite per round; the runner runs parts, not whole suites

- Status: proposed
- Date: 2026-10-26
- Spec: docs/specs/fast-verification (0.36.0)

Number not assigned: the harvest could not list `docs/adr/` (the file search returned nothing), so the
main session assigns the next free number and renames this file. Nothing existing was renumbered.

## Context
The plan's Goal (approved 2026-10-25) splits verification in two: a story's `## Verification` names a
`--part <topic>` that covers its files; the whole suite runs once per round in `lead-review` through
`tests/full-suite.sh`. Slow rows of `## Commands` carry `round-only` in their Purpose cell; `wave-check`
reports a story that names one and `close-story` refuses it with exit 2.

Two plan deltas then fixed how the runner fits its budget, quoted verbatim:

> 2026-10-26, story 07 NEEDS_CONTEXT, Queen ruling (a): the repair premise "shared setup is the cost" came from a seat's reading, not a measurement; the worker measured it at 0.5-0.7 s. The cost is repeated `install.sh` runs (16-21 s each, 5-12 per telemetry part). Within the owner's "fix the root, not the budget": keep parts in the runner, cache one pristine `install.sh` output per run (fixtures copy it, checked by `diff -r`), split the parts still over two minutes, run parts at a bounded default `--jobs`, latency suites after the rest. Finding 3's "whole suites" clause is dropped: whole suites cannot fit 540 s. Rejected: (b) a faster `install.sh` (product code, outside this spec), (c) accepting parts over two minutes (contradicts ask 1 and the owner's choice).

> 2026-10-26, story 08 NEEDS_CONTEXT again (profile: no repeated fixture worth 60 s; 83 install.sh runs each test a
> distinct case), owner ruling «Вынести в конец только замеры»: inject/intake split into functional and latency parts,
> only the latency parts run alone last; intake's fresh install cached. Pre-approved fallback: default budget 590 s.
> Rejected: a faster install.sh (product code, risk to every hive; a separate spec after ship).

## Options
1. Runner jobs are parts, each <= ~2 min, with a cached pristine install - chosen.
2. (b) a faster `install.sh` - rejected: product code, risk to every hive; a separate spec after ship.
3. (c) accept parts over two minutes - rejected: contradicts ask 1 and the owner's choice.
4. Runner runs whole suites - dropped: "whole suites cannot fit 540 s".
5. Hardcoded suite list in the runner - rejected in `## Assumptions`: the runner globs `tests/*.test.sh`
   and asks split suites for `--list-parts`, so a re-cut needs no runner edit.

## Decision
Option 1. Deciding factor, recorded: the cost is repeated `install.sh` runs, not shared setup, and the
owner's rule "fix the root, not the budget". Timing-sensitive (latency) parts run alone after the rest;
functional parts run in parallel at a bounded default `--jobs`.

## Consequences
Not recorded beyond the deltas. The plan's `## Integration gate` records the measurements (fit at 487-532 s
of 540 under round load, before the 590 s raise).

## Invariants created
- A story's `## Verification` never names a `round-only` row; `close-story` refuses it with exit 2.
- A slow suite is cut into `--part`s listed by `--list-parts`; a part targets <= ~2 min alone.
- The runner discovers jobs by glob and `--list-parts`, never a hardcoded list.
- Fixtures copy the per-run cached pristine `install.sh` output instead of re-running the installer,
  unless the case under test is the install itself.
- Latency/timing parts run alone after the parallel jobs, never among them.

## Revisit when
Not recorded. (The delta defers a faster `install.sh` to "a separate spec after ship".)
