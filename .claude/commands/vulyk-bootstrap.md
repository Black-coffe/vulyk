---
description: Adapt VULYK to this project - interview, tailor constitution, build initial map, seed wiki
argument-hint: [--quick to accept defaults]
---

You are initializing VULYK for this repository. Follow `bootstrap/interview.md`. The constitution is
`CLAUDE.vulyk.md` if it exists, else `CLAUDE.md`.

1. Interview. Ask the script's questions in three batches (context, conventions, posture). With
   `--quick` in "$ARGUMENTS", infer the answers from the repo (package files, CI config, lockfiles,
   README) and present them for one confirmation instead.
2. Tailor the constitution.
   - Profile: fill the rows between the `VULYK:PROFILE` markers from what you verified in step 1, never
     from what a README claims; a profile copied from another repository is a confident lie. The row
     that pays for itself is *Configurations that exist today*, with what is deferred and until when: a
     reviewer that does not know it demands guarantees for deployments nobody has. *Client path* is how
     a person reaches the running thing (a URL and a test login, a CLI entry point, a browser runner's
     quiet command), or `none: library only`; a filled row adds the black-box seat at Tier 3-4.
     *Release / deploy* names the default branch, how a version is published and who presses the
     button; `/vulyk-ship` prints it and never presses it.
   - Top model: run `bash scripts/top-model.sh --explain`, show the owner what the plan resolved to and
     why, and leave `TOP_MODEL = auto` unless question 13 asked for a deliberate pin (then write the
     alias in its place). Then run `bash scripts/top-model.sh --apply` whatever the answer: it pins the
     Queen's own session in the gitignored `.claude/settings.local.json`, so the session runs on the
     model the ladder assumes rather than the account default.
   - Telemetry: do not ask; the installer did. Print `bash scripts/telemetry.sh consent` in the summary
     with the one line that changes it (`install.sh --telemetry ask`, or edit the `| Telemetry |` row).
   - Commands: replace every row between the `VULYK:COMMANDS` markers, and the warning blockquote above
     the table; the shipped rows are VULYK's own and wrong for any other project. Use this project's
     real commands in their quiet form (`--reporter=dot`, `-q`, `--silent`), because their output is
     resent on every later turn. Run each one; where the project lacks one (no build step, no test
     runner), write that instead of a plausible command, since a verification that always exits 0 is
     worse than an admitted gap. Name the full suite in its own row: the reviewer runs it once per
     round.
   - Conventions tied to paths go into `.claude/rules/<area>.md` with a `paths:` frontmatter list, not
     into the constitution, which every agent that loads it pays for on every turn.
3. Prune the roster. Delete agents that cannot apply here (for example `worker-test` without a test
   runner, and say so in the summary) and adjust tool lists to the stack. The council seats are the
   ones whose removal is never silent: if this project cannot be run and observed at all (no *Client
   path*, no run command), write that sentence into the summary. Leave *Browser MCP* at `none` unless a
   browser-reachable Client path exists and the owner wants the black-box seat driving it on a separate
   test profile.
4. Build the map. Identify the top-level modules and dispatch `drone-scout` per module, up to four in
   parallel; save each report as `memory/map/<module>.md` with a `last-verified` date, under ~80 lines.
   For 1000+ files, map breadth-first: the 8-12 most load-bearing modules now, the rest listed in
   `memory/memory.md` as unmapped.
5. Seed memory. Write the `memory/memory.md` pointer index (at most 60 lines): map files, wiki notes to
   create, verification commands, unmapped territory.
6. Seed the wiki: 2-4 `docs/wiki/` notes for the most load-bearing domains or invariants found while
   mapping (`templates/wiki-note.md`).
7. Commit everything as `vulyk: initialize hive for <project>` and print a summary: tier examples for
   this codebase, the plan-build-ship loop, and any pruned agents.

Bootstrap ends with the commit and the summary; no feature work.
