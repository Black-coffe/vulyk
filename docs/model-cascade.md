# The model cascade

## Principle
Route each unit of work to the cheapest model that does it well, and spend top-model tokens where
they change everything downstream: **planning** (a wrong structure poisons every story) and **final
review** (a missed defect costs more than the reviewer). This is the "bookend" pattern.

What changed in July 2026 is the *reason* for the bookend, not the shape of it. With Opus 5 the
binding problem is no longer that a frontier model is unaffordable — it is that a frontier model
does more than it was asked. Anthropic's own system card explains the dip in coding scores at high
effort as the model making more changes than the task required. So the cascade now earns its keep
by holding scope, and the savings are a side effect.

## Where the cascade is enforced
1. **Agent frontmatter** — every `.claude/agents/*.md` declares `model:`. Committed to the repo:
   routing by configuration, not willpower.
2. **The routing matrix** in `CLAUDE.md` — tier decided before work starts and announced.
3. **`TOP_MODEL`** — one line in `CLAUDE.md`. Since v0.10.0 it reads `auto` and the plan decides;
   see the next section.

## The gate model follows the plan (v0.10.0, re-cut in v0.16.0)

**v0.16.0 (ADR-012).** On 2026-09-22 Opus 5.5 shipped and changed which model belongs where.
Artificial Analysis (Intelligence Index v4.3.2) measured Opus 5.5 at `medium` level with Fable 5.1
at `high` (51) for $1.34 a task against $3.91, and 38M output tokens against 62M. At `high`,
Opus 5.5 scores 54, above Fable 5.1 at `max` (53), for $2.00 against $7.63. Anthropic's own advice
became "start with Claude Opus 5.5 for most workloads", with Fable 5.1 for "demanding reasoning and
long-horizon agentic work". Its system card (§8.12) has Opus 5.5 ahead of Opus 5 and Fable 5.1 at
every agent-team size from 1 to 100. So the resolved alias no longer names the Queen. It names
the **gate**: `lead-review`, `lead-architect`, the Tier 4 `queen-planner` and a missed story's
retry. The Queen and every other rung run on `opus` on every plan. Two reasons keep Fable at the
gate. It is a short call where a miss costs most. And once the workers write on Opus 5.5, a gate on
Opus 5.5 would review code with the model that wrote it.

Whether Fable is the *right* gate is a question about money, not capability. Anthropic's plan terms
(September 2026, [support article][fable-plan]) draw the line: on **Max** plans and on premium
Team/Enterprise seats, up to half of the weekly limit may be spent on Fable at no extra cost; on
**Pro** and on standard seats, Fable is not inside the plan at all — every token bills to usage
credits on top of the subscription. So the rule VULYK applies is:

| Plan | Read from | Gate (`TOP_MODEL`) | Tier 4 second reviewer |
|---|---|---|---|
| Max 5x, Max 20x | `organizationType: claude_max` | `fable` → Fable 5.1 | `opus` |
| Team / Enterprise, premium seat | `organizationType` + `seatTier: premium` | `fable` | `opus` |
| Pro, standard seats | `organizationType: claude_pro` / seat tier | `opus` → Opus 5.5 | `sonnet` (Fable would bill to credits) |
| API key, unknown, not signed in | `ANTHROPIC_API_KEY` / nothing | `opus` — the floor | `sonnet` |

The Queen is `opus` in every row. With the gate holding only short calls, the half-of-the-limit
cap is never reached by design.

`scripts/top-model.sh` does the reading. Its source is the account profile Claude Code caches in
`~/.claude.json` (`oauthAccount.organizationType`, `.organizationRateLimitTier`, `.seatTier`) — the
one local place the plan is written down, and a cache of the signed-in account rather than a
credential. The credentials file is never opened; the resolver is grep and sed, so it runs on a
machine with neither `jq` nor Python. Every failure mode — no profile, an unrecognised
`organizationType`, an unreadable file — resolves to `opus` and says why under `--explain`.

Resolution order: `VULYK_TOP_MODEL` in the shell, then a non-`auto` pin in `CLAUDE.md`, then the
plan, then `opus`. The field names for Max were read off a real profile; the Pro and seat-tier
spellings follow the same pattern and are matched loosely (`*pro*`, `*premium*`), which is the
honest amount of confidence to encode.

**How the resolved alias reaches the work.** Three places, none of them willpower:

- `.claude/hooks/top-model-brief.sh` prints one `[VULYK] top model: ...` line at SessionStart
  naming the alias, the plan, the Tier 4 pairing, and whether the Queen's own session is pinned
  to it.
- `/vulyk-plan` and `/vulyk-review` pass it as the **per-invocation `model:` parameter** when
  they dispatch `queen-planner`, `lead-architect` and `lead-review`. That parameter takes
  precedence over the agent file's frontmatter ([sub-agents docs][subagents]).
- `scripts/top-model.sh --apply` pins `opus` as `"model"` in the gitignored
  `.claude/settings.local.json`, so the Queen's session — the orchestrator itself — starts on it
  from the next launch (v0.16.0: the Queen is not the gate). It merges one key and touches nothing else. The hook never writes this;
  it reports drift and leaves the decision to you.

**Why the gate files still say `model: opus`.** Frontmatter cannot be conditional, and
it ships to every install. `fable` there would bill a Pro owner's usage credits from the first plan
without asking; `inherit` would tie the gate to whatever the session happens to run on (Opus 5.5
by default since Claude Code 2.1.280, per Anthropic's [defaults table][model-config], but an
owner's `/model` choice otherwise). `opus` is right on
every plan and wrong on none; the dispatch parameter is the upgrade. Two native alternatives were
weighed and rejected: the `best` alias resolves to Fable "where available to you", and on Pro it
*is* available — for credits — so it implements exactly the rule this framework exists to avoid;
`CLAUDE_CODE_SUBAGENT_MODEL` only applies to agents with no `model:` of their own, which is none of
VULYK's.

[fable-plan]: https://support.claude.com/en/articles/15424964-claude-fable-models-on-your-plan
[subagents]: https://code.claude.com/docs/en/sub-agents
[model-config]: https://code.claude.com/docs/en/model-config

## Route with frontmatter, never with `/model`

The cascade is expressed in agent frontmatter for a reason beyond tidiness. A subagent runs in its
own context window with its own cache; dispatching to `model: sonnet` leaves the main session's
cached prefix untouched. Typing `/model sonnet` in the main session does the opposite: the model is
part of the cache key, so the entire conversation re-prefills at full input price on the next turn,
and every subsequent turn runs on the wrong model until you switch back — paying the re-prefill a
second time. The same holds for `/effort` and the fast-mode toggle.

This is what makes the Tier 4 "second reviewer on a different model" affordable: it is a second
subagent, not a session-level switch. See [token-economy.md](token-economy.md).

## Use aliases, not pinned IDs
Write `opus`, `sonnet`, `haiku` — not `claude-opus-5`. An alias resolves to the current model in
that tier, so the next generation is absorbed without editing a single file. That property is the
main reason this framework survived the 4.8 → 5 transition with a three-line diff instead of a
rewrite. Pin a full ID only when you deliberately want to freeze behaviour.

## The ladder (v0.16.0, ADR-012 — supersedes the rungs of ADR-007)

Three rungs. A rung is a job, not a budget line, and each agent's frontmatter fixes it to one.

| Rung | Alias | Agents | Work |
|---|---|---|---|
| Gate | `TOP_MODEL` — `fable` → Fable 5.1 on Max and premium seats, `opus` → Opus 5.5 on Pro, standard seats and API | `lead-review`, `lead-architect`, the Tier 4 `queen-planner`, the **second attempt** of any missed story | the gate, design, the hardest plans, retries; the frontmatter floor is `opus`, the dispatch parameter carries the upgrade |
| Workhorse | `opus` → Opus 5.5 | the Queen, `queen-planner` at Tier 1–3, `worker-code`, `worker-test`, `drone-scout`, `drone-docs`, `drone-coverage`, `librarian`, `council-opus`; the Tier 4 second reviewer beside a Fable gate | orchestration, planning, implementation, recon, memory upkeep, intent |
| Junior | `sonnet` → Sonnet 5 until a Haiku 5.5 ships | `council-sonnet` (permanently: a different model in the court), `council-haiku` (the black-box seat; the name is the angle, not the model), `cycle-clerk`, the `VULYK_AUTOLEARN` distiller | mechanical, one verb, running what exists |

**Why the workers left Sonnet.** Sonnet 5 costs half as much per token ($2/$10 against $4/$20).
Per solved task it is not cheaper. Its cache-read price is the same $0.20 as Opus 5.5, and cache
reads are the bulk of an agentic loop. Artificial Analysis measured Sonnet 5 (at `max`, the only
level it reports) at index 38 with 370M output tokens, about $4.8 a task. Opus 5.5 at `medium`:
51, 38M, $1.34. A worker's miss also costs a block, a `lead-architect` consult and a relaunch
(ADR-007), and that is where a cheaper worker's savings go.

**Why Sonnet stays at all.** Two places need what Sonnet has and Opus 5.5 lacks.
- *A different model in the court.* Two copies of one model are blind in the same places (see
  below).
- *No thinking to pay for.* Opus 5.5 cannot switch thinking off, so a clerk on it would reason
  before every one-verb call.

When a Haiku 5.5 ships, the clerk, the black-box seat and the distiller flip to `haiku` with one
word each (`council-haiku.md`, `cycle-clerk.md`, `session-end-learnings.sh`) and a CHANGELOG line.
`council-sonnet` stays on Sonnet. **Haiku 4.5 is still never dispatched** (the owner's rule,
ADR-007).

**The retry climbs to the gate.** A story's second dispatch goes to `TOP_MODEL` whatever its own
`model:` says. On Max that is Fable, so the second attempt is never the same model reading the same
wall. On Pro and API the gate is `opus`, so the retry runs on the same model as the first attempt.
That is the one rung those plans lack, and it is recorded as a gap rather than hidden. `status --json`
carries each story's `model` (default `opus`), so the driver never opens the story file to learn it.

`lead-review` and the three council seats are dispatched together, one message, per council round —
the same "independent in information, so independent in wall-clock cost" reasoning that used to pair
`lead-review` with the single `drone-acceptance` now pairs it with three; `scripts/cycle.sh judge`
folds their reports into one verdict, no model does.

### Caveat on the recon tier
Recon on the workhorse rather than the junior rung is a judgment, not a measurement. A scout
report feeds planning, where a bad map poisons every story downstream. The scout runs at
`effort: low`, which is what keeps it cheap.

### Why the second reviewer must be a different model
A production review benchmark (CodeRabbit) measured Opus 5 against Opus 4.8: precision rose
35.2% → 39.3% while **recall fell 61.1% → 55.2%**, with roughly four times as many minor nitpicks.
It finds fewer real problems but is more often right about the ones it reports. Two copies of one
model are blind in the same places, and adversarial framing does not fix that — so the Tier 4 pair
should not be two copies of one model. The same reasoning is why the gate must not be the model
that wrote the code, now that the workers write on Opus 5.5.

Two things to weigh. On plans where Fable bills to credits, the pairing is `sonnet` rather than
`fable` — the resolver already picks that. More importantly, Fable and Mythos are subject to the
30-day data-retention requirement and Opus is not ([anthropic.com/claude/fable][fable-page]) — and
on Max plans, where Fable is now the gate *and* the planner, the reviewer sees the entire diff and
the planner sees every brief. On a closed codebase that is a deliberate decision: pin
`TOP_MODEL = opus` in `CLAUDE.md` to opt out, and the resolver honours the pin over the plan.

[fable-page]: https://www.anthropic.com/claude/fable

*(That Fable specifically has better recall is an inference, not a measurement. What is supported
is only that an ensemble of different models beats a duplicate.)*

## Effort is a caste setting again (re-measured v0.16.0)

In July 2026, on Claude Code 2.1.220, `effort:` in agent frontmatter was silently ignored
(`low` → 8 819, `max` → 4 541 output tokens: inverted, i.e. no control). The same probe on
Claude Code **2.1.280** on 2026-09-22 found it working. The main session ran on Sonnet so that
the subagent's tokens were counted apart, the subagent ran on Opus 5.5, and the prompt was the
same logic puzzle in both runs. The subagent's docs now say the field "Overrides the session
effort level".

| Where effort is set | Works? | Evidence |
|---|---|---|
| `effort:` in `.claude/agents/*.md` (2.1.280) | **Yes** | `low` → 613 / 715, `max` → 3 136 / 3 296 output tokens (two runs each, ~4.8×) |
| `--effort <level>` at launch | Yes | July: low → 1 371, max → 7 434 |
| `/effort <level>` mid-session | Yes | Same mechanism; but see the cache note |
| `effortLevel` in `.claude/settings.json` | **Not for Opus 5.5** | Per the model-config docs a top-level `effortLevel` does not apply to Opus 5.5; it starts at its own default, `medium` |

VULYK now writes the level into the frontmatter of the agents whose work has a clear level. A seat
without one inherits the session level:

| Agents | `effort:` | Why |
|---|---|---|
| `drone-scout`, `drone-docs`, `librarian`, `cycle-clerk` | `low` | reading, mapping, one verb |
| `worker-code`, `worker-test`, `drone-coverage` | `medium` | Opus 5.5's own default; it matched Opus 5 at `high` with fewer tokens |
| `queen-planner`, `lead-architect`, `lead-review` | `high` | a wrong plan or a missed defect poisons everything downstream |
| council seats | — (session) | set per session by the owner |

Frontmatter now outranks the session, so `/effort max` in the session no longer lifts a worker.
To escalate a story, the retry rule does it with a different model, not a bigger budget.

Session levels for the Queen herself:

| Work | Level | Escalate when |
|---|---|---|
| Planning, review, Tier 3–4 | `high` | a real failure → `xhigh` |
| Building, recon, memory upkeep | `medium` | — |
| Anything | `max` | only after a falling test earns it |

The step from `high` to `max` on Opus 5.5 costs about **5× the output tokens for 4 index points**
(Artificial Analysis: 53M → 260M, 54 → 58). Simon Willison's `max` runs hit the 128K output cap
while still reasoning. Changing effort mid-session re-renders the prompt and drops the cached
prefix, so set the session level once at the start.

## Anti-patterns the cascade exists to kill
- Opus reading 40 files to "understand the project" (that is a scout's job).
- Re-dispatching a failed worker with the identical prompt — walls are information; route them.
- Running the gate on the same model that wrote the code.
- Reaching for `max` because the task feels important. Importance is not the signal; a failure is.
