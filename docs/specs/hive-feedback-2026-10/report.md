# Hive feedback, 30 days to 2026-10-16 (study)

Owner's request, 2026-10-16: «Ты можешь щас локально по всем проектам пройтись, где стоит Vulc, запустить этот анализатор и
собрать фидбеки по всем проектам? Может, там ещё есть что дорабатывать и доулучшать?»

Study work, no story. What `/vulyk-evolve` steps 0-2 read was collected read-only from every hive on this machine instead of
running evolve in each (it writes a branch and a ledger commit per hive):

- 42 install sites, 15 repositories. 25 sites are worktrees of two repositories, and their ledgers were unioned with
  duplicates removed. 10 repositories had council rounds in the window.
- The sources:
  - `memory/stats/*.jsonl`;
  - `scripts/token-report.py`;
  - every `story(...)` commit's paths against its `## Files`;
  - 93 hive defect cards;
  - the hives' Claude memory notes and evolve ledgers.
- Hives are named by shape. Numbers are 30 days.

## The numbers

| | |
|---|---|
| Weighted spend, 10 active hives | ≈1.84B tokens (largest: video hive 506M, local-RAG hive 288M, two game/SaaS hives ≈240M each) |
| Dispatches | 4,545, of which `cycle-clerk` 2,122 (47%) |
| Specs judged / reached GREEN | 147 / 128; median rounds to green 1-2 per hive; max 7 |
| Escalations | 44 (one SaaS hive 15 over 30 specs) |
| Owner REJECTED after GREEN | 7 (video 5, local-RAG 2) |
| Anomalies | `scope_breach` 815, `agent_prefix_high` 210, `agent_empty` 177, `context_high` 113, `council_rounds_high` 44, `driver_relaunched` 23 |

## Findings, open in 0.28.0

1. **`scope_breach` is noise.**
   - The commits: of 851 story commits, 4 touched a non-paperwork path outside `## Files`.
   - The metric: 815 story rows were flagged. In VULYK itself, 63 of 64 rows are non-zero.
   - The causes:
     - `scope-check` counted its own `scope.jsonl` (fixed in 0.28.0);
     - it still counts `memory/stats/skills.json` (`scripts/scope-check.sh:97`), which the Skill counter rewrites on almost every turn. That rule was the owner's call on 2026-09-15 (anomaly-telemetry A18), when the counter wrote rarely.
   - Fix: drop every `is_paperwork_path` path from the measurement. This needs the owner to reverse A18.
2. **The upgrade overwrites hive edits.**
   - Reach: 6+ hives. Three of them keep their own patch registers so the next upgrade can restore their edits.
   - Examples:
     - agent `maxTurns` raised from 60 to 140 after empty council seats, lost twice;
     - a `cycle.sh` fix re-ported on three upgrades;
     - a deleted hook restored silently.
   - Spec `upgrade-keeps-host-edits` is planned, not approved.
3. **No hive-owned config layer.** Five hives patch framework files for the same few knobs:
   - the paperwork globs, because specs live outside `docs/specs/` or smoke files sit inside specs;
   - the specs directory;
   - per-agent `maxTurns` and model;
   - a full-suite verification command that `wave-check` calls a verify-gap.

   One file the installer never touches would end most of the patching behind finding 2.
4. **`## Verification` against `## Commands` is brittle** (6 hives):
   - a parameterised command never matches;
   - a cell with two commands is read as one;
   - commands run from the repo root without the venv.

   One SaaS hive's database tests skipped silently and close-story recorded green. Fix: parse each backticked span, allow a
   `<file>` placeholder bound to `## Files`, and treat a run that skipped everything as red.
5. **`resume` drops the `DRIVER` claim with no liveness check** (`cmd_resume`, unconditional `rm -f`). A resume after
   `/clear` started a second driver over a live one, and a test file was overwritten (2 hives). Fix: a heartbeat in
   `DRIVER`; resume refuses a fresh one.
6. **Windows installs miss two settings.**
   - Glob/Grep return "No files found" for subagents and the main session (4 hives and VULYK's own memory). One hive fixed
     it with `USE_BUILTIN_RIPGREP=0` in `.claude/settings.json` (accepted by its evolve).
   - Court worktrees hit "Filename too long". No `core.longpaths` anywhere in the source.

   Fix: the installer sets both on Windows.
7. **`## Asks` has two parsers.** `asks_count` counts only `N. ` lines (`scripts/cycle.sh:260`), while `trace-check.sh`
   reads `> ` lines. `open-round` stopped after finished builds in 3 hives. Fix: one parser for both.
8. **`agent_empty`: 177 empty returns.**
   - By agent: worker-code 41, cycle-clerk 24, the four council seats together 40, `other` 67.
   - The cause is cap deaths, the same signal behind the hives' `maxTurns` patches.
   - `agent_prefix_high` is mostly `other` (178): agent types outside the telemetry's fixed list, such as general-purpose
     and workflow-subagent, so the report cannot say which ones.
9. **Smaller, each confirmed in code or a hive ledger:**
   - `.claude/rules/example-api.md` ships into every hive, and 6 delete it;
   - `/vulyk-gc` hard-codes `memory/memory.md`;
   - 5 GNU-only `sed -i` in `cycle.sh`, a problem for macOS operators;
   - a failed close-story commit leaves files staged for the next story;
   - commit types are hard-coded where a hive's commitlint rejects them;
   - a descope written only in plan.md, cost 3 rounds;
   - no "owner language" Profile row, so Russian-speaking owners get English reports (3 hives).

## Defect classes to promote from hives into VULYK

26 of the 93 hive cards are about the process, not the project. None has a VULYK card. Repeated across hives:

| Class | Hives | Example (owner's words) |
|---|---|---|
| Claim from memory, a docstring or a guess instead of the source | 4 | «Но в самом ролике прямо звучит "это ролик 2"» |
| Test or measurement that does not represent reality (unequal A/B arms, self-graded exam, preprod with flags off) | 3 | «На preprod были выключены около 60 фич, которые на проде включены.» |
| Safeguard bypassable or shipped after what it guards | 3 | «Местный охранник от паролей можно отключить одним флагом `--no-verify`» |
| "Done" without running in the real target | 3 | «Проверяй, тестируй то, что ты делаешь и отдаешь.» |
| Work handed back to the owner that an agent can do | 2 | «зачем мне это всё дублировать, если ты сам можешь всё это» |
| Outward artifact carries internal or client content (widen `host-internals-in-public-repo`) | 2 | «клиента в ролике могут узнать по цифрам, процессам» |
| The owner's words or decision written by the builder | 2 | a builder-written "owner decision" waiver |

Most of these classes have no `check:`. Promoting them gives every hive the text card. A check has to be written per class.

## Candidate stories, recommended order

1. **Quiet scope metric** (Tier 1). `scope-check` drops paperwork paths. Needs the owner to reverse A18. It is the
   cheapest change and makes one weekly number honest again.
2. **Hive config layer + upgrade keeps host edits** (Tier 3). Findings 2 and 3 together. The existing spec plus one
   hive-owned file. It removes the most repeated pain.
3. **Windows install + resume liveness + one Asks parser** (Tier 2). Findings 5, 6 and 7. Small and independent, and each one stopped a driver.
4. **Verification cells** (Tier 2). Finding 4, the only one where a test was recorded green on a silent skip.
5. **Promote the seven defect classes** (Tier 1, cards only), then checks one by one.
6. **Telemetry agent list** (Tier 1). Name general-purpose and workflow-subagent in `agent_*` rows. Report caps per agent.

Already fixed in 0.28.0 and earlier (the hives still on old versions keep hitting them until upgraded):
- worker self-marking `done`;
- hook-written stats dirtying the tree;
- the Tier 4 seat lost in transit;
- repair ignoring a review BLOCK;
- out-of-scope edits left behind;
- CRLF in the driver;
- the `TOP_MODEL` prose pin;
- Tier 1 ceremony.
