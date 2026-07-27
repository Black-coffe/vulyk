# Learnings — 2026-07-27 — Opus 5 migration

Two lessons from planning v0.2.0. Both were expensive to learn; neither is obvious from docs.

## 1. `effort` is session-level in Claude Code, not per-agent

**What looked true.** The Claude Code binary (2.1.220) contains a zod schema for
"Definition for a custom subagent" that includes
`effort: enum["low","medium","high","xhigh","max"] | int`, sitting next to `model`, `tools`,
`maxTurns`, `memory`, `permissionMode`. It reads as proof that a caste can carry its own effort.

**What is actually true.** That schema governs the subagent-definition *object* — the one passed
via `--agents <json>` and the SDK. The markdown frontmatter parser for `.claude/agents/*.md` does
not honour it. `effort: banana` in frontmatter raises no error and no warning; the session runs
normally. `model:` from the same frontmatter *is* applied (init reports `claude-opus-5`), which is
what makes the silent drop so easy to miss.

**How it was measured** (identical hard reasoning prompt, Opus 5, output tokens):

| Where effort was set | low | max | verdict |
|---|---|---|---|
| `--effort` flag (control) | 1 371 | 7 434 | 5.4× spread, correct direction — works |
| agent md frontmatter | 8 819 | 4 541 | inverted — pure run variance, no control |

**How to apply.** Set effort per work session, not per caste: `/effort <level>`, `--effort` at
launch, or `effortLevel` in `.claude/settings.json`. Subagents inherit the session level. Do not
put `effort:` in agent frontmatter — it looks configured and does nothing, which is worse than
leaving it out. Re-test after Claude Code upgrades; this is a parser gap, not a design decision,
and it may close.

**Generalisation worth keeping.** A schema found inside a binary proves a field exists *somewhere*
in the product. It does not prove the code path you intend to use reads it. Behavioural probe, or
it did not happen.

## 2. Do not import "simplify the scaffolding" advice without checking your scaffolding is mature

**What was nearly done.** The Opus 5 launch coverage carried a striking finding: at Every, mature
skills and mega-prompts tuned for Opus 4.8 performed *worse* under Opus 5, and the fix was
simplifying the scaffolding rather than lengthening prompts. VULYK is scaffolding, Opus 5 shipped,
so the planned v0.2.0 was a breaking subtraction — roughly a third of the agents, a quarter of the
commands, half the hooks, and the whole learnings layer.

**Why that was wrong.** Every's finding is about *tuned* systems: theirs had months of production
iteration behind it. VULYK at that point had one commit, agents of 16–29 lines, zero real runs,
and a `/vulyk-evolve` that had never once been executed. There was no accumulated tuning to undo.
The analogy carried the conclusion, and nobody checked whether the premise transferred.

Three further defects fell out of the same review:
- The proposed scope metric had **no event to fire on** — `/vulyk-build` neither commits nor
  merges, and the post-merge hook slot was already occupied by the map-staleness flag.
- The blast radius was **112 references across 38 files**, not the "eight documentation files"
  the plan assumed — including `install.sh`, the bootstrap interview, and three SVG assets.
- Removing `memory/learnings/` in favour of native `agent-memory` would have left the **Queen with
  no memory at all**: native memory is keyed by `agentType`, and the main session is not an agent.

**How to apply.** Before importing a fix for a problem someone else had, verify you have their
problem. For a framework specifically: a plan that deletes should state how many references the
deletions touch, and which event the replacement mechanism fires on. Both are one grep away, and
both were skipped.

**The sharpest version of it.** The same plan postponed `/vulyk-evolve` on the grounds that
changing configuration without feedback data is unsound — while itself making the largest
configuration change in the project's history without a single measurement. When your own stated
principle contradicts your plan, the plan is what is wrong.
