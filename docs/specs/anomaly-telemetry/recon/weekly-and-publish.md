# Scout report: weekly evolve + publish/telemetry surfaces (anomaly-telemetry spec)

Scout: drone-scout `scout-weekly`, 2026-09-14. Persisted by the Queen (the scout has no Write tool).

## Purpose
Recon of how `/vulyk-evolve`, `/vulyk-gc`, `/vulyk-status`, `/vulyk-ship`, `scripts/vulyk-update.sh` and `cycle.sh`'s stat-recording currently work, to ground a design for weekly anomaly telemetry without inventing new instrumentation.

## Entry points
- `.claude/commands/vulyk-evolve.md:1-46` - the whole `/vulyk-evolve` command, 5 steps, no code.
- `.claude/commands/vulyk-gc.md:1-11` - dispatches `librarian` for GC; no owning script.
- `.claude/commands/vulyk-status.md:1-37` - dashboard command, step 2 has the same council-summarizing awk as evolve step 2.
- `.claude/commands/vulyk-ship.md:1-18` - stage 06, step 3 is the publish-print-and-stop rule.
- `scripts/vulyk-update.sh:1-89` - pulls a VULYK release from origin into a local cache and hands off to that release's `install.sh --upgrade`.
- `scripts/journal.sh:1-33` - appends one line per stage change to `<spec-dir>/journal.md`.
- `scripts/cycle.sh:1302` `cmd_record_seat`, `:1462` `cmd_close_story`, `:278` `cmd_status` - the stat-writing/reading core.

## Key types / contracts
- `memory/stats/council.jsonl` row shape (cycle.sh:662,867,1736): `{"ts","spec","round","verdict","head","pack","asks","red":[],"red_unevidenced":[],"na","review","haiku","haiku_model","sonnet","sonnet_model","opus","opus_model","attempts","escalate","note"}`. `ts` is UTC ISO-8601, written at record-seat time (per council round, not per story).
- `journal.md` line (journal.sh:30): `- <UTC ts> · <stage> · <what> · next: <next>`; stage vocabulary is state.sh's `01-spec … 06-shipped`, `04-council:<verdict>`, or `paused`. No validation of the stage string in journal.sh itself.
- `cycle.sh status --json` object (cycle.sh:445): `{"spec","slug","stage","next","briefed","approved","branch","head","pack","stories":{"todo","in-progress","done","blocked"},"wave","wave_stories":[],"round","ceiling","tier","open","court","missing":[],"stale","verdict","review","red":[],"round_dir","paused","shipped"}`. **No timestamp field** - a point-in-time snapshot, not a series.
- `memory/stats/human.jsonl` rows carry `"ts"` and `"verdict"` (e.g. `"REJECTED"`) - read by vulyk-evolve.md:32-40 via an awk ts-window filter.
- `scope.jsonl` / `ship.jsonl` (README.md:231, vulyk-ship.md:14) append one entry per event; not read in this pass.

## Dependencies
- Inbound: `/vulyk-evolve` reads `memory/stats/skills.json`, `council.jsonl`, `human.jsonl`, `docs/specs/*/brief.md` (`**Escaped from:**` mtime), `memory/learnings/`.
- Outbound: `/vulyk-evolve` step 4 writes `CLAUDE.md`, `.claude/rules/`, agent prompts, skill scaffolds, `.claude/skills/_graveyard/<name>/RETIRED.md`, `CHANGELOG.md` - all on branch `vulyk/evolve-<date>`, never merged by the command itself (step 5 human gate: "Apply NOTHING to the main branch yourself").
- `scripts/vulyk-update.sh` outbound: only `git fetch`/`git clone` from `https://github.com/$REPO.git` (REPO from `VULYK_REPO` env or `.claude/vulyk-origin`, default `Black-coffe/vulyk`) into `$VULYK_SRC` (default `~/.vulyk/src`). **No `git push`, no `gh`** - pull-only.

## Gotchas
1. **"Weekly" is not mechanical anywhere.** `/vulyk-evolve` computes a rolling 7-day window at run time; nothing schedules it - no cron, git hook or CI job (ci.yml jobs: shell, top-model, cycle, council, handoff-window, driver, install-smoke).
2. **No push channel exists.** Any hive-to-origin upload is greenfield.
3. `status --json` has zero timestamp fields - a time-in-stage detector derives its signal from `journal.md` stage lines or file mtimes.
4. Council rounds are per-round, not per-story; rounds-to-green per spec is already computable from `council.jsonl` (evolve step 2's awk does it).
5. `/vulyk-gc` has no script; retention stated only as "snapshots >14 days" and "CONSOLIDATED.md 40-entry cap" (vulyk-gc.md:6,11); raw learnings have only a ">10 reminder" in `/vulyk-status` step 5.
6. `ci.yml` has no jsonl-schema pattern; the only `jq -e` uses (lines 190, 307) check fixed keys in `settings.json`. A telemetry PR validator is new CI surface.
7. README "What is measured, and what is not" (README.md:225-241) states `/vulyk-evolve` "has never been run against real data" - baseline framing for any telemetry claim.

## Answers
1. Evolve: Harvest -> Council check-in (read-only) -> Diagnose -> Propose (branch `vulyk/evolve-<date>`, CHANGELOG line per change) -> Human gate; `--dry-run` stops after step 3. Never runs git/gh push. Weekly = owner types it.
2. GC: thin wrapper over `librarian`; prune = stale map pointers, snapshots >14 days, the 40-entry cap.
3. Origin: `VULYK_REPO` env, else `.claude/vulyk-origin`, else `Black-coffe/vulyk` (vulyk-update.sh:34-38); cache `~/.vulyk/src` (line 39). Nothing sends hive -> origin.
4. Timestamps: journal.md per stage transition (UTC), council.jsonl `ts` per round. `status --json` none.
5. vulyk-ship.md:11 verbatim: "**Publish - print the command, then stop; never wait.** No agent in the hive deploys, publishes, pays or sends, and neither do you here."
6. README sections: Why VULYK exists, Built on native primitives only, How VULYK compares, Quickstart, The model cascade, The routing matrix, The build discipline, Command reference, The memory plane, Self-evolution, Hooks, What is measured and what is not, FAQ, Documentation, Roadmap, Contributing, License. No section on data leaving the machine. Profile rows: Stack, Package manager / runner, Where source lives, Test framework, Commit convention, Configurations that exist today, Client path, Browser MCP, Release / deploy.
7. ci.yml jobs: shell, top-model, cycle, council, handoff-window, driver, install-smoke. No structural jsonl validation.
