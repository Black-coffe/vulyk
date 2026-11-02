---
story: gate-split-02
spec: gate-split
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason:
---

# close-story and stamp-red: a cap per line, a resume mark, a repair keeps only its own lines

## Goal
`verify_run` (callers `cmd_close_story`, `cmd_stamp_red`) stops sharing one 540 s budget across every line. Each line
runs under its own cap (`VULYK_VERIFY_TIMEOUT`, default 300, clamped to 300); a line starts only when it fits the
call's budget (`VULYK_VERIFY_CALL`, default 540; the first line always runs); otherwise the verb writes
`verify_resume:` into the story frontmatter and exits 7, and the same command resumes there while the `## Files` hash
still matches. `cmd_repair` writes a `## Verification` that keeps only the deduped lines covering the paths its
`## Findings` name. Workers and the Queen's `/vulyk-build` learn exit 7: run the same command again.

## Requirements
> 6. Проверка перед закрытием истории: лимит на строку, исправление берёт только проверки своих файлов, продолжение с отметки.

## Files
- scripts/cycle.sh
- tests/council.test.sh
- tests/cycle.test.sh
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- .claude/commands/vulyk-build.md

## Non-goals
- Do not add the `suite` verb, touch `record-seat`/`judge` SUITE handling or cut the `replays` part: that is
  `gate-split-04`, next wave, in the same files.
- Do not narrow a repair story's `## Files`: the worker may still touch any done story's file; only the
  verification is filtered (plan Assumptions).
- Do not change the timeout message shape: `timed out after <N>s` stays, N = the per-line cap, so the asserts at
  `tests/council.test.sh` 3822 and 4200-4218 keep their meaning (update the numbers they expect only if N changes).

## Map slice
memory/map/cycle.md `## Verbs` (Red receipt, close-story bullets), `## Repair (ADR-013 D4)`; memory/map/scripts.md
`## Entry points` (`run_capped`, `set_hash`, `sealed_tests`), `## Gotchas`; memory/map/agents-and-commands.md
`worker-code / worker-test`; plan.md `## Contracts` (Verification, Repair `## Verification`).

## Acceptance criteria
- [ ] Two verification lines that together exceed the call budget (fixture: short sleeps with a small
      `VULYK_VERIFY_TIMEOUT` and `VULYK_VERIFY_CALL`) no longer fail on a shared budget: the first call runs line 1,
      writes `verify_resume: close-story 2 <hash>`, exits 7 with `"resume":2`; the second call runs line 2 and closes.
- [ ] A changed `## Files` set between the calls (hash differs) restarts at line 1; a finished verb leaves no
      `verify_resume:` line. `stamp-red` resumes the same way and keeps its refusals (no failing line with
      `red_reason`, 126/127, a timed-out line) unchanged.
- [ ] A line over its cap still fails exit 4 with `timed out after <N>s`; `VULYK_VERIFY_TIMEOUT` above 300 acts as 300.
- [ ] `cmd_repair`: `## Verification` lines are deduped and kept only when a path token hits a path named in the
      repair's `## Findings` (each finding starts with its path; the `wave-check` overlap rule); when the findings
      name no path or none survives, the lines hitting `## Files`; when none of those either, the deduped union.
- [ ] `worker-code.md`, `worker-test.md` (close step) and `vulyk-build.md` (solo close) say: exit 7 = run the same
      `close-story`/`stamp-red` command again, it resumes; it is not a failure and costs no retry.
- [ ] Red first: this story's `stamp-red` runs under today's `verify_run` (one 540 s total), so its two lines are
      chosen to fit it. Put the new cases in the `advance` or `roster` part; `tests/cycle.test.sh` is in `## Files` only
      for asserts the change breaks (recon question 5), and the round runs it whole.

## Verification
`bash tests/council.test.sh --part advance`
`bash tests/council.test.sh --part roster`

## Implementation notes

## Findings
