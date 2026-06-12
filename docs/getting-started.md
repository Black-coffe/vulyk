# Getting started

## Prerequisites
- Claude Code 2.x signed in (Pro, Max, Team, or API). VULYK uses native primitives only, so subscription plans are fully supported.
- `git`. Optional but recommended: `jq` (enables the skill-usage counter hook).

## Install

**New project:** click *Use this template* on GitHub, clone, done.

**Existing project:**
```bash
git clone https://github.com/Black-coffe/vulyk /tmp/vulyk
/tmp/vulyk/install.sh /path/to/your/project
```
The installer copies `.claude/`, `memory/`, `docs/wiki/`, `templates/`, `bootstrap/`, and the constitution. It never overwrites an existing `CLAUDE.md` - it writes `CLAUDE.vulyk.md` and prints the one-line import to add.

## First session
```bash
cd your-project
claude
> /vulyk-bootstrap        # ~10 minutes: interview -> tailored config -> initial map -> wiki seed
```
For large repos the initial mapping runs on Haiku drones in batches - cheap by design. A 1000-file repo maps breadth-first: the 8-12 load-bearing modules now, the rest recorded as unmapped territory.

## The working loop
```text
/vulyk-plan "add CSV export to the reports module"
  -> tier announced, scouts dispatched, stories written, approval requested
/vulyk-build
  -> workers implement stories on Sonnet, parallel where independent
/vulyk-review
  -> adversarial Opus gate; BLOCK findings loop back as fix stories
```
Weekly: `/vulyk-evolve` (config improvements from your own sessions) and `/vulyk-gc` (memory hygiene).
Anytime: `/vulyk-status` for the dashboard, `/vulyk-map <path>` after big merges.

## Recommended extras
```bash
# Agent Teams (experimental) for collaborative Tier 3-4 work:
echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> ~/.claude/.env
# Auto-distilled session learnings (spends a few Haiku tokens per session):
echo "VULYK_AUTOLEARN=1" >> ~/.claude/.env
# Map staleness flag after merges:
cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge
```
