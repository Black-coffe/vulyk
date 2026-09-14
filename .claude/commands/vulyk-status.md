---
description: Hive dashboard - driver mode, council numbers, unpushed merges, open stories, memory freshness, skill stats, budget posture
argument-hint: []
---

Produce the hive status report. Read only metadata - this command must stay cheap:

1. **Driver & release.** `driver:` - if `Workflow` is in your own tool list this session, print `driver: workflow`; otherwise print `driver: fallback (CLI <version>)`, reading `<version>` the same way `top-model-brief.sh` does (`claude --version`, compared against `2.1.154` with `sort -V`), plus one sentence: the fallback runs the build -> council -> repair loop inside this pinned top-model session instead of a background Workflow run - the most expensive path in the token economy (`docs/token-economy.md`), because no phase can be handed to a cheaper agent while the Queen's own context is carrying the loop. Then `merged locally, not pushed: <n>` - resolve the default branch the way `ship-check.sh` does (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `main`/`master`), then `git log origin/<default>..<default> --oneline | wc -l`; print `merged locally, not pushed: no remote` when `origin` is not configured.
2. **Council.** If `memory/stats/council.jsonl` does not exist, print `council: no rounds yet` and skip the rest of this step. Otherwise one `awk` pass over it, printed as-is (no model judgment on the numbers):
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
   gives `<specs>` (distinct specs the council has ever judged), `<median>` (median round number of each spec's first `GREEN` row, over specs that ever went green) and `<escalations>` (rows with `verdict":"ESCALATE"`). Separately, escaped defects: `grep -rl '^\*\*Escaped from:\*\*' docs/specs/*/brief.md`, then for each match read the `<slug>` after the label and count it only if `memory/stats/council.jsonl` holds a `GREEN` row for that slug (`grep -F "\"spec\":\"<slug>\"" memory/stats/council.jsonl | grep -q '"verdict":"GREEN"'`). Print `council: <specs> specs · median <n> rounds to green · <n> escalations · <n> escaped defects`.
3. **Stories:** run `bash scripts/state.sh` and read `.claude/state.json` -> table: spec, its `stage` (which confirmation of the six-stage cycle it has reached - `docs/cycle.md`; `study` is the one value outside the cycle: a document deliverable, ADR-008; a spec with a council round shows `04-council:<verdict>` here instead of the pre-council `04-tested:<verdict>`, and any spec with a `PAUSE` file shows `paused` regardless of how far it got), story, status, assigned tier. It is a derived view, regenerated on the spot, never a source of truth - if a number here disagrees with a story file, the story file wins and the view was stale. Report `unrecognised` counts out loud rather than folding them into anything: a spec written before the `todo|in-progress|done|blocked` convention is not a spec with nothing done, and treating it as one is the derived view lying.
4. **Memory freshness:** `memory/map/*` last-verified dates vs. recent git churn in their modules (`git log --since` per path); flag stale. Note if `scripts/git-hooks/post-merge` left a `.stale` flag.
5. **Learnings buffer:** count raw files in `memory/learnings/` awaiting consolidation; remind about /vulyk-gc past 10.
6. **Skill usage:** top/bottom entries from `memory/stats/skills.json`; note candidates the next /vulyk-evolve will examine.
7. **Budget posture:** run `bash scripts/top-model.sh --explain` and show it - the resolved top model, the plan it was read from, the Tier 4 pairing, and whether the Queen's own session is pinned to it; then the routing matrix one-liner. If the session has been long, recommend `/vulyk-handoff` then `/clear` after this report.
8. **Context hygiene** (only when the session is fresh — otherwise the advice arrives too late to act on): suggest `/context` to see what the session starts with, and `/mcp` to switch off servers this project never calls. Skip this step entirely on a long session.

Format: compact tables, no prose padding. End with the single most useful next action.
