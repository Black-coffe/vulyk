# The model cascade

## Principle
Match each unit of work to the cheapest model that does it well, and spend top-model tokens only where they change everything downstream: **planning** (a wrong structure poisons every story) and **final review** (a missed defect costs more than the reviewer). This is the "bookend" pattern. Community benchmarks of bookend-style routing consistently report near-parity output quality with the all-Opus baseline at a fraction of the cost - implementation simply does not need frontier reasoning most of the time, and recon almost never does.

## Where the cascade is enforced
1. **Agent frontmatter** - every `.claude/agents/*.md` declares `model:` (alias or full ID). Committed to the repo: routing by configuration, not willpower.
2. **The routing matrix** in `CLAUDE.md` - tier decided before work starts, announced, and the tier dictates which castes are deployed at all.
3. **`TOP_MODEL`** - a single line in `CLAUDE.md` for what the Queen herself runs on for Tier 3-4 planning. Everything else is model-agnostic.

## Choosing TOP_MODEL (June 2026 snapshot)
- `claude-fable-5`: strongest planner; included in paid plans only during its launch window (through June 22, 2026), then drawn from usage credits at ~2x Opus rates. Use it for Tier 3-4 while it is free on your plan.
- `claude-opus-4-8`: the durable default after the window; excellent orchestration-class model.
- Re-evaluate when Anthropic ships new tiers - the change is one line.

## Effort, turns, and budget posture
- `maxTurns` caps in agent frontmatter stop runaway loops (tests especially).
- Budget posture from bootstrap (FRUGAL / BALANCED / THROUGHPUT) caps parallel workers in `/vulyk-build`.
- The weekly limit, not the 5-hour window, is the binding constraint for heavy users in 2026 - the cascade's whole purpose is to keep 70-80% of session volume on Sonnet and recon on Haiku so the weekly cap buys more shipped work.

## Anti-patterns the cascade exists to kill
- Opus reading 40 files to "understand the project" (that is a scout's job, at ~15x lower cost).
- Re-dispatching a failed worker with the identical prompt (walls are information; route them).
- Running the gate on the same model that wrote the code without adversarial framing.
