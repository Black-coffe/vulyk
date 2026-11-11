---
story: upgrade-findings-03
spec: upgrade-findings
status: done
returned: DONE
tier: 3
worker: worker-code
model: opus
wave: 2
blocked_by: [upgrade-findings-01]
red: required
red_reason: a hand-written resume mark is ignored
red_verified_at: 2026-11-10T21:57:13Z f14d60565146511e19122b540dd9f52b9823065af21b8ad61f0b9d4d5e845b17
---

# The verification runner keeps its resume point and results in state the cycle owns

## Goal
Why `model: opus`: the store is shared by two gates and by story 05, and a wrong key or a missed re-check
weakens `close-story` without a sound.

`scripts/cycle.sh` gets the state directory of plan.md `## Contracts` S1 and the verify record S2.
`verify_pause` writes the record under `.vulyk/state/<slug>/` instead of a `verify_resume` line in the story;
`verify_resume_start` reads only that record, for `close-story` and `stamp-red` alike; `verify_run` appends a
`line=<k> <rc> <hash>` entry as each line ends. A resume is honoured only when story, verb, head (equal, or
only paperwork commits since), stamp, `## Files` hash and `
- [ ] A2 has its own regression case in part `red`, red on 0.50.2: a results directory planted at the old predictable path before a resumed stamp-red is not trusted (stamp-red reruns the line). (Queen, coverage gap ask 2)

## Verification` hash match and, in `close-story`,
every skipped line has a recorded exit 0; anything else starts at line 1 with one stderr line saying why.
stamp-red's results directory comes from `mktemp -d` (0700), its path is in the record, it is reused only
when it is a directory, not a symlink and owned by the caller, and a stored `<j>.code` / `<j>.line` is read
only with a matching `line=` entry. The verb that finishes removes its record and directory. `docs/cycle.md`
gains a short paragraph on `.vulyk/state/` (what lives there, that it is local and ignored, that a missing
record means the strict path).

## Requirements
> 1. A1: close-story and stamp-red never take their resume point from the story file. Resume state lives in a cycle-owned path (`.vulyk/`), keyed by story, HEAD and driver stamp, and every skipped line has a recorded exit 0 from the run that paused. A hand-written `verify_resume` mark past a failing first verification line does not let `close-story` close: a regression test that fails on 0.50.2.
> 2. A2: stamp-red's results directory is made with `mktemp -d` (0700), its path is recorded in that cycle-owned state, it is reused only when `[ -d ] && [ ! -L ] && [ -O ]` hold, and results this call chain did not produce are never trusted: a regression test that fails on 0.50.2.
> 5. A1-A4 each get a CHANGELOG line, and issue #5 is closed with the release that ships them.

## Files
- scripts/cycle.sh
- tests/cycle.test.sh
- tests/council.test.sh
- docs/cycle.md

## Non-goals
- No signing, HMAC or hidden path: the limit is stated in plan.md `## Assumptions` and stays.
- Do not change the caps, the 540 s call budget, exit 7, or what `verify_files_hash` hashes.
- Do not make `story_blocks_guard` refuse a `verify_resume` line: an old one is simply never read.
- Do not write the narrow record or touch `repair`, `build_round`, `round_second` (story 05, wave 3).
- Do not touch the cell helpers story 01 landed, `install.sh`, or `.gitignore` (the directory ignores itself).
- Tests and docs describe the new behaviour at the level of issue #5; no bypass recipe.
- Do not edit `tests/cycle.test.sh` outside parts `close` and `red`, nor `tests/council.test.sh` outside the gate-split-02 case in part `advance` (it asserts today's frontmatter mark; Queen recon, 2026-11-10).

## Map slice
`memory/map/cycle.md` → Verbs (Verify runner, Red receipt, Story trust from git, exits), Files one writer
each (Gitignored); `memory/map/scripts.md` → Entry points (`lib.sh`: `paperwork_only`, `run_capped`), Gotchas.

## Acceptance criteria
- [ ] `--part close`: a story with two verification lines, the first failing, and a hand-written
  `verify_resume` line pointing past it: `close-story` runs line 1, exits 4, commits nothing. The failing
  label contains `a hand-written resume mark is ignored`.
- [ ] `--part close`: a real pause exits 7, leaves a record under `.vulyk/state/<slug>/`, writes no
  `verify_resume` line, and `git status --porcelain` shows nothing new; the rerun starts at the paused line
  (a counter proves line 1 ran once) and closes.
- [ ] `--part close`: line 1 runs again when the record lacks a `line=1 0` entry, when a non-paperwork commit
  landed since, when `--stamp` differs, or when a verification line's text changed; a paperwork-only commit
  between pause and rerun still resumes. Each restart prints its reason on stderr.
- [ ] `--part red`: stamp-red's results directory is not the predictable `vulyk-sr-<cksum>` path: with that
  path pre-created and holding results, stamp-red runs every line itself. On a POSIX box the directory is
  mode 0700 (the mode assertion is skipped on Git Bash, said in the test).
- [ ] `--part red`: after a pause, a recorded directory swapped for a symlink, or a stored result with no
  `line=` entry, is not used: stamp-red starts at line 1 in a new directory and stderr names the failed check.
- [ ] A finished `close-story` / `stamp-red` leaves no record and no results directory behind. The existing
  resume and `invalidates the mark` cases in both parts pass against the record.
- [ ] `bash scripts/portability-check.sh scripts/cycle.sh` is clean (`mktemp -d` with a template, no
  `stat -c`).
- [ ] `## Implementation notes` ends with two `CHANGELOG:` lines, one for A1 and one for A2.

## Verification
`bash tests/cycle.test.sh --part close`
`bash tests/cycle.test.sh --part red`
`bash tests/council.test.sh --part advance`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each -->
- scripts/cycle.sh: new verify record store (verify_rec, verify_rec_new, verify_rec_get, verify_rec_drop, verify_nth_line, verify_text_hash); verify_resume_start checks head/stamp/files/verify/next and each skipped line=, sets VR_START/VR_OUTD; verify_pause writes next= into the record; verify_run appends line= entries via VR_REC; verify_resume_set removed.
- stamp-red: results directory from `mktemp -d "${TMPDIR:-/tmp}/vulyk-sr.XXXXXX"`, path in outd=; reused only if -d, not -L, -O and each j.code/j.line equals its line= entry.
- Decision: no record is the silent strict path; a record that fails prints `resume record not used (<why>): verification starts at line 1`. verify_rec_drop removes a directory only when its name is vulyk-sr.* and it passes -d/!-L/-O, so a forged outd= cannot aim rm -rf elsewhere.
- Decision: the verify= key hashes `<reps>` plus the command list; a record write failure is exit 2 (a pause that cannot be recorded would loop).
- tests: part close gains the hand-written-mark case, the real pause and the four restarts plus the paperwork resume; part red gains the planted old-path case, the missing line= entry and the symlink swap (Git Bash: a junction, which reads as -L); mode 0700 check skipped on Git Bash. council advance gate-split-02 cases assert the record.
- Surprise: after the first receipt I fixed three test bugs (flag file inside the fixture repo, scope.jsonl in git status, junction quoting); I put HEAD's cycle.sh back, re-ran stamp-red (red on HEAD as before), then re-applied my cycle.sh. The A2 cases were also run on HEAD's cycle.sh: red.
- docs/cycle.md: a paragraph on `.vulyk/state/` after the invalidation table.
- CHANGELOG: A1 - close-story and stamp-red resume a paused verification only from a record under .vulyk/state/<slug>/ keyed by HEAD (paperwork-only commits allowed), --stamp, ## Files and ## Verification, with a recorded exit 0 for every skipped close-story line; a verify_resume line in the story is no longer read (#5).
- CHANGELOG: A2 - stamp-red keeps a paused run's results in a mktemp -d directory named in that record, reused only when it is a real directory the caller owns and each stored result matches its line= entry; the predictable vulyk-sr-<cksum> path is gone (#5).

## Findings

## Red receipt
- command: bash tests/cycle.test.sh --part close
- exit: 1
- tests: f14d60565146511e19122b540dd9f52b9823065af21b8ad61f0b9d4d5e845b17 (tests/council.test.sh, tests/cycle.test.sh)
- impl: d1172a7b0c05f8fdc8c779cac18666ae7e9b2f07d1d09130baaf4c718846c95c
- stamped: 2026-11-10T21:57:13Z

```
::error::a hand-written resume mark is ignored - expected exit 4 with line 1 run once and nothing committed: exit=0 line-1 runs= head moved=yes out=cycle: close-story - note: no approved version in git for docs/specs/stray/stray-23.md; its working copy stands
cycle: close-story - verification paused before line 2 (call budget); run the same command again, it resumes
{"ok":false,"verb":"close-story","exit":7,"next":"resume","resume":2,"error":"verification paused before line 2: run the same command again"}
::error::paperwork-only commit: exit=0 runs=2 out=cycle: close-story - note: no approved version in git for docs/specs/stray/stray-25.md; its working copy stands
scope-check: stray-25 - declared 1, changed 0, out of scope 0
vs-other
cycle: stray-25 - closed, verification green
{"ok":true,"verb":"close-story","exit":0,"next":"branch","now":1794347551,"status":{"spec":"docs/specs/stray","slug":"stray","stage":"02-approved","next":"branch","briefed":true,"approved":true,"branch":null,"head":"5c0a22c","pack":"324e111bc58b","now":1794347551,"stories":{"todo":0,"in-progress":11,"done":10,"blocked":0},"wave":null,"wave_stories":[],"round":0,"ceiling":3,"tier":null,"open":false,"court":null,"missing":[],"stale":false,"verdict":null,"review":null,"red":[],"round_dir":null,"paused":false,"shipped":false,"since":null,"seat_attempt":{},"seats":[],"manual":[]}}
mass-audit-fixes-10 G6: a git add that fails in close-story --commit refuses with exit 2, nothing committed, status: untouched
  ok    a failing git add: exit 2 naming the path, nothing committed or left staged, status: untouched
  ok    without the shim the same close commits both files
```
