---
description: Adversarial review gate - lead-review hunts for reasons NOT to merge
argument-hint: [spec slug, branch, or file scope; defaults to working tree changes]
---

Run the merge gate on: "$ARGUMENTS" (default: current working tree changes against the base branch).

1. **Run the scope gate first - it costs nothing and it decides what to look at.** For each story in scope: `bash scripts/scope-check.sh <story-file>`. It compares the story's `## Files` block against the real diff and appends the numbers to `memory/stats/scope.jsonl`. Files it flags go into the review packet as the first thing `lead-review` reads: an out-of-scope file is either a story that was written wrong or a worker that went wide, and knowing which is worth more than any single bug found later. Report the two numbers to the human alongside the verdict.
2. Assemble the review packet: the diff, the story/plan files it implements, and pointers to `docs/wiki/` notes + ADRs for the touched modules.
3. Dispatch `lead-review` with the packet. For Tier 4 changes, dispatch a SECOND reviewer instructed to attack the first one's likely blind spots (concurrency, security, data migration safety). Make it a **different model** - two copies of one model are blind in the same places, and adversarial framing does not fix that. `claude-fable-5` is the intended pairing; see `docs/model-cascade.md` for the cost and data-retention tradeoff before enabling it.
4. On `BLOCK`: convert every finding worth acting on - not only the criticals - into a fix story in the same spec directory and route back through `/vulyk-build`. Do not hand-patch findings in the main session, whatever their size: fixes stay in the cascade (Law 5), each in its own story with its own commit.
5. On `PASS`: present the verdict and the full finding list - `lead-review` reports everything and ranks it; deciding what to act on is your job, not its. After merge, dispatch `drone-docs` with the diff to refresh map and wiki, and remind about `scripts/git-hooks/post-merge` staleness flags.

The gate's verdict is advice to the human, not authority over them - but overriding a BLOCK should be a conscious, stated decision.
