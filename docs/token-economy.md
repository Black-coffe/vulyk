# The token economy

Every rule in the constitution's *Token economy* section has a price behind it. This document is
that price list. Read it once; after that the rules should feel obvious rather than arbitrary.

Source for the mechanics: Anthropic's
[Maximizing the value of your Claude Code sessions](https://claude.com/blog/maximizing-the-value-of-your-claude-code-sessions).
The framework-specific consequences below are ours.

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
| `/effort` mid-session | Part of the cache key; same full re-prefill |
| Fast mode toggled | Part of the cache key; re-prefill, and turning it *on* is what costs |
| `/compact` | The conversation is replaced, so nothing matches (the system prompt survives) |
| Time | Subscription: **1 h**. API key: **5 min**, unless `ENABLE_PROMPT_CACHING_1H=1` |
| Resuming an old session | The cache is normally gone by then |

`/rewind` is the exception worth knowing: it cuts turns off the *end*, so everything before the cut
stays cached. Prefer it over `/compact` when you only need to undo the last few turns.

Two operational consequences:

- **Set `/model` and `/effort` once, at the start of a session.** Toggling either mid-flight can
  cost more than the setting saves.
- **Checkpoint while the cache is still warm.** `/compact` and `/vulyk-handoff` both re-read the
  conversation; inside the 1 h window that read is a cache hit, after it, full price. If you are
  going for lunch, compact *before* you go, not after.

## Why the cascade is cache-safe and `/model` is not

A subagent gets its own context window, its own turns, and its own system prompt, tools and
`CLAUDE.md` — but **not your conversation**. Only its final answer comes back; everything it read
along the way is discarded with it.

That is the whole trick behind VULYK's routing. Sending implementation to Sonnet through
`model: sonnet` in `.claude/agents/worker-code.md` costs the main session nothing in cache terms:
the Queen's prefix is untouched, and the worker's own prefill happens in a context you never pay to
re-send. Doing the same thing by typing `/model sonnet` in the main session would re-prefill the
entire conversation at full price and hand every later turn back to the wrong model.

**So: route with agent frontmatter, never with `/model`.** This applies to the Tier 4 second
reviewer too — a reviewer on a different model is a second *subagent*, not a session model switch.

The same accounting explains when a subagent is *not* worth it. A drone that re-reads three files
the Queen already has in context is pure overhead: it pays a fresh prefill to rediscover what was
already paid for. Dispatch is a win when the report **replaces** reading that would otherwise land
in the Queen's window — which is exactly the recon and noisy-output cases, and exactly not the
"look up one symbol I already have open" case.

## What is in the context before you type anything

Tool definitions, the system prompt, `CLAUDE.md` (and everything it imports), plus every loaded MCP
server. All of it is re-sent every turn, cached, for the life of the session.

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
`/clear` between tiers, and behind the handoff layer that makes clearing cheap.

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
2. **Context size** — files read, command output, unused MCP servers.
3. **Model and effort** — they multiply every price above.
4. **Cache breaks** — mid-session `/model` or `/effort` changes, compaction after the window closed.

The order matters more than the individual tactics: a perfectly tuned effort level inside a
400-turn session is a rounding error against having split it in two.
