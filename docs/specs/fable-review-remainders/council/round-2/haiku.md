<!-- seat: haiku · model: claude-sonnet-5 · round: 2 · head: e166c48 · pack: 37a505564b66 · attempt: 1 · recorded: 2026-09-14T14:49:20Z -->
COUNCIL: fable-review-remainders · round 2 · seat haiku
MODEL: claude-sonnet-5
COURT: E:/Projects/vulyk/.vulyk/court/fable-review-remainders/round-2
VERDICT: N/A
ASSUMED CONFIG: none given - Profile in COURT/CLAUDE.md has all fields as unfilled `<fill in>` placeholders (Stack, Client path, Browser MCP, Configurations, Release/deploy)
RAN: ls/find on COURT tree, read brief.md and CLAUDE.md Profile section; no scripts executed, no writes made
PATH: none named - Client path field is the literal placeholder text, not "none: library only" or a URL/CLI entry; no running service or documented CLI entry point to walk from outside
ASK 1: N/A - why: install.sh --upgrade byte-identical block insertion (head/tail vs EOF path) plus ci.yml D4.7 content check - exercising this would require running install.sh with writes, which is forbidden inside COURT (writes are discarded/prohibited per the honour clause), and there is no separate target directory to install into; no client path is defined to reach this from outside
ASK 2: N/A - why: LR31 is an internal scenario in tests/council.test.sh (wave_stories behavior on ready vs blocked stories); verifying it requires running the test suite, which is explicitly forbidden for this seat, and there is no external interface exposing wave_stories
ASK 3: N/A - why: "shown to fail at <sha>" probe behavior and the council CI job's fetch-depth are internal to tests/council.test.sh and .github/workflows config; no client-observable surface, and confirming behavior needs running the suite or reading CI source, both out of bounds
ASK 4: N/A - why: release's pause-guard exemption is a scripts/cycle.sh internal behavior (cmd_release calling or not calling pause_guard); no CLI entry documented in Profile Client path, and invoking cycle.sh release against a paused spec in COURT would require writes/state changes forbidden here
ASK 5: N/A - why: driver's three-way dispatch-failure classification (worker threw / empty return / text without report) is internal driver logic verified by tests/driver.test.sh; running the test suite is forbidden and there is no external interface to trigger and observe this distinction black-box
ASK 6: N/A - why: record-seat --file <path> behavior is an internal CLI flag of scripts/cycle.sh exercised by the test suite; no documented client path to invoke it standalone, and confirming file-vs-heredoc fallback requires reading source or running the forbidden suite
UNASKED: none
BREACH: none
