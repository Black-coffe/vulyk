---
description: Weekly self-evolution cycle - mine learnings and usage stats, check the council's weekly numbers, propose config diffs as a reviewable changeset
argument-hint: [--dry-run to report without writing the changeset]
---

Run the evolution cycle. Use the `insight-harvester` and `skill-gardener` skills - they define the method. "$ARGUMENTS"

1. **Harvest.** Read `memory/learnings/` (raw + CONSOLIDATED), `memory/stats/skills.json`, and - if the user can paste it - the output of the built-in `/insights` command (ask once; proceed without it if unavailable).
2. **Council check-in** (read-only; nothing here writes anything). If `memory/stats/council.jsonl` does not exist, print `council: no rounds yet` and skip to step 3. Otherwise run the same `awk` pass `/vulyk-status` step 2 uses, restricted to the last 7 days:
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
   Print `human.jsonl REJECTED (7d): <n>`. If escaped defects (7d) > REJECTED (7d), print the signal sentence: `signal: escaped defects this week (<n>) exceed what a human gate caught in a comparable span (<n>) - the "models are ready" hypothesis is losing this week; docs/grill/2026-09-12-autonomous-cycle-council.md Decision 14 names human_gate: blocking as the fallback, not a default.` Otherwise print `signal: none - escaped defects at or below the human-gate baseline`. Nothing in this step applies anything; it feeds step 3's diagnosis the way `skills.json` already does.

   **Anomaly telemetry (7d, same check-in).** Schema and enum: `docs/telemetry.md`. If `memory/stats/anomalies.jsonl` does not exist, print `anomalies: none logged yet` and skip to the consent line below. Otherwise count rows with `ts >= SINCE` (the same window as above) by `code`:
   ```
   awk -v since="$SINCE" '
     { match($0, /"ts":"[^"]*"/);   ts=substr($0, RSTART+6, RLENGTH-7) }
     ts < since { next }
     { match($0, /"code":"[^"]*"/); code=substr($0, RSTART+7, RLENGTH-8) }
     { count[code]++ }
     END { for (c in count) printf "%s\t%d\n", c, count[c] }
   ' memory/stats/anomalies.jsonl
   ```
   Print one row per code from `bash scripts/telemetry.sh enum` - `anomalies (7d): <code> <n>` (`<n>` is `0` for a code the awk pass did not emit) - beside the council stats above; no free text from the log, the schema carries none. Then run `bash scripts/telemetry.sh consent`: `off` prints its own one-line notice (`telemetry: off (Profile row Telemetry) - nothing to send`) and moves straight to step 3, nothing further sent or printed. `on` runs `bash scripts/telemetry.sh publish` - `publish --dry-run` instead when this `/vulyk-evolve` run itself carries `--dry-run` - shows its fenced command block to the owner verbatim, and states plainly that the command was printed, not run, same posture as `/vulyk-ship` step 3 (never `git commit`, never `gh`, never waits for the owner). The anomaly counts feed step 3's diagnosis the same way the council stats do.
3. **Diagnose.** Produce three lists with evidence: (a) top 3 friction patterns (repeated mistakes, expensive habits, recurring re-explanations); (b) skills/rules unused for 3+ weeks -> archive candidates; (c) patterns done manually 3+ times -> new skill/rule candidates. A "signal" line from step 2 is evidence for (a), not a separate list.
4. **Propose.** On a branch `vulyk/evolve-<date>`, write the actual diffs: edits to `CLAUDE.md` project profile, `.claude/rules/`, agent prompts, new skill scaffolds; move archived skills to `.claude/skills/_graveyard/<name>/` adding `RETIRED.md` (date, reason, evidence). Append a CHANGELOG.md entry justifying EVERY change in one line each.
5. **Human gate.** Present the changeset as a review: per-change rationale, expected effect, rollback note. Apply NOTHING to the main branch yourself. With `--dry-run`, stop after the diagnosis report.

Discipline notes: prefer deleting and tightening over adding - constitutions rot by accretion; a rule that fires rarely but prevents disasters stays (frequency is not the only signal - say when you keep something for severity reasons).
