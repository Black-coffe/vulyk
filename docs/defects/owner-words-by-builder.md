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
verdict, 8+ letters or digits unless a picked option; `--go` needs an owner prompt carrying `--go`. No Python or
an unreadable transcript: denied. `--check <file>` runs it on a fixture (hook input JSON; a `transcript` field
stands in for the file) and exits 1 on a deny. Left open on purpose: whether the words mean yes (no word list),
the transcript file itself (the session can write it), and text an agent wrote that the owner types or sends.

## Never
- Write a line that records the owner (a decision, a waiver, **Approved:**, `human-check.sh ACCEPTED`, a quote under
  `## Owner quotes`, a message in his name) from anything but his own words this session, verbatim.
- Widen what the owner said (time, scope, a promise) when writing in his name: leave a placeholder or ask.
- File model-written text (a relayed note, a filled prompt) as the owner's words.

## Allowed
- A draft in his name marked as a draft, with the open points left as `[ ]` for him.
