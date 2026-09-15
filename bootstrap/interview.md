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
8. Branch & commit discipline? (conventional commits, default branch, who merges; `/vulyk-build` puts every spec on `vulyk/<slug>` unless you name another scheme)
9. How does a person reach the running thing? (URL + a test login, a CLI entry point, a browser runner such as Playwright - its quiet command goes in the Profile's *Client path* row; "none: library only" is an answer)
10. Should the council's black-box seat drive a real browser for the *Client path*? `chrome-devtools` / `claude-in-chrome` / `none` - goes in the *Browser MCP* row, because only that one seat needs a live browser to prove the Client path from outside, not read about it; `none` is recommended unless a separate, signed-out test profile already exists for it (read-only, never a personal account)
11. How does a version get published, and who presses the button? (tag + push, `npm publish`, CI on merge, a deploy script - goes in the *Release / deploy* row; `/vulyk-ship` prints it and never presses it)

> Not a question - report it: telemetry is `off` unless the installer was told otherwise. Show the current value (`bash scripts/telemetry.sh consent`, from the `| Telemetry |` Profile row) and say it changes with `install.sh --telemetry ask` or by editing that row; `docs/telemetry.md` says what a bundle holds.

## Batch 3 - Posture
12. Token budget posture: FRUGAL (cap 2 parallel workers, Tier 2 max by default) / BALANCED (cap 4) / THROUGHPUT (cap 4+, Teams allowed)?
13. Top model policy: `scripts/top-model.sh --explain` has already read the plan - Fable 5.1 where the subscription carries it inside its limits (Max, premium seats), Opus 5 where it would bill to credits (Pro, standard seats, API). Confirm, or pin deliberately (sets TOP_MODEL; `auto` is the default and the right answer for almost everyone).
14. Risk tolerance: may agents commit to feature branches themselves, or stage-only?
15. Test reality: is there a runner worth keeping worker-test for? (If no - prune it and say so.)
16. Anything the previous AI setup kept getting wrong here? (seed for memory/learnings/)

## After the interview
Apply answers exactly as specified in /vulyk-bootstrap steps 2-7. Quote each answer back in the
`## Project profile` section so the human can spot a misheard answer immediately.
