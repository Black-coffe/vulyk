# Close the known gaps in VULYK's guard hooks (brief) - part 1 of 3 for 0.54.0

**Date:** 2026-11-15 · **Owner:** Andrei · **Tier:** 3 · **Sibling specs:** `tails-1115` (code tails), `docs-1115` (docs),
one minor release 0.54.0 after all three.
**Source:** the owner's request below. The verified inventory is private (`~/.vulyk/audits/known-defects-2026-11-15/`,
`security.md` items S1-S14 and `tails.md` item T14, plus `decisions.md`), never in the repo: it names open gaps in
security controls, and those stay private until the fix is released.

## Request (verbatim)

> бери все известные косяки и недочеты и устраняй и выкати минорную версию после фикса

## Privacy
In this repo the gaps are named only in generic words (owner rule: a vulnerability map stays private until released;
card `host-internals-in-public-repo`). Stories name the private item numbers (S<n>, T<n>); a worker reads the exact
forms from the private file. Comments, test labels, commit messages, the journal and council reports describe what a
hook refuses, never a working bypass of a still-open form.

## Answers (owner, 2026-11-15, picked options verbatim)
- Shape: «Три спеки, один 0.54.0 (Рекомендую)» - this spec is the guards part.
- Forms the hook headers name as open on purpose: «Только безопасные (Рекомендую)» - close the forms no agent needs
  (reading another round's court or the Queen's temp scratchpad, `tag -f`, `push --force`, `iex`); keep running code
  through an interpreter for council seats, and say so in the header.
- ADR statuses: «Принять все 15 (Рекомендую)» - done before this plan (479ba709).

## Answers (owner, 2026-11-16, after round 1 ESCALATE, picked option verbatim)
- Round 1 escalated (`half`: asks 1, 3-7 RED, ask 2 BLOCK): the hooks judge shell text, so a neighbour spelling always
  exists, and "by any tool" / "by any verb" cannot be met. Owner: «Ремонт классами + сузить вопросы (Рекомендую)».
  Meaning: one repair closes the found forms by class (paths resolved to one form; during a build a subagent gets
  only a read list of git verbs; the git and cycle.sh words found in every command position; what the hook cannot
  resolve is refused for a subagent), fixes the round-1 regression and the over-denies, each with a test. Asks 1, 3,
  4, 5 are narrowed below to the named form classes; every other form is named open in the hook's header, and each
  header says the guards stop accidents and shortcuts of a cooperative agent, not an adversary. Then a full round.
  If round 2 is RED again only on neighbour spellings, the fallback is the minimum: fix the regression and the
  over-denies, list the open forms honestly, close the rest in 0.55.0 (with a guard design not built on shell text).
  No 0.54.0 text (docs, CHANGELOG, release notes) says "any tool" or "any verb" of these guards.
- 2026-11-16, during the repair: the model's safety classifier stopped the git-guard repair worker three times on
  the list of forms; owner-guard was repaired by class. Owner: «Минимум для git-guard (Рекомендую)». Meaning: for
  git-guard only, the fallback now: fix the round-1 regression and the over-deny, add the cooperative-agent sentence
  and an honest open list by class (no spellings) to its header; its other classes move to 0.55.0 (a guard design
  not built on shell text), listed under plan.md `## Descoped`. owner-guard and court-guard keep the class repair.
  Asks 1, 3 and 4 are narrowed below for git-guard's part.
- 2026-11-16, after round 3: the Queen had extended that answer to ask 2's git-guard part (the `cycle.sh` verb
  spellings) on her own and recorded it under the owner's quote; asked, the owner chose «Чинить сейчас
  (Рекомендую)»: that class is fixed in this spec (story 10), and ask 2 keeps its wording.
- 2026-11-16, after round 4: the forced tag, forced push and `iex` forms had been denied to the owner's main
  Claude session too, on the Queen's own reading of «Только безопасные» (asked about subagents). Asked, the owner
  chose «Push/tag нельзя, iex можно (Рекомендую)»: the main session is denied forced push and forced tag;
  `iex` / Invoke-Expression stays allowed to the main session; subagents are denied all three.
- 2026-11-17, after round 5 (RED): the owner chose «Закрыть ремонт, узкий раунд 6 (Рекомендую)», whose text set
  the stop: if round 6 is RED again, no more rounds, and by default court-guard's parser goes back to its
  pre-round-4 version.
- 2026-11-17, after round 6 (ESCALATE): the owner chose «Откат к версиям без регрессий (Рекомендую)»: each hook
  goes back to its newest version that lets through no form 0.53 refused (court-guard as judged in round 3,
  git-guard and owner-guard as judged in round 5), with their tests and headers; no council round follows; the
  Queen re-runs the recorded forms against 0.53, then the full suite, then the owner's acceptance names the open
  classes and the over-denies that come back (to 0.55.0).

## Asks
1. A subagent cannot forge or alter the cycle's run-state records (claim, approval, verification) through the named
   form classes: a write tool by any spelling of the path (resolved: letter case, dot-dot, trailing dot or space, a
   link); a shell writer, a spaced redirect or an in-place editor naming the path; an interpreter naming the path.
   The shell classes git-guard does not close in 0.54.0 are named open in its header, by class. So history, scope and
   verification checks read only what `cycle.sh` wrote (private S1, S13).
2. The owner-record guards cannot be walked around by spelling the guarded script or record differently (quoting,
   globbing, a variable, a directory pathspec, a changed directory) (private S2, S11, S12).
3. During a build a subagent cannot change git history by the verbs on git-guard's list, not only `commit` and
   `add`; verbs outside the list are named open in the header, by class (private S3).
4. git-guard sees the git verb past the global options and command positions its tests pin, and keeps its subagent
   rules when Python is missing; a `cd` that does not take effect does not move its build-lock lookup, and an
   unresolved variable in a command word that names no guarded thing is not refused; the positions it misses are
   named open in the header, by class (private S4, S5, T14).
5. The blind council seat's court cannot be left through the named form classes: git reads by an allowlist wherever
   git stands as a command; paths resolved (dot-dot, a link or junction, one made in the same call, letter case), a
   path glued to its option, held in a variable set in the same call, inside a quoted substitution, or a file URL; no
   system-path escape. Any other form is named open in the header (private S7, S8, S9).
6. The header-named open forms are closed as answered above (private S6, S10), and each hook header lists exactly
   what it still leaves open, in general words, and says the guards stop accidents and shortcuts of a cooperative
   agent, not an adversary.
7. Every closed gap has a failing test with the original form and a neighbour form (Law 6), and no legitimate flow of
   the Queen, a worker or a council seat is denied (existing suites stay green).
8. Leftover raw test output is not left in the temp folder after a pause (private S14).

## Answers

**After escalation (round 1, 2026-11-16).**
> «Ремонт классами + сузить вопросы (Рекомендую)»

**After escalation (round 2, 2026-11-16).**
> «Теперь в ремонт классами (Рекомендую)»

**After escalation (round 4, 2026-11-16).**
> «Ремонт: регрессии + вопрос 2 (Рекомендую)»

**After escalation (round 6, 2026-11-17).**
> «Откат к версиям без регрессий (Рекомендую)»
