---
story: auto-maintenance-03
spec: auto-maintenance
status: done
returned: DONE
tier: 2
worker: worker-code
model: sonnet
wave: 3
blocked_by: [auto-maintenance-02]
---

# Evolve: hypothesis ledger, admission rules, own worktree, sunset (asks 3, 4, 5, 6)

## Goal
`scripts/evolve-ledger.py` owns `memory/stats/evolve.jsonl` (plan Contracts): `add`, `resolve` (infers
accepted / rejected from git, plan A3), `window` (the last 40 proposals with verdicts plus every older
rejection as one line), `last`, `pending`. `/vulyk-evolve` reads the window before proposing and never
re-proposes a rejected hypothesis without new evidence. It judges each change by written rules: growth of
always-loaded bytes only against owner-signed evidence, a neutral change only if it cuts bytes, n beside
every number with no improvement claimed from weekly counts, the habit each change could break, and three
critic questions. It builds the changeset in its own worktree on `vulyk/evolve-<date>`, one commit per
change. The noisy `signal:` line goes. `docs/self-evolution.md` records the ledger, the automatic run and
the sunset rule. The installer stops shipping VULYK's runtime ledgers.

## Requirements
> (3) журнал гипотез и правила приёма изменений в evolve

> (4) один реальный прогон evolve, а если потом он не запускается — в graveyard

> 3. Добавить журнал гипотез и правила приёма изменений в /vulyk-evolve.

> 4. Один реальный прогон evolve. Если после него evolve снова не запускается, отправить его в graveyard, а не достраивать.

> (6) всё прогнать, протестировать и проверить

> Делает правки в отдельной папке-копии (git worktree) на ветке vulyk/evolve-<дата>, твою рабочую папку не трогает. В main ничего не попадает без твоего merge.

## Files
- scripts/evolve-ledger.py
- .claude/commands/vulyk-evolve.md
- docs/self-evolution.md
- install.sh
- tests/maintenance.test.sh
- tests/telemetry.test.sh

## Non-goals
- No automatic merge, ever; the owner's merge is the verdict.
- No noise band, no telemetry guards, no prune-by-firing (report §4: they died in the grill).
- Do not edit `insight-harvester` or `skill-gardener`; the rules live in the command.
- Edit `install.sh` only with the Edit tool (literal CR bytes in it).

## Map slice
`memory/map/scripts.md`, `memory/map/agents-and-commands.md` - evolve.

## Acceptance criteria
- [ ] In a temp git repo: `add` twice, merge one branch, delete the other, `resolve` → one accepted, one rejected; `window` shows both; with 45 proposals the rejected one older than 40 still shows as one line; `pending` lists an unmerged branch; `last` prints the newest ts.
- [ ] `/vulyk-evolve` names the ledger, the window read, the worktree, the admission rules and the critic questions; the old `signal:` sentence is gone.
- [ ] `install.sh` classifies `memory/stats/*.jsonl` as runtime (2) - a check in `tests/telemetry.test.sh`.
- [ ] `tests/maintenance.test.sh`, `tests/telemetry.test.sh` and `tests/solo.test.sh` pass.

## Verification
`bash tests/maintenance.test.sh`
`bash tests/telemetry.test.sh`
`bash tests/solo.test.sh`

## Implementation notes
- `scripts/evolve-ledger.py`: add / run / resolve / window / last / pending over the append-only `memory/stats/evolve.jsonl` (proposal, run, verdict rows). Verdict from git per branch: exists and merged = accepted; exists unmerged = pending (no row); gone = accepted only if the run row's tip commit reached the default branch, else rejected. `window` = last 40 proposals + every older rejection as one line (fixes RRSI's own window-forgetting, `history.py:166-185`).
- Two defects caught by the test that ties the script to the brief: `json.dumps` default separators wrote `"kind": "run"`, which the brief's grep would never match (evolve due forever); and Windows Python printed `\r\n`, which `$(...)` keeps. Fixed with compact separators and `sys.stdout.reconfigure(encoding="utf-8", newline="\n")`.
- `/vulyk-evolve`: new step 0 (resolve, window, pending stops the run), the noisy `signal:` sentence replaced by "every number with its n, no trend from a week", new step 4 (admission rules + critic questions), step 5 builds in `.claude/worktrees/evolve-<date>` with one commit and one ledger row per change and always a `run` row, step 6 tells the owner in one line; merge, not squash.
- `install.sh`: `memory/stats/*.jsonl` is runtime (2). VULYK's own human/scope/ship ledgers were shipping into every fresh hive and would have fed a hive's evolve with VULYK's history. Hives that already hold them keep them; the installer never deletes.
- `docs/self-evolution.md`: "It runs itself", ledger, judge step, worktree, "Knowledge moves down", "Sunset".

## Findings
