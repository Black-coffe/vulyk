# docs-1115 - the doc contradictions of the 2026-11-15 inventory

**Date:** 2026-11-18 · **Owner:** Andrei · **Tier:** 1 · **Sibling specs:** `guards-1115`, `tails-1115` (both
merged, 0.54.0-dev.5)

## Request (verbatim)
> бери все известные косяки и недочеты и устраняй и выкати минорную версию после фикса

(2026-11-15, the request behind all three 1115 specs.) 2026-11-18: «Сделай хенд-офф, запиши планы на 1115, Tails и
запусти в новой сессии его. Но публикацию 0.54 в GitHub не делаем.»

## Privacy
Items are named by their private inventory number (T<n>); the exact text lives in
`~/.vulyk/audits/known-defects-2026-11-15/tails.md`. Nothing from it enters the repo but the corrected sentences.

## Answers (owner, picked options verbatim, from the private `decisions.md`)
- Shape: «Три спеки, один 0.54.0 (Рекомендую)» - this spec is the docs part, after the two code specs.
- A10 (T88): the defects README stops promising that `## Allowed` lines are dated owner quotes; quotes live under the
  owner-quote list. A11 (T99) CHANGED: README only, the 1.0-bar code is untouched. A12: docs match "instead". T4 by
  trimming.
- 2026-11-17, the rule for this repo: at most two rounds, checks sized to the change, no Sonnet or Haiku here
  (Fable and Opus only, every agent dispatched with an explicit model).
- 2026-11-18: no GitHub publish of 0.54 in this work.

## Asks
1. Every doc sentence the inventory items T18, T19, T21, T60, T66, T79, T81, T82, T83, T84, T86, T88 (A10), T89, T91, T99 (A11, README only) and the doc halves of T65, T80, T90 name says what the code does at HEAD; nothing else in those pages changes.
2. The doc lines `tails-1115` handed on are applied: the `memory/map/` lines of its stories 01, 02, 05 (listed under story 11's `## Findings`), and `.claude/commands/vulyk-bootstrap.md:23` (one blind seat, swapped for `haiku` when *Client path* is filled); `docs/hooks-reference.md` describes the 0.54 guard hooks in the general words of their headers; `docs/token-economy.md:144` matches the code.
3. No code, test or hook changes; the docs tests that pin sentences stay green.

## Answers

**After escalation (round 1, 2026-11-18).**
> Owner 2026-11-18: «Чиню сам, без раунда 2 (Рекомендую)» - Queen fixes both majors and the in-Files minors; templates/memory.md to the next circle; no round 2
