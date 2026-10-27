# Study: where Fable goes, and how to spend less of it (report)

Date: 2026-10-27 · Brief: [brief.md](brief.md) · Data: every Claude Code transcript of the last 7 days on this machine
(both accounts share one `projects/` folder), split by account through each account's `session-env/` and
`history.jsonl`; scratch scripts, not committed · Claude Code 2.1.311

## Bottom line

On the account that ran out, almost half of all Fable spend never passed through a VULYK agent. It went to a hive's
own judge scripts, which ask VULYK's `scripts/top-model.sh` for a model, get the gate model (Fable), and run it at
`xhigh` effort. Switching the profile does not reach them, because the gate stays Fable in `sonnet-builds`. VULYK's own
judges come second: review, blind seat and planner, all on Fable under `opus-builds`. A third of the judges' cache
writes are full rewrites after a 5-13 minute wait on the test suite. When Fable runs out, nothing switches over:
Claude Code's fallback chain does not fire on a usage limit, so the build stops. Four small changes cover all of it.

## How spend was weighed

Raw token counts mislead: a cache read is far cheaper than a cache write or an output token. Spend below is weighed by
the API list price of each family (Fable 5.1: input $10, cache write $12.50 (1.25× input, derived), cache read $0.25,
output $50 per MTok; Opus 5.5: $4 / $5 / $0.20 / $20; Sonnet 5.5: $2 / $2.50 / $0.20 / $10), from the bundled
`claude-api` skill (prices cached 2026-10-06). The dollars are a yardstick for comparing parts. How the subscription
weighs each family against its limits is not published beyond "Fable uses limits faster" (fact-check below).

| Account | Fable | Opus | Sonnet | Fable share |
|---|---|---|---|---|
| 1 (`~/.claude`; ran out of Fable 2026-10-27 19:00Z; weekly bar 80%) | $555 | $799 | $23 | 40% |
| 2 (`~/.claude-acc2`; weekly bar 41%) | $74 | $341 | $12 | 17% |

Account 1 also hit its five-hour limit three times in two days (2026-10-26 21h, 2026-10-27 06h and 09h UTC,
`apiError: usage_limit_reached`, `rateLimitType: five_hour`). The two $200 accounts are loaded very unevenly.

## Findings

**F1 · A hive's own judge scripts are the largest Fable consumer: $259, 41% of all Fable.** 101 headless `claude -p`
sessions in temp folders, each opening with «Прочитай task.md в текущей папке и выполни его». One overlay-judge run
costs about $7. The hive's three frame-judging scripts choose their model through VULYK's `bash scripts/top-model.sh`,
and fall back to a hard-coded `"fable"` when the call fails. `top-model.sh` names the **gate** model, which VULYK keeps
for a Tier 4 review, a Tier 4 planner and a missed story's retry. Under `sonnet-builds` it is still Fable
(`model-profile.sh --explain sonnet-builds`: `gate fable`), so the profile switch made today does not reach these
scripts. They also run at `xhigh`. The error records show `"perTurnEffort":"xhigh"`, and both accounts' settings carry
`modelSettings.claude-fable-5-1.effortLevel: "xhigh"`. A headless session has no agent frontmatter to override that.

**F2 · VULYK's own judges: $260, 41%.** `lead-review` $144 (23%), `council-opus` $57 (9%), `queen-planner` $44 (7%),
`lead-architect` $5, `council-haiku` $2. All of them are on Fable because the machine profile was `opus-builds`: Opus
writes, so every judge must be another family (`model-profile.sh --explain`). A Fable review dispatch has a median of
0.77M raw tokens over 13 turns, and the largest was 4.1M.

**F3 · A third of the judges' cache writes are rewrites.** Over 784 Fable calls of `lead-review` and `council-opus`,
23 calls rewrote the whole context (cache write over 20k tokens and above the cache read). That is 1.83M of 6.07M
cache-write tokens, 30%. The gap before those calls had a median of 474 s (range 312-792 s). That is the review
waiting on a blocking test-suite run: no request goes out while it waits, the prompt cache expires, and the next turn
pays the write price for everything again. Cache writes are the largest part of a Fable review's cost: about $76 of
$113 for `lead-review`, against about $12 for reads and $25 for output.

**F4 · What fills a review's context.** Tool output in `lead-review` transcripts (all models, 7 days): `Read` 26%,
`git diff` 21%, `cat`/`sed` 19%, `grep` 18%, test suites 11%, other 5%. The brief itself is tiny (median 207 characters).
No single kind dominates, so trimming one tool would not change much. F3 is the lever.

**F5 · When Fable runs out, nothing switches.** The refusal is `apiError: "model_requires_usage_credits"`, text «You've
reached your Fable limit. Switch to another model, or manage usage credits at …» (4 records, 2026-10-27 19-20h UTC).
Claude Code's fallback chain (`--fallback-model`, setting `fallbackModel`) covers subagents too. But by the docs it fires
only when a model is overloaded or unavailable: «Authentication, billing, rate-limit … errors … never trigger a
switch». A build therefore stops at the first judge after the cap, as the hive's did. Its owner then chose Opus by
hand, an exception to the family rule written into that plan's deltas.

**F6 · The rest: $119, 19%,** is `general-purpose` agents on Fable outside VULYK: the personal `crossgrill` panels
(Fable is one of three seats) and research agents in other projects. Out of VULYK's reach, listed for the owner.

## Options (recommended first)

**A. Four narrow changes, two in VULYK, one in the hive, one setting (recommended).**

1. **The hive's judge scripts stop defaulting to the gate.** They take the judge family from
   `bash scripts/model-profile.sh --role seat` (the profile's own judge family, the same rule the council follows),
   pass `--effort high` explicitly, drop the hard-coded `"fable"`, and on `model_requires_usage_credits` rerun once on
   the fallback family (item 3), with a log line. Expected effect: none on the family while `opus-builds` holds (seat is
   Fable there). The saving is the effort step from `xhigh` to `high`, Fable's documented default. Its size is not
   measured: the first runs after the change are the measurement.
2. **The reviewer starts the suite in the background.** `lead-review` runs its suite with Bash `run_in_background`
   first, reviews the diff while it runs, then reads the result. Turns keep coming, so the cache stays warm (F3), and the
   wall time overlaps. Ceiling: about 30% of judge cache writes. **Unverified:** whether a subagent's background Bash
   keeps the agent turning without a poll. A probe comes first, and if it fails, the fallback is that the driver runs
   the suite before dispatching the reviewer. That second form weakens «measure it yourself», so it is not the
   default.
3. **A Fable-limit fallback in VULYK.** When a judge, planner or architect dispatch returns the Fable-limit text,
   `/vulyk-build` (and the Workflow driver) redispatches that role once on a fallback family that
   `model-profile.sh --role <role> --fallback` names. It writes a journal line and a telemetry code
   (`fable_limit_fallback`) and tells the owner in one line. Which family: the owner decides (question below).
4. **`modelSettings.claude-fable-5-1.effortLevel` from `xhigh` to `high`** in both accounts' settings. It reaches every
   Fable session without its own effort: the hive's headless judges and `general-purpose` agents. It is the owner's
   personal setting, so it changes only with the owner's yes.

Until item 1 lands, the hive's judge scripts need an explicit `--model opus` on every run while account 1 is capped:
the hand-made exception in that hive's plan covers one video's blocks only.

Not code: run long builds on the less-loaded account (account 2 had 59% left while account 1 was capped).

**B. A as above, plus an `opus-builds` variant that puts Tier 1-2 review on Sonnet.** Cuts the biggest VULYK line
(F2), but Sonnet would judge Opus code with no quality data behind it. Not recommended until the review rounds
of a Sonnet judge are compared on real specs.

**C. Stay on `sonnet-builds` for good.** Fable only at Tier 4, so F2 disappears. But F1 does not (the gate stays
Fable), and the owner chose Opus as the writer on 2026-10-18 for quality.

## The question for the owner (item 3)

Under `opus-builds`, which family takes a judge's seat when Fable is out? Opus would be the same family as the writer,
the exception this hive's owner already chose by hand. Sonnet keeps the family rule but is a weaker judge. Neither has
measured evidence; the precedent favours Opus with the exception logged.

## Candidate stories (for the owner to approve next time)

1. `fable-budget-01` (VULYK): `model-profile.sh --role <role> --fallback`; the Fable-limit fallback in `/vulyk-build` and
   the Workflow driver; journal line, telemetry code, one-line notice; a test that feeds the refusal text and expects
   the redispatch on the fallback family.
2. `fable-budget-02` (VULYK): the background-suite probe, then `lead-review` step order (or the driver-run fallback);
   one round on a real spec to measure the rewrites again.
3. `fable-budget-03` (VULYK docs): `top-model.sh --help` and `docs/model-cascade.md` say the gate is for Tier 4 and a
   missed retry only; a hive's own judge asks `model-profile.sh --role seat` and passes `--effort`.
4. Hive work (that hive's own plan, its owner's call): its three judge scripts per option A.1.
5. Settings (not a story): `modelSettings.claude-fable-5-1.effortLevel` to `high` on both accounts.

## Fact-check

| Claim | Status | Sources |
|---|---|---|
| Fable draws from the plan's shared weekly limit, faster than other models, capped at 50% of it on Max | ❓ one primary source | support.claude.com/en/articles/15424964 (updated 2026-09-02, T1). Secondary blogs agree on the cap and call it a "separate limit" (christopheralarcon.com/blog/claude-fable-vs-opus, T3, not counted) |
| Claude Code's fallback chain does not fire on rate-limit or billing errors; it covers subagents | ❓ one primary source + local | code.claude.com/docs/en/model-config, «Fallback model chains» (no page date, T1); the local `claude --help` (2.1.311) words it «overloaded or not available» |
| `--effort` exists on the CLI; Fable's default effort is `high`, Opus 5.5's `medium` | ❓ one primary source + local | code.claude.com/docs/en/cli-reference and model-config (T1); `claude --help` lists `--effort <level>` |
| API list prices used as the yardstick | as cached | bundled claude-api skill, «Current Models (cached: 2026-10-06)»; cache write = 1.25× input is derived, not read |

## Not read or run

- How the subscription weighs Fable against other families: not published. The dollar yardstick is a proxy.
- Whether a subagent's `run_in_background` Bash keeps the agent turning (option A.2): not probed.
- Fable judge quality at `high` against `xhigh`: not measured.
- Sessions that are in neither account's `session-env/` or `history.jsonl` ("unknown", $106, no Fable): not traced.
- The `crossgrill` skill's own cost: out of scope. `general-purpose` Fable, mostly its panels, was $82 on account 1
  and $37 on account 2 this week.
