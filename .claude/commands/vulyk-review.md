---
description: Adversarial review gate - lead-review hunts for reasons NOT to merge
argument-hint: [spec slug, branch, or file scope; defaults to working tree changes]
---

Run the merge gate on: "$ARGUMENTS" (default: current working tree changes against the base branch).

1. Assemble the review packet: the diff, the story/plan files it implements, and pointers to `docs/wiki/` notes + ADRs for the touched modules.
2. Dispatch `lead-review` with the packet. For Tier 4 changes, dispatch a SECOND `lead-review` with the explicit instruction to attack the first reviewer's likely blind spots (concurrency, security, data migration safety) - adversarial pairs catch what single passes miss.
3. On `BLOCK`: convert each critical finding into a fix story in the same spec directory and route back through `/vulyk-build`. Do not hand-patch criticals in the main session - fixes stay in the cascade.
4. On `PASS`: present the verdict and the optional nits. After merge, dispatch `drone-docs` with the diff to refresh map and wiki, and remind about `scripts/git-hooks/post-merge` staleness flags.

The gate's verdict is advice to the human, not authority over them - but overriding a BLOCK should be a conscious, stated decision.
