---
description: One council round on demand - advance opens it, the required seats are dispatched, advance --ingest records and judges
argument-hint: [spec slug; defaults to the spec on the current branch]
---

Run one council round on: "$ARGUMENTS" (default: the spec whose `**Branch:**` matches the current
branch). Every call below that runs `advance` carries `timeout: 600000`.

1. Claim and advance. `stamp="$(openssl rand -hex 8 2>/dev/null || python -c 'import secrets;
   print(secrets.token_hex(8))')"`, then `bash scripts/cycle.sh advance docs/specs/<slug> --stamp
   $stamp --claim`. `ok:false` with `held by`: another driver holds the spec; print its `error` and
   stop. Otherwise act on `next`:
   - `dispatch:<seats>`: go to step 2.
   - `green`: the newest round is green and current. If the owner still wants a round, run `bash
     scripts/cycle.sh open-round docs/specs/<slug> --commit --stamp $stamp` (the tier's ceiling still
     counts it; exit 6 means it is reached), then `advance --stamp $stamp` again.
   - `build:<W>`: stories are open, or the last round was RED and `advance` has cut the repair story.
     Release and point at `/vulyk-build`.
   - `escalated`, `paused`, `shipped`, `briefed`, or any `ok:false`: release and report it as
     `/vulyk-build`'s Terminal section does.
2. Dispatch exactly the seats `next` names, in one message, as `/vulyk-build` describes: each writes to
   `.vulyk/reports/<slug>/round-<round>/<seat>.attempt-<k>.md` with k from `status.seat_attempt`;
   blind seats get slug, round, `court` and the report path only, never `round_dir`; `lead-review` gets
   the spec, branch, head, report path, and from round 2 `since` and the previous round's directory,
   with no model parameter at Tier 1-3 and two reviewers (`review-top`, `review-second`) at Tier 4.
3. Record and judge: `bash scripts/cycle.sh advance docs/specs/<slug> --stamp $stamp --ingest`. A seat
   still listed in `next` was rejected: re-dispatch it once with its `rejected` error appended, then
   `--ingest` again.
4. Release, whatever happened: `bash scripts/cycle.sh release docs/specs/<slug> $stamp`. Print the
   newest `**Council:**` line of plan.md and act on `next`:
   - `green`: recommend `/vulyk-ship`.
   - `build:<W>`: the round was RED and the repair story is written; it is built through `/vulyk-build`,
     never by hand in this command.
   - `escalated`: print `## Needs a human` from plan.md verbatim. The owner chooses: `human-check.sh
     ACCEPTED`, `cycle.sh reopen "<decision>"`, or leaving the spec open.

The council's verdict is what this command produces; there is no stop for the owner inside it.
