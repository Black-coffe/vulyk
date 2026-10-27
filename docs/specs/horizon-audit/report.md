# Study: the horizon step, checked against the code and its one real run (report)

Date: 2026-10-27 · Brief: [brief.md](brief.md) · Panel: crossgrill fable / opus / sonnet, two rounds, run directory
`.crossgrill/2026-10-27-horizon-audit/` (git-ignored) · Fact-check: Claude Code docs, sub-agents page, read 2026-10-27

## Bottom line

There is nothing new to build: all four ideas the review praises are already in VULYK. They shipped in 0.35.0 on
2026-10-25 (spec `horizon-intake`, ADR-022) and fired once in a real plan on 2026-10-26 (spec `symbol-map`). Two of
the four claims hold as written. Two overstate it: the court is not "absolutely clean", and the `(horizon)` tag
legalises nothing. The improvement is five small text edits to close what the real run exposed, plus two recorded
triggers and one honest note: the in-session parallel dispatch has never run for real. No new script, gate or agent.

## The four claims, checked

| Claim | Verdict | Evidence |
|---|---|---|
| C1 · horizon.md keeps the blind court "absolutely clean" | **partly** (panel 3/3) | `build_court` prunes the spec to `brief.md` (`scripts/cycle.sh:2236`), so `horizon.md` never reaches the court. But `## Answers` records every horizon question with the owner's pick, declined ones included: `docs/specs/symbol-map/brief.md:43` «История git (horizon H2): Не добавлять». The court does not see proposals. It does see the owner's decisions on them. Verdicts are safe because seats grade one line per `## Asks` item (`.claude/agents/council-opus.md`, «One `ASK` line per item of `## Asks`»). |
| C2 · silence never adds; `claude -p` skips the step entirely | **partly** (panel 3/3 after round 2) | Silence = «Не добавлять» holds (`templates/grill.md:61`). The skip is the default only: `--horizon` runs the step in no-question mode too (`.claude/commands/vulyk-plan.md:31`), and the proposals then go into `brief.md` `## Answers` as `(offered, not adopted)` (`templates/grill.md:81`). The no-question detection itself is sound: Claude Code removes `AskUserQuestion` from every subagent (fact-check below), and the grill keys on the tool's presence. |
| C3 · up to 3 horizon questions inside the 3-7 cap, no new round | **holds** (3/3) | `templates/grill.md:54`. In the real run: 4 ordinary + 2 horizon + the fixed last = 7, H3 folded into a design option. Gap: nothing orders ordinary questions against horizon ones inside the cap. |
| C4 · the `(horizon)` tag legalises adopted proposals for `trace-check.sh` | **partly** (3/3) | No script reads the tag (`grep horizon scripts/` hits only `scripts/telemetry.sh:65`, the agent list). A story quote is legal because it equals a whole `## Asks` item (`scripts/trace-check.sh:56-60`, ADR-013 D4). "No bash crutches" is true; "the tag legalises" is not. The tag is provenance for a human reader. |

## What the one real run exposed

From `docs/specs/symbol-map/horizon.md`, its brief and its two council rounds:

1. **Declined ideas sit in `brief.md`, and the court's leftovers feed the next brief.** `UNASKED:` lines are handed
   to the owner verbatim as the draft of the next brief (`.claude/commands/vulyk-ship.md:46`, `docs/cycle.md:133`).
   A blind seat that rediscovers an idea the owner declined would put it back in front of the owner as a fresh
   proposal. In `symbol-map` that did not happen: council-opus's UNASKED in both rounds lists other things
   (`docs/specs/symbol-map/council/round-1/opus.md:15-21`). One case only.
2. **ADR-022's reversal trigger has no instrument.** «owners answering «Не добавлять» to nearly every horizon
   question over a month of plans» (`docs/adr/022-horizon-step.md`, Consequences). No file or script counts picks;
   `/vulyk-evolve` has no horizon line. The `(horizon H2)` label in symbol-map's `## Answers` was a habit, not a rule:
   `templates/grill.md` does not require it.
3. **`kind: gap` is elastic, and «как рекомендуешь» adopts every gap.** The third clause, «a gap without which the
   owner's goal fails» (`.claude/agents/drone-horizon.md:41`), is set by a Sonnet lens. In symbol-map, H1
   (a replay as the acceptance number) went in as a gap; reasonable, but it is a quality bar, not a hole.
4. **The lenses could not read the Profile.** «None of them could read `CLAUDE.md`», so the check against
   *Configurations that exist today* rested on the recon summary alone (`docs/specs/symbol-map/horizon.md`). The
   cause is not established: `omitClaudeMd` only stops auto-injection, and step 1 of the agent tells it to read the
   file. The panel's guess (a Glob existence check on a machine where Glob is blind) is unverified.
5. **The in-session parallel dispatch has never run.** In 0.35 and in symbol-map the agent did not load in-session
   (`Agent type 'drone-horizon' not found`); the lenses ran as headless `claude -p --model sonnet`. 0.37 shipped a fix
   (`CHANGELOG.md:65`), and `drone-horizon` is in this session's agent list. So it loads now. Three lenses in one
   message, with web permission prompts in a default-mode hive, have not been seen yet.

## Options for the improvement (recommended first)

**A. Five text edits in one Tier 2 spec, two triggers in ADR-022 (recommended).** Each edit closes a finding above
with the smallest change. No new script, no new section in a template, no gate.

| # | Edit | File | Closes |
|---|---|---|---|
| E1 | Say what the court sees: «the court sees no proposals; it sees the owner's decisions on them». Correct "skipped" to "skipped unless `--horizon`" | `templates/grill.md`, ADR-022 amendment | C1, C2 wording |
| E2 | Every horizon entry in `## Answers` carries `(horizon H<n>)` and its pick: adopted, declined, or `(offered, not adopted)`. A kept proposal not asked already stays "offered" in `horizon.md` (`templates/grill.md:55`) | `templates/grill.md` | finding 2: the data exists from the next fire on |
| E3 | The Queen keeps `kind: gap` only when she names the ask or the verbatim request fragment that fails without it; otherwise it becomes `extension` | `.claude/commands/vulyk-plan.md` step 3a | finding 3 |
| E4 | The dispatch inlines the Profile rows *Configurations that exist today* and *Owner language*; the agent reads the file only when they are missing | `.claude/commands/vulyk-plan.md` step 3a, `.claude/agents/drone-horizon.md` step 1 | finding 4 |
| E5 | Order inside the cap: ordinary questions that change what gets built first, then horizon gaps, then extensions | `templates/grill.md` | C3 gap |

ADR-022 gains three lines:
- **Not yet run:** the in-session three-lens dispatch. The first real new-ground plan is its live run; its tokens and
  any permission prompts go into that spec's `horizon.md`.
- **Trigger 1 (counter):** after 3-5 real fires, `/vulyk-evolve` counts `(horizon H` entries across
  `docs/specs/*/brief.md`: adopted, declined, offered. This is the instrument for the reversal rule already in the ADR.
- **Trigger 2 (declined idea returns):** if a blind seat's `UNASKED:` ever repeats a proposal the owner declined,
  `/vulyk-ship` step 5 marks that line `(declined <date>, found again by the court)` when it hands the draft over.
  Marking it at ship is better than banning it in the seat: the owner still learns that the court found the idea on
  its own, and the change sits in one file, not in two seat prompts.

**B. The same edits, with the guards built now.** The evolve counter now (one panel model: it costs almost nothing)
and a line in `council-opus.md`: «an idea `## Answers` records as declined is not UNASKED» (two panel models).
Not recommended. There is one real fire and no case of a declined idea returning. Law 2 forbids guarding against
what has not happened. And a line in the seat prompt hides from the owner that the court valued the idea
independently.

**C. Do nothing but fix the wording.** Cheapest. Leaves the gap label elastic and the lenses blind to the Profile.
Both showed up in the one real run.

**Rejected outright (panel 3/3):** a `trace-check.sh` line that matches each `(horizon)` ask against `horizon.md`.
It would only warn, and under Law 6 «A check that only warns is not a check»; no real case failed. Moving horizon
answers out of `brief.md` into `horizon.md` only: it splits the owner's answers across two files and takes away the
court's one way to know an idea was declined. A probe dispatch now (~75k tokens, three lenses): it would show only
that the step launches on an artificial case; the next real plan shows the same for free.

## Where the panel split

- **The counter (trigger 1).** 2/3 (opus, fable) defer the counter until 3-5 fires; sonnet says count now. All three
  agree no new section is needed. Settled by splitting it: the label (E2) now, so no fire loses its data, and the
  counter later.
- **The declined-idea guard (trigger 2).** 2/3 (opus, sonnet) want one line in `council-opus.md` now. Fable says no
  guard at n=1, write the trigger down. The Queen sides with fable on timing, for the Law 2 reason. When the trigger
  fires, the fix goes in the ship step, not the seat (see option A).
- **Why the lenses missed the Profile.** Missing data, 3/3: the cause is not isolated. E4 works whatever the cause.

## Candidate stories (for the owner to approve next time)

1. `horizon-audit-01` (Tier 2, the Queen builds): E1-E5 and the ADR-022 amendment, CHANGELOG line. Verification:
   `bash tests/solo.test.sh` (plan and build mechanics intact) and `bash tests/maintenance.test.sh` (description and
   size caps). No suite reads prompt text, so the acceptance criteria must say so, as `horizon-intake` did.
2. After release: the hives on 0.38.0 get it with the next upgrade. None of the edits changes a live hive's behaviour
   until its next new-ground plan, so no hotfix is needed.

## Fact-check

| Claim | Status | Sources |
|---|---|---|
| `AskUserQuestion` is removed from every subagent, even when listed in `tools` | ❓ one primary source | Claude Code docs, «Create custom subagents», code.claude.com/docs/en/sub-agents (read 2026-10-27, T1, no page date): «The first filter removes these tools, even when listed in the `tools` field: `AskUserQuestion` …». No second independent source was fetched; `templates/grill.md:15` says the same but is VULYK's own text, not a source |
| `AskUserQuestion` absent under `claude -p` | ⚠️ contested over versions | GitHub issue anthropics/claude-code#77994 (opened 2026-07-16, closed 2026-08-17 as completed, fix not described): present in 2.1.185, missing in 2.1.204. Installed here: 2.1.311. Not load-bearing: the grill keys on the tool's presence, not on the mode. |

## Not read or run

- No drone-horizon dispatch in this study (see option A's ADR line).
- `council-haiku` reports: symbol-map had no black-box seat, so its UNASKED path is unread here.
- Hives were not surveyed for horizon runs; VULYK itself has one (`symbol-map`).
