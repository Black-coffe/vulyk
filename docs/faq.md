# FAQ

**Is VULYK a wrapper, proxy, or alternative client?**
No. It is configuration: agents, commands, skills, hooks, rules, templates, and conventions inside the official Claude Code client. Nothing intercepts your auth or your traffic.

**Does it work on Pro/Max subscriptions after Anthropic's April 4, 2026 third-party policy?**
Yes - by design. The policy restricts subscription OAuth to official clients; VULYK lives entirely inside the official client. (Independent of policy: parallel agents consume limits faster - the cascade exists to make that affordable.)

**Which model plans - Fable 5.1 or Opus 5?**
Whichever your plan carries inside its limits. `scripts/top-model.sh` reads the account profile Claude Code caches in `~/.claude.json`: Max 5x / 20x and premium seats get `fable` (up to half the weekly limit is Fable at no extra cost); Pro, standard seats and API keys get `opus` (Fable would bill to usage credits on top of the subscription). The SessionStart brief announces it; `/vulyk-plan` and `/vulyk-review` pass it as the dispatch `model:`. Details and the rejected alternatives in [model-cascade.md](model-cascade.md).

**I want Fable on Pro anyway / Opus on Max anyway.**
Replace `auto` in the `TOP_MODEL = auto` line of CLAUDE.md with the alias you want; the pin beats the plan. `VULYK_TOP_MODEL=<alias>` does the same for one shell. The cascade is model-agnostic everywhere else.

**The brief says my session is "not pinned".**
The Queen's own session starts on the account default (Sonnet 5 on Pro, Opus 5 on Max) unless something pins it. `bash scripts/top-model.sh --apply` writes one `"model"` key into the gitignored `.claude/settings.local.json` and the next launch starts on the resolved model; `/model <alias>` on the first turn does it for the current session, free, because the cache is still cold.

**Why can't my lead-build agent spawn workers?**
Claude Code subagents cannot use the Task tool - a platform constraint. VULYK's answer: fan-out lives in the main session's commands; subagents stay single-purpose. See [architecture.md](architecture.md).

**Do I need Agent Teams?**
No. Subagent fan-out covers Tiers 0-3 well. Teams (experimental env flag) add peer coordination for collaborative Tier 3-4 work - debugging with competing hypotheses, cross-layer features.

**How is this different from BMAD / Ruflo / Gas Town?**
BMAD is a spec-driven methodology (VULYK borrows the stories-as-truth idea, with a lighter ceremony and a model cascade). Ruflo is a swarm platform with its own runtime (powerful, but parts of it require API billing post-April-4). Gas Town orchestrates 20-30 full Claude Code processes (brilliant, expensive, built for a different scale of operator). VULYK is the subscription-safe, native-only middle: cascade + memory + evolution with zero runtime.

**Can I use a vector / semantic-search MCP with it?**
Yes - pairs well for million-line monorepos. VULYK's file-based map stays the source of truth; semantic search becomes another scout tool.

**A worker keeps failing the same way.**
That is a wall, and walls are information: the worker writes `## Findings`, the Queen re-scopes or escalates to `lead-architect`. If the same wall recurs across specs, `/vulyk-evolve` will surface it as a friction pattern.

**My CLAUDE.md is growing.**
It should not. Push path-specific content to `.claude/rules/`, domain knowledge to `docs/wiki/`, and let `/vulyk-evolve`'s deletion bias prune the rest. The constitution's power is inverse to its length.
