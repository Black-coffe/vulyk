# ADR-031: A portability hit outside a story's files is repaired at its root in the named file, never by loosening the gate

- Status: proposed
- Date: 2026-11-09
- Spec: docs/specs/ab-run-fixes (story 06 missed twice; consultation `council/architect-06.md`)

## Context
Story 06 (`ab-run-fixes-06-onboarding-readme`) fails `close-story` on `bash tests/maintenance.test.sh`
twice: `portability-check: the tree exits 0` is red. Every check of story 06's own work passes. The
three hits are all in committed `scripts/cycle.sh`, a file outside story 06's `## Files`:

- `cycle.sh:3532` `array`: `for p in "${PP[@]}"` (story 05, `claim_leftover`). A textual miss of the house
  idiom `${a[@]+"${a[@]}"}` (used 20 times elsewhere in the file). `PP` always holds one or two elements,
  so bash 3.2 would not fail at run time; the gate is a grep and the card's rule is textual.
- `cycle.sh:3799` `case-in-subst` and `cycle.sh:3818` `heredoc-in-subst` (story 04, the NARROW block of
  `cmd_repair`). Neither line is inside a `$( )`. Tracing `scan()` of `scripts/portability-check.sh`
  through `cmd_repair` shows why they are reported: `findings="$(` opens at 3763 and closes at 3785, and
  the body holds five comment lines (3767-3768, 3773, 3775-3776). The scanner treats `#` as a comment
  only when no `$( )` is open (`len(stack) == 1`), so those comments are read as code: the apostrophes in
  `vulyk-ship's`, `reviewer's`, `owner's`, `round's`, `judge's` open and close quote states, `(judge's
  override)` leaves one unmatched `(`, the `)"` of 3785 is swallowed inside a quote, and the substitution
  never closes on the stack. Story 04's `case` at 3799 is the first `case` and its `done <<EOF` at 3818 the
  first heredoc after that point, so they are the first lines the stale state can flag. Before story 04
  the same comments were there and the gate was green: nothing downstream could show the symptom.
  Only 3768 is story 04's own comment; the other four predate it.

Whether a real bash 3.2 also reads a comment inside `$( )` as code (its pre-`parse_comsub` matched-pair
scan) is not verified on a 3.2 binary in this session; the project has no macOS runner that exercised
this line. The decision below does not depend on it.

## Options
1. Repair `scripts/cycle.sh`: write the one array expansion in the house idiom and move the five
   comment lines out of the `$( )` body to just above `findings="$(`. One file, four small edits, no
   behaviour change; the gate stays exactly as strict as it is.
2. Loosen `scripts/portability-check.sh` so `#` after whitespace is a comment inside an open `$( )`
   too. Makes the three hits vanish without touching `cycle.sh`, but drops a guard that may be real on
   bash 3.2 (unverified) on the strength of convenience, and the checker's own tests and the
   `shell-needs-gnu-or-bash4` card would need to follow.
3. Add `# portable: ...` bypasses on 3532, 3799 and 3818. Smallest diff, but 3799 and 3818 are not the
   defect; a bypass on a symptom line hides the cause and leaves the stale state to hit the next `case`
   someone writes below it.

## Decision
Option 1. This is a repair, not a design fork: the plan, stories 04 and 05 and the checker's rule set
are sound; the checker reports the first visible symptom of an unclosed substitution, and the
substitution is unclosed because of comment lines inside it. The fix belongs in the file the hit names
(Law 3, card `shell-needs-gnu-or-bash4`), done by a worker in a story that names `scripts/cycle.sh`
(Law 5: stories 04 and 05, Tier 3, name that file, so the Queen does not edit it). The gate is kept
fail-closed: loosening it would trade a possibly real bash 3.2 break for a green run, which the card
`safeguard-bypassable-or-late` forbids. Moving comments rather than stripping apostrophes is chosen
because the invariant "no comment inside a `$( )` body" is one a later agent can see and a grep can
check; "no apostrophe in such a comment" is neither.

Story 06 needs no change: once `cycle.sh` is repaired its `close-story` is simply rerun. Its red
receipt stays valid (the `impl:` hash covers only story 06's files, the `tests:` hash is untouched).

## Consequences
- Easier: one story, one file, no change to the gate's tests or the card's `check:`. The next
  `case` or heredoc written below 3785 in `cmd_repair` is judged on its own merits again.
- Harder: `cmd_repair`'s five comments sit above the `findings="$(` line instead of next to the
  branch they describe; a short lead-in line keeps them readable.
- Debt accepted: the checker still reports a stale-state hit on the symptom line, not on the comment
  that caused it. A `comment-in-subst` rule (report on the comment line itself) is a follow-up, not
  part of this repair.
- The repair story touches four comment lines older than story 04; that is still inside
  `scripts/cycle.sh` and inside `cmd_repair`, which story 04 owned.

## Invariants created
- A comment line never sits inside a `$( ... )` body. Put it above the line that opens the
  substitution. The portability gate, and likely bash 3.2, read such a comment as code: an apostrophe,
  a backtick or a parenthesis in it corrupts the parse of everything that follows.
- Every `"${a[@]}"` or `"${a[*]}"` in a file under `set -u` is written `${a[@]+"${a[@]}"}`, even when
  the array is provably non-empty at that point: the gate is textual and the idiom costs nothing.
- When `portability-check` reports `case-in-subst` or `heredoc-in-subst` on a line that is not
  textually inside a `$( )`, the cause is upstream: an unclosed quote or paren the scanner met inside
  an earlier multi-line substitution (usually a comment). Fix the upstream line, not the reported one.
- A portability hit outside a story's `## Files` is repaired in the file it names by a story that
  names that file. Neither `scripts/portability-check.sh` is loosened nor a `# portable:` bypass put
  on a symptom line to let another story close.

## Revisit when
- A bash 3.2 run (a macOS job in CI, or a local 3.2 binary) shows that a comment with a quote inside
  `$( )` parses correctly there: then the checker may treat `#` as a comment inside substitutions and
  the first invariant relaxes to "no quote, backtick or paren in such a comment".
- A second hit lands on a symptom line for the same reason: add a `comment-in-subst` rule to
  `scripts/portability-check.sh` that reports the comment line itself, with a fixture in
  `tests/maintenance.test.sh` and a Never line in `docs/defects/shell-needs-gnu-or-bash4.md`.
