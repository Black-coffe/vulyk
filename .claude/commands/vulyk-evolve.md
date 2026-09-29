---
description: Weekly self-evolution cycle - mine learnings, usage stats and token spend, check the council's weekly numbers, propose config diffs as a reviewable changeset
argument-hint: [--dry-run to report without writing the changeset]
---

Run the evolution cycle. Use the `insight-harvester` and `skill-gardener` skills - they define the method. "$ARGUMENTS"

Nobody has to remember this command: the SessionStart brief says `maintenance due: ... evolve (...)` when it never ran, or ran 7+ days ago with a council round since, and the Queen runs it after the owner's task, on the default branch with a clean tree.

0. Ledger (`memory/stats/evolve.jsonl`, owned by `scripts/evolve-ledger.py`). Run `python scripts/evolve-ledger.py . resolve` - it records the owner's verdict on earlier changesets from git (merged = accepted, branch deleted unmerged = rejected; add `--reason-for <branch>=<text>` when the owner gave one) - then `python scripts/evolve-ledger.py . window` and read it before anything else. A hypothesis it shows rejected is not proposed again unless this run's evidence is newer than the rejection. If `python scripts/evolve-ledger.py . pending` names a branch, stop: tell the owner in one line that `<branch>` waits for review (merge to accept, delete the branch to reject) and propose nothing new.

1. Harvest. Read `memory/learnings/` (raw + CONSOLIDATED), `memory/stats/skills.json`, and - if the user can paste it - the output of the built-in `/insights` command (ask once; proceed without it if unavailable).
   Then the week's spend: `python scripts/token-report.py . --since "$(date -u -d '-7 days' +%Y-%m-%d)"`, printed as-is - one line per spec with raw and weighted tokens, dispatches and rounds. That report is the spend; the `totalTokens` a Workflow run prints is a sum of final contexts and never counts as spend. A spec whose dispatches or rounds stand out is evidence for step 3's friction list.
2. Council check-in (read-only; nothing here writes anything). If `memory/stats/council.jsonl` does not exist, print `council: no rounds yet` and skip to step 3. Otherwise run the same `awk` pass `/vulyk-status` step 2 uses, restricted to the last 7 days:
   ```
   SINCE="$(date -u -d '-7 days' +%Y-%m-%dT%H:%M:%SZ)"
   awk -v since="$SINCE" '
     { match($0, /"ts":"[^"]*"/);      ts=substr($0, RSTART+6, RLENGTH-7) }
     ts < since { next }
     { match($0, /"spec":"[^"]*"/);    spec=substr($0, RSTART+8, RLENGTH-9) }
     { match($0, /"round":[0-9]+/);    round=substr($0, RSTART+8, RLENGTH-8) }
     { match($0, /"verdict":"[^"]*"/); verdict=substr($0, RSTART+11, RLENGTH-12) }
     {
       specs[spec]=1
       if (verdict=="GREEN" && (!(spec in firstgreen) || round+0 < firstgreen[spec]+0)) firstgreen[spec]=round
       if (verdict=="ESCALATE") escalations++
     }
     END {
       n=0; for (s in specs) n++
       g=0; for (s in firstgreen) { g++; rounds[g]=firstgreen[s]+0 }
       for (i=1;i<=g;i++) for (j=i+1;j<=g;j++) if (rounds[j]<rounds[i]) { t=rounds[i]; rounds[i]=rounds[j]; rounds[j]=t }
       med=0; if (g>0) { if (g%2==1) med=rounds[(g+1)/2]; else med=(rounds[g/2]+rounds[g/2+1])/2 }
       printf "specs:%d median:%s escalations:%d\n", n, med, escalations+0
     }
   ' memory/stats/council.jsonl
   ```
   plus the same escaped-defect grep as `/vulyk-status` step 2, restricted to briefs whose file mtime falls in the last 7 days (`date -r <brief.md> +%s` vs. `date -u -d '-7 days' +%s`). Print `council (7d): <specs> specs · median <n> rounds to green · <n> escalations · <n> escaped defects`. Then the comparison the grill names - `human.jsonl` rows with `"verdict":"REJECTED"` in the same window:
   ```
   awk -v since="$SINCE" '
     { match($0, /"ts":"[^"]*"/); ts=substr($0, RSTART+6, RLENGTH-7) }
     ts < since { next }
     $0 ~ /"verdict":"REJECTED"/ { c++ }
     END { print c+0 }
   ' memory/stats/human.jsonl
   ```
   Print `human.jsonl REJECTED (7d): <n>`. Every number in this step is printed with its n, and none of them proves a trend on its own: a week holds a handful of specs, so a count of 0-2 against 0-2 is noise (report rrsi-self-improvement §1). Nothing in this step applies anything; it feeds step 3's diagnosis the way `skills.json` already does.

   Anomaly telemetry (7d, same check-in). Schema and enum: `docs/telemetry.md`. If `memory/stats/anomalies.jsonl` does not exist, print `anomalies: none logged yet` and skip to the consent line below. Otherwise count rows with `ts >= SINCE` (the same window as above) by `code`:
   ```
   awk -v since="$SINCE" '
     { match($0, /"ts":"[^"]*"/);   ts=substr($0, RSTART+6, RLENGTH-7) }
     ts < since { next }
     { match($0, /"code":"[^"]*"/); code=substr($0, RSTART+8, RLENGTH-9) }
     { count[code]++ }
     END { for (c in count) printf "%s\t%d\n", c, count[c] }
   ' memory/stats/anomalies.jsonl
   ```
   Print one row per code from `bash scripts/telemetry.sh enum` - `anomalies (7d): <code> <n>` (`<n>` is `0` for a code the awk pass did not emit) - beside the council stats above; no free text from the log, the schema carries none. Then run `bash scripts/telemetry.sh consent`: `off` prints its own one-line notice (`telemetry: off (Profile row Telemetry) - nothing to send`) and moves straight to step 3, nothing further sent or printed. `on` runs `bash scripts/telemetry.sh publish` - `publish --dry-run` instead when this `/vulyk-evolve` run itself carries `--dry-run` - shows its fenced command block to the owner verbatim, and states plainly that the command was printed, not run, same posture as `/vulyk-ship` step 3 (never `git commit`, never `gh`, never waits for the owner). The anomaly counts feed step 3's diagnosis the same way the council stats do.

   The inbox, repo side (the weekly distil-and-clear). Only when `telemetry/inbox/` exists at the repo root - that is the VULYK repository itself; a hive never has that directory, so in a hive skip this paragraph with one sentence (`inbox: not the VULYK repo - nothing to distil`) and move on. Otherwise run `bash scripts/telemetry.sh inbox`. It prints one TSV line per (week, code) - `<week> <code> <rows> <hives>` - across every bundle contributors have merged into `telemetry/inbox/`. Show that table beside the local 7-day counts above: both feed step 3's diagnosis, and the inbox table is the only evidence in this run that is not about this one machine. Put the same table verbatim into step 5's CHANGELOG entry, so the week's distillate is in the changeset a human reviews. The clearing happens in step 5, inside the evolve worktree, never here: run in the owner's tree, `--clear` would stage deletions that the ledger commit carries straight onto the default branch, while the distillate lives only on a branch the owner may reject. Under `--dry-run` distil only - never `--clear`. A non-zero `inbox` exit is a bundle that failed `bash scripts/telemetry.sh check`: it prints `<file>:<line>: <reason>` and deletes nothing - stop this paragraph, report the reason, clear nothing, and continue to step 3 without the inbox table.
3. Diagnose. Produce three lists with evidence: (a) top 3 friction patterns (repeated mistakes, expensive habits, recurring re-explanations); (b) skills/rules unused for 3+ weeks -> archive candidates; (c) patterns done manually 3+ times -> new skill/rule candidates.
4. Judge each candidate change before writing it. It is admitted only if every rule holds:
   - Always-loaded text (the constitution, agent and command `description:` lines, SessionStart output) grows only against owner-signed evidence: a verbatim owner quote in a defect class code cannot check, or an ADR the owner accepted. A class code can check becomes a `check:` instead (Law 6). The caps live in `tests/maintenance.test.sh`; raising one is part of the diff and cites that evidence.
   - A change with no measurable effect is admitted only if it cuts bytes (`tr -d '\r' < <file> | wc -c`, before and after).
   - It names the habit it could break and why it will not.
   - Three critic questions, one line each: does it remove a safeguard without a replacement; does it add a loop without an exit; is it drawn from a single spec?
   - It is not a hypothesis the step 0 window shows rejected, unless its evidence is newer.
5. Propose, in a worktree: `git worktree add .claude/worktrees/evolve-<date> -b vulyk/evolve-<date> <default-branch>`. Write every admitted diff there, never in the owner's tree: edits to the constitution (`CLAUDE.vulyk.md` if it exists, else `CLAUDE.md`), `.claude/rules/`, agent prompts, new skill scaffolds; archived skills move to `.claude/skills/_graveyard/<name>/` with `RETIRED.md` (date, reason, evidence). One commit per change, and one CHANGELOG.md line per change. In the VULYK repo with an inbox table from step 2, one more commit in the worktree: `VULYK_HIVE="$PWD/.claude/worktrees/evolve-<date>" bash scripts/telemetry.sh inbox --clear` stages the emptied week directories there, committed with the table's CHANGELOG line - so the bundles leave the default branch only when the owner merges. For each: `python scripts/evolve-ledger.py . add --branch vulyk/evolve-<date> --component <constitution|rule|agent|command|hook|skill|defect|memory|script|doc> --file <path> --hypothesis "<what should improve>" --evidence "<the facts, with n>" --bytes-delta <n>`. Then `git worktree remove .claude/worktrees/evolve-<date>`, `python scripts/evolve-ledger.py . run --branch vulyk/evolve-<date> --commit <tip> --proposals <n>`, and commit the ledger alone on the default branch: `git add memory/stats/evolve.jsonl && git commit -m "chore(evolve): ledger <date>" -- memory/stats/evolve.jsonl` (the pathspec keeps anything else staged out of it). Nothing admitted: no branch, but still the `run` row (`--proposals 0`) and its commit - the brief's clock reads it.
6. Human gate. Tell the owner in one line: `evolve: <n> changes ready for review on vulyk/evolve-<date> - merge to accept (a merge, not a squash), delete the branch to reject`; then the review: per-change rationale, expected effect, rollback note. Apply nothing to the default branch yourself. With `--dry-run`, stop after the diagnosis report and write no proposal or run row (step 0's verdict rows are facts read from git and stay).

Discipline notes: prefer deleting and tightening over adding - constitutions rot by accretion; a rule that fires rarely but prevents disasters stays (frequency is not the only signal - say when you keep something for severity reasons).
