<!-- seat: haiku · model: claude-sonnet-5 · round: 4 · head: 3984652 · pack: 07a6a02fb6fb · attempt: 1 · recorded: 2026-09-15T09:53:31Z -->
COUNCIL: anomaly-telemetry · round 4 · seat haiku
MODEL: claude-sonnet-5
COURT: E:/Projects/vulyk/.vulyk/court/anomaly-telemetry/round-4
VERDICT: GREEN
ASSUMED CONFIG: no Client path/Browser MCP filled in Profile; VULYK is a shell/Python CLI toolkit, no server - walked scripts/telemetry.sh and install.sh directly as a client would
RAN: telemetry.sh enum|agents|check|consent|bundle|publish|scan|record; install.sh into fresh temp dirs with --telemetry off/on/ask (no tty); publish with VULYK_LOCAL set and unset
PATH: CLI entry points scripts/telemetry.sh and install.sh, run end-to-end (fresh install -> consent row -> record anomaly -> bundle -> publish recipe)
ASK 1: GREEN - all terminals monitor anomalies and keep a log - `telemetry.sh enum` lists 8 codes, `record`/`scan` append to memory/stats/anomalies.jsonl (12-key local row, verified format)
ASK 2: GREEN - weekly send to VULYK repo: local PR / remote fork PR - `publish` with VULYK_LOCAL unset printed the 11-line `gh repo fork ... gh pr create` recipe; with VULYK_LOCAL set to a local checkout it wrote to telemetry/inbox/ and printed a `git add/commit/push` recipe - never executed either
ASK 3: GREEN - logs maximally anonymized - bundle row has exactly 10 keys (code, value, threshold, vulyk, tier, model, agent, week, hive-hash), no paths/spec/story; `telemetry.sh check` on the produced bundle exited 0
ASK 4: GREEN - wrapped into the framework - /vulyk-evolve.md step wires enum/consent/publish/inbox; /vulyk-bootstrap.md documents the Telemetry Profile row and defers asking to the installer
ASK 5: GREEN - public repo documentation - README.md has a "Anomaly telemetry — opt-in, anonymized, never automatic" section; docs/telemetry.md is the full contract (schema, consent, publish, weekly cycle, CI check)
ASK 6: GREEN - install/update prompts for consent, default off, explained - `install.sh --telemetry on|off|ask`: `off` and `ask` (no tty, non-interactive) both wrote `Telemetry | off`, `on` wrote `Telemetry | on`; docs confirm interactive prompt runs over /dev/tty with explanation text
UNASKED: none
BREACH: none - one self-inflicted stray write into COURT (telemetry/inbox/2026-W38/*.jsonl and memory/stats/anomalies.jsonl, from running `scan`/`publish` with cwd/VULYK_LOCAL pointed at COURT) was caught and reverted via `rm` + `git checkout --` before finishing; git status in COURT is clean
