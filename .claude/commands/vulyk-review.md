---
description: One council round on demand - lead-review plus the three blind seats, judged by cycle.sh
argument-hint: [spec slug; defaults to the spec on the current branch]
---

Run one council round on: "$ARGUMENTS" (default: the spec whose `**Branch:**` matches the current
branch).

1. **Precondition: every story on the branch is `done` or `blocked`.** Do not compute this
   yourself - `bash scripts/cycle.sh open-round docs/specs/<slug> --commit` refuses (exit 2, stderr
   names the failing precondition: stories still open, a dirty tree, no `## Asks`, or paused) when
   it is not true yet. On that refusal, surface it verbatim and point at `/vulyk-build` to finish
   the wave; do not open a round by hand. `open-round` is idempotent - calling it again on an
   already-open, non-stale round just resumes it, so running this command mid-round (or twice) is
   safe. Exit 6 means the ceiling is reached: treat it exactly like the `escalated` stop below.
   Print the resulting `<spec-dir>/journal.md` last line, nothing else.

2. **Read the round's coordinates.** `bash scripts/cycle.sh status docs/specs/<slug> --json` and
   take `round` (N), `court`, `round_dir` and **`missing`** - the same list a driver's `dispatch:`
   step reads (C3, R20): the seats the round's frozen tier requires and has no accepted report for
   yet. This on-demand round costs exactly those seats, never a hardcoded four - a Tier 1 spec pays
   `sonnet` alone, Tier 2 `sonnet` + `review`, Tier 3 adds `opus`, Tier 4 adds `haiku` (the
   black-box seat - on the junior rung, Sonnet until a Haiku 5 exists) and the second reviewer;
   `lead-review` only when `review` itself is in `missing`. Resolve `top_model`
   (`bash scripts/top-model.sh`, the alias the session brief announced) and, once here,
   `stamp="$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"` (16 hex characters, never `date`) - both
   used below and neither ever repeated inside a seat prompt: it is a per-run value the seat is
   never told, not a secret a report is expected to guess (R31).

3. **Dispatch only the seats `missing` names, one message, in parallel** - the same "independent in
   information, so independent in wall-clock cost" reasoning that ran `lead-review` alongside the
   old blind gate now runs it alongside whichever blind seats this tier still needs:
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

4. **Record each report.** The report travels as free text inside the clerk's prompt; the heredoc
   delimiter `VULYK_<stamp>_<seat>_<attempt>` is a per-run random value the seat is never told,
   which is what keeps the body from ending the heredoc early (R31):
   `bash scripts/cycle.sh record-seat docs/specs/<slug> <N> <haiku|sonnet|opus|review> [--model <id>] <<'VULYK_<stamp>_<seat>_<attempt>'`
   ... `VULYK_<stamp>_<seat>_<attempt>` - never `EOF`, and an empty report is still piped through
   unchanged, so the attempt exists on disk. Exit 4 (`MALFORMED`) -> re-ask that one seat once,
   naming the `error` field verbatim so it knows the exact gap, with `<attempt>` now `2` in the next
   delimiter; record the second attempt either way and move on - a seat that is still malformed on
   attempt 2 is `ABSENT` per D3/D4, and `judge` accounts for that on its own. Print each
   `record-seat` call's own one-line `cycle: ...` confirmation, nothing else (it does not journal
   per seat).

5. **Judge.** `bash scripts/cycle.sh judge docs/specs/<slug> --commit`. Print the resulting
   `**Council:**` line the same way step 1 prints a journal line, then act on `next`:
   - `green` - say so; recommend `/vulyk-ship`.
   - `repair` - say plainly: **fix stories go through `/vulyk-build`**, never through this command
     and never by hand-patching in this session (Law 5). Do not cut the fix stories here.
   - `escalated` - print `## Needs a human` from `plan.md` verbatim; the owner's three exits are
     `human-check.sh ACCEPTED`, `cycle.sh reopen "<decision>"`, or leaving the spec open - do not
     choose for them.

There is no stage-05 stop here and no check card: the council's verdict, not the owner's look, is
what this command exists to produce. The owner's look happens if and when they run `/vulyk-ship` or
answer an escalation, never as a wait inside this command.
