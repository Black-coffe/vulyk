# Stream B — Context keeper (round 2)

Date 2026-09-29. Everything below was checked on disk today. Byte counts: `wc -c`, `git show <tag>:CLAUDE.md | wc -c`.

## 1. Attacks

**On A**
- **Wrong line citations (the content is right):**
  - `vulyk-evolve.md:106`: the file has 61 lines. The "one line each" text is at `:58`.
  - `docs/memory-system.md:38`: the file has 26 lines. The librarian text is at `:16`.
  - `skill-gardener/SKILL.md:39`: the file has 22 lines. The rule is at `:16`.
- **§1.12, the guard on `scope_breach` blocks every changeset.** `scope_breach` makes up 167 of the 195 rows in `anomalies.jsonl`, and 127 of the 140 rows in `scope.jsonl` have `out_of_scope>0`. A guard with a 91% base rate is always on. C already made this point, and A's guard ignores it.
- **§1.6, a δ = 2·sd band over past weeks.** There are about 3 weeks of data (`council.jsonl` has 16 rows) and 9 minor versions shipped in 16 days. The sd would come from a different harness every week. The band cannot be estimated. It is honest to print n, not δ.
- **§1.7, `context_bytes_delta` puts "agent bodies" into the always-on set.** It is not always on. A body loads only when that agent is dispatched. It costs in proportion to how often the agent is dispatched, so it needs a separate account from `CLAUDE.md`.
- **§1.10 overreaches.** A says "the removal is not recorded" (`history.py:129-138`). In fact a prune edit is recorded as an ordinary accepted edit with `hypothesis: "prune: …"` (`propose.py:122-125`, `history.py:83-99`). What is missing is the link to the edits it removed: `accepted_edits()` keeps listing them. The weakness is real, but it is narrower than A says.

**On C**
- **"Exploration forces K_str (client_tool, skill, memory, subagent)" is wrong.** `untried = [c for c in K if c not in tried]` (`history.py:198`) covers all 9 components, including `prompt` and `config`. Novelty ν counts K_str, but exploration does not. C's conclusion (reject the stall rule) still holds on other grounds.
- **"The prune set already exists" (`vulyk-evolve.md:57`) overreaches.** That rule covers only skills and uses only usage (`skill-gardener/SKILL.md:16`). The constitution, `.claude/rules/` and `text` cards have no exit criterion at all. The rule has also never run: there is no `vulyk/evolve-*` branch.
- **"+55% over H₀" is correct arithmetic (2.42/1.56) but misread.** The same row shows OOD +3.9 and ID held-out +2.3, so it is a trade and not a pure ratchet. The part I accept is C's cure: measure against the release, not against the current incumbent.

## 2. Concessions

**(a) The caps.** Measured today, VULYK's own always-on set in the Queen's session:

| Item | Bytes |
|---|---|
| `CLAUDE.md` (in git, v0.20.0) | 8,531 |
| agent descriptions | 2,907 |
| command descriptions | 1,716 |
| SessionStart output (413 + 616; the handoff adds up to 4,000 only after `/clear` or a compaction, `handoff.py:74`) | 1,029 |
| **Total** | **14,183** |

On top of that sit the owner's global `CLAUDE.md` (9,205) and `MEMORY.md` (2,379). Per turn the cost is about 0:
- The handoff nudge is about 0.45 KB, at most 3 times per session (`handoff.py:62, 770-786`).
- `defect-intake` adds 544 B only on a correction prompt.
- `defects-inject` adds 0 today, because there are no cards.

Cost per dispatch:
- Tier 1 `lead-review`: 4,711 + 8,531 + 9,205 ≈ 22.4 KB.
- Tier 3 `worker-code`: ≈ 21.4 KB.
- Agents with `omitClaudeMd`: 0.7 to 3.9 KB.

So `CLAUDE.md` is paid once per non-omit dispatch, which makes it the unit worth pricing.

**My 16 KB was a round number, and I withdraw it.** The only sourced cap is ADR-013 D7, "under ~7 KB and under 120 lines" (accepted by the owner, `013-light-vulyk.md:3, 255-256`). Today the file is 8,531 B and 121 lines, so both limits are already exceeded.

I also correct the r1 framing:
- "+19% in 2 days" used the CRLF size. In git the sizes are v0.18.0 7,269 → v0.19.0 7,875 → v0.20.0 8,531.
- Each step is one paragraph backed by an ADR the owner accepted (014, 015). That growth was paid for, not blind accretion.

**(b) Who pays.** Metrics cannot pay, because C's numbers put them inside the noise. The honest payments are events that can be counted without noise:
1. an owner-accepted ADR or decision, with a verbatim quote;
2. a defect card with 2+ dated quotes;
3. a `check:` that fails on the original case and on a neighbour form.

There is one limit: payment 2 pays only for the on-touch tier (the card's `paths:`). Always-on growth also has to pass a placement test: if a rule can be scoped to a path, it does not go into `CLAUDE.md`. Payment 3 is negative bytes, because the text leaves context and becomes code.

**(c) Firing does not mean usefulness. I drop fire logging.** A card that does not recur has two possible explanations: the card works, or the area is dead. We cannot tell them apart. What can be decided without counting fires:
- **Dead exposure.** The card's `paths:` or a rule's glob match no file in the tree. This is a static check in `defects-check.sh`, and such items are prune candidates.
- **Recurrence despite exposure.** A dated quote newer than the card means the text did not work. The answer is to escalate to `check:`, not to delete. Law 6 already does this.

**(d) Forgetting, and the safety net.**
- `learnings/`: 42 files, all in git (`git ls-files`). Deleting the 36 stubs is safe; I verified them as empty by content.
- `.claude/handoff/`: gitignored (`.gitignore:12`). I propose no deletion there.
- The graveyard with `RETIRED.md` is in git.
- The chronicle is **not** a safety net here: litopys is not installed (SessionStart says so), and `docs/chronicle/sessions/` holds 2 files.
- The real risk is `MEMORY.md` and auto-memory under `~/.claude/projects/…`. It lives outside git, and trimming it cannot be undone.

The rule: **nothing outside git is deleted, only moved into git first**. Everything inside git is removed by an owner-approved commit, and git history is the net.

## 3. Final position

1. **Context price rule measured against the last release** — MERGE-WITH-A (§1.7) and C (review question, release baseline). The set is `wc -c` of `CLAUDE.md`, agent/command descriptions and hook output. Growth passes only with an ADR, a card with 2+ quotes (on-touch only) or a `check:`. The one absolute cap is ADR-013's 7 KB / 120 lines. Cut reason: the 16 KB was a round number, and δ-metrics cannot pay.
2. **`memory/stats/evolve.jsonl`, a log of evolve hypotheses** — MERGE-WITH-A (§1.2) and C. My addition: one-line summaries of all rejected changes stay visible, not just the last 40 rows. That fixes the window-forgetting shown at `history.py:166-185`.
3. **Prune by dead exposure, escalate on recurrence** — KEEP, reshaped. A static dead-path check in `defects-check.sh`, with Law 6 handling recurrence. Cut reason: fire counts reward noise.
4. **Knowledge moves down, plus the placement test** — KEEP. Learning → on-touch → `check:`. Anything that can be scoped to a path never goes into `CLAUDE.md`. Cut reason: none; this is ADR-014 generalised.
5. **Hygiene (Tier 0)** — KEEP. One `/vulyk-gc` run (the stubs are verified empty and in git), a fix to the counter at `session-start-brief.sh:8`, and auto-memory moved into the repo before it is trimmed. Cut reason: I dropped the handoff-by-direction item. It belongs to the owner's global hook, not to VULYK.
6. **Fire logging in `defects-inject.sh`** — DROP. See (c).
7. **The 16 KB always-on cap** — DROP. See (a).
