---
description: Hive dashboard - driver, council numbers, token spend per spec, unpushed merges, open stories, memory freshness, skill stats, budget posture
argument-hint: []
---

Produce the hive status report. Read only metadata; this command stays cheap.

1. Driver and release. Print `driver: workflow` if `Workflow` is in your own tool list this session,
   else `driver: agent loop` (Tier 3-4 run their agents from the Queen's session; Tier 1-2 build solo
   either way). Then `merged locally, not pushed: <n>`: resolve the default branch as `ship-check.sh`
   does (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `main`/`master`), then
   `git log origin/<default>..<default> --oneline | wc -l`; print `no remote` when `origin` is absent.
2. Council. If `memory/stats/council.jsonl` does not exist, print `council: no rounds yet` and skip the
   rest of this step. Otherwise one `awk` pass over it, printed as-is:
   ```
   awk '
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
   Escaped defects: `grep -rl '^\*\*Escaped from:\*\*' docs/specs/*/brief.md`, counting a match only
   when `memory/stats/council.jsonl` holds a `GREEN` row for the slug it names
   (`grep -F "\"spec\":\"<slug>\"" memory/stats/council.jsonl | grep -q '"verdict":"GREEN"'`). Print
   `council: <specs> specs · median <n> rounds to green · <n> escalations · <n> escaped defects`.
3. Token spend. `python scripts/token-report.py . --since "$(date -u -d '-14 days' +%Y-%m-%d)"` and
   print its per-spec lines as-is: raw and weighted tokens, dispatches, rounds. The `totalTokens` a
   Workflow run prints is a sum of final contexts, not spend; quote this report instead.
4. Stories. Run `bash scripts/state.sh` and read `.claude/state.json` into a table: spec, `stage`, story,
   status, tier. `stage` is the cycle confirmation reached (`docs/cycle.md`); `study` marks a document
   deliverable; a spec with a council round shows `04-council:<verdict>`; a `PAUSE` file shows `paused`.
   The view is derived: a story file that disagrees wins. Statuses are `todo | done | blocked`; older
   specs may still carry `in-progress`. Report `unrecognised` counts out loud.
5. Memory freshness. `memory/map/*` `last-verified` dates against recent git churn in their modules
   (`git log --since` per path); flag stale ones, and a `.stale` flag left by `scripts/git-hooks/post-merge`.
6. Learnings buffer. Count raw files in `memory/learnings/`; past 10, suggest `/vulyk-gc`.
7. Skill usage. Top and bottom entries of `memory/stats/skills.json`; name the candidates the next
   `/vulyk-evolve` will examine.
8. Budget posture. Show `bash scripts/top-model.sh --explain`: the gate model, the plan it came from,
   the Tier 4 pairing, and whether the Queen's session is pinned to `opus`. On a long session,
   recommend `/vulyk-handoff`, then `/clear`.
9. Context hygiene, only on a fresh session: suggest `/context` to see what the session starts with,
   and `/mcp` to switch off servers this project never calls.

Format: compact tables, no padding. End with the single most useful next action.
