---
description: Adapt VULYK to this project - interview, tailor constitution, build initial map, seed wiki
argument-hint: [--quick to accept defaults]
---

You are initializing VULYK for this repository. Follow `bootstrap/interview.md` exactly:

1. **Interview.** Ask the questions in the script in 3 batches (context -> conventions -> posture). With `--quick` in "$ARGUMENTS", infer answers from the repo (package files, CI config, lockfiles, README) and present them for one-shot confirmation instead.
2. **Tailor the constitution.** Append a `## Project profile` section to `CLAUDE.md` (stack, no-go zones, budget posture). Set `TOP_MODEL` per the budget answer. Fill the `## Commands` table with this project's real commands **in their quiet form** — find the flag that suppresses per-test/per-file chatter (`--reporter=dot`, `-q`, `--silent`, `--quiet`) rather than pasting the README's default invocation; that output is resent on every later turn. Write path-scoped conventions into `.claude/rules/<area>.md` instead of bloating CLAUDE.md.
3. **Prune the roster.** Delete agents that cannot apply here (e.g. `worker-test` if the project has no test runner - and say so loudly), adjust tools lists to the stack.
4. **Build the map.** Identify top-level modules. Dispatch `drone-scout` per module - batch up to 4 in parallel - and save each report as `memory/map/<module>.md` with a `last-verified` date. For very large repos (1000+ files), map breadth-first: top 8-12 load-bearing modules now, note the rest in `memory/memory.md` as unmapped territory.
5. **Seed memory.** Write `memory/memory.md` pointer index (<= 60 lines): map files, key wiki notes to create, verification commands, unmapped territory.
6. **Seed wiki.** Create 2-4 `docs/wiki/` notes for the most load-bearing domains/invariants discovered during mapping (use `templates/wiki-note.md`).
7. **Commit** everything as `vulyk: initialize hive for <project>` and print a summary: tier examples for THIS codebase, the three-command loop, and any pruned agents.

Do not start any feature work. Bootstrap ends with the commit and summary.
