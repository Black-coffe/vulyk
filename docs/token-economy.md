# The token economy

Every choice in VULYK's shape — who builds at which tier, how many agents a round dispatches, what
each subagent loads — has a price behind it. This document is that price list. Read it once;
after that the rules should feel obvious rather than arbitrary.

Source for the mechanics: Anthropic's
[Maximizing the value of your Claude Code sessions](https://claude.com/blog/maximizing-the-value-of-your-claude-code-sessions).
The framework-specific consequences below are ours; the measured numbers come from the
[token audit](specs/token-audit/report.md) (1,844 sessions, 13–26 September 2026).

## Not all tokens cost the same

Three multipliers stack on every token that moves through a session.

**Which model burns it.** A larger model does more work per token on both ends, so the model choice
multiplies everything downstream. This is the cascade's whole reason for existing.

**Input or output.** Prefill — reading the system prompt, `CLAUDE.md`, tool definitions and the
conversation so far — is comparatively cheap per token. Decode — thinking, tool calls, visible text,
one token at a time — occupies the accelerator far longer, and is priced at roughly **5× input**.
Thinking tokens are output tokens, which is why effort level shows up in the bill directly.

**Cached or not.** A cache hit costs about **0.1×** the input price; writing to the cache costs up to
**2×**. A conversation whose prefix stays cached is nearly free to re-send. A conversation whose
prefix was invalidated is re-prefilled at full price on the very next turn.

## The cache key, and what breaks it

The cached prefix survives while the conversation is *appended to*. It dies when anything earlier
in the request changes:

| Event | Effect |
|---|---|
| `/model` mid-session | Each model has its own cache — the whole conversation re-prefills at full price |
| `/effort` mid-session | Keeps the cache on Opus 5.5 and Fable 5.1 (a per-message effort change); on other models, and on Bedrock/Vertex, a full re-prefill |
| Fast mode toggled | Part of the cache key; re-prefill, and turning it *on* is what costs |
| `/compact` | The conversation is replaced, so nothing matches (the system prompt survives) |
| Time, main session | Subscription: **1 h**. API key or usage credits: **5 min**, unless `ENABLE_PROMPT_CACHING_1H=1` |
| Time, subagents and Workflow agents | **5 min** on every plan, Max included; `subagentPromptCacheTtl` raises it, and a 1 h write bills higher |
| Resuming an old session | The cache is normally gone by then |

`/rewind` is the exception worth knowing: it cuts turns off the *end*, so everything before the cut
stays cached. Prefer it over `/compact` when you only need to undo the last few turns.

Three operational consequences:

- **Set `/model` once, at the start of a session.** Toggling it mid-flight can cost more than the
  switch saves. `/effort` is free to change on Opus 5.5 and Fable 5.1, not elsewhere.
- **Checkpoint while the cache is still warm.** `/compact` and `/vulyk-handoff` both re-read the
  conversation; inside the 1 h window that read is a cache hit, after it, full price. If you are
  going for lunch, compact *before* you go, not after. The audit counted 58 full re-writes of the
  Queen's cache after she sat idle for over an hour waiting on a long run: 25M weighted tokens.
- **A subagent that waits more than five minutes pays for its whole context again.** A worker or
  reviewer idle on a ten-minute suite re-writes its cache on its next request. That is one
  reason `close-story` runs verification once, under a 540 s timeout, instead of the worker
  running the suite and then `close-story` running it again.

## Why the cascade is cache-safe and `/model` is not

A subagent gets its own context window, its own turns, and its own system prompt and tools — but
**not your conversation**. Only its final answer comes back; everything it read along the way is
discarded with it.

That is the whole trick behind VULYK's routing. The workers run on Sonnet through the story's
`model: sonnet` (and the scout through `model: sonnet` in `.claude/agents/drone-scout.md`), and that
costs the main session nothing in cache terms: the Queen's prefix is untouched, and each subagent's
own prefill happens in a context you never pay to re-send. Doing the same thing by typing
`/model sonnet` in the main session would
re-prefill the entire conversation at full price and hand every later turn back to the wrong model.

**So: route with agent frontmatter, never with `/model`.** This applies to the Tier 4 second
reviewer too — a reviewer on a different model is a second *subagent*, not a session model switch.

The same accounting explains when a subagent is *not* worth it. A drone that re-reads three files
the Queen already has in context is pure overhead: it pays a fresh prefill to rediscover what was
already paid for. Dispatch is a win when the report **replaces** reading that would otherwise land
in the Queen's window — which is exactly the recon and noisy-output cases, and exactly not the
"look up one symbol I already have open" case. It is also why the Queen builds Tier 1-2 herself:
a small change costs less in the session that already holds the plan than in a worker that has
to load it again.

## What every subagent loads before it starts

A subagent does not see your conversation, but it does load every level of `CLAUDE.md` the main
session loads — `~/.claude/CLAUDE.md`, the project's `CLAUDE.md` and everything it imports,
`AGENTS.md`, `.claude/rules/` — plus a git-status snapshot, and it writes all of that to a fresh
5-minute cache of its own. The audit measured a subagent's first request at **27–36k tokens**
(48k for `council-haiku`, whose browser MCP schemas ride along), about 85% of it that instruction
bundle, re-read on every turn. The bundle was **23% of all spend**.

Two things answer it (changed in 0.18.0, ADR-013 D7):

- **`omitClaudeMd: true`** (Claude Code ≥ 2.1.271) on the agents that take everything from their
  dispatch prompt: `cycle-clerk`, `council-opus`, `council-haiku`, `drone-scout`,
  `drone-coverage`, `drone-docs`, `librarian`. Workers, `lead-review`, `queen-planner` and
  `lead-architect` keep the constitution, because they need the host's conventions.
- **A 7 KB constitution.** Laws, routing, models, Secrets, Profile and Commands only (was 16 KB,
  and 15–31 KB in hives with a sidecar `CLAUDE.vulyk.md`). The ladder, the cycle and this page
  live in `docs/` and in the `/vulyk-*` commands, which load only into the Queen. A hive gets
  this saving only after `install.sh --upgrade --constitution replace`.

## The cost of a spec

**Measured, v0.17.0.** A median task (44 tasks with a cycle) processed **84.9M raw tokens, 13.5M
weighted** (cache read ×0.1, cache write ×1.25 or ×2, input and output ×1) and dispatched **67
subagents, 43 of them `cycle-clerk`** — an agent that runs one shell command and returns one line.
Spend split into near-equal thirds: the Queen 30.5%, workers 30.4%, review machinery 30.7%
(council seats 13.4%, `lead-review` 9.7%, clerks 7.6%). 82% of specs took two rounds or more; a round cost a median 7.3M raw / 1.46M weighted, and extra
rounds took **29.5%** of the spend of the tasks that had them.
**56%** of driver runs stopped before a verdict and were relaunched.

**By design, v0.18.0** (ADR-013; the dispatch counts are the code's, the saving is an estimate):

| Tier | Dispatches per spec, v0.17.0 | v0.18.0, happy path |
|---|---|---|
| 1 | 14 (10 clerks) | 1 `lead-review` |
| 2 | 21–33 | 1–2 `lead-review` (one per round) + at most one scout |
| 3 | 35–53 | the workers + 2 seats (3 with a *Client path*) per round + 4 clerk calls for a one-wave, one-round run |
| 4 | 52–73 | as Tier 3, with two reviewers per round and a `lead-architect` consult |

The clerk count fell because the driver calls `cycle.sh advance` once per agent boundary —
`advance --claim`, `advance` after a wave, `advance --ingest` after a council dispatch, `release` —
instead of once per verb. Each extra wave or round adds one or two calls. Rounds are cheaper as
well: a green blind seat is carried forward, and from round 2 `lead-review` reads only the diff
since the last round. The estimate is −40…55% on a median task.

**Measure it, do not trust the printed figure.** The `totalTokens` a Workflow run prints is the
sum of each agent's *final* context, not what was processed — about 29 times too low on the median
task. `python scripts/token-report.py . --spec <slug>` reads the transcripts and prints raw and
weighted tokens, dispatches by agent type and rounds per spec; `/vulyk-status` and `/vulyk-evolve`
print its lines.

At Tier 3-4 without the Workflow tool, the Queen runs the same `advance` loop and dispatches with
the `Agent` tool. The dispatches are the same; the difference is that every seat's reply lands in
her own long-lived context, so that path costs more.

## What is in the context before you type anything

Tool definitions, the system prompt, `CLAUDE.md` (and everything it imports), plus every loaded MCP
server. All of it is re-sent every turn, cached, for the life of the session — and, `CLAUDE.md`
included, into every subagent that does not omit it.

Run `/context` in a fresh session, before your first message, and look at the actual numbers. Then:

- Turn off MCP servers this project does not use, with `/mcp`. Tool definitions are pure overhead
  when nothing calls them.
- Keep `CLAUDE.md` to standing instructions. Anything workflow-specific belongs in a skill or in
  `.claude/rules/` — both load only where they are relevant, and the constitution stays lean.

## What lands in the context during the session

**Vague requests.** "The tests are failing" buys a grep and half a dozen file opens, all of which
stay in the transcript. `Fix the failing case in utils.test.ts` buys one read. Name the path.

**`@`-mentions.** Typing `@path/to/file` attaches the file to your message before the request is
sent: it is present in the very first prefill and there is no `Read` call at all. Same tokens for
the file, fewer around it. Mention each file **once** per conversation — a second `@` puts a second
copy in the window.

**Command output.** Under **30 000 characters** the full output is appended to the conversation and
re-sent on every turn that follows. Above it, Claude Code writes the output to a file and keeps a
short preview plus the path in context — usually the better outcome; `BASH_MAX_OUTPUT_LENGTH` moves
that threshold, and *lowering* it pushes noisy commands into files sooner.

This is why `CLAUDE.md` carries a `## Commands` table of quiet variants, and why a story's
`## Verification` line must name one. A chatty test reporter can outweigh the implementation it was
meant to verify.

**Background loops.** `/loop` fires a full turn each time, carrying the entire conversation with it
— and if an hour has passed since the previous turn, a cache miss on top. Run long polling loops in
a separate session, in another terminal.

## How long it all stays there

Turn 40 re-reads turns 1 through 39. The same work done as one long session costs
disproportionately more than the same work split across several — which is the arithmetic behind
`/clear` between tiers, and behind the handoff layer that makes clearing cheap. It is also why a
Tier 2 build starts in a fresh session after approval: the build needs the files, not the planning
conversation.

- `/clear` when switching tasks; `/vulyk-handoff` first if the thread has state worth keeping.
- `/rename` before `/clear` if you intend to come back to the session.
- `/compact` when the early part of a session is finished but the tail still matters — while the
  cache is warm.
- `/autocompact 200k` restores the automatic safety net (Claude Code v2.1.221+).
- The `## Compact instructions` section of `CLAUDE.md` tells `/compact` what a hive session must
  never lose: tier, story statuses, decisions with reasons, walls.

VULYK measures the first of these for you. `handoff.py` reads the real context size out of the
transcript on every turn and warns at 110k / 140k / 165k tokens, alongside how long the cached
prefix has left. See [hooks-reference.md](hooks-reference.md).

## The levers, in order of how much they cost

1. **Session length.** Nothing else on this list compounds.
2. **Agent count.** Every subagent re-pays its instruction bundle into a fresh cache; a clerk that
   runs one command costs about as much to start as a worker.
3. **Context size** — files read, command output, unused MCP servers, the constitution.
4. **Model and effort** — they multiply every price above.
5. **Cache breaks** — a mid-session `/model` change, compaction after the window closed, a
   subagent idle past five minutes.

The order matters more than the individual tactics: a perfectly tuned effort level inside a
400-turn session is a rounding error against having split it in two.
