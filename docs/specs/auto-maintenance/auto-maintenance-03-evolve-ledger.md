---
story: auto-maintenance-03
spec: auto-maintenance
status: todo
returned:
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

## Findings
