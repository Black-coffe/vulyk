---
name: skill-gardener
description: Audits the skill and rule garden using usage counters - flags dead skills for retirement and recurring manual patterns for promotion into new skills. Used by /vulyk-evolve. Trigger when asked to audit skills, find unused skills, or propose new ones.
---

# Skill Gardener

Skills are living things: they are born from repetition, earn their place through use, and retire when the season changes.

## Inputs
- `memory/stats/skills.json` (per-skill invocation counters, maintained by the skill-usage-counter hook)
- `.claude/skills/` inventory and `.claude/rules/` inventory
- `memory/learnings/CONSOLIDATED.md` for repetition signals

## Method
1. **Retirement review.** Zero invocations for 3+ weeks -> archive candidate. EXCEPTION: severity-justified skills (incident response, security checklists) stay regardless of frequency - mark them `keep: severity` so they are not re-flagged every cycle.
2. **Promotion review.** A pattern executed manually 3+ times (from learnings) -> draft a new skill: name, trigger description, method skeleton. The draft goes in the changeset for human review, never silently installed.
3. **Hygiene.** Flag skills whose description no longer matches their body, overlapping skills that should merge, and skills above ~150 lines (split or tighten).
4. **Retire with dignity.** Archive = move to `.claude/skills/_graveyard/<name>/` + add `RETIRED.md` (date, reason, evidence, how to resurrect). History is never deleted.

## Output
Three lists with evidence: retire | promote | repair. Each entry one line + links.
