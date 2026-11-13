---
story: audit-fixes-1113-04
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 1
blocked_by: []
red: required
red_reason: a PowerShell command gets the card
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

## Findings
