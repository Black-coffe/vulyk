---
story: guards-1115-10
status: done
returned: DONE
worker: worker-code
model: opus
wave: 8
blocked_by: [guards-1115-09]
red: required
red_reason: a cycle.sh verb outside the six is refused under every listed spelling
red_verified_at: 2026-11-16T17:32:36Z 02e9c00e2189fc336ee735c983e2b01e13f89bf9744b4c892dec1791ace16afa
---

# git-guard: owner-only cycle.sh verbs under the spellings ask 2 names

## Goal
The owner's 2026-11-16 answer «Чинить сейчас (Рекомендую)»: git-guard refuses a subagent's `cycle.sh` verb outside the
six (advance, status, release, suite, stamp-red without --baseline, close-story) under each spelling class of
council round 3, finding 3 (quoted under ## Findings): a shell option that carries a value before the script, a verb
handed in by `xargs`, a shell or the whole command held in a variable, a globbed or variable script word behind a
wrapper. Where the hook cannot tell which script or verb a call runs and the call could name `cycle.sh`, it refuses
the subagent. This is defensive work on this repository's own guard hook: name the class, not a working form, in
messages; tests hold the forms this story closes. The six verbs keep passing under every spelling.
Marked red: a parser that decides whether an owner-only verb runs.

## Requirements
> 2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting, globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
> 6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative agent, not an adversary.
> 7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of the Queen, a worker or a council seat is denied (existing suites stay green).

## Files
- .claude/hooks/git-guard.sh
- tests/maintenance.test.sh
- docs/defects/work-discarded-by-git-verb.md

## Non-goals
- No other git-guard class (the owner's «Минимум для git-guard» moved them to 0.55.0); owner-guard and court-guard
  are not touched.
- Keep every over-deny case of stories 05, 08 and 09 passing; keep the long-part split of story 09.

## Acceptance criteria
- [ ] Each spelling class of finding 3 refuses a subagent's `cycle.sh revise` (and one other verb outside the six),
  with a neighbour form per class; the label contains `a cycle.sh verb outside the six is refused under every
  listed spelling`. The six verbs under the same spellings pass.
- [ ] git-guard's header no longer lists this class as open; the card's `## Check` list matches the header.
- [ ] Every new case fails on HEAD; the notes list them.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash scripts/defects-check.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one CHANGELOG: line. -->
- .claude/hooks/git-guard.sh: `shell_opts` (shared by `run_word` and `fed_string`) skips a shell's options and the values they carry (`-euo pipefail`, `--rcfile f`) and takes the `-c` string after all options (`bash -c -e "..."`).
- git-guard.sh: `wrapped` walks a wrapper's options, values (WRAP_VALUED), env assignments and timeout's duration; `command_word` takes that word when it is made by a variable or a pattern, else the old next-LANDS-word rule.
- git-guard.sh: `xargs_replace` / `handed_run`: a script, program or `-c` string that xargs hands in (from input or its replace string) is UNREADABLE; cycle.sh with no verb behind xargs and stamp-red behind xargs are denied (its input could add --baseline: stamp-red behind xargs is refused, not passed).
- git-guard.sh: a variable's value of several words is judged both whole and split (`variants` returns word lists, `judge_run` / new `judge_cycle` split the script, verb and stamp-red values).
- git-guard.sh: `judge_run` is also called on a fed command string, so a shell that xargs feeds with no string is seen; header describes the new reads; open list keeps other handing programs, unknown valued wrapper options, a command string a wrapper runs, and the short heredoc end word; no-Python line adds xargs.
- tests/maintenance.test.sh: 19 deny cases (each red on HEAD: `bash -eo pipefail`, `--rcfile`, `sh -euo pipefail -c`, `bash -c -e`, `xargs bash cycle.sh`, `xargs -n2 cycle.sh`, `xargs -I{} bash {}`, `xargs -0 sh -c`, `xargs -I status`, `xargs ... stamp-red`, `$C` whole command, `bash $C dv`, `eval $C`, `$S` = "timeout 60 bash", `stamp-red $b`, `timeout 60 cyc*.sh`, `nice -n 5 cycle.s?`, `timeout 60 "$C"`, `timeout -k 5 60 $c`) and 19 pass cases; the r3 header check is replaced by four "no longer names" checks (red on HEAD).
- docs/defects/work-discarded-by-git-verb.md: `## Check` open list matches the header; summary names the closed spellings.
- Surprise: the heredoc end-word item from finding 3 is not one of the story's four classes; it stays on the open list, unfixed.
CHANGELOG: git-guard refuses a subagent's cycle.sh verb outside the six past shell options with values, xargs input, a command held in a variable and a variable or pattern program word behind a wrapper.

## Findings
3. .claude/hooks/git-guard.sh:796 [ask 2] a `cycle.sh` verb outside the six must be refused for a subagent under the spellings ask 2 names, or that part must be narrowed the way the owner chose for git-guard: a shell option that carries a value (:796-803), a verb handed in by xargs, the shell or the whole command held in a variable and a globbed or variable script word behind a wrapper still exit 0 (11 of my round 1 cases, unchanged; round 2 line 3), while the 2026-11-16 line of plan.md `## Descoped` names only asks 1, 3 and 4, ask 2 is not narrowed, and the open list (:84-103, the card's `## Check` with it) names none of these classes nor a command line after a heredoc whose end word the hook reads short, although :36-41 says such calls are denied (card `safeguard-bypassable-or-late`, Never line 1).

## Red receipt
- command: bash tests/maintenance.test.sh
- exit: 1
- tests: 02e9c00e2189fc336ee735c983e2b01e13f89bf9744b4c892dec1791ace16afa (tests/maintenance.test.sh)
- impl: 31c00080730f9c4f80d6c5dba2ecd47a4d5e859ecf44f231a8ae42b811eb4cc3
- stamped: 2026-11-16T17:32:36Z

```
::error::git-guard: a cycle.sh verb outside the six is refused under every listed spelling, yet the header's left-open list still names a shell option that takes a value before the script
::error::git-guard: a cycle.sh verb outside the six is refused under every listed spelling, yet the header's left-open list still names xargs among them
::error::git-guard: a cycle.sh verb outside the six is refused under every listed spelling, yet the header's left-open list still names a shell or a whole command held in a variable
  ok    ship 2a: the plugin.json version moves with VERSION
  ok    ship 2a: the dev build gets a local tag for the next upgrade
  ok    ship 2a: a reverted canary is held too
  ok    ship 2: in the VULYK source the build number comes from 2a
  ok    ship 2a: the canaries go first
  ok    ship 2a: a red canary stops the rollout
--- beta-fixes-1113-03: a paperwork-only suite.log head, --go from the owner
  ok    lead-review: a suite.log head that differs only by paperwork commits is not reported
  ok    plan: --go comes only from the owner's own words
maintenance.test.sh: 1304 checks, 23 failed
```
