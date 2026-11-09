---
story: mass-audit-fixes-03
spec: mass-audit-fixes
status: todo
returned:
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: bare clock time
---

# defect-intake: a bare clock time is not a correction; a filing phrase inside a paste asks first

## Goal
`.claude/hooks/defect-intake.sh` stops filing «at 14:32 the build ran» / «в 14:32 упал билд» as a correction
quote: a timecode counts only next to a media cue (video/ролик/кадр/сек/frame and the like) or a correction
word; media-heavy hives keep their recall. «снова» / "again" stay out of the lexicon (owner decision). The
explicit filing phrase («внеси в запрет», "add this to the never list") is matched on the typed text only:
found solely inside a `<pasted_content>` block or a quote, the hook emits the "ask the owner whether these are
their words before filing" line instead of the write-now line, unless the paste starts with the dictation tag
(`VULYK_DICTATION_TAG`). Contributor limit (1) of P10-08; private audit (2026-11-08) finding S3 and card
`owner-words-by-builder`. Marked red: parser branches.

## Requirements
> 7. P10-08 extended: a bare clock time in typed text is no longer filed as a correction; «снова» / "again" stay out of the correction words.
> 11. Every finding of our private audit that the merged branch does not close (Scope E) is fixed, with a regression test wherever code can check it.

## Files
- .claude/hooks/defect-intake.sh
- tests/intake.test.sh

## Non-goals
- Do not add «снова» / "again" back, and do not widen the lexicon elsewhere.
- Do not change the `--lexicon` export format or the correction pass on quotes.
- Do not touch `defects-inject.sh` (story 01) or `docs/hooks-reference.md` (story 13).

## Map slice
`memory/map/scripts.md` → Entry points (hooks), Gotchas; `memory/map/agents-and-commands.md` → Commands
(`/vulyk-plan` step 2 is unaffected; read for the intake's place in the flow only).

## Acceptance criteria
- [ ] Typed «at 14:32 the build ran» and «в 14:32 упал билд» produce no correction line; typed «в 00:42 на
  ролике не то» and «at 01:15 in the video, wrong» still do; a correction word next to a timecode still does.
- [ ] A prompt that is only a paste holding «add this to the never list» yields the ask line, not the write-now
  line; the same phrase typed yields the write-now line; a paste starting with the dictation tag yields the
  write-now line.
- [ ] `--lexicon` prints no «снова» and no "again".
- [ ] The failing-test label for the timecode case contains `bare clock time`; the S3 case's label contains
  `phrase inside a paste`.
- [ ] `bash tests/intake.test.sh --part latency` stays within its cap (no new Python start on the no-match path).

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes

## Findings
