# FAQ

**Is VULYK a wrapper, proxy, or alternative client?**
No. It is configuration: agents, commands, skills, hooks, rules, templates, and conventions inside the official Claude Code client. Nothing intercepts your auth or your traffic.

**Does it work on Pro/Max subscriptions after Anthropic's April 4, 2026 third-party policy?**
Yes - by design. The policy restricts subscription OAuth to official clients; VULYK lives entirely inside the official client. (Independent of policy: parallel agents consume limits faster - the cascade exists to make that affordable.)

**Which model plans, which builds?**
Since v0.20.0 (ADR-015) the cut is by kind of work. Opus plans, orchestrates and judges on every
plan. Sonnet builds: the workers, the scout and the docs drone; the clerk runs on Haiku 5.5. The family that builds
never judges. Fable is kept for the **gate**: the Tier 4 review, `lead-architect`, the Tier 4
planner and a missed story's retry. `lead-review` below Tier 4 runs on Opus. The gate goes to
whichever model your plan carries inside its limits. `scripts/top-model.sh` reads the account profile Claude Code caches in `~/.claude.json`: Max 5x / 20x and premium seats get `fable` (up to half the weekly limit is Fable at no extra cost); Pro, standard seats and API keys get `opus` (Fable would bill to usage credits on top of the subscription). The SessionStart brief announces it; `/vulyk-plan`, `/vulyk-build`, `/vulyk-review` and the Workflow driver pass it as the dispatch `model:` on exactly those calls. Details and the rejected alternatives in [model-cascade.md](model-cascade.md).

**I want Fable on Pro anyway / Opus on Max anyway.**
Replace `auto` in the `TOP_MODEL = auto` line of CLAUDE.md with the alias you want; the pin beats the plan. `VULYK_TOP_MODEL=<alias>` does the same for one shell. The cascade is model-agnostic everywhere else.

**The brief says a model is below the floor.**
VULYK routes by family alias (`opus`, `sonnet`), and an alias brings the newest model on the Anthropic API. It does not on every provider: on Bedrock, Google Cloud and Foundry `sonnet` still resolves to 4.5, and six env vars can remap any alias. Nor on every Claude Code: the alias table ships inside it, and before 2.1.293 `haiku` still ran Haiku 4.5 (fix: `claude update`). The floor (`fable 5.1 · opus 5.5 · sonnet 5.5 · haiku 5.5`, in `scripts/lib.sh`) catches that. `bash scripts/top-model.sh --floor` names the pin or provider responsible; set the family's `ANTHROPIC_DEFAULT_*_MODEL` to your provider's ID for the newest model. To run lower on purpose, set `VULYK_MODEL_FLOOR`. Details in [model-cascade.md](model-cascade.md#the-model-floor).

**The brief says my session is "not pinned".**
The Queen's own session starts on the account default (Opus 5.5 since Claude Code 2.1.280) unless something pins it. `bash scripts/top-model.sh --apply` writes `"model": "opus"` into the gitignored `.claude/settings.local.json` and the next launch starts there; `/model <alias>` on the first turn does it for the current session, free, because the cache is still cold.

**Why can't my lead-build agent spawn workers?**
Claude Code subagents cannot use the Task tool - a platform constraint. VULYK's answer: fan-out lives in the main session's commands and in the Workflow driver; subagents stay single-purpose. See [architecture.md](architecture.md).

**Why does the Queen build Tier 1-2 herself? Law 5 used to forbid it.**
Since v0.18.0 (ADR-013) Law 5 binds from Tier 3. The token audit found three near-equal thirds of spend - the Queen, the workers, the review machinery - and Anthropic's current guidance calls separate plan/build/review agents for a small task over-verification. Below Tier 3 one session builds, `close-story` runs the verification once, and one fresh-context `lead-review` judges each round. Workers in waves remain for cross-cutting work, where parallelism earns them.

**Do I need Agent Teams?**
No. Subagent fan-out covers Tiers 0-3 well. Teams (experimental env flag) add peer coordination for collaborative Tier 3-4 work - debugging with competing hypotheses, cross-layer features.

**How is this different from BMAD / Ruflo / Gas Town?**
BMAD is a spec-driven methodology (VULYK borrows the stories-as-truth idea, with a lighter ceremony and a model cascade). Ruflo is a swarm platform with its own runtime (powerful, but parts of it require API billing post-April-4). Gas Town orchestrates 20-30 full Claude Code processes (brilliant, expensive, built for a different scale of operator). VULYK is the subscription-safe, native-only middle: cascade + memory + evolution with zero runtime.

**Can I use a vector / semantic-search MCP with it?**
Yes - pairs well for million-line monorepos. VULYK's file-based map stays the source of truth; semantic search becomes another scout tool.

**A worker keeps failing the same way.**
That is a wall, and walls are information: after three failed `close-story` reruns the worker writes `## Findings` and returns `WALL`; the driver retries the story once on the gate model, and a second miss stops the run so the Queen can re-scope or consult `lead-architect`. If the same wall recurs across specs, `/vulyk-evolve` will surface it as a friction pattern.

**How much did that spec cost?**
`python scripts/token-report.py . --spec <slug>`: raw and weighted tokens, dispatches by agent type, rounds. Not the `totalTokens` a Workflow run prints - that is the sum of each agent's final context, about 29 times less than what the median task actually processed.

**My CLAUDE.md is growing.**
It should not: it rides every agent that loads it, on every turn. Push path-specific content to `.claude/rules/`, domain knowledge to `docs/wiki/`, and let `/vulyk-evolve`'s deletion bias prune the rest. VULYK's own constitution is about 7 KB; an upgraded hive gets it with `install.sh --upgrade --constitution replace`.
