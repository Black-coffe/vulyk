<!-- seat: review · model: unknown · round: 1 · head: 6ae3d99 · pack: 92f41ba75c4c · attempt: 1 · recorded: 2026-09-15T17:05:32Z · verdict: PASS -->
VERDICT: PASS

Reviewed: branch vulyk/driver-hardening at 6ae3d99 vs base b74e13c (20 files). Scope: every touched file is named by a story or is cycle paperwork (story files, plan.md Branch line, journal.md, ROUND, scope.jsonl, anomalies.jsonl) - no Law 3 violation. No docs/wiki/ directory exists; invariants checked against ADR-001/006/009 and memory/map/scripts.md Gotchas (whitelist anchoring holds: the two new entries are exact / one-level). Ran only: taint_reason() directly against real story-file name shapes (below). Suites not re-run.

## Major

1. E:/Projects/vulyk/scripts/cycle.sh:1176-1177 - plan - The taint detector must catch the story file in the form the repo actually produces: every one of the 74 story files under docs/specs/ is `<slug>-NN-<title>.md`, none is `<slug>-NN.md`, and `taint_reason 'cat demo-14-title.md' demo` returns clean (verified) while the pre-change regex caught it; a seat that types the real basename without a directory prefix now passes untainted. C4 prescribed the exact regex, so the gap is the contract's; the condition to satisfy is that `<slug>-NN-<anything>.md` (with or without `docs/specs/<slug>/`) is taint while a bare `<slug>-NN` stays clean.

2. E:/Projects/vulyk/.claude/workflows/vulyk-cycle.js:94-98 - plan - A re-dispatched clerk prompt must not turn a succeeded mutating verb into a run-ending failure: when the first `close-story --commit`, `record-seat` or `judge --commit` actually ran and only its relay line was garbled, the identical second dispatch hits `already done` (cycle.sh:1521-1523, tree now clean so the C3 tolerance does not apply) or `already recorded` (cycle.sh:1388), both exit 2, which the build branch (:222) and the dispatch branch treat as a stop. Plan A4 chose "every verb"; the ask's recovery intent holds only for verbs that are idempotent on re-run (`status`, `claim`, `branch`, `open-round`). Condition: either the retry is limited to verbs whose re-run is idempotent, or a re-run of a just-succeeded `close-story`/`record-seat` returns ok with its carried status the way `open-round`'s no-op path does.

3. E:/Projects/vulyk/docs/adr/011-driver-hardening.md:103 - worker - ADR-011 records "the top-level `next` of a verb's JSON always equals `status.next` when `status` is present" as an invariant, but story 03's own implementation notes say the opposite was built deliberately (`next` stays the verb's own value; the two differ on a plan with no Briefed line or a round whose pack moved) and `emit_status` (cycle.sh:73-82) only defaults to `status.next` when the caller passes none. The ADR must state the relation as built (equal on a well-formed spec, verb-owned otherwise) or the code must be changed to match it; story 05's map slice named story 03's notes.

4. E:/Projects/vulyk/docs/specs/driver-hardening/plan.md:77 - plan - C5 says "The top-level `next` of that JSON equals `status.next`"; the delivered behaviour narrows that to "coincide on a well-formed spec" and `## Plan deltas` is empty. The delta must be on the record in `## Plan deltas` (it is currently only inside story 03's `## Implementation notes`).

## Minor

5. E:/Projects/vulyk/scripts/cycle.sh:1527 - worker - The self-mark journal line hardcodes `build:1` as its `next`, so a wave-2/3 story journals "next: build:1"; the line must carry the real next (the `status --json` next, or the wave the story belongs to).

6. E:/Projects/vulyk/scripts/cycle.sh:1527 - plan - The journal line is appended before the `returned:` check, so a self-marked story that then exits 4 (`returned: missing`, red verification, scope breach) adds one journal line per attempt and the exit-4 acceptance case does not assert journal state; C3 prescribed this order. Condition: the self-mark is journalled once per closing story, or the exit-4 case asserts the line count it accepts.

7. E:/Projects/vulyk/docs/adr/011-driver-hardening.md:88 - worker - The quoted C5 key list begins with `status,` which `status --json` (cycle.sh:466) does not emit; the acceptance criterion said "quoted, not paraphrased", and the quote is wrong. Condition: the key list matches `cmd_status`'s printf byte for byte.

8. E:/Projects/vulyk/scripts/lib.sh:46-49 - plan - Widening `is_paperwork_path` also changes `paperwork_only` at ship-check.sh:203 and :273 (council/human staleness at ship) and human-check.sh:62, so a commit of `skills.json`/learnings between judge and ship no longer stales a verdict or an ACCEPTED check; consistent with the ask, but neither plan A1 ("changes `open-round` and staleness only") nor ADR-011 decision 2 names those callers. Condition: ADR-011's invariant for decision 2 lists every `paperwork_only` caller the widening reaches.

9. E:/Projects/vulyk/.claude/agents/worker-test.md:21 - plan - `worker-test.md` still says "`close-story` and the driver read this key" while `worker-code.md:18` was corrected to "the driver never opens the story file"; C7 only named worker-code for that phrase, so the two agents now contradict each other on a fact story 01 declared false. Condition: both agent files carry the same true sentence.

10. E:/Projects/vulyk/scripts/cycle.sh:73-82 - worker - If `cmd_status` inside `emit_status` fails (the usage branch, cycle.sh:297-300, emits `{"ok":false,"verb":"status",...}` on stdout), that object is embedded verbatim as `status`, `carriedStatus()` accepts it (it is an object with `ok:true` on the outer line), and the driver reads `next: "error"` and returns an unrecognised-next stop with no error text; a carried `status` must be a status object or absent, never an error envelope.

11. E:/Projects/vulyk/docs/adr/011-driver-hardening.md:9 - worker - "The anomaly-telemetry circle's round 6 surfaced five defects" - per the brief only ask 4 came from round 6; the clerk `]`, the dirty-tree refusals and the self-mark were met at launch and between waves. Condition: the Context paragraph attributes each defect where the brief does.

12. E:/Projects/vulyk/tests/council.test.sh:1589-1596 - worker - The C2 open-round case proves "not refused as unclean" only indirectly, by asserting the *next* precondition's exit 2 with `grep -qiF 'tier'`; it would still catch the regression (the dirty-tree message contains no "tier"), but a future message rewording could make it pass vacuously. Condition: the case asserts the absence of `working tree not clean` explicitly.

## Verification claims checked

- Story 04 "reverting only vulyk-cycle.js turns exactly (ag), (aj) red while (ah)/(ai) stay green": consistent with the scenarios as written - (ah) stubs verbs without `status` and (ai) a non-ok result, both of which the old loop also satisfies; (ag) asserts 13/3 and (aj) asserts no poll between judge and queen-planner, both false on the old loop. Claim holds.
- Story 02 scenarios (ad)(ae)(af) assert dispatch count, raw second line and Paused propagation - real behaviour assertions, not run-only.
- Story 03 `c5_check` compares the carried object to a `status --json` call made immediately after via `jq -S`, plus key order and one-JSON-line - real assertions; the `next == status.next` assertion passes only because the fixture is well-formed (see finding 3/4).
- Story 01 C3 cases assert exit code, journal line, status line, commit count and HEAD-unchanged on exit 4 - real assertions.
- `tests/telemetry.test.sh:339-343` also tests `is_paperwork_path`; no story's verification ran it, but its three cases (anomalies.jsonl true, other.jsonl false, bare basename false) are unaffected by the widening.
