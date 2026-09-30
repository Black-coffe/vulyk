# The model cascade

## Principle
Route each unit of work to the cheapest model that does it well, and spend top-model tokens where
they change everything downstream: **planning** (a wrong structure poisons every story) and **final
review** (a missed defect costs more than the reviewer). This is the "bookend" pattern.

What changed in July 2026 is the *reason* for the bookend, not the shape of it. With Opus 5 the
binding problem is no longer that a frontier model is unaffordable — it is that a frontier model
does more than it was asked. Anthropic's own system card explains the dip in coding scores at high
effort as the model making more changes than the task required. So the cascade now earns its keep
by holding scope, and the savings are a side effect. Since v0.20.0 the cascade is cut by kind of
work: Sonnet executes, Opus orchestrates and judges, Fable holds the Tier 4 gate. The family that
builds never judges.

## Where the cascade is enforced
1. **Agent frontmatter** — every `.claude/agents/*.md` declares `model:`. Committed to the repo:
   routing by configuration, not willpower.
2. **The story's `model:`** — the driver dispatches each worker on it (default `sonnet`).
3. **The routing matrix** in `CLAUDE.md` — tier decided before work starts and announced.
4. **`TOP_MODEL`** — one line in `CLAUDE.md`. Since v0.10.0 it reads `auto` and the plan decides;
   see the next section.
5. **The model floor** — no dispatch may run below it; see [The model floor](#the-model-floor).

## The gate model follows the plan (v0.10.0, re-cut in v0.16.0)

*History, kept short.* **v0.16.0 (ADR-012)** moved the Queen off the gate. On 2026-09-22 Artificial
Analysis measured Opus 5.5 at `medium` level with Fable 5.1 at `high` (index 51) for $1.34 a task
against $3.91. From then on the resolved alias named the **gate**, not the Queen. **v0.18.0
(ADR-013)** narrowed the gate to Tier 4: `lead-review` runs on `opus` at Tier 1–3, one fresh-context
reviewer per round. The audit behind it found `lead-review` BLOCK behind 39 of 64 non-green rounds,
and extra rounds took 29.5% of the spend of the tasks that had them.

Today the gate model is passed only where the stakes justify it: the Tier 4 review (beside a second
reviewer on a different model), `lead-architect`, the Tier 4 `queen-planner` and a missed story's
retry. Fable stays there because it is a short call where a miss costs most. Since v0.20.0 the
workers write on Sonnet, so at Tier 3 the Opus reviewer judges code a different family wrote. At
Tier 1–2 the Queen builds on Opus and an Opus reviewer judges in a fresh context. That tradeoff is
unchanged.

Whether Fable is the *right* gate is a question about money, not capability. Anthropic's plan terms
(September 2026, [support article][fable-plan]) draw the line: on **Max** plans and on premium
Team/Enterprise seats, up to half of the weekly limit may be spent on Fable at no extra cost; on
**Pro** and on standard seats, Fable is not inside the plan at all — every token bills to usage
credits on top of the subscription. So the rule VULYK applies is:

| Plan | Read from | Gate (`TOP_MODEL`) | Tier 4 second reviewer |
|---|---|---|---|
| Max 5x, Max 20x | `organizationType: claude_max` | `fable` | `opus` |
| Team / Enterprise, premium seat | `organizationType` + `seatTier: premium` | `fable` | `opus` |
| Pro, standard seats | `organizationType: claude_pro` / seat tier | `opus` | `sonnet` (Fable would bill to credits) |
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

- `.claude/hooks/top-model-brief.sh` prints one `[VULYK] gate model: ...` line at SessionStart
  naming the alias, the plan, the Tier 4 pairing, which dispatches carry it, and whether the
  Queen's own session is pinned to `opus`.
- It travels as the **per-invocation `model:` parameter**, which takes precedence over the agent
  file's frontmatter ([sub-agents docs][subagents]): `/vulyk-plan` passes it to the Tier 4
  `queen-planner` and `lead-architect`; `/vulyk-build` and `/vulyk-review` to the Tier 4 review
  (`top_model` and `second_model`); the Workflow driver to a missed story's second attempt.
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
second time. The same holds for the first fast-mode turn, and for `/effort` on models other than
Opus 5.5, Sonnet 5.5 and Fable 5.1 (on those three, an effort change keeps the cache, except on
Bedrock, Vertex and gateways).

This is what makes the Tier 4 "second reviewer on a different model" affordable: it is a second
subagent, not a session-level switch. See [token-economy.md](token-economy.md).

## Use aliases, not pinned IDs
Write `opus`, `sonnet`, `haiku` — not `claude-opus-5`. An alias resolves to the current model in
that family, so the next generation is absorbed without editing a single file. That property is the
main reason this framework survived the 4.8 → 5 transition with a three-line diff instead of a
rewrite. Pin a full ID only when you deliberately want to freeze behaviour.

An alias is not a guarantee, though. What it resolves to depends on the provider and on env pins.
The floor, below, is what catches that.

## The ladder (v0.20.0, ADR-015)

Four families, cut by kind of work. A rung is a job, not a budget line. Each agent's frontmatter,
or a story's `model:`, fixes it to one. **The family that builds never judges.**

| Family | Job, and where it ends | Agents |
|---|---|---|
| Fable — the gate, `TOP_MODEL` (`fable` on Max and premium seats, `opus` on Pro, standard seats and API) | short, high-stakes calls. It never writes a first attempt and never orchestrates. | the Tier 4 `lead-review` (beside a second reviewer), `lead-architect`, the Tier 4 `queen-planner`, the **second attempt** of any missed story. The frontmatter says `opus`; the dispatch parameter carries the upgrade. |
| Opus — judgment, `opus` | orchestrate, plan, judge. At Tier 3–4 it writes no story code on a first attempt. | the Queen (who also builds Tier 1–2 herself), `queen-planner`, `lead-review` at Tier 1–3 and as the second reviewer beside Fable, `lead-architect` where the gate is `opus`, `council-opus`, `council-haiku`, `drone-coverage`, `librarian` |
| Sonnet — execution, `sonnet` | a story, a map, a doc, one verb. It never judges code its own family wrote. | `worker-code`, `worker-test` (story default `model: sonnet`), `drone-scout`, `drone-docs`, `cycle-clerk`; the Tier 4 second reviewer beside an Opus gate |
| Haiku — mechanical, `haiku` | nothing until a Haiku at or above the floor exists. Then only `cycle-clerk`. | none today |

`council-haiku` is the black-box seat. The name is the angle, not the model; it runs on `opus`
because it judges. `council-sonnet` left the ladder in v0.18.0: it returned no RED in 16 rows of
VULYK's own ledger, and its job, running the suite, is done once by `close-story`.

**Why the workers are on Sonnet.** A VULYK story is well-scoped by construction: named files, quoted
asks, a `## Verification` line. That is the case Anthropic names for Sonnet ("well-scoped everyday
tasks, fixing bugs"). On Anthropic's launch table (2026-09-28), Sonnet 5.5 led Opus 5.5 on
Terminal-Bench 4.0, 70.6% against 66.4%. That benchmark is the closest one to "edit, run, close".
Sonnet costs half as much per token. Two gains are not about money:
- At Tier 3 the Opus `lead-review` now judges code another family wrote.
- The retry climbs a rung on every plan (below).

The per-task cost is a vendor claim until measured. `token-report.py` per story is the check. If a
Sonnet story costs more than a 0.19 Opus story, `model: opus` goes back into `templates/story.md`
and the `cycle.sh` default. (History: 0.16.0 moved the workers off Sonnet 5, which Artificial
Analysis measured at about $4.8 a task against $1.34 for Opus 5.5 at `medium`.)

**Why planning and judging stay on Opus.** On the same table Opus 5.5 led on FrontierCode 1.1 (54.4
against 46.2) and on HLE. Anthropic's advice is Opus for "complex work requiring careful judgment",
and "for the hardest long-horizon work, an Opus model is the better choice".

**Why the clerk is on Sonnet.** One verb at `effort: low`, where Sonnet "skips thinking on most
simple requests". Opus cannot switch thinking off. When a Haiku at or above the floor ships, the
clerk flips to `haiku` with one word in `cycle-clerk.md` and a CHANGELOG line. Nothing else moves to
Haiku. **A Haiku below the floor is never dispatched** (the owner's rule, ADR-007).

**The retry climbs to the gate.** A story's second dispatch goes to `TOP_MODEL` whatever its own
`model:` says. The first attempt runs on Sonnet, so the retry is always a different family: Fable on
Max, Opus on Pro and API. `status --json` carries each story's `model` (default `sonnet`), so the
driver never opens the story file to learn it.

At Tier 3–4, `lead-review` and the blind seats (`council-opus`, and `council-haiku` when the
Profile's *Client path* is filled) are dispatched together, one message per council round: they
are independent in information, so they can be independent in wall-clock time. `cycle.sh advance
--ingest` records their reports and `cycle.sh judge` folds them into one verdict; no model does.

### Caveat on the recon tier
Recon on Sonnet is a judgment, not a measurement. A scout report feeds planning, where a bad map
poisons every story downstream. Mapping is read-only, well-scoped work, and the planner that reads
the map is Opus. If a plan misses because of a bad map, the scout goes back to `opus`.

## The model floor

The owner's rule: only the newest model of each family, and never below the floor. The routing names
families, never versions, so the newest model arrives through the alias. The floor catches the cases
where the alias does not deliver it.

**Where an alias falls short.** Claude Code's [model-config page][model-config] shows what an alias
resolves to per provider (read 2026-09-28):

| Provider | `opus` | `sonnet` |
|---|---|---|
| Anthropic API / subscription | Opus 5.5 | Sonnet 5.5 |
| Claude Platform on AWS | Opus 5.5 | Sonnet 4.6 |
| Amazon Bedrock, Google Cloud | Opus 5.5 | Sonnet 4.5 |
| Microsoft Foundry | Opus 4.6 | Sonnet 4.5 |

Six env vars can also remap an alias to any ID, from the shell or from a settings file's `env` block:
- `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`, `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
  `ANTHROPIC_DEFAULT_FABLE_MODEL`;
- `ANTHROPIC_MODEL`;
- `CLAUDE_CODE_SUBAGENT_MODEL`.

**The floor is a few lines of data:** `model_floor` in `scripts/lib.sh`, today
`fable 5.1 · opus 5.5 · sonnet 5.5 · haiku 5.5 unreleased`. It ships with every upgrade, so a hive
never keeps a stale copy. When a model ships, raising its line is a one-line diff and a CHANGELOG
line. `unreleased` marks a floor no model of the family meets yet: while it stands, the bare alias
(`haiku`, which resolves to Haiku 4.5) is itself below the floor. Delete the word the day a Haiku 5.5
ships. Env `VULYK_MODEL_FLOOR` overrides line by line (`sonnet 4.5; opus 4.6`) for a hive that
deliberately runs lower, for example a Bedrock account without 5.5; a family it does not name keeps
its default.

`--floor` also reads every story's `model:` in `docs/specs/`, because the driver passes it verbatim.
Two paths it cannot see before the fact: managed (enterprise) settings, and Claude Platform on AWS,
which has no `CLAUDE_CODE_USE_*` flag. `model_below_floor` catches both after the fact. It reads the
newest real model ID of each transcript, so a session that ran below the floor and then switched
back up for its last turn goes unrecorded.

**Before the fact: `bash scripts/top-model.sh --floor`.** It checks every place an alias can be
remapped:
- the env vars above, in the shell;
- the `env` and `model` keys of the user and project settings files;
- a `CLAUDE_CODE_USE_*` provider flag with no family pin. Using the table above, it names which
  alias falls below the floor there.
- a pinned ID in agent frontmatter.

It exits 1 on any finding, and the SessionStart brief prints the result. It warns and never edits
settings: a provider's model IDs are the owner's to set (`anthropic.claude-sonnet-5-5` on Bedrock).

**After the fact: telemetry code `model_below_floor`.** `scan` reads the model ID each main and
subagent transcript actually ran on. Below the floor, it records a row with the version and the
floor. This is the only ground truth, and it catches every path, including one nobody has thought of
yet. The SessionStart brief counts this week's rows.

Rejected: pinning full IDs (the per-release rewrite the floor exists to end); a floor that raises
itself to the highest version seen in local transcripts (a state file, and different answers on
different machines); `availableModels` / `deniedModels` (managed settings for enterprise
administrators, not something a framework ships).

### Why the second reviewer must be a different model
A production review benchmark (CodeRabbit) measured Opus 5 against Opus 4.8: precision rose
35.2% → 39.3% while **recall fell 61.1% → 55.2%**, with roughly four times as many minor nitpicks.
It finds fewer real problems but is more often right about the ones it reports. Two copies of one
model are blind in the same places, and adversarial framing does not fix that — so the Tier 4 pair
should not be two copies of one model. The same reasoning is why no gate or reviewer should be the
family that wrote the code.

Two things to weigh. On plans where Fable bills to credits, the pairing is an `opus` gate and a
`sonnet` second reviewer — the resolver already picks that. Sonnet is the builders' family there.
Fable would bill credits, and a second Opus would duplicate the gate, so this is the accepted gap.
The gate itself is still not the builder. More importantly, Fable and Mythos are subject to the
30-day data-retention requirement and Opus is not ([anthropic.com/claude/fable][fable-page]) — and
on Max plans, where Fable is the Tier 4 reviewer and planner, it sees every Tier 4 diff and brief,
plus the stories a retry needs. On a closed codebase that is a deliberate decision: pin
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
| a top-level effort level in `.claude/settings.json` | **Not for Opus 5.5** | Per the model-config docs it does not apply to Opus 5.5, which starts at its own default, `medium`; VULYK's settings no longer set it (0.18.0) |

VULYK now writes the level into the frontmatter of the agents whose work has a clear level. A seat
without one inherits the session level:

| Agents | `effort:` | Why |
|---|---|---|
| `drone-scout`, `drone-docs`, `cycle-clerk` (Sonnet), `librarian` (Opus) | `low` | reading, mapping, one verb |
| `worker-code`, `worker-test` (Sonnet) | `medium` | Anthropic's Sonnet 5.5 advice: `medium` for well-specified agentic coding, `high` for harder or longer work |
| `drone-coverage`, `council-opus` (Opus) | `medium` | Opus's own default; Opus 5.5 at `medium` matched Opus 5 at `high` with fewer tokens |
| `queen-planner`, `lead-architect`, `lead-review` (Opus) | `high` | a wrong plan or a missed defect poisons everything downstream |
| `council-haiku` (Opus) | — (session) | set per session by the owner |

Sonnet 5.5's prompting guide (2026-09-28) names what a worker at `medium` does that a harness must
plan for:
- it may stop and check in before a long task is done;
- at `low` it may skip verification;
- at every level it adds tests, docs and small files nobody asked for.

The worker prompts carry Anthropic's two published remedies instead of a higher effort:
- the scope paragraph ("When the work ... is done and checked, stop and report. Don't add features,
  tests, files, docs or refactors that weren't asked for"), which also serves Law 3;
- the verification paragraph (run a real check that exercises the change before reporting done).

An early stop shows up as the existing `agent_empty` telemetry code. If that rate rises on Sonnet
workers, the fix is `effort: high` on the two worker files: one word each.

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
while still reasoning. On Opus 5.5, Sonnet 5.5 and Fable 5.1 an effort change keeps the cached
prefix; on other models it drops it, so there set the session level once at the start.

## Anti-patterns the cascade exists to kill
- Opus reading 40 files to "understand the project" (that is a scout's job).
- Re-dispatching a failed worker with the identical prompt — walls are information; route them.
- Running the Tier 4 gate on the same model that wrote the code.
- Writing a version into routing ("use Sonnet 5.5"). Name the family; the floor holds the version.
- Reaching for `max` because the task feels important. Importance is not the signal; a failure is.
