---
story: anomaly-telemetry-05
spec: anomaly-telemetry
status: done
returned: DONE
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
- `CLAUDE.md`: the `Telemetry` row added after *Release / deploy* inside the PROFILE markers, `off`; `install.sh`'s `telemetry_row()` is the single source of that string and the fresh-install placeholder ends with `telemetry_row off`, so the CI row-count check stays honest.
- `install.sh`: arg loop became a `while`/`shift` loop for `--telemetry <v>`; `telemetry_row_value`, `telemetry_constitution`, `telemetry_tty`, `print_telemetry_explanation`, `telemetry_decide` (A10 precedence) run before the constitution block, `ensure_telemetry_row` after it - on whichever file is the constitution now (sidecar included). The row edit replaces only the first alphabetic token of the value cell, so backticks and an owner-edited description survive.
- Terminal test: `[ -t 0 ]`, else `[ -r /dev/tty ]` **and** an actual `( exec 3< /dev/tty )` open. The `-r` test alone is true on GitHub runners (the device node is mode-readable while opening it fails), which would have printed the question into CI logs.
- Decision: `--telemetry ask` with no terminal and an existing row leaves the row alone rather than resetting it to `off` - A10(5)'s `off` default is written for a *missing* row.
- `wire_hook <event> <script>` + `py_wire` (the python heredoc, now taking `event` and `--dry`); `wire_session_hook` is a one-line wrapper. The "already wired" test is per event, not per file, or a script on Stop would never reach SessionEnd; `--check` runs the same python with `--dry` and falls back to the old file-wide grep when python is absent.
- `wire_hook Stop|SessionEnd anomaly-scan.sh` is called unconditionally beside the SessionStart pair (not only under `--upgrade`): a fresh install into a project that already has its own `settings.json` needs it too, and it is idempotent.
- `vulyk-update.sh`: `--telemetry <v>` parsed and forwarded as an array; `TELARGS=()` assignment is an `if`, not `&&` - a top-level `&&` that yields 1 kills the script under `set -e`.
- Verified: `bash tests/telemetry.test.sh` - 125 checks, 0 failed (the pseudo-terminal case skipped here, no util-linux `script` on this box; not observed green on this branch - skipped locally). Also green: `bash -n` over all shell files, `py_compile`, `jq -e` over all JSON.

## Findings
- `scope-check.sh` reports 3 out-of-scope paths - `memory/learnings/2026-09-14_222936.md`, `memory/stats/anomalies.jsonl`, `memory/stats/skills.json`. All three were already untracked/modified in the working tree when this story started (see the session's git status); this story touched none of them.
