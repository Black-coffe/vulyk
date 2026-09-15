<!-- seat: haiku · model: claude-sonnet-5 · round: 2 · head: 8b80941 · pack: 3a929636825c · attempt: 1 · recorded: 2026-09-15T18:38:07Z -->
COUNCIL: driver-hardening · round 2 · seat haiku
MODEL: claude-sonnet-5
COURT: E:/Projects/vulyk/.vulyk/court/driver-hardening/round-2
VERDICT: N/A
ASSUMED CONFIG: Profile unfilled (`<fill in>` placeholders for Stack, Client path, Browser MCP) - this is VULYK's own repo, which per its own Commands section has not run /vulyk-bootstrap on itself
RAN: bash scripts/cycle.sh (usage) ; bash scripts/cycle.sh status/open-round/close-story/record-seat/judge/branch (no args, usage errors) ; bash scripts/cycle.sh status docs/specs/anomaly-telemetry --json ; git status --porcelain before/after
PATH: scripts/cycle.sh is the only CLI entry point in COURT relevant to these asks. Read-only invocations (usage errors, `status --json`) work and returned JSON. All 5 asks concern internal behaviour of mutating verbs or an out-of-process clerk/driver relay, none reachable without either (a) reading source, which this seat is barred from, or (b) writing/mutating inside COURT (creating dirty git state, fake story files, malformed clerk relay output) to trigger the code paths, which this seat is also barred from ("Writing inside it is forbidden"). No URL, no browser surface, Browser MCP row blank.
ASK 1: N/A - why: клерк retry on unreadable JSON line - requires simulating a garbled sub-agent (clerk) relay mid-driver-run; no CLI entry point exposes this, and I have no access to dispatch a hive/clerk sub-agent from this seat to reproduce it.
ASK 2: N/A - why: skills.json / memory/learnings/*.md as cycle paperwork (not blocking/aging open-round) - only observable by running `open-round` against a spec with those files dirty; doing so requires writing files inside COURT and committing, both forbidden here.
ASK 3: N/A - why: close-story accepting a self-marked `status: done` story with uncommitted diff - only observable by writing a story file with that status and an uncommitted diff, then running close-story; writing inside COURT is forbidden.
ASK 4: N/A - why: taint_reason() treating a bare `<slug>-NN` token as non-leaking while still catching file paths - only testable by feeding record-seat a crafted report (stdin) against a real round directory; docs/specs/driver-hardening in COURT holds only brief.md (no round dir, no council/), and record-seat itself writes report files on success, which is forbidden here.
ASK 5: N/A - why: mutating verbs (branch/close-story/open-round/record-seat/judge) returning `next` in their own JSON so the driver only polls status at start - confirmed the *error* envelope already carries a `next` key (e.g. `{"ok":false,"verb":"open-round","exit":1,"next":"error","error":"usage"}`) for every verb tried, but the success-path JSON (the actual ask) can only be observed by completing a real mutating run, which writes/commits and is forbidden inside COURT.
UNASKED: none
BREACH: none
