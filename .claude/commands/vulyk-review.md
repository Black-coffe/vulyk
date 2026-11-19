---
description: One council round on demand - advance opens it, the required seats are dispatched, advance --ingest records and judges
argument-hint: [spec slug; defaults to the spec on the current branch] [--full: the owner's full check]
---

Run one council round on: "$ARGUMENTS" (default: the spec whose `**Branch:**` matches the current
branch). Every call below that runs `advance` carries `timeout: 600000`.

1. Claim and advance. `stamp="$(openssl rand -hex 8 2>/dev/null || bash scripts/py.sh -c 'import secrets;
   print(secrets.token_hex(8))')"`, then `bash scripts/cycle.sh advance docs/specs/<slug> --stamp
   $stamp --claim`. `ok:false` with `held by`: another driver holds the spec; print its `error` and
   stop. Otherwise act on `next`:
   - `dispatch:<seats>`: go to step 2.
   - `green`: the newest round is green and current. If the owner still wants a round, run `bash
     scripts/cycle.sh open-round docs/specs/<slug> --commit --stamp $stamp` (the tier's ceiling still
     counts it; exit 6 means it is reached), then `advance --stamp $stamp` again.
   - With `--full` in the arguments (the owner's word only: a major version, about once a month, bugs or
     feedback), and no round open: `bash scripts/cycle.sh open-round docs/specs/<slug> --full --commit --stamp $stamp`
     opens the full check of the whole project (every seat over every ask, no carried seat, the reviewer from the
     branch base, every gate step), then `advance --stamp $stamp` again and go to step 2. Never without that word.
   - `build:<W>`: stories are open, or the last round was RED and `advance` has cut the repair story.
     Release and point at `/vulyk-build`.
   - `escalated`, `paused`, `shipped`, `briefed`, or any `ok:false`: release and report it as
     `/vulyk-build`'s Terminal section does.
2. First the round's test gate: `bash scripts/cycle.sh suite docs/specs/<slug> --commit --stamp $stamp`, one Bash
   call per step with `timeout: 600000`, repeated until the last line says `"done":true` (`ok:false`: print its
   `error`, release and stop; with `.vulyk-solo-gate` = `merge-only` on the default branch a Tier 1-2 round runs no step).
   Then dispatch exactly the seats `next` names, in one message, as `/vulyk-build` describes: each writes to
   `.vulyk/reports/<slug>/round-<round>/<seat>.attempt-<k>.md` with k from `status.seat_attempt`;
   blind seats get slug, round, `court` and the report path only, never `round_dir`; `lead-review` gets
   the spec, branch, head, report path, and from round 2 `since` and the previous round's directory,
   at Tier 1-3 with `model: <r>` from `r="$(bash scripts/model-profile.sh --role review)"` only when the
   profile is not `sonnet-builds` (else no model parameter), at Tier 4 on `model: <top_model>`; `review2`,
   when `next` names it (Tier 4: a risk path or a `review` BLOCK), is one `lead-review` on `model: <second_model>`. Blind seats get `model: <s>` from `s="$(bash scripts/model-profile.sh --role
   seat)"` only when the profile (`bash scripts/model-profile.sh`) is not `sonnet-builds`.
   A seat whose dispatch returns the Fable-limit refusal (an error carrying `You've reached your Fable
   limit` / `model_requires_usage_credits`, or a text that starts with `Agent terminated early due to an
   API error` and carries `reached your Fable limit`; a report quoting it is a report) and was not already on `opus` is redispatched once with the same
   prompt and agent type and `model: opus`; then, `<from>` the model it was passed (`""` when none):
   `bash scripts/journal.sh docs/specs/<slug> 04-council "fallback: <agent> round-<round>/<seat> <from>
   -> opus (Fable limit; ADR-015 exception)" "ingest"`, `bash scripts/telemetry.sh record
   fable_limit_fallback 1 0 --spec <slug> --ref <slug>:round-<round>/<seat>:<agent> --model fable
   --agent <agent>`, and one sentence to the owner, in the owner's language. A refusal on the
   redispatch is the existing path: the seat stays absent. No other error is retried this way.
3. Record and judge: `bash scripts/cycle.sh advance docs/specs/<slug> --stamp $stamp --ingest`. A seat
   still listed in `next` was rejected: re-dispatch it once with its `rejected` error appended, then
   `--ingest` again.
4. Release, whatever happened: `bash scripts/cycle.sh release docs/specs/<slug> $stamp`. Print the
   newest `**Council:**` line of plan.md and act on `next`:
   - `green`: first `bash scripts/ship-check.sh docs/specs/<slug>`; when its `suite:` line asks for the merge
     run (`suite: no full run at <sha>`), run `bash scripts/cycle.sh suite docs/specs/<slug> --merge --commit` step by step until `"done":true`, before «Выпускаем?»
     (one Bash call per step, `timeout: 600000`, no agent). A `suite: FAIL` line is a repair: fix the parts it
     names, commit, run the merge run again. Then ask the owner once with `AskUserQuestion`, in the owner's language: «<slug>: council
     GREEN, round <n>. Выпускаем?», yes first and recommended. Yes: run `vulyk-ship` with the Skill
     tool (args `<slug>`). No, or no `AskUserQuestion` (`claude -p`): recommend `/vulyk-ship` in one line.
   - `build:<W>`: the round was RED and the repair story is written; it is built through `/vulyk-build`,
     never by hand in this command. A RED round is followed by a repair and a narrow round: one reviewer reads
     the repair's diff, the blind seat re-judges only the asks to re-judge, the gate re-runs only the steps that
     were red; a full round follows a repair only after a design fault.
   - `escalated`: print `## Needs a human` from plan.md verbatim. The owner chooses: `human-check.sh
     <spec> ACCEPTED "<his words>" --commit`, `cycle.sh reopen "<decision>"` (add `--full` only on his word that
     it is a design fault, never without it), or leaving the spec open.

The council's verdict is what this command produces; there is no stop for the owner inside it.
