# Hindsight harvest: delivery, overlap and escape checks, wider redaction, a gc guard (plan)

**Tier:** 2 · **Spec slug:** `hindsight-harvest` · **Brief:** [brief.md](brief.md)
**Governed by:** ADR-014 (defect library: verbatim quotes, block needs a failing check + 2 fixtures, debt by git blame), ADR-017 (memory agents list, main session deletes), constitution Law 6 and `## Secrets`
**Depends on:** docs/specs/hindsight-memory/report.md (study, 4aa0fb3); v0.22.0 on main (8d170d7)

## Goal
Take what the editorial board accepted from Hindsight into VULYK as checks, not as prose. The defect gate
learns three things it cannot see today. First, a `text` card that no hook can ever deliver. Second, two cards
whose keys send one owner remark to two classes. Third, a remark that came back after its class was
already blocked. `redact.sh` and its `handoff.py` mirror mask the token shapes that pass through today.
`/vulyk-gc` cannot silently commit a consolidation that gutted `CONSOLIDATED.md`. The litopys side
(C1, C2, the C3 reader) and the C3 line in `/vulyk-evolve` are a separate task in the litopys repo,
by the owner's answer.

## Assumptions
- **"New" follows the debt rule.** It means committed after the commit that added `docs/defects/README.md` (git blame
  committer time); uncommitted counts as new. Anything older is reported on an `I` line and never fails. Without
  this rule, `lead-review`, which runs the audit, would fail an upgraded host for cards it already had.
- **C5 (undeliverable).** A card is undeliverable when `defects-inject.sh` would treat it as text
  (`injected_as` = text: not revoked, and not `block` with a `check:`) and its `paths:` list is empty.
  A card is "new" when the file's first commit is newer than the README's, or it is uncommitted. The finding
  says `area:` is a label, not a path glob. No installer migration: the host writes `paths:` itself.
- **C4 (overlap).** Keys are normalised to lowercase, trimmed, with runs of whitespace collapsed. Only live cards count (not
  `revoked`). Two cards with an equal key are red when the newer `keys:` line is new by blame; otherwise the pair is an
  `old overlap` I line. A key contained in another card's key is always an I line (`ambiguous key`), never red.
- **C11 (escape).** Applies to a card whose effective status is `block`. Its block time is the blame time of its `check:`
  line. A quote line newer than that is an escape unless some `fixtures:` file, or the `check:` line, changed after the
  quote. A change can be a commit, or an uncommitted edit that counts as newest. An escape is red from day one (`ESCAPE <id>`),
  with no report-only stage (ADR-014 D4).
- **New checks reuse the existing card parser.** Quotes are counted under the quotes heading only, and `## История`-style
  dated lines are never counted.
- **C6.** Patterns are prefix-anchored with length floors: `glpat-`, `npm_`, `pypi-`, `hf_`, `gsk_`, `SG.<22>.<43>`,
  `sk_live_`/`rk_live_`, Slack `hooks.slack.com/services/…`, and the Telegram bot token `<8-10 digits>:AA<33>`. No card numbers,
  no PII, no entropy rule. Negatives that must stay unmasked: a 40-hex git sha, a 30-char base64 word, `sk-learn`, an ISO
  timestamp. The redact tests go into `tests/maintenance.test.sh`, the existing quick suite. `redact.sh` has no suite of its
  own, and a new file would also need a CI job and a `## Commands` row.
- **C9** is a shell condition in the command's commit step, not a sentence the model is asked to honour. The one-line
  report always prints `CONSOLIDATED.md: entries a→b, bytes a→b`. `tests/maintenance.test.sh`
  extracts the condition and runs it in a throwaway repo, so the guard is a check, not a sentence.
- The version is 0.23.0 (minor: new red findings in the gate). CHANGELOG and version at `/vulyk-ship`.

## Stories

**Wave 1**
- `hindsight-harvest-01` — `defects-check.sh`: undeliverable text card (C5), key overlap (C4), escape after block (C11), with fixtures in `tests/defects.test.sh` and the rules in `docs/defects/README.md`
- `hindsight-harvest-02` — `redact.sh` + the `handoff.py` mirror: nine token shapes, positive and negative samples in `tests/maintenance.test.sh`

**Wave 2** (shares `tests/maintenance.test.sh` with 02)
- `hindsight-harvest-03` — `/vulyk-gc`: refuse a commit that loses more than half of `CONSOLIDATED.md`, always print the counts

## Contracts
- none (02 and 03 share only `tests/maintenance.test.sh`, so 03 follows 02; no interface crosses stories)

## Integration gate
`git ls-files '*.sh' | xargs -n1 bash -n` · `python -m py_compile .claude/hooks/*.py` · `bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh` · `bash tests/maintenance.test.sh`

## Descoped
- C3, the VULYK line in `/vulyk-evolve` (unfiled owner corrections), moves to the litopys task. Owner, 2026-09-29: «После litopys (Рекомендую)».
- YouTube_AI's 9 undeliverable cards and its SessionEnd `claude -p` are a separate task in that repo after the release. Owner, 2026-09-29: «Отдельно после выпуска (Рекомендую)».

## Plan deltas

**Approved:** Andrei, 2026-09-29 («Да»)
**Briefed:**
**Branch:** vulyk/hindsight-harvest
**Checked:**
**Council:**
**Shipped:**
