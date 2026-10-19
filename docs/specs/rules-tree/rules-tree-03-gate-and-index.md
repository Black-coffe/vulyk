---
story: rules-tree-03
spec: rules-tree
status: done
returned: DONE
tier: 4
worker: worker-code
wave: 2
blocked_by: [rules-tree-01]
---

# Gate for three branches, the generated index, search, the status counter

## Goal
After this story `scripts/defects-check.sh` judges the three branches: debt stays red for a repeated Never/How-to
without a check, a repeated Allowed is a counter, an Allowed/Never overlap without an `exception:` link is `CONFLICT`
(new/old by blame), a broken link or a `passes:` fixture the Never check still fails on is `EXCEPTION`, a stale
generated index is `INDEX`, and a text card whose only scope is `cmd:`/`tool:` is deliverable. A new
`scripts/defects-index.sh` generates `docs/defects/INDEX.md` (three tables by area with counters), checks it, greps the
cards and prints counts; VULYK's own INDEX.md is committed; the hand-written README `## Cards` table becomes a pointer;
`/vulyk-status` prints the counts line.

## Requirements
> нужно делать так, чтобы они были древовидные, хорошо индексировались и были максимально понятны для агента
> 2. Разрешение — самостоятельная запись с областью и словами владельца; перебивает запрет только явной ссылкой на него (с фикстурой «проверка запрета на разрешённую форму не срабатывает»); пересечение без ссылки — действует запрет, гейт красный.
> 3. Повтор по «Нельзя» и «Как надо» — долг, красный до проверки кодом; повтор по «Можно» — счётчик в витрине и /vulyk-status.
> 6. Витрина: сгенерированный индекс из трёх таблиц (запреты / разрешения / правила) по областям со счётчиками; гейт красный при расхождении с карточками; команда поиска по карточкам.

## Files
- scripts/defects-check.sh
- scripts/defects-index.sh
- tests/defects.test.sh
- docs/defects/INDEX.md
- docs/defects/README.md
- .claude/commands/vulyk-status.md

## Non-goals
- Do not touch the parser (`defects_lib.py`) except through its public functions; a missing function is
  `NEEDS_CONTEXT`, not a local copy.
- Do not make `INDEX` red for a library without an INDEX.md (hives on upgrade must stay green until they generate one).
- Do not add counters with escalation: the Allowed repeat is a number in the index and status, nothing else.
- Do not touch the hooks, `install.sh`, or the README's format section (story 01 wrote it); replace only `## Cards`
  and add the gate/index/search paragraphs.

## Map slice
- memory/map/scripts.md: `defects-check.sh` entry; `## Key contracts` (gates exit 0 and report; `defects-check.sh`
  exit 0/1/2).
- docs/specs/rules-tree/scout-machinery.md: Gotcha 6 (debt `208-227`, undeliverable `231-238`, overlap `256-281`,
  escape `241-254`, README table never read), Gotcha 2 (git paths), Tests.
- .claude/commands/vulyk-status.md step 2 (council line) for the shape of a status line.
- docs/specs/rules-tree/plan.md `## Contracts`: Index and gate, Sections.

## Acceptance criteria
- [ ] Debt: a permissive card (Allowed lines only) with ≥2 owner quotes or ≥2 dated Allowed lines is never `DEBT`; the
      audit prints `allowed repeats <n> <ref>` as an info line; a prohibitive card behaves as today.
- [ ] `CONFLICT <ref-allowed> <ref-never>` red when both are live, have overlapping scope (identical `paths:` entry strings, or one entry's glob matches the other entry as a
      path, `cmd:`/`tool:` entries compared as strings) and the
      permissive card's `exception:` does not name `<ref-never>`; old by blame (newest Allowed line older than the
      README add-commit) → `old conflict` info line.
- [ ] `EXCEPTION <ref> ...` red when an `exception:` ref names no live card, or when the referenced card has a `check:`
      and a `passes:` fixture makes it exit non-zero; a linked pair whose `passes:` fixture exits 0 is green (this is
      the ask's fixture "the never check does not fire on the allowed form").
- [ ] `UNDELIVERABLE` is not raised for a text card whose `paths:` holds only `cmd:`/`tool:` entries.
- [ ] `bash scripts/defects-index.sh` writes INDEX.md per the contract (three tables, by area, `repeats` column);
      `--check` exits 1 with `index stale` on a drift, 0 otherwise; `--grep <pattern>` prints `<ref>:<line>: <text>`
      over cards only; `--counts` prints the one-line counts. Without python3 it exits 2 like the gate.
- [ ] `defects-check.sh` runs `defects-index.sh --check` when INDEX.md exists: red `INDEX` on stale, else nothing; no
      INDEX.md → one `no index` info line, exit unaffected.
- [ ] `docs/defects/INDEX.md` for VULYK's own library is generated and committed; `bash scripts/defects-check.sh` is
      green on the repo; README `## Cards` is replaced by a pointer to INDEX.md plus the gate/index/search commands.
- [ ] `/vulyk-status` gains a step `defects: ` printing `bash scripts/defects-index.sh --counts` (or `defects: no
      library`).
- [ ] `tests/defects.test.sh` gains failing-first cases: permissive repeat not debt; conflict red / old / linked green;
      exception blind (fixture fails the never check) red; tool-only scope deliverable; index stale red, missing index
      silent; `--grep` output; `--counts` output.
- [ ] Overlap form (coverage gap, Queen 2026-10-19): a permissive card scoped `src/pay/**` and a prohibitive card
      scoped `src/pay/stripe.py` with no `exception:` is `CONFLICT` — the neighbour form of the identical-string case.

## Verification
`git ls-files '*.sh' | xargs -n1 bash -n`
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`bash scripts/defects-check.sh`

## Implementation notes
- scripts/defects-check.sh: debt skipped for permissive cards (`allowed repeats <dated-1> <ref>` info); CONFLICT via defects_lib.parse_scope/scope_matches; EXCEPTION (missing ref, red/old by the exception: line; passes: fixtures run as `P` records in the audit only, like block fixtures); INDEX via defects-index.sh --check, `no index` info otherwise; UNDELIVERABLE hint names tool:.
- scripts/defects-index.sh (new): write / --check / --grep / --counts; `status` column is the declared status (effective status would make the index drift on a fixture file change); counts are over live cards, tables list revoked cards too.
- --grep exits 1 on no match (grep convention); --check normalises CRLF in INDEX.md so an autocrlf checkout is not stale.
- docs/defects/INDEX.md generated and committed; README `## Cards` table replaced by pointer + commands, branch findings added under `## The gate`.
- .claude/commands/vulyk-status.md: new step 3 `defects:`, later steps renumbered.
- tests/defects.test.sh: 21 new cases; against HEAD's gate the debt/conflict/exception/index cases fail; the tool-only UNDELIVERABLE cases already passed before (c.paths was non-empty), they pin the behaviour.
- Existing VULYK cards carry undated `## Allowed` lines inside prohibitive cards: they appear in the Allowed table with repeats 0.

## Findings
