---
story: ab-run-fixes-11
status: done
returned: DONE
worker: worker-code
model: opus
wave: 6
blocked_by: []
red: required
red_reason: plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map
red_verified_at: 2026-11-09T01:44:34Z 19606e4c711893230081e0d504c77b1fcc2b0c7c8f8ec0219f42d452cf1297a2
---

# Repair round 2

## Goal
Make the asks and findings council round 2 left RED pass, and change nothing else.

## Requirements
> 8. Грилевка пачкой до 4 вопросов. Горизонт в существующем репо — только по `--horizon`. Подтверждение требований совмещено с утверждением плана, а утверждение Tier 3–4 сразу запускает сборку.

## Findings
ASK 8: RED - grill batch of 4, horizon only by --horizon in an existing repo, confirm merged with approval, approval launches build - run: grep templates/grill.md, vulyk-plan.md 3a/9/10, vulyk-bootstrap.md:60, memory/memory.md headings saw: batches of up to 4 (grill.md:20), no confirm question (grill.md:36), Tier 3-4 approval starts /vulyk-build in the same turn (plan step 10) all present; but 3a gates the horizon on "`## Codebase map` lists a module", while bootstrap step 4 now writes modules only under `## Unmapped territory` (memory.md:17) and maps none, so a freshly bootstrapped existing repo still fires the grep trigger on its first plan without --horizon - the owner case (old repo, new capability) stays uncovered until something gets mapped

## Files
- .claude/commands/vulyk-plan.md
- tests/maintenance.test.sh

## Queen note
Files narrowed by the Queen (2026-11-09): the RED item is one sentence in `/vulyk-plan` step 3a. Today it reads
"In a repo whose `memory/memory.md` `## Codebase map` lists a module, it runs only with `--horizon`". Bootstrap step 4
now lists modules only under `## Unmapped territory` and maps none, so a freshly bootstrapped existing repo still takes
the grep trigger. The gate must count a module listed under either heading (`## Codebase map` or `## Unmapped
territory`) as an existing repo; "Only a repo with no mapped module" becomes a repo whose memory.md lists no module
under either. No other change to step 3a, to bootstrap or to `memory/memory.md`.
Red: a check in `tests/maintenance.test.sh` that step 3a's existing-repo gate names `## Unmapped territory` beside
`## Codebase map` (it fails on HEAD).

## Implementation notes
- .claude/commands/vulyk-plan.md: step 3a gate counts a module under `## Codebase map` or `## Unmapped territory`; the grep trigger runs only when memory.md lists no module under either.
- tests/maintenance.test.sh: new check reads step 3a (joined, spaces squeezed) for the two-heading gate.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 19606e4c711893230081e0d504c77b1fcc2b0c7c8f8ec0219f42d452cf1297a2 (tests/maintenance.test.sh)
- impl: 65c8847ec7848dfd17e5e9651ee80c755ab102f3206b6526392d3c475e03a76f
- stamped: 2026-11-09T01:44:34Z

```
::error::plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map - expected '`## Codebase map` or `## Unmapped territory` lists' in:
  ok    git-guard: --check passes a file that is no hook input
--- git guard: a mod with tool.check
  ok    git-guard: an enabled mod with tool.check gets a brief line
  ok    git-guard: a disabled mod is not named
  ok    git-guard: no such mod, no line
  ok    git-guard: an enabled mod without tool.check, no line
--- plan step 3a: the existing-repo horizon gate
::error::plan 3a: the existing-repo gate counts a module under ## Unmapped territory beside ## Codebase map - expected '`## Codebase map` or `## Unmapped territory` lists' in:
        3a. Horizon, Tier 2-4 on new ground (ADR-022). Skip it for study work, Tier 0-1, no-question mode and `--no-horizon`; `--horizon` runs it anyway. In a repo whose `memory/memory.md` `## Codebase map` lists a module, it runs only with `--horizon`: no lens, no horizon question. Only a repo with no mapped module uses the trigger that follows. New ground is a recon fact: take two to four terms that name the asked capability (its nouns and verbs, not the project's) and Grep them in `memory/memory.md`, `memory/map/` and the source. Zero hits on the capability fires the step; a hit on its container (a folder or file family, such as `.claude/commands/` for a new command) does not count. An empty repo fires it too. A request inside existing code gets no horizon and no extra question. Announce it in one line in the owner's language: the terms, where they were searched, that the step runs, and that in the default permission mode the three lenses may ask for web search (a refusal is safe: their outside facts come back `не подтверждено`). VULYK grants no web permission itself. Then dispatch `drone-horizon` three times in one message, `lens: altitude`, `depth` and `range`, each with the brief path, a one-paragraph recon summary (what was not found and where it was looked for) and the Profile rows *Configurations that exist today* and *Owner language* copied verbatim, with no model parameter. Each returns up to three proposals: `what`, `why`, `cost`, `check`, `sources`, `status`, `kind` (`gap` or `extension`) and an `ask line`. A lens that fails or returns nothing is noted, and the step goes on with the others. Cut the candidates to at most three: merge duplicates, and drop what contradicts the Profile's *Configurations that exist today* or the repo, or is not tied to the owner's goal. A kept `kind: gap` stays a gap only when you name the ask or the verbatim request fragment that fails without it, and write that fragment beside it; otherwise relabel it `extension`. Number the kept proposals `H1`-`H3`. Write `docs/specs/<slug>/horizon.md`: the terms and where they were searched, every candidate with its verdict (kept, merged or dropped, one-line reason), and the kept proposals, numbered, with their fields and, for a gap, the fragment it rests on. Proposals never go into `brief.md` by themselves; only what the owner picks in the grill does. 4. Grill, Tier 2-4. Follow `templates/grill.md`; it owns every rule of the round, horizon questions 
maintenance.test.sh: 391 checks, 1 failed
```
