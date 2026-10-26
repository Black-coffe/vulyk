# Horizon: symbol-map

Date: 2026-10-26 · Step 3a of `/vulyk-plan` (ADR-022)

## Why the step ran

Terms: `symbol map`, `callers`, `ctags`, `tree-sitter`, `AST`. Searched in `memory/memory.md`, `memory/map/*.md`,
`scripts/`, `.claude/agents/`, `.claude/commands/`. Zero hits on the capability (a deterministic symbol or caller
index). The only hits were the prose rule "grep every caller of what you touch" (`worker-code.md` step 2,
`vulyk-build.md`) and drone-scout's model-written "call paths", which belong to the container and not the capability.

## How the lenses ran

The interactive session could not dispatch `drone-horizon` (`Agent type 'drone-horizon' not found`), and neither
could a fresh headless session. Probes in scratch projects showed the file loads once its description is shortened,
or once `WebSearch, WebFetch` are dropped from `tools:`. The full agent set and the old description together did not
load. The fix shipped in this session: `description:` shortened and the redundant `disallowedTools:` line removed,
since `tools:` is already an allowlist. With it, `drone-horizon` loads in this repo. The cause inside Claude Code is
not established. The three lenses then ran headless (`claude -p --model sonnet`), one `drone-horizon` dispatch each.
None of them could read `CLAUDE.md` (the agent has `omitClaudeMd: true`, and Glob comes back empty on this Windows
machine), so their *Configurations that exist today* check rests on the recon summary alone.

## Candidates

| # | Lens | Candidate | Verdict | Reason |
|---|---|---|---|---|
| 1 | depth P3, altitude P1 (check) | Replay the 73 stories that named a path outside `## Files`, and use the share of missed paths the tool finds as the acceptance number | kept as **H1** (merged) | the measured planner-side gap; the only check that shows the tool does more than look right |
| 2 | depth P2, range P1 | Co-change block from `git log`: files and tests that historically change together with each `## Files` path | kept as **H2** (merged) | catches tests that assert behaviour without calling the symbol, a case static callers miss; works on every stack |
| 3 | depth P1, range P2 | Every caller line labelled `exact` (ast), `textual` (token match) or `unresolved` (dynamic, `import *`, string dispatch) | kept as **H3** (merged) | without labels a 1C/PHP worker reads a token match as a proven call, which is the gap the goal fails on |
| 4 | altitude P1 | Make the tool a `## Files` completeness check for the planner, not a worker speed-up | merged into the design question (where it plugs in) | the same evidence as the recon; it is the main design fork, not an extra |
| 5 | altitude P2, range P3 | Post-diff gate: callers of changed/removed signatures left outside the diff | merged into the design question (gate) | already in the Queen's draft design; the block-vs-report choice goes to the owner |
| 6 | altitude, depth, range DROPPED | tree-sitter / ctags as a default dependency | dropped | contradicts the public-repo rule: the default path needs no extra tool |
| 7 | depth DROPPED | Aider-style PageRank ranking | dropped | serves a chat token budget; here the input is already bounded by `## Files` |
| 8 | altitude DROPPED | Feed the full graph to every worker to save tokens | dropped | the measured saving is small (repo-wide search median 1 call per worker) |

## Kept proposals

**H1 · replay acceptance** (kind: gap, status: confirmed, sources: none: repo only)
- what: before release, run the tool on the original `## Files` of the 73 stories that later named a path outside
  them, and on the commits behind the few missed-caller review findings; record the hit rate and the noise.
- why: the request's profit ("never forgets a dependent call") is a completeness claim; only a replay shows it.
- cost: one evaluation script and a results table next to the spec.
- check: hit counts from story files and git history, no model in the loop.
- ask line: (horizon) до выпуска прогнать symbol-map на историях, где нужный путь оказался вне `## Files`, и записать долю найденных как критерий приёмки.

**H2 · co-change** (kind: extension, status: не подтверждено, method sources read by the lens: adamtornhill.com
article, code-maat README, both undated)
- what: a `co-change` block from `git log --name-only`: files and tests that changed together with each path, with
  counts; labelled candidates, not callers; "insufficient history" on young or shallow repos.
- why: 73 stories missed tests that assert old behaviour; such a test may not call the symbol directly.
- cost: about 80 lines; noise from lock and generated files; a threshold to tune.
- check: the same replay as H1, recall of the missed path in the top N.
- ask line: (horizon) symbol-map показывает файлы и тесты, которые по истории git меняются вместе с файлами из `## Files`.

**H3 · confidence labels** (kind: gap, status: confirmed for the design; the Aider fallback fact is from the Queen's
fact-check, aider repomap.py read 2026-10-26)
- what: each reference line carries `exact`, `textual` or `unresolved`, and each run names the files it could not parse.
- why: a regex match on a non-Python stack must not read as a proven call.
- cost: a label per line, little code.
- check: fixture repos per stack with known callers; the test fails when a label is wrong.
- ask line: folded into the design; not asked separately (it is how the tool reports, not an extra).
