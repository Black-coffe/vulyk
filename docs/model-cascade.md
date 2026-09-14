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

## The top model follows the plan (v0.10.0)

Fable 5.1 is the strongest planner there is, and whether it is the *right* planner is a question
about money, not capability. Anthropic's plan terms (September 2026, [support article][fable-plan])
draw the line: on **Max** plans and on premium Team/Enterprise seats, up to half of the weekly
limit may be spent on Fable at no extra cost; on **Pro** and on standard seats, Fable is not inside
the plan at all — every token bills to usage credits on top of the subscription. So the rule VULYK
applies is:

| Plan | Read from | King of planning & orchestration | Tier 4 second reviewer |
|---|---|---|---|
| Max 5x, Max 20x | `organizationType: claude_max` | `fable` → Fable 5.1 | `opus` |
| Team / Enterprise, premium seat | `organizationType` + `seatTier: premium` | `fable` | `opus` |
| Pro, standard seats | `organizationType: claude_pro` / seat tier | `opus` → Opus 5 | `sonnet` (Fable would bill to credits) |
| API key, unknown, not signed in | `ANTHROPIC_API_KEY` / nothing | `opus` — the floor | `sonnet` |

The half-of-the-limit cap is the bookend pattern's own shape: Fable on planning and the gate,
Sonnet on the workers, and the cap is never reached by design.

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
- `scripts/top-model.sh --apply` pins the alias as `"model"` in the gitignored
  `.claude/settings.local.json`, so the Queen's session — the orchestrator itself — starts on it
  from the next launch. It merges one key and touches nothing else. The hook never writes this;
  it reports drift and leaves the decision to you.

**Why the three top-caste files still say `model: opus`.** Frontmatter cannot be conditional, and
it ships to every install. `fable` there would bill a Pro owner's usage credits from the first plan
without asking; `inherit` would drag the planner down to whatever the session happens to run on —
Sonnet 5 by default on Pro, per Anthropic's own [defaults table][model-config]. `opus` is right on
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

## The ladder (v0.13.0, ADR-007)

Four rungs, named the way a team is: lead, senior, mid, junior. A rung is a job, not a
budget line, and the rule that fixes each agent to one is in its frontmatter.

| Rung | Alias | Agents | Work |
|---|---|---|---|
| Lead | `TOP_MODEL` — `fable` → Fable 5.1 on Max and premium seats, `opus` → Opus 5 on Pro, standard seats and API | Queen, `queen-planner`, `lead-architect`, `lead-review` | planning, design, the gate; the frontmatter floor is `opus`, the dispatch parameter carries the upgrade |
| Senior | `opus` → Opus 5 | `council-opus`; the **second attempt** of any story a mid missed; stories the planner marks `model: opus` (cross-cutting, contract-touching, the tracer); the Tier 4 second reviewer beside a Fable gate | judgment, hard stories, retries |
| Mid | `sonnet` → Sonnet 5 | `worker-code`, `worker-test`, `council-sonnet`, `drone-scout`, `drone-docs`, `drone-coverage`, `librarian` | implementation against an explicit story, recon, memory upkeep |
| Junior | `haiku` **only once a Haiku 5 exists** — `sonnet` until then | `council-haiku` (the black-box seat; the name is the angle, not the model), `cycle-clerk`, the `VULYK_AUTOLEARN` distiller | mechanical, one verb, no judgment |

**Haiku 4.5 is never dispatched.** The one seat that ran on it returned `N/A` in all three
recorded rounds, and a clerk that mangles one line ends a driver run. When a fifth-generation
Haiku ships, the junior rung flips back with three one-word edits (`council-haiku.md`,
`cycle-clerk.md`, `session-end-learnings.sh`) and a CHANGELOG line - not before, and not by a
resolver guessing the generation from a local file.

**The retry climbs one rung.** A story's second dispatch goes to `opus` whatever its own
`model:` says: a red verification, an empty report or a `WALL` is information, and the same
model rereading the same wall was, in every recorded case, the cheapest way to buy the second
miss that blocks the story and wakes the Queen. `status --json` carries each story's `model`
so the driver never opens the story file to learn it.

`lead-review` and the three council seats are dispatched together, one message, per council round —
the same "independent in information, so independent in wall-clock cost" reasoning that used to pair
`lead-review` with the single `drone-acceptance` now pairs it with three; `scripts/cycle.sh judge`
folds their reports into one verdict, no model does.

### Caveat on the recon tier
Recon on Sonnet rather than the junior rung is a judgment, not a measurement: a scout report
feeds planning, where a bad map poisons every story downstream. The measurement stays on the
list for the day a Haiku 5 exists - two scout reports over the same module, one per rung.

### Why the second reviewer must be a different model
A production review benchmark (CodeRabbit) measured Opus 5 against Opus 4.8: precision rose
35.2% → 39.3% while **recall fell 61.1% → 55.2%**, with roughly four times as many minor nitpicks.
It finds fewer real problems but is more often right about the ones it reports. Two copies of one
model are blind in the same places, and adversarial framing does not fix that — so the Tier 4 pair
should not be two Opus 5 instances.

Two things to weigh. On plans where Fable bills to credits, the pairing is `sonnet` rather than
`fable` — the resolver already picks that. More importantly, Fable and Mythos are subject to the
30-day data-retention requirement and Opus is not ([anthropic.com/claude/fable][fable-page]) — and
on Max plans, where Fable is now the gate *and* the planner, the reviewer sees the entire diff and
the planner sees every brief. On a closed codebase that is a deliberate decision: pin
`TOP_MODEL = opus` in `CLAUDE.md` to opt out, and the resolver honours the pin over the plan.

[fable-page]: https://www.anthropic.com/claude/fable

*(That Fable specifically has better recall is an inference, not a measurement. What is supported
is only that an ensemble of different models beats a duplicate.)*

## Effort is a session setting, not a caste setting

Measured on this repository in July 2026, and worth knowing before you try the obvious thing:

| Where effort is set | Works? | Evidence |
|---|---|---|
| `--effort <level>` at launch | **Yes** | low → 1 371 output tokens, max → 7 434 on an identical prompt |
| `effortLevel` in `.claude/settings.json` | **Yes** | low → 1 603, xhigh → 5 504 |
| `/effort <level>` mid-session | Yes | Same mechanism; but see the cache note |
| `effort:` in `.claude/agents/*.md` | **No — silently ignored** | low → 8 819, max → 4 541: inverted, i.e. no control at all. An invalid value raises no error |

Subagents inherit the session's level. Do not write `effort:` into agent frontmatter: it reads as
configured and does nothing, which is worse than leaving it out. This looks like a parser gap
rather than a design decision, so re-test after Claude Code upgrades.

VULYK ships `"effortLevel": "medium"` in `.claude/settings.json`. Raise it per session for planning
and review work:

| Work | Level | Escalate when |
|---|---|---|
| Recon, map refresh, memory upkeep | `low` | — |
| Ordinary implementation | `medium` | tests fail → `high` |
| Planning, review, Tier 3–4 | `high` | a real failure → `xhigh` |
| Anything | `max` | only after a falling test earns it |

Two constraints behind that table. The step from `high` to `max` costs roughly **+94% for about two
points of benchmark index**, and higher effort raises the number of tool calls — which is where the
money actually goes in agentic runs. Separately, changing effort mid-session re-renders the prompt
and drops the cached prefix; a cache miss can cost more than the effort reduction saves, so set the
level once at the start of a session rather than toggling it per message.

## Anti-patterns the cascade exists to kill
- Opus reading 40 files to "understand the project" (that is a scout's job).
- Re-dispatching a failed worker with the identical prompt — walls are information; route them.
- Running the gate on the same model that wrote the code.
- Reaching for `max` because the task feels important. Importance is not the signal; a failure is.
