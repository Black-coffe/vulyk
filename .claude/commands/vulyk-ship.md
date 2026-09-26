---
description: Stage 06 of the cycle - fix history, merge locally, print the publish command, open the next circle. Never pushes, tags, publishes or deploys.
argument-hint: [spec slug; defaults to the newest spec with a GREEN council row or a human check recorded]
---

Ship: "$ARGUMENTS" (default: the newest spec under `docs/specs/` whose plan.md carries a GREEN
`**Council:**` row or a `**Checked:** ACCEPTED` line).

1. Gate. `bash scripts/ship-check.sh docs/specs/<slug>` and show its output. `NOT READY` is a refusal:
   name the open stage and stop. Expect two kinds: a council `RED` or `ESCALATE` (repair, or
   `## Needs a human`, is unresolved), and `STALE` (a repair round or a hand edit moved the code after
   the council judged it; a hand fix reopens a round that re-reviews only the new diff). Both are cured
   by going back, never by shipping around them. A newer `**Checked:**` line is the owner's override in
   either direction (`scripts/human-check.sh`), and the owner may also override a plain `NOT READY`:
   it is their release, but say so out loud and quote the override into the `--record` note below.
2. History. The spec branch (`**Branch:**`) holds one commit per story; do not squash them, they are
   the rollback points and the review units. Work out the version from the Profile's *Commit
   convention* (a semver bump sized to the change). If a story on this branch already wrote `VERSION`
   and the top `CHANGELOG.md` entry for that version, there is nothing to bump. Otherwise add one commit
   on the branch with the version bump and the CHANGELOG entry. This is release paperwork: Law 5 does
   not apply, and `VERSION` and `CHANGELOG.md` are paperwork to the cycle, so this commit does not stale
   a GREEN round. Then merge into the default branch the way the Profile's *Release / deploy* row says;
   a local merge is reversible and yours to run.
3. Publish: print, then stop. Under a `to publish, run:` heading, print the publish step exactly as the
   *Release / deploy* row names it, with the version. Do not run it, ask about it, or check back on it.
   `/vulyk-status`'s `merged locally, not pushed: <n>` line is how anyone learns whether it ran.
4. Record. `bash scripts/ship-check.sh --record docs/specs/<slug> <version> "merged to <default
   branch>, publish pending"`, then commit it (`vulyk(<slug>): shipped <version>`). The spec is closed
   on disk.
5. Next circle. Dispatch only what has work to do, in one message:
   - `drone-docs`, only when the merged range touches a module listed in `memory/memory.md`'s map. Give
     it the changed paths (`git diff --name-only <base>..<merge>`) and the map files that cover them,
     not the diff itself.
   - `librarian` for the ADR harvest, only when plan.md's `## Plan deltas` or `## Descoped` has entries.
   Then hand the owner, verbatim, the draft of the next brief: every `UNASKED:` line from the newest
   round's seat files under `docs/specs/<slug>/council/round-<N>/` (skip "none"), every minor in that
   round's `review.md`, every `[unanchored]` critical or major finding in any round's `review.md` (and
   the findings of any BLOCK that `judge` recorded as PASS with the note `review BLOCK unanchored`),
   every `## Descoped` entry, and plan.md's `## Needs a human` section when it has one. Do not open a
   spec for them; what the next circle is belongs to the owner.
6. Close the session. Recommend `/vulyk-handoff` and `/clear`: everything this spec needed is in git.
