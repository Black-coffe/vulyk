<!-- seat: review · model: claude-fable-5-1 · round: 1 · head: bed3139 · pack: 071e42715dbd · attempt: 1 · recorded: 2026-11-09T16:13:34Z · verdict: BLOCK -->
VERDICT: BLOCK
SUITE: FAIL 1047s - cut part council:suite, part council:escalate failed, part e2e:green failed, part e2e:red failed
MODEL: claude-fable-5-1

## Critical
1. tests/e2e.test.sh:117 [regression] the e2e seam (real driver + real cycle.sh) must close its Tier 3 story again: `make_fixture` commits plan and story as `git commit -q -m init`, so story 05's `story_blocks_guard` (scripts/cycle.sh:2313 approved_rev, :2328) finds no `vulyk(demo): ` commit and refuses `close-story` with exit 2 `no approved version in git for docs/specs/demo/demo-01-app.md: commit the plan or a revision first`; the worker returns, the story stays todo and the run stops at `next: build:1` (same fixture for `--part red`) - repro: `bash tests/e2e.test.sh --part green` (E2E_DEBUG=1 shows the stop), and a throwaway repo with the fixture's files + `cycle.sh close-story ... --commit` gives the exit 2 above; base: `git show main:docs/specs/ab-run-fixes/council/round-3/suite.log` has `PART e2e:green ok`, `PART e2e:red ok`.
2. tests/council.test.sh:2115 [regression] close-story on a locked index must still satisfy r2m2 (exit 2 and an error that names the commit): head's `cs_add` (scripts/cycle.sh:2918, G6) refuses with `git add failed: docs/specs/cstorylock1/cstorylock1-01-first.md: fatal: Unable to create '.git/index.lock'` and no word "commit" in the output, so `grep -qiF 'commit'` fails - the refusal names the commit it could not make, or the r2m2 assertion follows the G6 wording - repro: `bash tests/council.test.sh --part escalate` (`::error::exit=2 out=... git add failed ...`); base: main suite logs `PART council:escalate ok 48-110s`.
3. tests/council.test.sh (part suite) [regression] the council:suite part must run under 70 % of its 300 s cap again: head ran it 247 s and suite-parts-check cuts it (`cut part council:suite`), base logs on main show 70-182 s for the same part; every `status --json` now pays D2's `git log -- <spec>` (scripts/cycle.sh:2360 close_subjects; measured here 978 ms vs 826 ms per call on this spec, base cycle.sh from `git archive 704eb85 scripts`) and story 10 added sleeping X-08 cases - split the part or take the per-call cost back under 210 s (card test-gate-one-long-limit ->) - repro: `bash tests/council.test.sh --part suite` timed against `bash scripts/suite-parts-check.sh`.

## Major
None.

## Minor
- scripts/cycle.sh:1510 go_guard passes a plan whose `**Tier:**` line is missing or unparsable (contract D4 says so; card safeguard-bypassable-or-late "a check exits 0 when what it reads is missing") - open-round refuses such a plan later, so a note only.
- scripts/cycle.sh:1527 cmd_briefed: at Tier 2-4 a re-run of `briefed` without `--go` on a plan whose Briefed line already records `(--go)` now exits 2 (go_guard reads the Briefed line only for `branch`); a re-run used to be a no-op.
- .claude/workflows/vulyk-cycle.js:70 retryModel: at Tier 3 the `opus` seat always judges, so with TOP=fable and REVIEW=fable the retry lands on opus beside the opus seat; the contract names REVIEW only - a recorded gap, not a defect.
- scripts/vulyk-update.sh:69 canon: a cache cloned over SSH (`git@github.com:owner/name.git`) against a declared `owner/name` origin is refused as `cache remote differs`; today's caches were cloned by this script over https, so it does not fire.
- Not checked here: ask 8's macOS CI step runs only on GitHub (the branch has no CI run yet), and ask 11 was read against the plan's Scope E list and the diff, not against the private audit file; the O2/O7/O8, S6 and I3 narrowings stand as the plan records them.
