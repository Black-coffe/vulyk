---
story: hindsight-harvest-01
spec: hindsight-harvest
status: done
returned: DONE
tier: 2
worker: worker-code
model: sonnet
wave: 1
blocked_by: []
---

# Defect gate sees undeliverable cards, key overlaps and escapes after block

## Goal
`scripts/defects-check.sh` reports three new findings, each following the debt rule: new = red, old = an `I` line.
- **C5.** A text card whose `paths:` is empty: no hook can ever deliver it.
- **C4.** Two live cards that share a normalised key: red when new. A key contained in another card's key is info only.
- **C11.** `ESCAPE <id>`: a block card received an owner quote after its `check:` line, and neither a fixture nor the check changed since.

`docs/defects/README.md` states the three rules. `tests/defects.test.sh` proves each rule on an original case and a neighbour form.

## Requirements
> 1. карточка-запрет без paths: — дефект библиотеки
> 3. новый общий ключ у двух карточек — красный, старые пересечения — справка
> 4. повтор правки после block без новой фикстуры — красный

## Files
- scripts/defects-check.sh
- tests/defects.test.sh
- docs/defects/README.md

## Non-goals
- Do not touch `defects-inject.sh` or `defect-intake.sh`. Delivery stays as it is; this story only reports what it cannot deliver.
- No installer or upgrade migration of `area:` to `paths:`. Do not treat `area:` as a glob.
- No sorting or quote counts in injection (C7), no stale line (C8), no rendered index (C10): the board deferred all three.
- Do not add a report-only or warn stage for ESCAPE.

## Map slice
memory/map/scripts.md: the `defects-check.sh` section.

## Acceptance criteria
- [ ] A new card with `status: text` and no `paths:` makes the audit red. Neighbour forms: `paths: []` and a blank `paths:`. A card whose `paths:` holds only `cmd:` stays green. `block` with a `check:` is exempt. A card committed together with the README reports an `I` line and the verdict stays green. The message says `area:` is a label, not a glob.
- [ ] Two live cards with the equal key `не дышит` (differing only in case or spacing), where the newer `keys:` line was committed after the README: red. The same pair committed with the README: an `old overlap` I line, green. Containment (`пустота` inside `где пустота`): an I line only. A `revoked` card never counts.
- [ ] An effective-block card with a quote committed after its `check:` line and no newer fixture or check commit: `ESCAPE <id>`, red. After a fixture commit newer than that quote: green. A quote older than the check line (the `owner-does-prep` shape): green. An uncommitted quote is an escape unless a fixture is uncommitted too.
- [ ] The new findings count quotes only under the quotes heading. A dated line under `## История` is never a quote.
- [ ] The README's `## Debt` / `## The gate` text names the three findings. The verdict line counts them (`N undeliverable`, `N overlaps`, `N escapes`).

## Verification
`bash tests/defects.test.sh && bash tests/intake.test.sh && bash tests/inject.test.sh`
`git ls-files '*.sh' | xargs -n1 bash -n`

## Implementation notes
- `defects-check.sh`: new records U/O/E (red) beside D; `when()`/`is_new()` reuse the blame and the README-time rule of debt, `touched()` reads a fixture's newest commit (dirty = newest). The verdict names `N undeliverable`, `N overlaps`, `N escapes`.
- `tests/defects.test.sh`: the `card` helper now writes `keys: [k-<id>]` and `paths: ["src/<id>/**"]`, otherwise every old fixture card would be undeliverable and share key `x`. There are 18 new cases, each with an original and a neighbour form.
- Read-only run on D:/YouTube_AI: 8 old undeliverable (info), `review-take-uncut` new → red, old overlap `не дышит`, 2 ambiguous keys, 0 escapes.

## Findings
