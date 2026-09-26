---
story: <slug>-NN
spec: <slug>
status: todo            # todo | done | blocked - close-story writes done, a driver writes blocked
returned:              # written by whoever builds the story, as its last edit: DONE | NEEDS_CONTEXT | WALL
tier: 1                 # the spec's routing tier
worker: worker-code     # worker-code | worker-test - the agent a Tier 3-4 wave dispatches
model: opus             # the worker's model; the driver reads it, and a second attempt runs on the gate model
wave: 1                 # dispatch group: at Tier 3-4 one wave's workers run concurrently in one tree.
                        # Stories in one wave must declare disjoint `## Files` - wave-check.sh reports overlaps.
blocked_by: []          # story ids that must be `done` first, e.g. [<slug>-01]. A story's wave
                        # must be strictly later than the wave of every story it names here.
---

<!--
Size budget: keep this file under ~1500 tokens (~6 KB). A story that does not fit is an epic in
disguise - split it. The budget forces the planner to decide what matters instead of pasting
everything it read. The `## Requirements` quotes are exempt: verbatim owner words are never trimmed.
-->

# <Story title>

## Goal
<one paragraph - what exists after this story that does not exist now>

## Requirements
<!--
Tier 2+ only; Tier 1 stories skip this section. Verbatim quotes from the spec's brief.md - the
owner's words, not a paraphrase - one `> ` blockquote line per fragment. Quote the shortest fragment
that justifies this story; a story that cannot quote any requirement is speculative (cut it, or raise
it as an assumption at the approval stop). `scripts/trace-check.sh` matches these lines against
brief.md, its `## Asks` items, and plan.md's `## Plan deltas`, whitespace-normalized - do not fix the
owner's grammar inside a quote.
-->
> <verbatim fragment from brief.md>

## Files
<!--
Machine-readable: one repo-relative path or glob per line, prefixed with "- ", no prose.
`scripts/scope-check.sh` parses this block against the diff, `close-story` commits exactly these
paths, and it is the Law 3 boundary: nothing else is touched. It is also the collision key for waves:
two stories in the same wave must not share a path.
-->
- path/to/file.ext

## Non-goals
<!--
What a capable builder will be tempted to do here and must not. Models expand scope when the task
looks small next to their capability; an explicit stop-list is cheaper than a review round. Write what
this story invites ("do not also migrate the old callers"), not generic prohibitions.
-->
- <...>

## Map slice
<memory/map/<module>.md sections the builder should load - sections, not whole files>

## Acceptance criteria
- [ ] <observable behavior, not implementation detail>
- [ ] <...>

## Verification
<!--
One command per line, each `&&` segment a literal cell of the constitution's `## Commands` table
(`wave-check.sh` reports one that is not) - in its quiet form, because output under 30 000
characters is pasted into the builder's context and resent every turn. `close-story` runs these
lines, once, on the record; the builder runs only targeted checks while working.

The command must be able to fail for this story: its scope has to reach the paths under `## Files`.
`wave-check.sh` reports the obvious gap, but not an ignore file (`.prettierignore`,
`testPathIgnorePatterns`, a lint excludes list) that removes exactly these files - check that here.

Optional `repeat: N` on its own line when the surface is known to be flaky: `close-story` runs the
block N times and all N must pass. Derive N from the measured rate, never from habit - five runs catch
a 1-in-5 flake about two times in three. If you do not know the rate, say so in
`## Acceptance criteria` instead of inventing a count.
-->
`<exact command that proves the criteria>`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->

## Findings
<!-- a repair story arrives with the round's findings here, verbatim - each is a condition to satisfy.
     The builder appends here only on a wall or a question: what was tried, best hypothesis. -->
