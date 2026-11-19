# ADR-040: A repair re-checks what it repaired; the full check is the owner's call

- Status: accepted (2026-11-15, with the plan: `**Approved:**` in `docs/specs/narrow-repair-1115/plan.md`)
- Date: 2026-11-15 · Version: 0.54.0
- Spec: docs/specs/narrow-repair-1115 (drafted at plan time, filed by story 05 as built by stories 01-04)
- Evidence: the owner's words of 2026-11-14 in `docs/specs/narrow-repair-1115/brief.md` and on card
  `full-round-for-a-narrow-fix`; a three-model review of the audit-fixes-1113 build (local, not in the repo): a full
  round after a small repair cost about 110 minutes, and the repair stories inherited every check of the spec.
- Amends:
  - ADR-013 D4 (repair story: `## Files` and `## Verification` as the union of every done story) and its 2026-11-08
    amendment C5 (narrow repair: one RED item in one non-test file); ADR-013 carries a dated amendment pointing here;
  - ADR-013 D3 and its amendment C4 (which blind seat is carried into the next round);
  - ADR-023 / ADR-029 (the full suite runs once per round);
  - the 0.52 rule that a repair whose findings name no real file gets a full round with its suite.

  Everything else in those ADRs stands: state on disk, the frozen roster, the ceiling, `no-progress`, `half`,
  `reopen`, the review of every diff, the gate's steps, parts and caps.

## Context

After a RED round the loop cut a repair story that carried the files and the checks of every story before it, and
then opened a whole new round: every seat again, the whole suite again. The narrow path of 0.49 covered only one RED
item in one non-test file, so a repair of four red asks, or of one slow test part, paid for the full round. The owner
rejected that twice (2026-10-16, 2026-11-14).

## Decisions

### D1 - The round after a repair is narrow by default
`open-round` computes the scope of the round that follows a repair from committed records only (`round_scope`: HEAD's
`memory/stats/council.jsonl` and `council/REOPEN`, never a story's frontmatter or run state) and freezes it into
`ROUND`: `repair=<story>`, then either `narrow=1` with `asks=`, `rerun=` and `second=none`, or `full=<why>`. It is a
full round only when
- the repaired round escalated as `half` or `no-progress` and the owner reopened it (`full=design`): those two
  reasons already mean the plan was wrong, not the patch; a reopened `ceiling` gets a narrow round (*amended
  2026-11-16 below: a reopened `no-progress` is narrow too, `full=design` needs the owner's `reopen --full`*);
- the owner asked for a full check (`cycle.sh open-round <spec> --full`, `full=asked`);
- the records the scope is computed from cannot be read (`full=norecord`, one stderr line): a missing input is never
  a pass.

The number of files and of red items no longer decides anything. `narrow_file`, `narrow_round_holds` and the local
`.vulyk/state/<slug>/narrow.round-<n>` record of 0.52 are gone; a story's `narrow: true` line is information only.

#### Amendment to D1 (2026-11-16) - spec `tails-1115`, story 13
Source: the owner's answer in `docs/specs/tails-1115/brief.md` `## Answers` (ask 13).

- A reopened `no-progress` gets a narrow round, not `full=design`: the reviewer on the repair's diff, the blind seat
  over `asks=`, which holds every ask red in the repaired round (seat or review) and every touched one, so a repeated
  red never drops out of scope.
- `full=design` follows only the owner's word that it is a design fault: `cycle.sh reopen <spec> "<decision>" --full`
  writes `full=1` on the round's `council/REOPEN` line (`round=<n> full=0|1 · <ts>`; a second `--full` for the same
  round changes nothing, one given after a plain reopen turns `full=0` into `full=1`), and `round_scope` answers
  `full design` for that round whatever its reason. A REOPEN line written before this amendment, with no `full`
  field, reads as `full=0`.
- A reopened `half` stays `full=design`, with or without `--full`; a reopened `ceiling` stays narrow without it.
  `--full` is never added by a model or a driver without the owner's word; `reopen` on a row that is not ESCALATE is
  refused as before.

### D2 - A repair story carries its findings' rows
`## Files`: the paths the findings name, their exact tests, `docs/defects/*`. `## Verification`: the rows of the done
stories whose `## Files` match one of those paths; for a red ask whose findings name no path, the files and rows of
the stories that serve it (one of their `## Requirements` lines found inside the ask's text). Nothing tied: `none —
reviewed by lead-review`. Never the union of every story's rows.

### D3 - A seat runs only when it has an ask to judge
`asks=` of a narrow round: the asks RED in the repaired round (seat or review), the asks served by a done story whose
`## Files` match a path of the repair's diff (`since..head`), and every ask when no earlier round holds the blind
seat's report. An empty list freezes `seats=review`: no court, no dispatch, no empty report. Otherwise the tier's
blind seat is dispatched with no carry; `court_round_asks` writes `<court>/docs/specs/<slug>/round-asks`, one ask
per line, and the seat judges only those asks, marking the others `N/A - why: not re-judged this round` (an `N/A`
counts as agreement in `judge`). With no such file a seat judges every ask. A narrow round has no second reviewer.

### D4 - The gate of a narrow round re-runs what was red
`cycle.sh suite` in a narrow round runs only the steps `rerun=` lists, the steps that were `FAIL` in the repaired
round's `suite.log` (`all` when the step count changed), and writes `SUITE: ok|FAIL <N>s - narrow repair round,
steps <list> of <S>`; none red means `SUITE: none - narrow repair round`. The files the repair touched are covered by
the repair story's own rows at `close-story`. A `ROUND` opened before this release with `narrow=1` and no `asks=` or
`rerun=` reads as review-only with no gate step.

### D5 - The full suite runs once before a local merge, with no agents
`ship-check.sh` is ready on its `suite:` line only with a finished `SUITE: ok` over every suite step keyed to the
branch head, or to a commit with only paperwork after it: the newest round's `suite.log` when that round was not
narrow, else `council/merge-suite.log`, written by `cycle.sh suite <spec> --merge` one step per call with the
round's caps and resume, never while a round is open. A round that ran every step green on the head already
satisfies it, so the suite runs once, not twice. A red merge run is cured by fixing what failed and running the
whole suite once more with `--merge`, with no agents; never by a council round, which stays the owner's explicit
`open-round --full`. A constitution with no `round-only` row reads `suite: none`, ready.

### D6 - The full check of the whole project is the owner's call
Every seat over every ask plus every suite step (`open-round --full`: the tier's whole roster with no carried seat,
`since=` the branch base, no `round-asks`) runs when the owner says so: when the major version goes up (0.5x to
0.6x), about once a month, when bugs or feedback come in. `/vulyk-ship` offers it at a major bump and never opens it
on its own; a minor release, public or not, does not trigger it. No timer, reminder or version parser is built.

## Consequences

- A repair of several asks costs one worker, one reviewer and, when an ask is in scope, one blind seat over those
  asks, instead of a full round.
- Tradeoff, accepted by the owner: a regression in an ask no seat re-judges is caught by the reviewer of the diff, by
  the merge gate, or by the next full check, not by the blind seat in the same round.
- A hand fix after a GREEN round keeps today's path (carried seats, a review of the new diff, the round's own gate).
- Card `full-round-for-a-narrow-fix` checks a round's `ROUND` and `suite.log` text against D1-D4.
- Built in the same spec: a story's sections are read outside fenced code blocks only, so a red receipt's captured
  output cannot add a line to them.
- Contract tests change with the contract: `tests/council.test.sh`, `tests/cycle.test.sh`, `tests/e2e.test.sh`.

## Rejected

- A `[design]` tag written by the reviewer as the full-round signal: a new report field every reviewer must be taught,
  and the cost of a round would rest on a model's label; the escalation reasons are already computed by a script.
- Passing the ask list to the seat through the dispatch prompt: a `status` field, the driver and three command files
  would change for what one file in the court does.
- Keeping one full suite per repair round: about 20 machine minutes per repair for what the merge gate checks once.
