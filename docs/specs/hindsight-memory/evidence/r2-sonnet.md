# Board R2 - Sonnet 5.5 - cross-grill and vote

Read-only everywhere except this file. I ran `redact.sh` and `defects-check.sh` read-only (the latter against D:/YouTube_AI, it executes that host's `check:` commands).

## 1. Checks

| Claim | Author | Holds? | How I checked |
|---|---|---|---|
| 61 of 110 `## user` blocks in VULYK's own journals are `<task-notification>` | Opus | Yes | `E:/Projects/vulyk/.litopys/raw/*.md`: `grep -c '^## user'` sums to 110; `grep -h -A3 '^## user' \| grep -c '<task-notification'` = 61 (a wider tag set gives 64). Caveat: many are this very board's agent reports, so the rate is inflated by multi-agent sessions, not a steady-state number. |
| The owner's own text carries harness tags | Opus | Partly | First block of `13718469...md` is the owner's message with the Telegram post inside `<pasted_content>`: pasted material, not harness output and not the owner's words. Affects the C1 label (see vote). |
| `не дышит` is a key of two cards; 3 containment pairs in 113 keys | Opus | Yes | YouTube_AI `speech-cut.md:7` and `breath-cut.md:6` both list `не дышит`; python over all cards: 113 keys, pairs = (breath-cut, speech-cut `не дышит`), (dead-silence `пустота` / overlay-on-busy-screen `где пустота`), (script-shallow `неполноценно` / shoot-step-guesswork `неполно`). My R1 parse found none and I wrote "at most one shared key": that was a parser slip, Opus is right on the count. |
| ...and "each hit is a real ambiguity" | Opus | No, 2 of 3 are not | `пустота` (audio, dead-silence) vs `где пустота` (frame overlay) and `неполно` vs `неполноценно` (script vs shoot step) are different classes that happen to share a stem. Only the exact-equal `не дышит` is a plausible split. A RED gate would fail the host on 3 pairs, 2 of them harmless. |
| `memory/learnings` "is being retired" | Opus | Half | ADR-014 supersedes the *session-end distillation*, grill 09-21 D9 says "learnings упраздняется", but `librarian`/`/vulyk-gc` were wired on 09-29 (ADR-017) and `CONSOLIDATED.md` (59 lines, 4 sources merged) was committed 2026-09-29. The dir now holds only `CONSOLIDATED.md` + README: no raw learnings, so gc's trigger (stubs or >=10 raw) will not fire. Alive but empty. |
| The grill decided "sorting by repeats x freshness" and a count on the injected line | Fable | Yes, and unbuilt | `docs/grill/2026-09-27-self-learning-corrections.md:99`: "одна строка на запрет (... · повторов 3), сортировка по повторам×свежести, <= ~1000 токенов". Listed under "Решения без вопроса (Law 1, рутина)". `defects-inject.sh` card header is `cid — title` only, no count (read the code). |
| Hindsight's `claude_code_llm.py` isolates the spawned CLI (scratch `CLAUDE_CONFIG_DIR`, `CLAUDE_SECURESTORAGE_CONFIG_DIR=""`, issue #1751, CLI >= 2.1.150) | Fable | Yes | raw file lines 38-60. Its reason is macOS keychain namespacing; on this Windows box OAuth credentials live in the config dir, so a scratch dir may lose login (untested). |
| litopys `bench` spawns `claude -p` with host hooks firing | Fable | Plausible, no damage seen | `/tmp/lit/bin/litopys:478-494` runs `claude -p --plugin-dir`; but none of the 11 raw journals in VULYK is a bench session and `.litopys/` has no bench-journal trace. No evidence of pollution. |
| `hindsight-memory` plugin deprecated; successor writes hooks to `~/.claude/settings.json` | Sonnet (mine), Fable | Yes | `upgrade_notice.py` NOTICE text; coding-agents README: "3 hooks in `~/.claude/settings.json`". |
| 9 of 9 YouTube_AI `text` cards have no `paths:` | Sonnet (mine) | Yes | all 22 cards have `area:`, 0 `paths:`; host `defects-inject.sh` has 0 mentions of `area` and reads only `fm.get('paths')` (line 253). |
| ...holding "32 owner quotes, one class 13" | Sonnet (mine) | **No, wrong** | I counted every `^- YYYY-MM-DD · ` line, including log/revoked lines. Counting only under `## Owner quotes` for the 9 text cards: 2+1+1+1+2+1+3+7+1 = **19**; `shoot-step-guesswork` = 7 (matches `defects-check.sh`: "7 quotes" and Opus's 7). The conclusion (9 of 9 undeliverable) stands, the volume does not. |
| `redact.sh` masks 5 of 15 shapes; Telegram token and npm pass | Sonnet (mine) | Yes | re-ran: `123456789:AAA...` and `npm_...` come out unchanged. |
| Fable: `retractions.py`, `claude_code_llm.py` exist in Hindsight | Fable | Yes | `gh api .../git/trees/HEAD?recursive=1` lists both. |

## 2. Votes

Bar: does it pay for itself under Law 2, and does the evidence exist on disk today.

| ID | Vote | Variant | Amendment | Reason |
|---|---|---|---|---|
| C1 | FOR with amendment | - | Three buckets, not two: harness text (`<task-notification>`, `<system-reminder>`, `<cross-session-message>`) -> `## notice`; `<pasted_content>` -> `## pasted` (owner-supplied material, still not the owner's words); the rest stays `## user`. Reuse `defect-intake.sh`'s strip list, do not fork it. | 61/110 verified. It is the prerequisite for C2 and C3; $0, bash. |
| C2 | FOR with amendment | - | Validate the quote against `## user` text only (after C1), whitespace-normalised substring; the distiller must omit a quote it cannot find; record refused otherwise. Decisions and `## Corrections` share one validator. | Deterministic $0 provenance check; makes chronicle decisions carry the owner's real words. Depends on C1. |
| C3 | FOR | **b now, a deferred** | b: `scripts/defects-check.sh --intake-audit` over closed journals ($0), reports fired / filed / unfiled with n; sunset if n<10 after a month. Own caveat I missed in R1: it replays the *same* lexicon, so it measures "fired but unfiled", never regex recall. a (model-extracted corrections + brief line) is the only thing that measures recall, but only 2 chronicle records exist for 11 journals, so a would be empty for weeks. DEFER a until >=10 distilled records; reopen then. | b works on the 11 journals on disk today at no cost; a needs a section in a model call plus a CLI plus a brief line for a number with n~0. |
| C4 | b, merged form | **b, no date wait for overlap** | Info `overlap` line now, not red: equal keys only trigger "possible split", containment pairs listed as "ambiguous key" for the human. Red only if a first real split-quote case appears. The 2026-12-27 date belongs to C8 (stale), not here: overlap has data today (3 pairs), stale does not. | Checked: only 1 of 3 real pairs is a plausible split; RED would fail the host's gate 2 times for a harmless shared stem. Law 6 is about the owner's work, not key hygiene. |
| C5 | FOR | - | Also mention in the message the legacy `area:` case and that fix belongs in the host (upgrade diff may propose `paths:`, never auto). New = red by git-blame, old = reported. Fix the R1 number in the card: 19 quotes, not 32. | Only proposal with a delivery defect proven on disk in a real host: 9/9 text cards can never fire. |
| C6 | FOR | - | Prefix-anchored with length floors only, plus negatives (git sha, base64 word, `sk-learn`); no PII; no entropy rule. | Re-ran: Telegram and npm tokens pass unmasked. Cheap, and litopys reads the host's `redact.sh`, so chronicle records inherit it. |
| C7 | FOR with amendment | - | Ship the `N quotes, last <date>` suffix (a decided, unbuilt routine item, grill 09-27:99). Defer the *sort* until the "Also matched, not shown (budget)" line is seen once in a real inject state; today overflow has never been observed and the biggest host injects nothing (C5). | The count is ~30 chars once per card; a sort with no overflow is speculative. |
| C8 | DEFER | reopen 2026-12-27 | - | Fable's own date is right: the library is 2 days old, a 90-day window has no data. |
| C9 | DEFER | reopen at first collapse or when raw learnings >= 10 | - | `CONSOLIDATED.md` is 59 lines, raw learnings = 0 so gc will not run; I made the same call in R1 ("no incident"). |
| C10 | AGAINST | - | - | Opus admits thin evidence: hand index is 21/22 right, and a committed table plus render plus drift check is 40 lines to save one missing row. Law 2. |
| C11 | DEFER (withdrawing my R1 P5) | reopen when a block card gets a quote newer than its block commit, or 2026-10-27 | - | Zero escapes on disk. It is the same "signal with no data" I would reject in C8; by hand the Queen sees it at ship time. |
| C12 | DEFER | reopen when litopys phase 3 (consolidator) is opened | - | A note about an agent that does not exist. The rules are already recorded in two R1 reports. |
| C13 | DEFER | reopen when a bench session shows up as a journal | - | No bench journal on disk; on Windows a scratch `CLAUDE_CONFIG_DIR` may drop OAuth (credentials file in that dir); needs a one-run test first. |
| R | CONFIRM | - | Add one row from my R1: "per-prompt recall injections persist in the transcript" is the cost argument, and the deprecated plugin is a fact to state to the owner. | All three agree; nothing in the rejects has new evidence against it. |

Self-corrections: my R1 P4 was circular as written (see C3), my P5 is withdrawn (C11), and my R1 "32 quotes" was wrong (19).

## 3. Missed by all three

- The post's headline promise (agent changes behaviour after corrections) has no metric anywhere, ours included: C3b and C7 are the only items that touch it, and both are counts, not outcomes.
- None of the reports asked whether the owner's other hosts (16 wait on 0.18+ upgrades) hold cards with `area:` only; a one-line survey of host libraries before C5 would size it.
