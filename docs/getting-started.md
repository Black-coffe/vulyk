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

One thing it deliberately does *not* copy verbatim: the `## Commands` table. Those rows are VULYK's own verification commands, and a wrong command that still exits 0 reads as a passing check. The installer blanks the table back to placeholders for `/vulyk-bootstrap` to fill, and says so in its output - or warns loudly if it cannot find the markers it anchors to.

## First session
```bash
cd your-project
claude
> /vulyk-bootstrap        # ~10 minutes: interview -> tailored config -> initial map -> wiki seed
```
The first line of every session is the `[VULYK] top model:` brief: which model plans on this account - Fable 5.1 where the plan carries it (Max, premium seats), Opus 5 where it would bill to credits (Pro, standard seats) - and whether your own session is pinned to it. `bash scripts/top-model.sh --apply` pins it; bootstrap does that for you.

For large repos the initial mapping runs on Sonnet drones in batches - cheap by design. A 1000-file repo maps breadth-first: the 8-12 load-bearing modules now, the rest recorded as unmapped territory.

## Context hygiene (once, then rarely)

Run `/context` in a fresh session before typing anything: that is what every turn of every session
re-sends. Switch off MCP servers this project never calls (`/mcp`) — their tool definitions are pure
overhead — and keep `CLAUDE.md` to standing instructions, pushing anything workflow-specific into
`.claude/rules/` or a skill. Set `/model` and `/effort` at the start of a session rather than
mid-flight: both are part of the prompt-cache key, and changing them re-prefills the whole
conversation. The reasoning is in [token-economy.md](token-economy.md).

## The working loop
```text
/vulyk-plan "add CSV export to the reports module"
  -> tier announced, scouts dispatched, the grill asks 3-7 questions one at a time (recommended
     option first and labelled, a free-text Other, silence always safe), stories cut into waves,
     wave-check + trace-check, blind coverage check at Tier 3-4 (brief + plan, never the stories) -
     then the plan is shown to you and waits for one word; `--go` builds straight through, and
     `--study` (or any request whose answer is a document) ends at report.md with no build at all
/vulyk-build
  -> launches the driver (a Workflow run where available, this session's own loop otherwise):
     wave by wave, parallel Sonnet workers on disjoint files, one commit per story, then the
     council round opens on its own
  -> the terminal shows one journal line per step; you next see it wake on green or on an escalation
/vulyk-review
  -> the same council round, run again on demand: `lead-review` at the top model plus the tier's
     blind seats (sonnet suite-then-each-ask; opus intent and edge cases at Tier 3+; the black-box
     client-path seat at Tier 4), judged by `cycle.sh` from labelled evidence - never by a person's look
/vulyk-ship
  -> ship-check (all six confirmations, free) -> version + CHANGELOG -> local merge ->
     `/vulyk-ship` prints the publish command under "to publish, run:" and stops there - you press
     it whenever you choose -> recorded
  -> map/wiki refresh, ADR harvest, and the circle's leftovers handed over as the next brief's draft
```
The shape behind the commands is [the cycle](cycle.md): spec, plan, code, tests+human, ship - each
stage closed by a file on disk. `/vulyk-pause <slug>` hands the working tree back to you at any
point the loop is running, and `/vulyk-resume <slug>` relaunches it fresh once you are done. The
grill and the plan approval are the two human stops at the start; an owner who wants the build to
start the moment the plan is written says so on the grill's fixed last question or passes `--go`.
Weekly: `/vulyk-evolve` (config improvements from your own sessions) and `/vulyk-gc` (memory hygiene).
Anytime: `/vulyk-status` for the dashboard, `/vulyk-map <path>` after big merges.

## Recommended extras
```bash
# Agent Teams (experimental) for collaborative Tier 3-4 work:
echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> ~/.claude/.env
# Auto-distilled session learnings (one short junior-rung call per session):
echo "VULYK_AUTOLEARN=1" >> ~/.claude/.env
# Map staleness flag after merges:
cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge
```
