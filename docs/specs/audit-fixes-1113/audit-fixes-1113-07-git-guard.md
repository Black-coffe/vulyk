---
story: audit-fixes-1113-07
spec: audit-fixes-1113
status: todo
returned:
tier: 3
worker: worker-code
wave: 3
blocked_by: [audit-fixes-1113-02, audit-fixes-1113-05]
red: required
red_reason: a discarding verb fed to a shell is denied
---

# git-guard: every discarding form, a bash fallback without Python, no subagent commit under a DRIVER

## Goal
`.claude/hooks/git-guard.sh` after this story (plan.md `## Contracts` G1):
1. It classifies every git form that discards uncommitted work or commits: the verbs it knows today, the forms
   that overwrite the tree from the index, move or delete a branch or ref by force, and the same verbs reached
   through a shell (`bash -c`, `sh -c`, `pwsh -Command`), through a `-c alias.<name>=` definition, or inside a
   heredoc fed to a shell (the body of such a heredoc is read, not cut). Every form left open on purpose is named
   in the header's "Not covered, on purpose" list and in the card's `## Check`.
2. With no Python it no longer steps aside. A pure-bash fallback reads the same verb list as the Python part (one
   list, or two with a test that compares them) and denies each listed verb in Bash and PowerShell, for any
   caller; other git commands pass. An interpreter that starts and ends with a status other than 0 or 1 on a
   command naming git is a deny, with a message that says the guard failed and that the owner can run the command.
3. For a subagent (contract H1) it denies `git commit` and `git add` while any `docs/specs/*/DRIVER` file exists,
   and every `cycle.sh` verb outside `advance`, `status`, `release`, `suite`, `stamp-red` (never with
   `--baseline`) and `close-story`. `git update-index --chmod` stays allowed. Both worker prompts say never to
   commit or stage: `close-story` commits the story's paths.

Private input, read first: the `git-guard.sh` sections of
`~/.vulyk/audits/framework-audit-2026-11-13/FINAL.md` hold the exact forms for item 1. The header and the card
list what is denied and what is left open; no comment, label or note says what used to pass.

Marked red: security branches in the hook that guards this build.

## Requirements
> 5. git-guard covers every git form that discards uncommitted work or commits, including git run through a shell, an alias or a heredoc fed to a shell. Every form it leaves open on purpose is named in its header.
> 6. git-guard without Python: a pure-bash fallback with the same verb list (a test compares both lists) still denies the work-losing verbs in Bash and PowerShell; a real interpreter that crashes on a git command denies it; the SessionStart brief says when Python is missing.
> 8. The scope check also catches edits outside `## Files` that were committed before `close-story`, counting from the head recorded at claim. A subagent cannot `git commit` or `git add` while a DRIVER holds the spec, and worker prompts say never to commit.
> 9. A story's approved version is bound to a commit that `cycle.sh` itself made, not to a commit subject.

## Files
- .claude/hooks/git-guard.sh
- docs/defects/work-discarded-by-git-verb.md
- docs/defects/work-discarded-by-git-verb.shell.fixture
- .claude/agents/worker-code.md
- .claude/agents/worker-test.md
- tests/maintenance.test.sh

## Non-goals
- Do not touch `.claude/settings.json` or `install.sh` (story 10): no matcher change, and the `onFailure` key is
  that story's decision. The deny on a crash lives in this hook's own wrapper.
- Keep the main-session rule (a listed verb is denied only when the affected paths are dirty) wherever Python
  runs; the stricter any-caller rule is the fallback's alone.
- Do not add `rm` or `Remove-Item`; they stay on the "not covered" list.
- Do not build the owner-word or court rules here (story 08, its own hook files), and do not change `cycle.sh`
  (story 09 writes the `revise` verb this hook closes to subagents).
- In the card, extend the existing Never bullet and `## Check`; add no bullet and change no status (story 08 owns
  `INDEX.md` in this wave). Add the new fixture to `fixtures:`.
- Do not edit `tests/maintenance.test.sh` outside the git-guard block and the worker-prompt pins.
- The Python stays in the no-op heredoc below `exit 0`; no bash 4 syntax in the fallback.

## Map slice
`memory/map/scripts-hooks.md` → Entry points (`git-guard.sh`), Gotchas; `memory/map/agents-and-commands.md` →
Agents (worker-code / worker-test); `memory/map/cycle.md` → Files, one writer each (DRIVER).

## Acceptance criteria
- [ ] `--check`, subagent: each form of the private list is denied, and its read-only or unforced twin passes.
  The first shell-fed case's label contains `a discarding verb fed to a shell is denied`. Main session: the same
  forms are denied on a dirty `porcelain` and pass on a clean one, except those that lose commits, which follow
  today's `branch -D` rule.
- [ ] The new fixture (a discarding verb inside a heredoc fed to a shell, hook-input JSON) fails `--check`; the
  two existing fixtures still fail; a heredoc fed to `cat` holding the same words passes.
- [ ] With every Python launcher stubbed away: each verb of the list is denied for a Bash and a PowerShell input,
  `git status` and `git log` pass, and a non-git command passes. A test extracts the fallback's list and the
  Python part's list and fails when they differ.
- [ ] With a launcher stub that exits 3: a git command is denied with the failure message, a non-git command passes.
- [ ] Subagent input, a `DRIVER` file present: `git commit -m x`, `git add .`, `git -C sub commit` and the same
  through `bash -c` are denied; with no `DRIVER` file they pass; the main session is not affected.
- [ ] Subagent input: `bash scripts/cycle.sh revise <story>`, `branch`, `reopen` and `stamp-red <story>
  --baseline` are denied; `close-story`, `stamp-red`, `advance`, `status`, `release`, `suite` pass.
- [ ] `worker-code.md` and `worker-test.md` each say never to run `git commit` or `git add`, pinned in the suite;
  `bash scripts/prompt-check.sh --touched .claude/agents/worker-code.md .claude/agents/worker-test.md` has no error.
- [ ] `bash scripts/portability-check.sh .claude/hooks/git-guard.sh` is clean.

## Verification
`bash tests/maintenance.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
<!-- appended by the builder: files changed, decisions, surprises - 1-2 lines each. End with one `CHANGELOG:` line
per ask (5, 6, 8, 9) that says what the guard does now. -->

## Findings
