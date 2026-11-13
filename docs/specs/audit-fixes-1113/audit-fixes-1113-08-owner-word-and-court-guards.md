---
story: audit-fixes-1113-08
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [audit-fixes-1113-04, audit-fixes-1113-06]
red: required
red_reason: a subagent cannot record an acceptance
---

# Two new guards: the owner's word, and the court of a blind seat

## Goal
Two PreToolUse hooks with one skeleton (a bash wrapper that exits before Python when the call cannot concern it,
Python in a heredoc as `git-guard.sh` has it, a `--check <file>` mode). Story 10 wires them; this story builds and
tests the files.
1. `.claude/hooks/owner-guard.sh` (plan.md `## Contracts` O1). An acceptance (`human-check.sh ... ACCEPTED` or
   `REJECTED`), a `cycle.sh briefed ... --go`, and an edit that adds or changes a `**Approved:**` or `**Checked:**`
   line of a spec's `plan.md` are refused for a subagent, always. For the main session they pass only when the
   note, or the new line, holds the owner's own words from this session, verbatim, written after the spec's latest
   verdict (the quote rule in plan.md `## Assumptions`). Without Python, or with a transcript it cannot read, a
   guarded call is refused with a message that says why. Card `owner-words-by-builder` gets this hook as its
   `check:`, two fixtures, and `status: block`.
2. `.claude/hooks/court-guard.sh` (contract C1). For a blind council seat it denies a read outside the court and a
   git read of the spec. Both seat prompts stop saying that `record-seat` enforces blindness: the hook keeps the
   seat inside the court, and `record-seat` checks the report.

First step: create both hook files as stubs that exit 0 and set their mode in the index (`git update-index --add
--chmod=+x <file>`), because a wave-mate's suite checks the bit of every wired hook. Make no other git write.

Verify before building, against the installed Claude Code: where hook input carries `transcript_path`, `agent_id`
and `agent_type`; how a transcript entry shows an owner prompt, an `AskUserQuestion` answer, and text that only
looks like one (a tool result, hook context, an agent's message, a command expansion). Write the shapes you found
in the notes. If an owner prompt cannot be told from injected text, return `NEEDS_CONTEXT`; do not guess.

Private input: the sections on the acceptance record and on court blindness in
`~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md`. Headers, the card and the notes say what each hook refuses
and what it leaves open on purpose, never what used to pass.

Marked red: security handling of the records only the owner may write.

## Requirements
> 4. Only the owner's own words record his acceptance (`human-check.sh ACCEPTED|REJECTED`) or a plan's straight-through `--go`: a subagent is always refused; the main session passes only when the note quotes, verbatim and after the latest verdict, an owner prompt or AskUserQuestion answer from this session, with whitespace normalised and a bare «ок» not enough; direct edits of the record file and of the `**Approved:**` line are guarded the same way; without Python the guard refuses with a loud message.
> 13. A hook keeps a blind council seat inside its court: no reads outside the court, no git reads of the spec. Seat prompts no longer say `record-seat` enforces blindness.

## Files
- .claude/hooks/owner-guard.sh
- .claude/hooks/court-guard.sh
- docs/defects/owner-words-by-builder.md
- docs/defects/owner-words-by-builder.original.fixture
- docs/defects/owner-words-by-builder.neighbour.fixture
- docs/defects/INDEX.md
- .claude/agents/council-opus.md
- .claude/agents/council-haiku.md
- tests/defects.test.sh
- tests/inject.test.sh

## Non-goals
- Do not touch `.claude/settings.json`, `install.sh` or `docs/hooks-reference.md` (story 10), `git-guard.sh`
  (story 07), `scripts/human-check.sh` or `cycle.sh` (the guard sits in front of them and changes neither).
- The hook judges where the words come from, never whether they mean yes: no word lists beyond the length rule.
- Fixtures and tests use synthetic prompts and stand-ins (Acme); no real transcript line enters the repo.
- `record-seat`'s taint check stays as it is.
- In `tests/inject.test.sh` add one block for the court guard and change nothing else.
- Run `bash scripts/defects-index.sh` after the card edit; never edit `INDEX.md` by hand.

## Map slice
`memory/map/scripts.md` → Entry points (`human-check.sh`); `memory/map/cycle.md` → Files one writer each, Seats and
the verdict, Staleness (court, seat report); `memory/map/agents-and-commands.md` → Agents (council-opus,
council-haiku); `memory/map/scripts-hooks.md` → `git-guard.sh` (the skeleton); `docs/defects/README.md`.

## Acceptance criteria
- [ ] Owner guard, subagent input: `human-check.sh <spec> ACCEPTED "<any note>"`, `REJECTED`, `cycle.sh briefed
  <spec> --go`, and an Edit adding `**Approved:** <text>` to a spec's `plan.md` are each denied (label contains
  `a subagent cannot record an acceptance`).
- [ ] Main session, fixture transcript: a note holding a whole owner line written after the latest verdict
  passes, also when its spacing differs; an `AskUserQuestion` answer quoted whole passes. Denied: a note with no
  owner text; a quote older than the latest verdict; a fragment cut from inside a line; a bare «ок»; text that
  stands only in an assistant message, a tool result or an agent's message.
- [ ] `briefed --go` passes only when an owner prompt of the session carries `--go`.
- [ ] Plan approval: an `**Approved:**` line quoting the owner's latest message after the spec's plan commit passes
  at any length («Погнали»); one quoting an earlier owner message, or one written before the plan commit, is denied.
- [ ] Release acceptance: `ACCEPTED`/`**Checked:**` passes only with the answer to a one-question `AskUserQuestion`
  naming the spec slug, or the owner's next message after it (8+ letters or digits unless a picked option);
  an owner message of 8+ letters that answers no such question is denied.
- [ ] A Write or Edit that leaves the template placeholder on a marker line passes, for a subagent too; an edit of
  `plan.md` that changes no marker line passes; a shell command writing a `**Checked:**` line into a `plan.md` is
  judged like the Edit.
- [ ] With every Python launcher stubbed away, a guarded call is denied with a message naming the missing Python,
  and an unrelated Bash or Edit call passes without starting an interpreter (counting stub).
- [ ] `owner-guard.sh --check` exits 1 on both card fixtures and 0 on a file that is no hook input, tested in
  `tests/defects.test.sh`. The card is `status: block`, its `## Check` says what the hook reads and names what it
  leaves open on purpose, and `bash scripts/defects-index.sh --check` exits 0.
- [ ] Court guard, `agent_type` a blind seat: Read, Grep and Glob of a path outside `<project>/.vulyk/court/` are
  denied (the main tree's copy of a spec file included) and inside it pass; a Bash path argument that leaves the
  court is denied; a git command that reads objects with no pathspec, or with one under `docs/specs/`, is denied,
  and one whose every pathspec lies elsewhere passes. Any other `agent_type`, and the main session: no effect.
- [ ] Both seat prompts carry the new sentence and no claim that `record-seat` enforces blindness;
  `bash scripts/prompt-check.sh --touched .claude/agents/council-opus.md .claude/agents/council-haiku.md` has no error.
- [ ] `git ls-files -s .claude/hooks/owner-guard.sh .claude/hooks/court-guard.sh` shows 100755 for both;
  `bash scripts/portability-check.sh` on both is clean.

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each; the transcript and hook-input
shapes you verified. End with one `CHANGELOG:` line per ask (4, 13). -->

## Findings
