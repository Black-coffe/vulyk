# owner-guard must not block committing a record human-check already wrote (brief)

**Date:** 2026-11-14 · **Owner:** Andrei · **Tier:** 1 · **Escaped from:** audit-fixes-1113

## Request (verbatim)

> (Forwarded by the owner: a side agent's note, not the owner's own words) owner-guard ложно блокирует законный коммит записи приёмки: `git add memory/stats/human.jsonl` с ACCEPTED в сообщении коммита считается подделкой записи (one clause (moved to a private file before publishing)). Починить до выкатки в остальные ульи: записью приёмки считать только команду, которая реально пишет в human.jsonl, а не упоминание пути.

Reproduction (2026-11-14, the main session, right after a legitimate `human-check.sh ... ACCEPTED` with the owner's
quote): `git add docs/specs/<slug>/plan.md memory/stats/human.jsonl && git commit -m "vulyk(<slug>): human check ACCEPTED"`
-> `PreToolUse:Bash hook error: VULYK owner guard: a human.jsonl row written by a command for a spec the hook cannot
name.` The same refusal met a heredoc that only wrote this brief's text to a temp file. Cause:
`.claude/hooks/owner-guard.sh:410` treats any command that names `human.jsonl` and holds `ACCEPTED` or `REJECTED`
anywhere (a commit message, a heredoc body) as writing a row.

## Asks
1. owner-guard keeps the strict record rule: a shell command naming `human.jsonl` beside ACCEPTED or REJECTED is a row write, a `git add` / `git commit` included; `scripts/human-check.sh --commit` commits its own `plan.md` line and record row with `git commit -- <those paths>`, so no agent command has to name the record beside a verdict, and the callers use `--commit`.

Ask 1 was rewritten on 2026-11-15 after the re-check BLOCK at 56ec89b7: the owner picked «Строгое правило + коммит внутри скрипта (Рекомендую)» (an option label, the agent's wording). The earlier ask (a row counts only when the command writes the file) was dropped: every shell-text parser built for it let writes through or refused real commits.
