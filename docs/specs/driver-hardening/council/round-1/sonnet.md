<!-- seat: sonnet · model: claude-sonnet-5 · round: 1 · head: 6ae3d99 · pack: 92f41ba75c4c · attempt: 1 · recorded: 2026-09-15T17:05:13Z -->
COUNCIL: driver-hardening · round 1 · seat sonnet
MODEL: claude-sonnet-5
COURT: E:/Projects/vulyk/.vulyk/court/driver-hardening/round-1
VERDICT: GREEN
ASSUMED CONFIG: VULYK's own repo, unbootstrapped (Profile still `<fill in>`) - shell+Python+markdown toolkit, no compiler/build; Commands table taken as-is from CLAUDE.md
RAN: git ls-files '*.sh' | xargs -n1 bash -n; python -m py_compile .claude/hooks/*.py; git ls-files '*.json' | xargs -n1 jq -e .; bash .claude/hooks/handoff.sh status; bash tests/cycle.test.sh; bash tests/driver.test.sh; bash tests/telemetry.test.sh; bash tests/council.test.sh
PATH: none: library/CLI only - client path is the `## Commands` table, walked in full
ASK 1: GREEN - unreadable clerk status line -> driver retries once, then stops - run: bash tests/driver.test.sh saw: "ok C1: a non-JSON clerk line is re-asked once, then proceeds" / "ok C1: two non-JSON clerk lines end the run with the raw second" / "ok C1: a Paused result on the retried attempt is not swallowed"
ASK 2: GREEN - skills.json and memory/learnings/*.md are cycle paperwork: do not block or stale open-round - run: bash tests/council.test.sh saw: "ok status --json stale:false after a skills.json + learnings-only commit" / "ok skills.json + memory/learnings/*.md dirty alone do not trip 'working tree not clean'"
ASK 3: GREEN - close-story accepts a self-marked status: done story with an uncommitted diff; worker-code.md tells the worker not to touch status - run: bash tests/council.test.sh saw: "ok self-marked done + dirty diff -> exit 0" / "ok journal.md gained the self-mark line"; run: grep -n status .claude/agents/worker-code.md saw: "Never edit the story's `status:` line - `close-story` writes it ... you write `returned:` only."
ASK 4: GREEN - a bare story id <slug>-NN is not a leak; the story file and prior paths still are - run: bash tests/council.test.sh saw: "ok bare <slug>-NN (demo-01) in body -> accepted, not tainted (C4: synthesized id)" / "ok <slug>-NN.md (demo-01.md) -> tainted" / "ok <slug>/<slug>-NN (demo/demo-14) -> tainted" / "ok docs/specs/<slug>/<slug>-NN.md -> tainted"
ASK 5: GREEN - the five mutating cycle.sh verbs return next in their own JSON; driver polls status only at start and after parallel steps - run: bash tests/driver.test.sh saw: "ok C6 carried: steady Tier 3 round costs 13 clerk calls and 3 status polls" / "ok C6 judge -> repair: the carried status routes the repair with no poll between"; run: bash tests/council.test.sh saw: "=== Story driver-hardening-03 ... === ok branch --commit carries the post-commit status" / "ok judge --commit on a GREEN fixture: status.next green, status.verdict GREEN" / "ok close-story exit 4 (returned: WALL): no status key, line unchanged"
UNASKED: none
BREACH: none
