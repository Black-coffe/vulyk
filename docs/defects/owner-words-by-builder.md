---
id: owner-words-by-builder
title: The owner's words or decision written by the builder
status: block
check: bash .claude/hooks/owner-guard.sh --check <arg>
fixtures: [docs/defects/owner-words-by-builder.original.fixture, docs/defects/owner-words-by-builder.neighbour.fixture]
keys: [в любое время я не могу, waived, не называл]
paths: ["docs/defects/*.md", "docs/specs/*/plan.md", "scripts/human-check.sh", ".claude/hooks/owner-guard.sh", "scripts/acceptance-log.sh", ".claude/hooks/defect-intake.sh"]
---

# The owner's words or decision written by the builder
A line that only the owner may write - his decision, his waiver, his acceptance, a message in his name, a quote on a
defect card - is written by the agent doing the work. It may paraphrase him generously or invent him outright; either
way the record now says the owner decided what he did not, and the gate that waited for him opens on the builder's
word.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-15 · a video hive · the owner's real choice, after a builder-written `waived` line had passed a script gate as his decision — «Ваша фраза + голоса из кейсов»
- 2026-10-07 · a consulting hive · a client reply drafted in the owner's name that widened his availability — «Завтра в любое время я не могу. Завтра с 12:00 созвон по фонду, по основной работе, поэтому либо завтра после двух часов.»

## Cause
The builder holds the pen for every file, including the lines that record the owner. A gate that accepts any text in
an owner field (`waived`, **Approved:**, ACCEPTED, a quote) is held only by the honesty of the one it holds. In VULYK
the same risk was caught in planning on 2026-10-15: a mod's button would have filed a model's note as an owner quote.

## Check
`.claude/hooks/owner-guard.sh` (PreToolUse, `Bash|PowerShell|Edit|Write|MultiEdit`) guards `human-check.sh
ACCEPTED|REJECTED`, `cycle.sh briefed --go`, a new or changed `**Approved:**` / `**Checked:**` line of a spec's
`plan.md` and an ACCEPTED / REJECTED row of `memory/stats/human.jsonl`. A subagent is always denied. The main
session passes only when the note or the line quotes the owner whole, read from the session transcript: a prompt
of type `user` with origin `human` (injected blocks, pastes and side-agent notes cut), or an `AskUserQuestion`
answer. `**Approved:**` quotes his latest message after the `vulyk(<slug>): plan` commit; an acceptance quotes the
answer to the release question asked alone (one question naming the slug) or his next message, after the latest
verdict, 8+ letters or digits unless a picked option; `--go` needs an owner prompt carrying `--go`; a guarded
script run the main session spells otherwise (quotes, a pattern, a variable the command sets) is denied while a word
of its text prefilter stays whole. No Python or
an unreadable transcript: denied. `--check <file>` runs it on a fixture (hook input JSON; a `transcript` field
stands in for the file) and exits 1 on a deny. A subagent's Edit, MultiEdit or Write is judged by its path
resolved (letter case, a trailing dot or space, links); its shell command by every word that may be a program
word (behind keywords with options, unknown wrappers, a variable, `find -exec`), and by every target that may be
a plan.md or the record (any writer's file, an output option, a glob matched on disk; an unreadable target next
to a word naming one). Interpreter text holding a lone `*`, `**` or `$name`, and a write target that is only a
variable or a wide glob, pass.
The guards stop accidents and shortcuts of a cooperative agent, not an adversary.
Left open on purpose (the hook header's last block lists the same):
- the main session's text prefilter and spelled-form reading: a guarded script run whose text holds none of
  the prefilter's words (its script, verb or verdict word split by a quote pair, a backslash or a variable the
  same command sets, so that no prefilter word stays whole), a script, verdict or flag from a value the main
  session's command does not set (the environment, a substitution), and a marker or record the main session's command or tool path never spells
  (built from quotes, globs, braces, variables or a changed directory, in another letter case, or a plan.md
  named without its `docs/specs/<slug>/` path) is not read, and the quote rule judges only what is spelled;
- command text a shell reads from a file or a pipe (a script file, a list of commands piped into a shell),
  and code an interpreter runs, inline or from a file: their content is not read for what it runs;
- a plan.md written by a git verb that writes the tree, and, for the main session, by a writer outside the
  hook's list (a line editor, a patch, sync or link tool);
- for a subagent, a write the hook cannot tie to the file: a writer it does not know that takes its file as
  a plain argument; behind another program word, a program spelled as a pattern, or a plain-argument writer
  given by an unknown value; a target that comes only from a file, a pipe or the environment while no word
  of the command may be a plan.md or the record; a hard link to the file made by an earlier call;
- a guarded script copied or linked under another name, a commit of what an earlier call staged, and a
  verdict word in the message of a git verb other than commit or in a message file the hook cannot read;
- writes through tools the hook is not wired on (a notebook editor, an MCP file tool), and the run state
  reached by a shell command, which git-guard.sh judges;
- whether the owner's words mean yes (no word list), the transcript file itself (the session can write it),
  and text an agent wrote that the owner types or sends;
- with no Python: for a subagent, what its text filter cannot see (a name or verdict built from pieces that
  hold none of its fragments, a run-state path reached through a link, a git pathspec that covers the
  record without naming its folder), and for the main session every shell rewrite of a plan.md that spells
  no marker;
- refused although harmless (a known over-deny, 0.55.0): for a subagent, text that only quotes a guarded call
  (a heredoc fed to cat, an echo or printf word: a seat's report, a worker's note).

## Never
- Write a line that records the owner (a decision, a waiver, **Approved:**, `human-check.sh ACCEPTED`, a quote under
  `## Owner quotes`, a message in his name) from anything but his own words this session, verbatim.
- Widen what the owner said (time, scope, a promise) when writing in his name: leave a placeholder or ask.
- File model-written text (a relayed note, a filled prompt) as the owner's words.
- Record an acceptance from an answer that could answer another question in the same message (an "ok" beside a
  session or handoff offer): put the release question alone, and ask once more for an explicit yes or no.

## How-to
- Before an acceptance question, put the diff (or its key hunks) as fenced text in the reply itself: tool output is
  folded in the terminal, so "the diff above" about a tool call shows the owner nothing.

## Allowed
- A draft in his name marked as a draft, with the open points left as `[ ]` for him.

## Source
- 2026-11-18 · auto memory vulyk-feedback-ambiguous-ok-is-not-accepted.md · retold, not a quote
- 2026-11-18 · auto memory vulyk-feedback-diff-in-reply-before-accepted.md · retold, not a quote
