---
story: mass-audit-fixes-03
spec: mass-audit-fixes
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: bare clock time
red_verified_at: 2026-11-09T13:12:54Z d64e3ae63edabfdfe8c08f20588a2bf224e4c905e962fa3d54ff2ca420fb8f80
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
- .claude/hooks/defect-intake.sh: `triggers()` takes a timecode only with a MEDIA cue (video/ролик/кадр/сек/frame/voice/голос/audio/звук/clip/track/subtitle...) or a lexicon word within NEAR=48 chars; shared, so the answer pass gets it too.
- Same file: the phrase is matched on typed text (pastes and quotes cut, a dictation-tagged paste kept); found only in the raw text (paste, quote or fence) it returns the new `phrase_ask_lines` ask line.
- Decision: a phrase inside a ``` fence also asks first (the fence is cut from typed text like before); «снова»/"again" untouched.
- tests/intake.test.sh: bare-clock and S3 cases plus neighbours, a --lexicon снова/again check; two fixtures that relied on a bare timecode ("at 10:04 again", the cwd case) now say "in the video"; the old in-paste phrase case flips to the ask.
- Surprise: latency median is ~230-270 ms both for HEAD and this hook under parallel-worker load (cap 200 ms); no new Python start was added.

## Findings

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: d64e3ae63edabfdfe8c08f20588a2bf224e4c905e962fa3d54ff2ca420fb8f80 (tests/intake.test.sh)
- impl: a1d73eb2c7d3f8d4855e7387bde34df1a5cc6cf74e8f332451a2a6872b6b97ae
- stamped: 2026-11-09T13:12:54Z

```
::error::P10-08: a bare clock time (at 14:32 the build ran) is silent - expected no output and exit 0, got:
::error::P10-08: a bare clock time (в 14:32 упал билд) is silent - expected no output and exit 0, got:
  ok    --lexicon exits 0 without reading stdin
  ok    a stem matches at a word start (переделайте)
  ok    neighbour: a stem inside a word does not match
  ok    a phrase with a punctuation edge matches (i told you!)
  ok    neighbour: a phrase needs both edges (i told yours)
  ok    P10-08: the export has no bare "again"
  ok    P10-08: --lexicon prints no «снова» and no "again"
  ok    a capitalised Cyrillic stem matches under a UTF-8 locale
  ok    one ERE line per stem and phrase of the hook's own lists
intake.test.sh: 119 checks, 6 failed
```
