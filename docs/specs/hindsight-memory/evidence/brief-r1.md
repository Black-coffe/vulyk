# Editorial board, round 1 — Hindsight → VULYK

You are one of three independent members of an editorial board (Opus 5.5, Sonnet 5.5, Fable 5.1). You work
alone; you do not see the others' work. This is **study work**: you write a report, you change NO file in
the repo.

## The question from the owner

The owner read a Telegram post about **Hindsight** (vectorize-io/hindsight, agent memory that learns from
the owner's corrections). The post text: `SCRATCH/post.md`.

Decide: **what can VULYK take from Hindsight to extend itself, without harming VULYK's ideology and
concept?** Ideas, mechanisms, data shapes, algorithms — or nothing, if nothing fits. Also say what
must NOT be taken and why.

## Do all of this

1. Read the post.
2. Study Hindsight for real on GitHub: README, the Claude Code plugin (hooks: what runs before a prompt /
   after a reply, how recall is injected, token budget), the memory model (world facts / experience /
   observations / mental models, evidence quotes, confirmation counter, how an observation is *refined*
   instead of overwritten), retrieval (semantic, keyword, graph, temporal), its benchmark claims. Use
   WebFetch / Exa web_fetch / `gh api` (gh CLI is logged in) on github.com/vectorize-io/hindsight —
   read actual source files of the plugin and the consolidation/reflect logic, not only the README.
   Also check the post's claims (stars 42k, Mem0 66k, MemPalace 59k, `HINDSIGHT_LLM_PROVIDER=claude-code`
   personal-use only, port 9077, `HINDSIGHT_DYNAMIC_BANK_ID`) against the repo or two sources; mark
   each confirmed / not confirmed.
3. Study VULYK fully enough to judge fit. Repo: `E:/Projects/vulyk`. Minimum reading:
   - `CLAUDE.md` (constitution, Laws 1-6), `docs/architecture.md`, `docs/memory-system.md`,
     `docs/self-evolution.md`, `docs/defects/README.md`, `docs/hooks-reference.md`, `docs/token-economy.md`
   - ADRs `docs/adr/013-light-vulyk.md`, `014-defect-library.md`, `016-*`, `017-*`
   - grills that already decided memory/self-learning questions — **do not re-propose what they rejected
     unless you have new evidence, and then say so explicitly**:
     `docs/grill/2026-09-21-project-memory-chronicle.md`, `docs/grill/2026-09-27-self-learning-corrections.md`,
     `docs/grill/2026-09-27-self-learning-pilot-feedback.md`
   - `docs/specs/self-learning/plan.md`, `docs/specs/rrsi-self-improvement/report.md` (yesterday's study of
     a similar self-improvement post — do not duplicate it; build on it)
   - hooks `.claude/hooks/defect-intake.sh`, `defects-inject.sh`, `session-start-brief.sh`,
     `scripts/defects-check.sh`, `.claude/agents/librarian.md`, `.claude/commands/vulyk-evolve.md`
   - the separate chronicle plugin **litopys** (VULYK's chosen long-term memory, a separate plugin by
     design): look at `docs/chronicle/` here, and its public repo github.com/Black-coffe/litopys
     (README + bin) if needed.
   On this Windows box the Glob tool may return "No files found" falsely — use `ls`/`grep`/`cat` via Bash
   with explicit paths.

Known owner decisions you must respect (from memory, verify on disk if you rely on one):
- Lessons from owner corrections live in `docs/defects/` as class cards with verbatim quotes; a checkable
  class becomes a blocking `check:` with two fixtures; **prose-only lesson carriers are banned**, "never
  make the text louder"; forbids only.
- No model calls inside SessionEnd hooks (60 s cap). Model work goes to SessionStart, PreCompact or a command.
- Long-term memory = a separate plugin (litopys), VULYK is a consumer; navigation + grep first, vectors
  only if a golden-question metric says so; capture cost cap ~5% of session.
- No overengineering (Law 2); the owner forbids growing base prompts; injection cost ≤ ~1%.
- Sonnet executes, Opus judges, Fable gates; nothing below the model floor.
- No new runtime services a host must keep running is a strong prior (VULYK is bash + markdown +
  hooks, no server, no DB) — if you propose breaking it, justify hard.

## Output

Write your report to `OUT` (markdown). **Checkpoint**: create the file early and append each section as
you finish it, so a crash loses nothing. Structure:

1. **Fact check of the post** — table: claim | confirmed? | source URL(s).
2. **How Hindsight actually works** — 15-30 lines, from source, with file paths in its repo.
3. **VULYK today vs. Hindsight** — where they already overlap (name the VULYK file), where VULYK is
   stronger, where Hindsight has something VULYK lacks.
4. **Proposals** — `P1..Pn`, at most 7, each:
   - what exactly is borrowed (mechanism, not the product)
   - where it lands in VULYK or litopys (files), and which of the two owns it
   - why it does not harm the concept (name the Law / ADR / grill decision it respects)
   - cost (tokens / complexity / new deps), risk, how we'd measure it worked
   - size: Tier 0-4
5. **Rejected** — what must not be taken (e.g. installing Hindsight itself, a vector server, …) with reasons.
6. **Top-3** in priority order, one line each.

Be concrete and skeptical. "Take nothing" is a legitimate answer for any part. Your final reply to the
caller: 10 lines max — the path to your file and your top-3.
