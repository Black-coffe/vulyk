---
story: audit-fixes-1113-04
spec: audit-fixes-1113
status: todo
returned: NEEDS_CONTEXT
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: leak-check: a file naming a root from the fixture registry -> exit 1
red_verified_at: 2026-11-13T16:46:30Z 38fea80585d984d0d146d4f1580d892e628e9627ff17c951ca256667b5cb833f
---

# The leak check catches any outside path and the tree is cleaned; defect cards reach PowerShell commands

## Goal
Two changes that share `tests/inject.test.sh`.
1. `scripts/leak-check.sh` follows plan.md `## Contracts` K1. It flags an absolute path that leaves the VULYK root
   whatever the drive or folder layout, a Claude temp-folder path, and every hive root listed in the private
   registry (`${VULYK_HIVES_FILE:-~/.vulyk/hives}`; with no registry it prints one stderr note and that rule
   matches nothing). The pass list (system locations, `~/...`, a `<placeholder>` first segment, paths under the
   repo root) is named in the script header. Card `host-internals-in-public-repo` gets two neighbour fixtures.
   Every hit in the tracked files this story names is replaced by a shape (`<hive>/docs/specs/<folder>/...`) or a
   stand-in built from a variable (`$T/acme-hive/...`), never by another literal absolute path.
2. `.claude/hooks/defects-inject.sh` treats a `PowerShell` tool call as it treats a `Bash` one: the command line is
   read for `cmd:` entries and for paths, and `.claude/settings.json` wires the hook on
   `Edit|Write|MultiEdit|Bash|PowerShell` (contract M1; the installer follows in story 06).

Marked red: two parsers.

## Requirements
> 14. `leak-check.sh` catches any absolute path outside the VULYK root, the hive roots in the private registry and Claude temp-folder paths, and today's hits in the repo are replaced with stand-ins.
> 12. Defect cards reach PowerShell commands as they reach Bash ones.

## Files
- scripts/leak-check.sh
- docs/defects/host-internals-in-public-repo.md
- docs/defects/host-internals-in-public-repo.abspath.fixture
- docs/defects/host-internals-in-public-repo.temppath.fixture
- .claude/hooks/defects-inject.sh
- .claude/settings.json
- tests/inject.test.sh
- tests/defects.test.sh
- docs/specs/self-learning/contract.md
- docs/defects/command-injection-follows-cwd.md
- docs/grill/2026-09-27-self-learning-corrections.md
- docs/grill/2026-09-27-self-learning-pilot-feedback.md
- docs/specs/beta-feedback-1113/brief.md
- docs/specs/beta-fixes-1113/brief.md
- docs/specs/claude-code-mods-9/research-anthropic.md
- docs/specs/claude-code-mods-9/research-budget-memory.md
- docs/specs/claude-code-mods-9/research-ui.md
- docs/specs/close-story-scope-refusal/close-story-scope-refusal-02-repair-round-1.md
- docs/specs/close-story-scope-refusal/council/round-1/review.md
- docs/specs/constitution-merge/brief.md
- docs/specs/constitution-merge/constitution-merge-02.md
- docs/specs/constitution-merge/plan.md
- docs/specs/fable-budget/brief.md
- docs/specs/gate-split/gate-split-03-cut-long-suites.md
- docs/specs/gate-split/gate-split-04-round-suite-verb.md
- docs/specs/gate-split/gate-split-05-driver-and-reviewer.md
- docs/specs/handoff-cwd/brief.md
- docs/specs/handoff-ownership/brief.md
- docs/specs/handoff-ownership/plan-review/BRIEF.md
- docs/specs/handoff-ownership/plan-review/BRIEF.md
- docs/specs/handoff-ownership/plan.md
- docs/specs/hindsight-harvest/hindsight-harvest-01.md
- docs/specs/hindsight-memory/evidence/brief-r2.md
- docs/specs/hindsight-memory/evidence/r1-opus.md
- docs/specs/hindsight-memory/evidence/r1-sonnet.md
- docs/specs/hindsight-memory/evidence/r2-fable.md
- docs/specs/hindsight-memory/evidence/r2-opus.md
- docs/specs/hindsight-memory/evidence/r2-sonnet.md
- docs/specs/next-circle-0-22/council/round-1/review.md
- docs/specs/self-learning/plan.md
- docs/specs/token-audit/evidence/scripts/council_collect.py
- docs/specs/token-audit/evidence/scripts/specs_collect.py
- tests/intake.test.sh
- docs/specs/handoff-ownership/plan-review/fable.md
- docs/specs/token-audit/evidence/scripts/item6c.py
- docs/specs/v0-12-0-remainders/brief.md
- docs/specs/token-audit/evidence/forensics.md
- docs/specs/token-audit/evidence/scripts/item3b.py
- docs/specs/token-audit/evidence/scripts/item4b.py
- docs/specs/token-audit/evidence/scripts/item6b.py
- docs/specs/token-audit/evidence/scripts/parse_all.py
- docs/specs/anomaly-telemetry/council/round-1/opus.md
- docs/specs/anomaly-telemetry/council/round-4/opus.md
- docs/specs/anomaly-telemetry/council/round-5/opus.md
- docs/specs/anomaly-telemetry/council/round-6/opus.md
- docs/grill/2026-09-21-project-memory-chronicle.md
- docs/specs/next-circle-0-22/plan.md
- docs/specs/post-037-tails/brief.md
- docs/specs/mass-audit-fixes/mass-audit-fixes-14-client-name-scrub.md
- docs/specs/vulyk-pulse/study-recon-sonnet.md
- docs/specs/anomaly-telemetry/plan.md
- docs/adr/034-busy-hives-are-held-one-green-canary-carries.md
- docs/specs/post-052-tails/plan.md
- docs/specs/post-052-tails/post-052-tails-01.md
- docs/specs/post-052-tails/post-052-tails-03.md
- docs/specs/post-052-tails/post-052-tails-04-repair-round-1.md
- docs/specs/rules-tree/council/round-1/review.md
- docs/specs/rules-tree/council/round-2/review.md
- docs/specs/rules-tree/rules-tree-07-repair-round-1.md
- docs/specs/autonomous-cycle/council/round-3/review.md
- docs/specs/convergent-judge/council/round-2/sonnet.md
- docs/specs/trace-autopsy/horizon.md
- docs/specs/trace-autopsy/trace-autopsy-01-script.md
- docs/specs/uncommitted-work-guard/uncommitted-work-guard-04-repair-round-1.md
- docs/specs/uncommitted-work-guard/uncommitted-work-guard-05-repair-round-2.md

## Non-goals
- Do not edit a file outside `## Files` to clear a hit: list the remaining hits under `## Findings` and return
  `NEEDS_CONTEXT`. Never touch this spec's own folder.
- Do not rewrite git history and do not read or print the private registry's content into any repo file, test
  output or note: tests use a fixture registry through `VULYK_HIVES_FILE` with stand-in roots.
- Do not change the card's Never or Allowed bullets or its status (the index must not change in this wave);
  add the fixtures to `fixtures:` and say in `## Cause` what the check reads now.
- Do not change the private-terms matching (`VULYK_EXTRA_TERMS`, whole words, Cyrillic endings).
- In `.claude/settings.json` change the one matcher string only (story 10 owns the file in wave 3).
- Do not touch `install.sh` (story 06) or the hook's Read skip and its exit before Python when no card can match.

## Map slice
`memory/map/scripts-checks.md` → Entry points (`leak-check.sh`, `defects-check.sh`, `defects-inject.sh`);
`docs/wiki/rules-tree.md` (delivery); `docs/defects/README.md` (Fixtures).

## Acceptance criteria
- [ ] `leak-check.sh` exits 1 on each new fixture: one holds an absolute path on a drive and layout unlike the
  owner's, one a Claude temp-folder path. It exits 1 on a file naming a root from a fixture registry, and 0 on the
  same file when the registry is absent (stderr carries the note).
- [ ] It exits 0 on a file holding only passing forms: `/usr/bin/env`, `/dev/null`, `~/.vulyk/hives`,
  `<drive>:/<hive>/docs`, a URL with `://`, a path under the repo root.
- [ ] After the story, `leak-check.sh` exits 0 on every tracked file under the card's `paths:` (`docs/**`,
  `memory/**`, `CHANGELOG.md`) and on `tests/inject.test.sh`, the card's own fixtures excepted. The notes list the
  command that was run and its result.
- [ ] `tests/defects.test.sh` holds the cases above; the existing three fixtures of the card still fail the check.
- [ ] A `PowerShell` tool input whose command matches a card's `cmd:` entry gets the same card text as the same
  command under `Bash` (label contains `a PowerShell command gets the card`); a PowerShell command naming a file
  inside a card's glob gets that card; one that matches nothing starts no Python (counting stub, as the latency
  cases do).
- [ ] `git ls-files '*.json' | xargs -n1 jq -e . > /dev/null` is clean.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.json' | xargs -n1 jq -e . > /dev/null`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (14, 12). -->
- `scripts/leak-check.sh`: K1 rules (drive, Git Bash/WSL, home, Claude temp, slug, registry roots in every shape incl. slug); pass list in the header; a registry hit prints `<from the private registry>`, never the root; an elided first segment (`...`) passes like a `<placeholder>`; the old `Projects`-only rule is gone.
- Card `host-internals-in-public-repo`: `abspath` (a drive and layout unlike the owner's) and `temppath` (Linux Claude temp) fixtures added to `fixtures:`, `## Cause` says what the check reads now; Never/Allowed/status untouched.
- `defects-inject.sh`: `PowerShell` joins the bash pre-filter's path tools and is parsed as `Bash` in Python; the Read skip and the no-card exit are untouched.
- `.claude/settings.json`: `PowerShell` added to the existing inject matcher string. M1's literal `Edit|Write|MultiEdit|Bash|PowerShell` would drop Read (story-file cards), NotebookEdit and `tool:` delivery, so I widened the string and did not replace it; story 06 should do the same.
- Tests: `tests/defects.test.sh` holds the leak cases with a fixture registry and empty term lists. `tests/inject.test.sh` checks PowerShell `cmd:` (the text equals Bash's), the path token, a silent unrelated command, and that no python starts in a library with no card (the `started` stub). Bash cannot know "nothing matches" without python when cards exist, as with Bash.
- `red_reason` changed from the planner's PowerShell label: the verification line chains with `&&`, and the red `defects.test.sh` stops the run before `inject.test.sh` prints. The PowerShell label was confirmed red separately (3 failures) before the stamp.
- `tests/inject.test.sh`, `tests/intake.test.sh`: the latency library is now `$VULYK_LATENCY_LIBRARY` instead of a literal hive path.
- Scrubbed the 33 listed docs: registry roots became `<hive>` (`<hive> (path masked)` inside the owner's quoted words), Claude temp paths became `<claude-temp>/...` or `<scratchpad>/...`, the npm path became `<npm-global>/...`, and the two collect scripts read `VULYK_HIVE_ROOTS`.
- Scan run: `git ls-files 'docs/**' 'memory/**' CHANGELOG.md tests/inject.test.sh` (card fixtures excluded) | `bash scripts/leak-check.sh` per file, with the real registry and term lists. The listed files and tests/inject.test.sh are clean. 52 hit lines remain in 26 files outside `## Files` (see Findings).
- Suites now: defects.test.sh all passed, inject 106/0, intake 119/0, json clean (not yet run through close-story).
CHANGELOG: leak-check flags any absolute path outside the VULYK root, Claude temp-folder paths and the hive roots of the private registry; the listed docs are scrubbed to shapes (ask 14).
CHANGELOG: defect cards reach PowerShell commands as they reach Bash ones; the inject matcher includes PowerShell (ask 12).

## Findings
- NEEDS_CONTEXT (Non-goals: no edit outside `## Files` to clear a hit). After the scrub, `leak-check.sh` (K1 as written) still exits 1 on 26 tracked files outside `## Files`. The hits are listed by kind only, so this file does not carry them:
  - real host internals: docs/specs/handoff-ownership/plan-review/fable.md:13 (registry root); docs/specs/token-audit/evidence/scripts/item6c.py:10 (registry root); docs/specs/v0-12-0-remainders/brief.md:24 (registry root, Git Bash form); docs/specs/token-audit/evidence/forensics.md:5 (Claude temp path with the owner's home); docs/specs/token-audit/evidence/scripts/item3b.py:14, item4b.py:4, item6b.py:4, parse_all.py:16 (the owner's home `.claude/projects`); docs/specs/anomaly-telemetry/council/round-1/opus.md:11, round-4/opus.md:11, round-5/opus.md:11, round-6/opus.md:11 (owner home, Windows or Linux form); docs/grill/2026-09-21-project-memory-chronicle.md:78,188, docs/specs/next-circle-0-22/plan.md:22,44, docs/specs/post-037-tails/brief.md:37, docs/specs/mass-audit-fixes/mass-audit-fixes-14-client-name-scrub.md:56 (the owner's projects folder, one with a tool or hive name); docs/specs/vulyk-pulse/study-recon-sonnet.md:119 (a local Python install path); docs/specs/anomaly-telemetry/plan.md:14 (Git Bash projects path).
  - synthetic stand-ins written as literal drive paths (single-letter or Acme/My_App/build/tmp names): docs/adr/034-busy-hives-are-held-one-green-canary-carries.md:43,44,60; docs/specs/post-052-tails/plan.md:62; post-052-tails-01.md:60; post-052-tails-03.md:21,22,52; post-052-tails-04-repair-round-1.md:25; docs/specs/rules-tree/council/round-1/review.md:23, round-2/review.md:24, rules-tree-07-repair-round-1.md:25; docs/specs/autonomous-cycle/council/round-3/review.md:191; docs/specs/convergent-judge/council/round-2/sonnet.md:7; docs/specs/trace-autopsy/horizon.md:34, trace-autopsy-01-script.md:47; docs/specs/uncommitted-work-guard/uncommitted-work-guard-04-repair-round-1.md:57, -05-repair-round-2.md:61; memory/map/scripts.md:63,64.
  - Question: add these 26 paths to this story's `## Files` (scrub them as I scrubbed the others), or put them in a follow-up story? The synthetic ones could instead pass by a narrower K1 (for example a one-letter first segment, or a `Acme` stand-in), but K1 as approved flags them. memory/map/scripts.md belongs to drone-docs/librarian, so it may need their pass.

## Red receipt
- command: bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh
- exit: 1
- tests: 38fea80585d984d0d146d4f1580d892e628e9627ff17c951ca256667b5cb833f (tests/defects.test.sh, tests/inject.test.sh, tests/intake.test.sh)
- impl: 379c8d5145ad17d1dd7f30eba63eafe45b452c3c925cac3c8c2082f901cf26c8
- stamped: 2026-11-13T16:46:30Z

```
::error::leak-check: a file naming a root from the fixture registry -> exit 1
::error::leak-check: docs/defects/host-internals-in-public-repo.abspath.fixture -> exit 1
::error::leak-check: docs/defects/host-internals-in-public-repo.temppath.fixture -> exit 1
  ok    leak-check: docs/defects/host-internals-in-public-repo.original.fixture -> exit 1
  ok    leak-check: docs/defects/host-internals-in-public-repo.neighbour.fixture -> exit 1
  ok    leak-check: the plain-name fixture with the card's terms -> exit 1
::error::leak-check: the card lists both new fixtures
::error::leak-check: a file naming a root from the fixture registry -> exit 1
::error::leak-check: the same file with no registry -> exit 0, one stderr note
  ok    leak-check: only passing forms -> exit 0
defects.test.sh: FAILED
```
