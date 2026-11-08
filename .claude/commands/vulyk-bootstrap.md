---
description: Adapt VULYK to this project - facts from the repo, questions only on a gap, tailor constitution, seed wiki
argument-hint: [--quick to ask nothing and list the gaps]
---

You are initializing VULYK for this repository. Follow `bootstrap/interview.md`. The constitution is
`CLAUDE.vulyk.md` if it exists, else `CLAUDE.md`. Nobody has to know this command: while the Profile
still holds a `<fill in` row, the SessionStart brief tells the Queen to offer it once, before the first
task. A no is recorded as the Profile row `| Bootstrap | declined <date> |`, which silences the offer.

1. Facts first. Read the repo before asking anything: manifests and lockfiles, CI config, compose files
   and Dockerfiles, the README. Fill each interview question from those facts. Ask the owner only where
   no fact answers a question, or two facts disagree (a README naming one test runner, a lockfile or
   CI another); name both sources in that question. Ask the open ones in one batch per interview
   section. With `--quick` in "$ARGUMENTS", ask nothing: a gap takes the script's default and is listed
   in the summary.
2. Tailor the constitution.
   - Profile: fill the rows between the `VULYK:PROFILE` markers from what you verified in step 1, never
     from what a README claims; a profile copied from another repository is a confident lie. The row
     that pays for itself is *Configurations that exist today*, with what is deferred and until when: a
     reviewer that does not know it demands guarantees for deployments nobody has. *Client path* is how
     a person reaches the running thing (a URL and a test login, a CLI entry point, a browser runner's
     quiet command), or `none: library only`; a filled row adds the black-box seat at Tier 3-4.
     *Release / deploy* names the default branch, how a version is published and who presses the
     button; `/vulyk-ship` prints it and never presses it. *Owner language* is the one reports and
     questions to the owner come in (`--quick`: the language the owner writes in), `en` when unsure.
   - Top model: run `bash scripts/top-model.sh --explain`, show the owner what the plan resolved to and
     why, and leave `TOP_MODEL = auto` unless question 15 asked for a deliberate pin (then write the
     alias in its place). Then run `bash scripts/top-model.sh --apply` whatever the answer: it pins the
     Queen's own session in the gitignored `.claude/settings.local.json`, so the session runs on the
     model the ladder assumes rather than the account default.
   - Telemetry: do not ask; the installer leaves it off unless told otherwise. Print
     `bash scripts/telemetry.sh consent` in the summary with the one line that changes it
     (`install.sh --telemetry ask`, or edit the `| Telemetry |` row).
   - Commands: replace every row between the `VULYK:COMMANDS` markers, and the warning blockquote above
     the table; the shipped rows are VULYK's own and wrong for any other project. Use this project's
     real commands in their quiet form (`--reporter=dot`, `-q`, `--silent`), because their output is
     resent on every later turn. In a docker stack (a compose file whose services run the code), write
     each row as `docker compose exec -u <user> <service> <cmd>`, with `<user>` read from the repo: the
     service's compose `user:`, else the Dockerfile's last `USER`; with neither, that is a gap to ask
     about. Run each one; where the project lacks one (no build step, no test runner), write that
     instead of a plausible command, since a verification that always exits 0 is worse than an
     admitted gap. Per-story rows run in a minute or two. Name the full suite in its own
     row with `(round-only)` in its Purpose cell: the reviewer runs it once per round and no story names
     it. A suite that runs longer gets a part switch (`--part <topic>` or the runner's equivalent), and
     each story names the part covering its `## Files`.
   - Court setup: question 7's install step goes verbatim into `.claude/vulyk-setup` (a bash script; it
     runs with the court as its working directory and `VULYK_ROOT`, `VULYK_COURT` set, capped at 300 s).
     Run it once in a scratch checkout before committing it. "None" writes no file. The installer never
     ships or touches this file (`docs/cycle.md`, stage 05).
   - Conventions tied to paths go into `.claude/rules/<area>.md` with a `paths:` frontmatter list (shape:
     `templates/rule-example.md`), not into the constitution, which every agent that loads it pays for
     on every turn.
3. Prune the roster. Delete agents that cannot apply here (for example `worker-test` without a test
   runner, and say so in the summary) and adjust tool lists to the stack. The council seats are the
   ones whose removal is never silent: if this project cannot be run and observed at all (no *Client
   path*, no run command), write that sentence into the summary. Leave *Browser MCP* at `none` unless a
   browser-reachable Client path exists and the owner wants the black-box seat driving it on a separate
   test profile.
4. List the modules, map none. Name the top-level modules in `memory/memory.md` as unmapped territory.
   Bootstrap dispatches no scout: `/vulyk-plan` recon maps what a task touches, and `/vulyk-map` maps
   an area on request.
5. Seed memory. Write the `memory/memory.md` pointer index (at most 60 lines): wiki notes to create,
   verification commands, unmapped territory.
6. Seed the wiki: 2-4 `docs/wiki/` notes for the most load-bearing domains or invariants found while
   reading the repo (`templates/wiki-note.md`).
7. Commit everything as `vulyk: initialize hive for <project>` and print a summary: tier examples for
   this codebase, the plan-build-ship loop, any pruned agents, and the gaps `--quick` defaulted.

Bootstrap ends with the commit and the summary; no feature work. The summary does not suggest
`/vulyk-handoff` or `/clear`: the owner's next step is their first task.
