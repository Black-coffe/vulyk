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
3. **`TOP_MODEL`** — one line in `CLAUDE.md` for the Queen's own model.

## Use aliases, not pinned IDs
Write `opus`, `sonnet`, `haiku` — not `claude-opus-5`. An alias resolves to the current model in
that tier, so the next generation is absorbed without editing a single file. That property is the
main reason this framework survived the 4.8 → 5 transition with a three-line diff instead of a
rewrite. Pin a full ID only when you deliberately want to freeze behaviour.

## Current assignment (July 2026)

| Caste | Model | Why |
|---|---|---|
| Queen, `queen-planner`, `lead-architect`, `lead-review` | `opus` → Opus 5 | Frontier reasoning at half of Fable's price; default on Max plans |
| `worker-code`, `worker-test` | `sonnet` → Sonnet 5 | Implementation against an explicit story does not need frontier reasoning |
| `drone-scout`, `drone-docs`, `librarian` | `sonnet` → Sonnet 5 | See the caveat below — this one is a judgment call, not a measurement |
| Second reviewer, Tier 4 only, opt-in | `claude-fable-5` | Ensemble, not duplication — see below |

### Caveat on the recon tier
Moving the drones off Haiku is **not backed by evidence**, and the honest case runs the other way:
Anthropic's own effort-routing guidance puts classification and simple summarisation at "Sonnet or
cheaper", which is exactly what recon is. The argument for the move is that Haiku 4.5 is the only
tier without a fifth-generation upgrade, so the quality gap is now the widest it has ever been —
and a scout report feeds planning, where a bad map poisons every story downstream.

That is a hypothesis. It is first in line to be measured: run two scout reports over the same
module on `haiku` and `sonnet` and compare. Reverting is three lines.

### Why the second reviewer must be a different model
A production review benchmark (CodeRabbit) measured Opus 5 against Opus 4.8: precision rose
35.2% → 39.3% while **recall fell 61.1% → 55.2%**, with roughly four times as many minor nitpicks.
It finds fewer real problems but is more often right about the ones it reports. Two copies of one
model are blind in the same places, and adversarial framing does not fix that — so the Tier 4 pair
should not be two Opus 5 instances.

Two things to weigh before enabling it. Fable 5 costs about twice as much. More importantly, Fable
and Mythos are subject to the 30-day data-retention requirement and Opus is not — and the reviewer
sees the entire diff. On a closed codebase that is a deliberate decision, not a default. It ships
off by default for that reason.

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
