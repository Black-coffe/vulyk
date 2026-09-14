---
story: anomaly-telemetry-05
spec: anomaly-telemetry
status: todo
returned:
tier: 3
worker: worker-code
model: opus
tracer: false
wave: 3
blocked_by: [anomaly-telemetry-01, anomaly-telemetry-02, anomaly-telemetry-04]
---

# Consent: `Telemetry` Profile row, the installer's terminal question, hook wiring on upgrade, exclusions

## Goal
The constitution's Profile table carries a `Telemetry` row, `off` by default, that `telemetry.sh consent` reads. `install.sh`, on a fresh install and on `--upgrade`, prints a short explanation of telemetry in the terminal and asks one yes/no question on `/dev/tty`; the answer sets the row. When no terminal is reachable (CI, pipes, `--check`, non-interactive `vulyk-update.sh`) there is no prompt and the row is, or becomes, `off`. `/vulyk-bootstrap` shows the current value instead of asking again. A generalised `wire_hook` wires `anomaly-scan.sh` on Stop and SessionEnd into existing hives. The installer never ships `memory/stats/anomalies.jsonl`. CI install-smoke cases and the local suite cover every branch.

## Requirements
> При апдейте вулика либо при первой установке нужно, чтобы он в терминале спрашивал у пользователя, хочет ли он включить телеметрию, и объяснить, что это, и сказать, что по умолчанию она выключена.
> строка Telemetry в Профиле, по умолчанию off: новая строка в таблице Profile конституции, /vulyk-bootstrap спрашивает её одним вопросом, установщик дописывает её старым хайвам как off.
> Правильно завернуто в фреймворк VULYK, чтобы не потерялось.

## Files
- CLAUDE.md
- bootstrap/interview.md
- .claude/commands/vulyk-bootstrap.md
- install.sh
- scripts/vulyk-update.sh
- .github/workflows/ci.yml
- tests/telemetry.test.sh

## Non-goals
- Do not touch `scripts/telemetry.sh`, `anomaly-scan.sh`, `handoff.py`, VULYK's own `settings.json`, README, `docs/telemetry.md` or the `telemetry-inbox` CI job (stories 01-04). Touch `ci.yml` only inside the install-smoke job.
- Do not rewrite a hand-written Profile without markers (ADR-005 D4.9: warn, never rewrite). The only permitted change to a filled marked block is the one `Telemetry` row: append it when missing, replace its value when the question was answered (A10). Every other byte stays.
- Do not rely on git checkout side effects for the row text: the bytes come from the source checkout's `CLAUDE.md` (the 0.13.3 lesson) or one string constant used by fresh install and upgrade alike - never two copies.
- Do not read the answer from stdin: `install.sh`'s existing `read` calls are pipeline loops over `find`/`ls` (lines 70, 256, 503, 520) and a piped install has no answer on stdin. Read `/dev/tty`, guarded by `[ -t 0 ] || [ -r /dev/tty ]`; one question, one read, `off` on empty or EOF. Never prompt under `--check`.
- Do not add stdin plumbing to `vulyk-update.sh` - line 76 already runs `install.sh --upgrade` in the foreground with inherited stdin; only the flag/env passes through.
- Do not change what `wire_session_hook` does for SessionStart or any of its CI cases; `wire_hook` generalises it, it does not re-order or rewrite existing entries.
- No exclusion for a top-level `telemetry/` - `copy_tree` never copies it (A11). Do not add a gitignore entry for `memory/stats/anomalies.jsonl` (brief Answer 1).
- Keep the explanation to 4-6 lines; no second question in `bootstrap/interview.md` - it reports the current row and how to change it.

## Map slice
recon/hooks-and-stats.md §5 (OWNED, `shippable()`, `ensure_gitignore()`, the `skills.json` seed precedent) and §1 (the `settings.json` hook groups); recon/weekly-and-publish.md Entry points (`vulyk-update.sh:76` hands off to the fetched release's `install.sh --upgrade`); ci.yml install-smoke case names at lines 313-386 (D4.7-D4.11); plan.md `## Contracts` (Consent row, `consent` verb, installer prompt, `wire_hook`) and A6, A10, A11, A13; memory/map/agents-and-commands.md `/vulyk-bootstrap`.

## Acceptance criteria
- [ ] `CLAUDE.md` Profile table has the plan's `Telemetry` row after *Release / deploy*, `off` literal (not `<fill in>`), and `bash scripts/telemetry.sh consent` prints `off` in this repo.
- [ ] Fresh `install.sh` with a reachable terminal prints the 4-6 line explanation (what is collected = the enum names, what never, where it goes, default off) and the question `Enable telemetry? [y/N]`, reading the answer from `/dev/tty`; `y`/`yes` writes the row as `on`, anything else (including empty) writes `off`. With no terminal, or under `--check`, or with `VULYK_TELEMETRY=on|off` / `--telemetry on|off`, no question is printed and the row is set per A10.
- [ ] `install.sh --upgrade` into a hive whose marked Profile block is filled and lacks `| Telemetry |`: with a terminal asks the same question and appends exactly one line inside the block after the last table row; without one appends it as `off`. A block whose row is already `on` or `off` is byte-identical after upgrade and no question is asked, unless `--telemetry ask` / `VULYK_TELEMETRY=ask` (or an explicit `on|off`) is given, in which case only that row's value changes. `--check` reports the pending insertion and writes nothing.
- [ ] `wire_hook <event> <script>` exists and `--upgrade` uses it to wire `.claude/hooks/anomaly-scan.sh` on `Stop` and `SessionEnd` in the hive's `settings.json`: added when absent, unchanged when present (a second upgrade is byte-identical), every existing entry preserved, `--check` reports only. SessionStart wiring and its existing CI cases are unchanged.
- [ ] `scripts/vulyk-update.sh` accepts `--telemetry <v>` and forwards it (and `VULYK_TELEMETRY` by environment) untouched to the fetched release's `install.sh --upgrade`; no other behaviour of the wrapper changes.
- [ ] `bootstrap/interview.md` Batch 2 gains one line that shows the current `Telemetry` row value (via `bash scripts/telemetry.sh consent`) and says how to change it (`install.sh --telemetry ask`, or edit the row) - it does not ask; `vulyk-bootstrap.md` prints that value in its Profile summary.
- [ ] `shippable()` classifies `memory/stats/anomalies.jsonl` as runtime/not-shipped; the existing "ships no runtime artifact" install-smoke cases stay green with that file planted.
- [ ] `ci.yml` install-smoke (no terminal): the "never touches an already-filled Profile block" case (recon: line 313) is amended to allow only the appended `Telemetry` row; cases added: row appended as `off` when missing; byte-identical when present; `VULYK_TELEMETRY=on` sets `on` on a fresh install; `--check` never writes the row; `--upgrade` wires the two `anomaly-scan.sh` entries idempotently.
- [ ] `tests/telemetry.test.sh` gains, in the section story 01 marked: `bash -n install.sh`; the no-terminal upgrade and `wire_hook` cases above; a terminal case driven through `script`/a pseudo-terminal when available (skipped with a printed reason otherwise), asserting the explanation text names `off` as the default and `y` lands the row as `on`; and a piped-stdin case (`echo y | install.sh ...` with no tty) asserting the row is `off` - stdin is never the answer channel.

## Verification
`bash tests/telemetry.test.sh`

## Implementation notes

## Findings
