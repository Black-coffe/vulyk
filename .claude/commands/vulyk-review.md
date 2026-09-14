---
description: One council round on demand - lead-review plus the three blind seats, judged by cycle.sh
argument-hint: [spec slug; defaults to the spec on the current branch]
---

Run one council round on: "$ARGUMENTS" (default: the spec whose `**Branch:**` matches the current
branch).

1. **Claim, then check the precondition.** Resolve
   `stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"` (16 hex characters, never `date`) first,
   once, here - it is a per-run value the seat is never told, not a secret a report is expected to
   guess (R31) - then claim the DRIVER semaphore before touching anything else (ADR-004/K3):
   `bash scripts/cycle.sh claim docs/specs/<slug> $stamp`. `"ok":false` (`held by <stamp>`) means
   another driver holds this spec - print the `error` verbatim and stop; never retry the claim.
   Every story on the branch must be `done` or `blocked` before a round opens. Do not compute
   this yourself -
   `bash scripts/cycle.sh open-round docs/specs/<slug> --commit --stamp $stamp` refuses (exit 2,
   stderr names the failing precondition: stories still open, a dirty tree, no `## Asks`, or paused)
   when it is not true yet. On that refusal, release the semaphore, surface it verbatim and point at
   `/vulyk-build` to finish the wave; do not open a round by hand. `open-round` is idempotent -
   calling it again on an already-open, non-stale round just resumes it, so running this command
   mid-round (or twice) is safe. Exit 6 means the ceiling is reached: release the semaphore and treat
   it exactly like the `escalated` stop below. Print the resulting `<spec-dir>/journal.md` last line,
   nothing else.

2. **Read the round's coordinates.** `bash scripts/cycle.sh status docs/specs/<slug> --json` and
   take `round` (N), `court`, `round_dir` and **`missing`** - the same list a driver's `dispatch:`
   step reads (C3, R20): the seats the round's frozen tier requires and has no accepted report for
   yet. This on-demand round costs exactly those seats, never a hardcoded four - a Tier 1 spec pays
   `sonnet` alone, Tier 2 `sonnet` + `review`, Tier 3 adds `opus` and `haiku` (the black-box
   seat - on the junior rung, Sonnet until a Haiku 5 exists), Tier 4 adds the second reviewer;
   `lead-review` only when `review` itself is in `missing`. Resolve `top_model`
   (`bash scripts/top-model.sh`, the alias the session brief announced) - `stamp` was already taken
   in step 1 and is reused here, not re-rolled.

3. **Dispatch only the seats `missing` names, one message, in parallel** - the same "independent in
   information, so independent in wall-clock cost" reasoning that ran `lead-review` alongside the
   old blind gate now runs it alongside whichever blind seats this tier still needs. Compute each
   seat's report path first, `.vulyk/reports/<slug>/round-<N>/<seat>.attempt-1.md` (repo-relative,
   forward slashes, `2` in place of `1` on the exit-4 re-ask below) - every dispatch but the Tier 4
   second reviewer's ends with: `As your last action, write your full report verbatim to <path>
   (mkdir -p its directory); your chat reply is the same text.`
   - `review` in `missing` -> `lead-review` at `top_model`, in the **main tree**, never the court -
     it needs the stories. Give it `round_dir` and its packet: the diff, the story/plan files it
     implements, pointers to `docs/wiki/` notes and ADRs for the touched modules.
   - `haiku`/`sonnet`/`opus` in `missing` -> the matching `council-<seat>`, working in `court` with
     nothing else attached - `slug`, `round` and `court` only, **never `round_dir`**: a seat that
     echoes its own input back is tainted on the spot (R9). Skip any seat `missing` does not name.
   - **Tier 4 only, and only when `review` is in `missing`:** also dispatch a second reviewer on the
     paired model (`scripts/top-model.sh --explain` names it: `opus` beside a Fable gate; `fable` or
     `sonnet` beside an Opus gate, unless the spec's own Tier 4 sentence in `plan.md` names another),
     given the same packet as `lead-review` and instructed to attack its likely blind spots
     (concurrency, security, data migration safety). Before recording anything, fold the two
     verdicts into **one** `review` report: the folded verdict is the **stricter of the two** -
     `BLOCK` if either one blocks, `PASS` only if both pass. Report both sets of findings under that
     one report so nothing is lost; only the merged `PASS`/`BLOCK` line reaches `record-seat`.
     `record-seat` accepts exactly one `review` file per round - there is no second slot to hold a
     second opinion separately.

4. **Record each report.** Good case, every seat but the Tier 4 second reviewer's fold: `bash
   scripts/cycle.sh record-seat docs/specs/<slug> <N> <haiku|sonnet|opus|review> --stamp $stamp
   [--model <id>] --file <path>` (the report path from step 3). On exit 2 with `error` starting
   `file: `, fall back to today's heredoc form with the chat reply as the body - and this is the
   only form for the Tier 4 folded review, which never gets a report path: the report travels as
   free text inside the clerk's prompt; the heredoc delimiter `VULYK_<stamp>_<seat>_<attempt>` is a
   per-run random value the seat is never told, which is what keeps the body from ending the
   heredoc early (R31):
   `bash scripts/cycle.sh record-seat docs/specs/<slug> <N> <haiku|sonnet|opus|review> --stamp $stamp [--model <id>] <<'VULYK_<stamp>_<seat>_<attempt>'`
   ... `VULYK_<stamp>_<seat>_<attempt>` - never `EOF`, and an empty report is still piped through
   unchanged, so the attempt exists on disk. Exit 4 (`MALFORMED`) on either form -> re-ask that one
   seat once, naming the `error` field verbatim so it knows the exact gap, with `<attempt>` now `2`
   in the next report path/delimiter; record the second attempt either way (`--file` first, same
   fallback) and move on - a seat that is still malformed on attempt 2 is `ABSENT` per D3/D4, and
   `judge` accounts for that on its own. Print each `record-seat` call's own one-line `cycle: ...`
   confirmation, nothing else (it does not journal per seat).

5. **Judge.** `bash scripts/cycle.sh judge docs/specs/<slug> --commit --stamp $stamp`. Then release
   the semaphore - `bash scripts/cycle.sh release docs/specs/<slug> $stamp` - regardless of `next`;
   this is the one release point for a round that reached judgement (step 1 already released on a
   precondition refusal). Print the resulting `**Council:**` line the same way step 1 prints a
   journal line, then act on `next`:
   - `green` - say so; recommend `/vulyk-ship`.
   - `repair` - say plainly: **fix stories go through `/vulyk-build`**, never through this command
     and never by hand-patching in this session (Law 5). Do not cut the fix stories here.
   - `escalated` - print `## Needs a human` from `plan.md` verbatim; the owner's three exits are
     `human-check.sh ACCEPTED`, `cycle.sh reopen "<decision>"`, or leaving the spec open - do not
     choose for them.

There is no stage-05 stop here and no check card: the council's verdict, not the owner's look, is
what this command exists to produce. The owner's look happens if and when they run `/vulyk-ship` or
answer an escalation, never as a wait inside this command.
