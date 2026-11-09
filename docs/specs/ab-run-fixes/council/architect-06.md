# Architect ruling: story 06 missed twice (portability gate red on cycle.sh)

- Date: 2026-11-09, HEAD e1b2597, branch vulyk/ab-run-fixes
- ADR: docs/adr/031-comments-inside-command-substitution.md

## Verdict
Not a design fork. A repair of `scripts/cycle.sh` lines from stories 04 and 05, plus four older comment
lines in the same function. `scripts/portability-check.sh` does not misread by its own rules and is not
changed. Story 06 is innocent and needs only a `close-story` rerun once the repair is committed.

## Cause of each hit
1. `cycle.sh:3532` `array` (story 05, `claim_leftover`): a plain textual miss of the house idiom.
   `PP` always holds one or two elements, so no run-time failure, but the gate is a grep and the card's
   rule is textual.
2. `cycle.sh:3799` `case-in-subst` and 3. `cycle.sh:3818` `heredoc-in-subst` (story 04, NARROW block):
   both are symptoms of one root. `findings="$(` opens at 3763 and closes at 3785. Inside that body are
   five comment lines: 3767-3768, 3773, 3775-3776. The scanner only recognises `#` as a comment when no
   `$( )` is open, so it reads those comments as code: the apostrophes in `vulyk-ship's`, `reviewer's`,
   `owner's`, `round's`, `judge's` toggle quote state, `(judge's override)` leaves one unmatched `(`,
   the `)"` on 3785 is swallowed inside a quote, and the substitution never closes on the stack. Story
   04's `case` at 3799 is the first `case` after that point and `done <<EOF` at 3818 the first heredoc,
   so they are the first lines the stale state can flag. Before story 04 the same comments were there
   and the gate was green because nothing downstream could show the symptom. Only 3768 (`ab-run-fixes
   C2`) is story 04's own comment; the other four are older.

Whether a real bash 3.2 behaves the same (reads a comment inside `$( )` as code) is not verified on a
3.2 binary here. The route does not depend on it: the gate stays fail-closed.

## The route
One repair story, built by a worker (Law 5: stories 04 and 05 are Tier 3 and name `scripts/cycle.sh`;
the Queen does not edit it). Suggested shape:

- `docs/specs/ab-run-fixes/ab-run-fixes-07-repair-portability.md`, wave 3, `worker: worker-code`,
  `model: opus` (a repair of judged-done work climbs a rung, ADR-015, as `cmd_repair` writes it).
  Red: the gate itself is the red (`bash scripts/portability-check.sh scripts/cycle.sh` exits 1 on HEAD
  e1b2597, 3 hits); no separate failing test is needed. If the frontmatter wants a value, name that.
- `## Files`: `scripts/cycle.sh`, `docs/defects/shell-needs-gnu-or-bash4.md`.
- The smallest fix per hit:
  - 3532: `for p in ${PP[@]+"${PP[@]}"}; do`
  - 3799 and 3818: no change to those lines. Move the five comment lines 3767-3768, 3773, 3775-3776 out
    of the `$( )` body to just above `findings="$(` (line 3763), with a one-line lead-in such as
    `# findings, in order: seat RED asks; anchored review findings; red gate parts; owner REJECTED`.
    Stripping the apostrophes would also clear the gate but leaves the trap for the next comment;
    moving them makes the invariant visible.
  - Card: one How-to line in `docs/defects/shell-needs-gnu-or-bash4.md`: a comment inside a `$( )` body
    is code to the gate (and likely to bash 3.2); put comments above the line that opens the
    substitution. The card already has its `check:` (portability-check.sh), so this adds no debt.
- `## Verification` (the C5 rule by hand: the gate, plus the covering lines of the stories that named
  the file, trimmed to what the edits touch):
  `bash scripts/portability-check.sh scripts/cycle.sh`
  `bash tests/maintenance.test.sh`
  `bash tests/driver.test.sh`
  `bash tests/council.test.sh --part verbs`
  `git ls-files '*.sh' | xargs -n1 bash -n`
- Acceptance: `bash scripts/portability-check.sh` prints its ok line on the whole tree; `claim_leftover`
  behaviour unchanged (a rename line still yields two paths); `cmd_repair` output unchanged.

## Sequencing, and what story 06 needs
1. Build and `close-story` 07 first. Story 06's uncommitted edits can stay in the tree: `close-story`
   commits only the story's own files (`--only -- OWN`) and ran story 06's checks with story 05's dirty
   `cycle.sh` present before, so dirty files outside `## Files` do not stop it.
2. Then story 06: set `status:` back to `todo` (clear `returned:`), rerun `close-story`. Nothing else:
   its red receipt stays valid (the `impl:` hash covers only its own files; `tests:` unchanged), its
   `## Findings` stay as history.
3. If the Workflow driver is relaunched instead of running the two verbs by hand: `claim` refuses while
   story 06's dirty files belong to a story that is not `todo` (`claim_leftover` maps dirty paths only to
   `todo` stories of the current wave, the rest is "working tree not clean", exit 2). So story 06 goes
   back to `todo` before the claim, and story 07 sits in the same wave with 06 `blocked_by:
   [ab-run-fixes-07]` so the driver builds 07 first. The manual path is cheaper for two verbs.

## Rejected
- Loosening `portability-check.sh` to treat `#` as a comment inside `$( )`: drops a guard that may be
  real on bash 3.2, unverified, to get a green run (card `safeguard-bypassable-or-late`).
- `# portable:` bypasses on 3532, 3799, 3818: 3799 and 3818 are not the defect; a bypass there hides the
  stale state for the next `case` written below.
- Writing `(pat)` at 3799 or moving the 3818 heredoc into a function: cargo cult, the lines are not in a
  `$( )`; 3818 would stay red because the stale substitution would still be open.
- Repairing inside story 06: Law 3, `cycle.sh` is not in its files.

## Follow-up (not this repair)
A `comment-in-subst` rule in `portability-check.sh` that reports the comment line itself, with a
fixture in `tests/maintenance.test.sh`; opened by ADR-031's "Revisit when", on the next such hit or
when a bash 3.2 run settles what 3.2 does.

## Not checked
No bash 3.2 binary on this box; the 3.2 behaviour for comments inside `$( )` is stated as likely, not
verified. The ADR number 030 follows ADR-029, the newest the plan and CHANGELOG reference; this box's
directory search is blind, so renumber if a 030 already exists.
