# Grill brief: what VULYK takes from the "Spec-Driven Development with Coding Agents" course

<!-- supergrill-state
status: done
level: deep
hardness: medium
lens: product
questions_asked: 12
open_branches: []
next_question: ""
web_policy: allow
updated: 2026-10-08
-->

Date: 2026-10-07 | deep | medium | product | Claude Code, hive root E:/Projects/vulyk (v0.25.0, 8587c3e)

## Recon (what was known before the first question)
- Source: Recall #7103 "Full Course: Spec-Driven Development with Coding Agents" (JetBrains x DeepLearning.AI,
  instructor Paul Everett; YouTube, transcribed 2026-09-30, 49 265 chars).
- The course's loop: constitution (mission, tech stack, roadmap) written in conversation -> per feature: branch,
  spec as plan / requirements / validation, `/clear`, implement, human review + subagent deep review, merge ->
  replanning between features (constitution, roadmap, the process itself) -> skills to automate the loop.
- Full comparison: 23 practices graded against VULYK with file:line evidence, 8 gaps ranked
  (scratchpad report `sdd-vs-vulyk.md`, summarised here).
- VULYK already ahead on: verbatim traceability (`trace-check.sh`), evidenced blind council, deterministic gates,
  STALE after a hand edit, corrections -> checks (Law 6), self-evolution on a branch, study/code split, model routing
  + floor, token economy, stage confirmations on disk.
- Gaps: G1 plain-words digest at GREEN (`vulyk-build.md` Terminal `green` shows only the round count and the Council
  line); G2 no owner-ordered queue / roadmap in git; G3 no mission / audience in the Profile (constitution cap 7 168 B,
  ADR-016); G4 "why the plan was wrong" after an escalation (overlaps Law 6 + evolve); G5 brownfield import of
  TODO/issues (depends on G2); G6 constitution sha per spec; G7 README comparison vs SpecKit / OpenSpec (needs a
  fact-check); G8 portability via AGENTS.md / Agent Skills / ACP (clashes with `README.md:48` "only official Claude
  Code mechanisms").
- Contradictions in sources alone: `vulyk-ship.md` says the next circle "belongs to the owner", yet owner-ordered next
  items live outside git - Claude-side memory (`vulyk-next-circle-fast-verification.md`, "Owner's order, 2026-09-23"),
  handoffs ("Хвосты на следующий бриф VULYK", 2026-09-30), and per-spec files (`docs/specs/convergent-judge/next-circle.md`,
  spec `next-circle-0-22`).
- Owner rule on record (2026-09-30): results in plain words first; a dense table got "Я так и не понял".
- Rejected on data before: the human look as a stage (P14, `docs/cycle.md`), an external memory engine (ADR-019).

## Q&A transcript
Q1 (D1): which of the course's pains do you actually hit with VULYK today?
A1: tails get lost (G2); agents do not know why / for whom (G3). Not G1 (digest at GREEN), not G8 (portability). — opinion
    Recon backs G2: the owner-ordered "first item" of 2026-09-23 (fast/full verification, `convergent-judge/next-circle.md`)
    is in none of 8 releases since (0.18-0.25). Live again today: `close-story` of `haiku-5-5-floor` timed out at 540 s.
Q2 (D1, success criterion): when does the queue surface without the owner's memory?
A2: at session start - one line in the VULYK brief. — opinion. Closed.
Q3 (D2): what feeds the queue?
A3: all four - the owner's "запиши на потом", ship's tails (minor / UNASKED / next-circle draft), study reports'
    candidates, the Queen's own findings. Plus a new source: Claude Code's "Heads up" notes, collected while working
    and decided on later. — opinion
    Verified (T1): the notes come from the built-in mod `cc-plugin-you-should-know` ("Runs a side agent that watches your
    back while Claude works on longer tasks... shows you a note above the prompt", code.claude.com/docs/en/plugins/mods/overview;
    CHANGELOG 2.1.287 "Added You should know, a built-in mod where a side agent watches your back"). Enabled in every hive by
    VULYK 0.25.0. Local: only notes answered "1: Learn more" reach the transcript, as a user message "Here is a note offered
    by a side agent: > Heads up · ..."; 4 on this machine (2 senseti-doker, 2 vulyk); "2"/"0" leave no trace.

Q4 (D3): how to collect Heads up notes when Claude Code keeps only the "Learn more" ones?
A4: a short study first (can a VULYK mod see every note, incl. "0"/"2", and at what cost); meanwhile "1" notes are
    harvested from transcripts into the queue. — opinion. Closed.
Q5 (D2): where does the queue live?
A5: one file in each hive's git (`docs/queue.md`), a plain list; line order = priority. — opinion. Closed.
Q6 (D4, from A3's caveat): does the Queen append her own findings, or ask first?
A6: she appends herself, at the bottom, marked "не разобрано"; the owner's reorder or strike makes it sorted; the
    session-start line shows the sorted top + a count of new. — opinion. Closes "ship: next circle belongs to the
    owner" vs auto-fill: appending is not ordering.
Q7 (D2): litopys `## Brainstorm` vs the queue?
A7: different roles - litopys is the past (what was discussed), the queue is the future (what to do); nothing is
    copied from litopys. — opinion. Closed.
Q8 (D2): when does an item leave the queue?
A8: when its spec ships - /vulyk-plan marks which item it took, /vulyk-ship removes it with the version; the owner
    may strike any item at any time with a reason. git keeps the history. — opinion. Closed.
Q9 (D1, G3): where did agents not knowing "why / for whom" actually show?
A9: "plan and council miss the purpose" AND "no case yet, it is about the future". — opinion
Q10 (D4): A1 marked G3 as felt in practice, A9 says no case yet - so what happens to G3?
A10: into the queue, until the first case (trigger: a plan or the council missed the purpose). — opinion. Closed.

Q11 (D2): seed the new queue with the tails already scattered?
A11: yes, once - memory files, handoffs, `next-circle.md`, study reports, the 2 persisted Heads up notes; all "не
     разобрано", the owner's own orders on top, each line linked to its source. — opinion. Closed (folds G5 in).
Q12 (D5, sequencing): in what order?
A12: tests (fast/full split, ordered 2026-09-23) -> queue -> Heads up study. — opinion. Closed.
Mid-grill, 2026-10-08, the owner added a correction that jumps the order: an upgrade must merge, not replace, a hive's
CLAUDE.md ("чтобы не потерялся смысл, сенс, логика и правила того проекта"). It became spec `constitution-merge`
(Tier 2, planned, awaiting approval), to ship with 0.26.0.

## Synthesis
1. **Verdict.** The course's loop is already inside VULYK, mostly stricter. The one pillar VULYK lacks is the living
   roadmap: tails get lost because they live outside git. Build a plain owner-ordered queue, `docs/queue.md`, shown in one
   line at session start, fed by five sources, closed by ship. Mission/audience waits for a real case; portability is
   rejected; the GREEN digest is not a felt pain.
2. **Decision log.** G2 yes (A1-A8, A11) · G3 queued until a case (A10) · G1 dropped (A1) · G8 rejected (A1, clashes with
   "only Claude Code mechanisms") · Heads up: study first, "Learn more" notes from transcripts meanwhile (A4) ·
   order: constitution-merge (owner, 2026-10-08) -> fast/full tests -> queue -> Heads up study (A12).
3. **Assumptions.** ✗ a VULYK mod can observe the You-should-know note incl. "0"/"2" (the study) · ✗ the queue stays
   readable in one line (count after two weeks of use).
4. **Facts.** ✅ "You should know" = built-in mod `cc-plugin-you-should-know` (docs mods overview; CHANGELOG 2.1.287) ·
   ✅ only "Learn more" notes persist in transcripts, 4 on this machine (local grep, 2026-10-07) · ✅ the 2026-09-23
   fast/full order is unbuilt through 0.25 (CHANGELOG) and cost two 540 s timeouts on 2026-10-07 (measured).
5. **Contradictions.** ship "next circle belongs to the owner" vs auto-fill -> append is not order (A6) · Queen's
   findings vs "only after your yes" -> unsorted mark (A6) · G3 felt vs "no case yet" -> queued (A10).
6. **Risks.** The queue becomes a dump -> unsorted items shown only as a count · two homes for undecided ideas -> litopys
   is the past, the queue the future (A7).
7. **Residual ambiguity.** goal clarity 8/10 · decision-tree coverage 7/10 (queue line format and the per-hive
   install path are plan-time details) · evidence strength 6/10 (the Heads up mod's internals unread).
8. **Next step.** Approve and build `constitution-merge`; then `/vulyk-plan` the fast/full verification split.

## Ledger (kept current at every wave)
### ✅ Facts — with source
- Owner-ordered "fast/full verification" (2026-09-23) unbuilt through 0.18-0.25 — CHANGELOG, next-circle-0-22 Asks.
- `close-story` default budget 540 s (`cycle.sh:1892`, ADR-013 D5); `telemetry.test.sh` 532 s standalone, timed out at
  468/478 under close-story on 2026-10-07 — measured.
- "You should know" = built-in mod `cc-plugin-you-should-know`, side agent, note above the prompt — docs + CHANGELOG 2.1.287.
- Only "Learn more" notes persist (user message "Here is a note offered by a side agent"), 4 on this machine — local grep.
- litopys records carry `## Brainstorm` ("ideas raised and not decided"), per session, git-ignored by default,
  11 journals pending distill here — `E:/Projects/litopys/agents/distiller.md`, SessionStart banner.
### 🎯 Decisions — with why
- G2 queue: yes. G3 mission/audience: open. G1 digest at GREEN: not a felt pain, dropped. G8 portability: rejected.
- Queue surfaces at session start, one line (A2).
- Sources: owner's "запиши", ship tails, study candidates, Queen's findings, Heads up notes (A3).
- Heads up: study first, "1" notes from transcripts meanwhile (A4).
- Home: `docs/queue.md` in git per hive (A5).
### 🅰 Assumptions — ✓ verified (how) / ✗ unverified (cheapest check)
- ✗ A VULYK mod can observe another mod's note, incl. dismissed ones — the Heads up study.
- ✗ The queue stays small enough to read in one line at session start — count after 2 weeks.
### ⚠️ Risks — with the user's chosen mitigation
- The queue becomes a dump (5 sources, one of them automatic) — open (Q6).
- Two homes for undecided ideas: litopys `## Brainstorm` and `docs/queue.md` — open.
### ❓ Open branches
- Queen's findings: appended on her own, or after the owner's yes?
- Who orders the queue, and when an item leaves it.
- litopys Brainstorm vs queue.
- G3: mission / audience — where, and who reads it.
### 🔍 Contradictions — found / resolved how
- `vulyk-ship.md` "the next circle belongs to the owner" vs an auto-filled queue — resolved (A6): the Queen appends
  unsorted, the owner orders.
- A3 picked "Queen's findings" whose own description said "safer only after your yes" — resolved (A6): appended,
  marked unsorted, shown only as a count until the owner sorts it.
- A1 "felt in practice" for G3 vs A9 "no case yet" — resolved (A10): G3 is anticipated; it waits in the queue.

Wave 2 decisions: A6 Queen appends unsorted · A7 litopys stays the past · A8 an item leaves on ship or owner's strike ·
A10 G3 waits in the queue for its first case.

## Rejected alternatives (with why)
