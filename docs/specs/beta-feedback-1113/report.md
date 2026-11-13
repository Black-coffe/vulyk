# How the local beta builds ran in the live hives (study report)

**Date:** 2026-11-13 · **Window:** 2026-11-12 08:00 .. 2026-11-13 10:00 · **Evidence:** private, `~/.vulyk/audits/beta-feedback-1113/`
(hive commits, spec journals and session transcripts are quoted only there; this file names hives by root only).

## Bottom line
The builds held up, and the long overnight run in YouTube_AI was the best measured run so far. The run was on
0.51.0-dev.1, not on the 0.52 builds. By that hive's own measurement (one task, one run each, numbers read from its
results file, not re-measured here) it used about 40% less wall clock and 57% less operator time than the same task on
0.47.0, with a third of the stops. No hive ran a session on 0.52.0-dev.3 yet: the five upgraded hives were idle after
the upgrade. One real defect matters before a public release. A repair story can take the reviewer's item number
`1.` for a file path; the round is then judged narrow and runs no test suite. It hit three hives and VULYK itself.

## Findings (framework), most costly first
1. **Repair parser takes `1.` for a path.** `scripts/cycle.sh:2487` `finding_paths` strips `- ` and `[tag]`, not a
   `N. ` number, and keeps any token with a dot. `lead-review` numbers its findings (`1. path:line`), so the repair's
   `## Files` gets `- 1.`, its `## Verification` comes out empty, the round counts as narrow and runs `SUITE: none`.
   In one hive the repair changed four app files and no suite ran; only a later test run on the deploy host covered them.
2. **The driver retries a NEEDS_CONTEXT as a miss.** `.claude/workflows/vulyk-cycle.js:206-228` counts a worker that
   returned `NEEDS_CONTEXT` as a miss and dispatches the same story again with nothing new, then stops. That happened 4 times
   in one hive overnight, costing up to ~7 min of an Opus dispatch each.
3. **A `## Verification` line outside `## Commands` is caught only at close-story.** `wave-check.sh` (verify-cell)
   runs at plan time; a story revised later reaches a worker who does the work and then gets `close-story` exit 2.
4. **`agent_prefix_high` counts agents VULYK never dispatched.** 20 of 21 rows in the window were `general-purpose`
   agents launched by an owner's own second-opinion rule; their prefix is the session's system prompt and tool list.
   `scripts/telemetry.sh:84` and `:455` take every agent type.
5. **Every review carries the same noise Minor.** `.claude/agents/lead-review.md:60` notes a `suite.log` head that
   differs from the reviewed head; `open-round` always commits paperwork after the suite, so it always differs.
6. **`--go` was added by the Queen herself** in one hive, which skips the owner's approval stop.
   `.claude/commands/vulyk-plan.md:122` does not say that only the owner gives `--go`.
7. **Quoted `red_reason` never matches.** `scripts/cycle.sh:2395` `fm_raw` keeps YAML quotes.
8. **`/vulyk-resume` does not switch to the spec branch**; the first launch fails `on main, spec branch is ...`.
9. **Ship paperwork reaches main unchecked.** An ADR written at ship copied a non-English quote and broke a hive's own
   docs test on main; the next round's suite failed after 522 s.
10. **The publish step is handed back in hives whose owners want the agent to run it** (`vulyk-ship.md:72-77`, no
    per-hive switch). Two owners said so in the window.
11. **Tier 1's one-round ceiling sent every BLOCK of a privacy fix to the owner** (3 escalations, waits up to 6 h).
12. Smaller: `driver_relaunched` recorded unevenly (`vulyk-resume.md:21` is the only rule); the checkpoint cannot fire
    inside a long dispatch; a cut clerk status line ends the driver (known tail); wave-check verify-gap on a new test file
    not yet on disk (`wave-check.sh:203-207`); git-guard refuses `close-story $f` with a variable; `reopen` after GREEN
    is refused with no pointer; `detect_scope` keeps a first breach a re-run cleared.

## Worked well
- Overnight Tier 3 build: NEEDS_CONTEXT, RED, repair, GREEN without the operator; a leftover claim picked up a
  half-done story; PAUSE, resume and a manual stop overnight were clean; the handoff came back after compaction.
- A 12-story spec went from approval to GREEN in 80 min; the council caught a real critical and a major.
- git-guard stopped two stashes of uncommitted work; stamp-red refused "red for another reason"; close-story refused
  edits outside `## Files`; the Fable reviewer found real leaks. No Fable-limit fallbacks in the window.

## Not read or run
Side-run transcripts outside the hive; workflow subagent journals beyond their first message; one session that ended
early; an open round in one hive with no verdict yet. Nothing was run in any hive.

## Options
1. **(Recommended)** Fix findings 1-8 as one spec before the public release, then publish. 1 is a gate hole, 2-3
   waste dispatches, 4-5 are noise in the numbers the owner reads, 6-8 are one-line rules or fixes. Cost: one Tier 3
   build of a few hours.
2. Fix only finding 1 (Tier 1, one story), publish, and leave 2-8 for the next circle. Faster; ships known noise.
3. Publish as is. Ships the gate hole.

Findings 9-12 change behaviour owners rely on (ship paperwork checks, who presses publish, the Tier 1 ceiling) and
belong to the owner, not to this fix list.

## Candidate stories
- repair parser drops `N. ` numbering, and a repair with no real path is not narrow (red test in `tests/cycle.test.sh`);
- driver stops on a worker's `NEEDS_CONTEXT` with its findings instead of a blind retry (driver test);
- `advance` runs the verify-cell check on the wave's stories before a build dispatch;
- `agent_prefix_high` counts only VULYK agent types;
- `lead-review` compares `suite.log` with the round's code head, paperwork commits excluded;
- `vulyk-plan`: `--go` only from the owner's words; `fm_raw` strips YAML quotes; `vulyk-resume` checks out the spec branch.
