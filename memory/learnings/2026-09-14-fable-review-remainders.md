---
name: fable-review-remainders-2026-09-14
description: Lessons from the fable-review-remainders build (v0.13.1) - the NEEDS_CONTEXT stop, a worker's botched story edit, journal-after-commit, the ship-gate staling commit, and on-disk report discipline.
metadata:
  type: project
---

**NEEDS_CONTEXT stop on story 06 (worker driver, two `returned NEEDS_CONTEXT` misses).**
The worker's finding: C3's third failure class ("text without a report") was unreachable
through the stub interface story 06 was told to keep - the pre-story driver only ever
classified empty vs. non-empty, and "no report" *was* the empty case renamed. Three rulings
were offered (strike the class / test it as defensive residue / make it real); the Queen chose
"make it real" because the owner had confirmed it as one of three named reasons in the grill,
and only the human removes a confirmed requirement. This produced story 07 (content-check
via `STATUS:`/`VERDICT:` grep), which round-1 council later BLOCKed (critical 1: it made the
driver decide on a worker's chat prose, contradicting ADR-006 and ADR-001 C11 without amending
either). Story 08/09 re-derived the third reason from verb exit codes instead. See
[[dispatch-failure-reasons-adr-009]] (docs/adr/009-dispatch-failure-reasons-and-report-by-file.md).
**Lesson:** when a worker reports a contract gap mid-build, the fix that satisfies the letter
of the ask can still violate an existing, unamended ADR - check the invariant list, not just
the ask, before ruling.

**Worker overwrote its own story body.** The story-06 worker's Edit clobbered
`## Non-goals` through `## Verification` with its finding text (a botched Edit, not malice).
The Queen restored the body from the pre-edit commit and appended the finding under
`## Findings` instead. **Lesson:** a worker's mid-story finding belongs in a `## Findings`
section appended, never as a replacement of the story's structural sections - if a diff shows
missing headers where the story previously had them, restore from git before trusting the
worker's rewrite.

**Journal written after the commit.** Recurring friction: the build journal entry landed in a
commit after the code commit it describes, leaving the tree dirty between them. Not yet fixed;
flagged for the next circle.

**Release-paperwork commit staled the ship gate.** A commit made purely for release paperwork
(version bump / changelog) after the code commit caused `ship-check.sh` to see a HEAD it hadn't
validated. Order matters: paperwork commits that follow the last validated commit re-open the
gate's assumptions.

**Every seat/reviewer report was on disk before its agent returned, both rounds.** The
file-by-path recording design (`record-seat --file <path>`, agent writes its report as its
last Bash action) held for round 1 and round 2 of this spec's council - no report was lost to
truncation or a missing file, and the `--file` attempt was the only check needed (no separate
`test -s` probe). This validates the plan's C1/C2 contracts in practice, not just on paper. See
[[dispatch-failure-reasons-adr-009]].
