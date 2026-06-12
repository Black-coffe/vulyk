# Bootstrap interview script

Ask in three batches. Keep it brisk - infer what the repo already answers and confirm instead of asking cold.

## Batch 1 - Context
1. What does this project do, in one sentence?
2. Stack and versions? (language, framework, package manager - confirm what manifests show)
3. Approximate size? (files / LOC / age) - affects mapping strategy
4. Solo or team? Any conventions imposed from outside (org style guides, CI gates)?

## Batch 2 - Conventions & safety
5. Exact verification commands: build, test, lint, typecheck. (These go into memory/memory.md verbatim.)
6. Code conventions worth enforcing as rules? (error handling shape, naming, layering)
7. No-go zones: paths agents must never touch (generated code, vendored deps, migrations history)?
8. Branch & commit discipline? (conventional commits, branch naming, who merges)

## Batch 3 - Posture
9. Token budget posture: FRUGAL (cap 2 parallel workers, Tier 2 max by default) / BALANCED (cap 4) / THROUGHPUT (cap 4+, Teams allowed)?
10. Top model policy: which model is economical for Tier 3-4 planning right now? (sets TOP_MODEL)
11. Risk tolerance: may agents commit to feature branches themselves, or stage-only?
12. Test reality: is there a runner worth keeping worker-test for? (If no - prune it and say so.)
13. Anything the previous AI setup kept getting wrong here? (seed for memory/learnings/)

## After the interview
Apply answers exactly as specified in /vulyk-bootstrap steps 2-7. Quote each answer back in the
`## Project profile` section so the human can spot a misheard answer immediately.
