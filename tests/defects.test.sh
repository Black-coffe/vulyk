#!/usr/bin/env bash
# The defect library gate (contract 0.19 §1-2): scripts/defects-check.sh against throwaway git repos -
# effective status, fixtures (blind = red), the gate with an argument, and debt by git blame commit time.
#
#   Usage: bash tests/defects.test.sh            # from the VULYK repo root
set -u

SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"   # vulyk_python, sed_inplace
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "::error::$1"; fail=1; fi; }

mkrepo() { # mkrepo <dir> - a git repo with the gate, a check and good/bad fixtures; README not committed yet
  mkdir -p "$1" && cd "$1" || exit 1
  git init -q -b main . && git config user.name t && git config user.email t@t && git config core.autocrlf false
  mkdir -p scripts docs/defects/fixtures .claude/hooks
  cp "$SRC/scripts/defects-check.sh" "$SRC/scripts/defects-index.sh" scripts/
  cp "$SRC/.claude/hooks/defects_lib.py" .claude/hooks/
  printf '# Defect library\n' > docs/defects/README.md
  printf '#!/usr/bin/env bash\n! grep -q bad "$1"\n' > check.sh
  printf 'bad original\n' > docs/defects/fixtures/orig.txt
  printf 'bad neighbour\n' > docs/defects/fixtures/near.txt
  printf 'fine\n' > docs/defects/fixtures/clean.txt
  printf 'fine\n' > good.txt; printf 'bad\n' > bad.txt
}
cm() { # cm <YYYY-MM-DD> <paths...> - commit those paths at that date
  local d="$1T12:00:00 +0000"; shift
  git add -- "$@" && GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -q -m "at $d"
}
card() { # card <id> <status> <check> <fixtures> <quote lines...>
  local id="$1" st="$2" ck="$3" fx="$4"; shift 4
  { printf -- '---\nid: %s\ntitle: Class %s\nstatus: %s\ncheck: %s\nfixtures: %s\nkeys: [k-%s]\npaths: ["src/%s/**"]\n---\n\n# Class %s\nWhat it is.\n\n## Owner quotes\n\n' \
      "$id" "$id" "$st" "$ck" "$fx" "$id" "$id" "$id" "$id"
    for q in "$@"; do printf -- '- %s · video 1 · 00:10 — «words»\n' "$q"; done
    printf '\n## Cause\nWhy.\n\n## Never\n- do it\n'
  } > "docs/defects/$id.md"
}
run() { out="$(bash scripts/defects-check.sh "$@" 2>&1)"; rc=$?; last="$(printf '%s\n' "$out" | tail -1)"; }
has() { printf '%s\n' "$out" | grep -q -- "$1"; }
FX='[docs/defects/fixtures/orig.txt, docs/defects/fixtures/near.txt]'
vulyk_python || { echo "defects.test.sh: needs python3 or python"; exit 1; }
PYBIN="$VULYK_PY"
dump() { "$PYBIN" .claude/hooks/defects_lib.py docs/defects 2>&1; }

echo "--- no library, empty library"
mkrepo "$TMP/none"; rm -rf docs/defects
run; ok "no docs/defects -> exit 2" "$([ "$rc" = 2 ] && has 'no defect library'; echo $?)"
mkrepo "$TMP/empty"; cm 2026-01-01 docs/defects/README.md
run; ok "README only -> GREEN: 0 blocking checks, exit 0" "$([ "$rc" = 0 ] && [ "$last" = 'GREEN: 0 blocking checks' ]; echo $?)"

echo "--- effective status"
mkrepo "$TMP/status"; cm 2026-01-01 docs/defects/README.md
card nocheck block '' "$FX" 2026-01-05
card onefix block 'bash check.sh <arg>' '[docs/defects/fixtures/orig.txt, docs/defects/fixtures/missing.txt]' 2026-01-05
card warned warn 'bash check.sh <arg>' "$FX" 2026-01-05
run
ok "block without check -> reported as text" "$(has '^text  nocheck: block without check'; echo $?)"
ok "block with one existing fixture -> check runs, not earned" \
  "$(has '^block onefix: block without fixtures (check runs, not earned) - 1 of 2 listed exist'; echo $?)"
ok "the audit does not run a check that has not earned block" "$(! has 'onefix: fixture'; echo $?)"
ok "unknown status (warn) -> reported as text" "$(has "^text  warned: status 'warn'"; echo $?)"
ok "notes alone stay green with 0 blocking checks" "$([ "$rc" = 0 ] && [ "$last" = 'GREEN: 0 blocking checks' ]; echo $?)"

echo "--- fixtures in the audit"
mkrepo "$TMP/audit"; cm 2026-01-01 docs/defects/README.md
card caught block 'bash check.sh <arg>' "$FX" 2026-01-05
run
ok "every fixture fails the check -> ok per fixture, GREEN: 1" \
  "$([ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -c '^ok    caught: fixture')" = 2 ] && [ "$last" = 'GREEN: 1 blocking checks' ]; echo $?)"
ok "the check output goes to a log outside the tree" \
  "$(log="$(printf '%s\n' "$out" | sed -n 's/^log: //p')"; [ -s "$log" ] && [ -z "$(git status --porcelain --untracked-files=no)" ] && ! git status --porcelain | grep -q '\.log'; echo $?)"
card caught block 'bash check.sh <arg>' '[docs/defects/fixtures/orig.txt, docs/defects/fixtures/clean.txt]' 2026-01-05
run
ok "a fixture that passes the check -> BLIND, RED, exit 1" \
  "$([ "$rc" = 1 ] && has '^BLIND caught: fixture docs/defects/fixtures/clean.txt passes' && [ "$last" = 'RED: 1 blind fixtures' ]; echo $?)"

echo "--- the gate with an argument"
card caught block 'bash check.sh <arg>' "$FX" 2026-01-05
card other block 'bash check.sh <arg> && true' "$FX" 2026-01-05
run good.txt; ok "a good argument passes every block check -> GREEN: 2" "$([ "$rc" = 0 ] && [ "$last" = 'GREEN: 2 blocking checks' ]; echo $?)"
run bad.txt
ok "a bad argument -> RED line per failing card, exit 1" \
  "$([ "$rc" = 1 ] && has '^RED   caught - Class caught: bash check.sh bad.txt' && has '^RED   other' && [ "$last" = 'RED: 2 red checks' ]; echo $?)"
ok "the gate does not run fixtures" "$(! has 'fixture'; echo $?)"
ok "no carriage returns in the output (Windows python)" "$(! printf '%s\n' "$out" | od -c | grep -q '\\r'; echo $?)"
card caught block 'bash check.sh <лист>.json' "$FX" 2026-01-05
rm -f docs/defects/other.md; printf 'bad\n' > sheet.json
run sheet.json
ok "a host token <лист>.json takes sheet.json whole (no .json.json)" "$([ "$rc" = 1 ] && has 'bash check.sh sheet.json (exit 1)'; echo $?)"

echo "--- debt by commit time"
mkrepo "$TMP/debt"
card rep text '' '' 2026-01-01; cm 2026-01-01 docs/defects/rep.md
cm 2026-01-02 docs/defects/README.md
run; ok "one quote is no debt" "$([ "$rc" = 0 ] && ! has 'rep'; echo $?)"
card rep text '' '' 2026-01-01 2025-12-31; cm 2026-01-03 docs/defects/rep.md
run
ok "2 quotes, text, one committed after README -> DEBT with sha and time, exit 1" \
  "$([ "$rc" = 1 ] && has '^DEBT  rep: 2 quotes, not block, new quote [0-9a-f]\{7\} 2026-01-03' && [ "$last" = 'RED: 1 new debt' ]; echo $?)"

mkrepo "$TMP/old"
card rep text '' '' 2026-01-01 2026-02-01; cm 2026-01-01 docs/defects/rep.md
cm 2026-01-02 docs/defects/README.md
run; ok "both quotes committed before README -> old debt, green" "$([ "$rc" = 0 ] && has '^old debt  rep: 2 quotes' && [ "$last" = 'GREEN: 0 blocking checks' ]; echo $?)"
card rep text '' '' 2026-01-01 2026-02-01 2026-09-27
run; ok "an uncommitted quote line is new -> DEBT uncommitted" "$([ "$rc" = 1 ] && has '^DEBT  rep: 3 quotes, not block, new quote uncommitted'; echo $?)"
card rep revoked '' '' 2026-01-01 2026-02-01 2026-09-27
run; ok "revoked card is ignored (no debt, no line)" "$([ "$rc" = 0 ] && ! has 'rep'; echo $?)"
card rep block 'bash check.sh <arg>' "$FX" 2026-01-01 2026-02-01 2026-09-27
run; ok "an effective block card owes no debt" "$([ "$rc" = 0 ] && ! has 'DEBT' && [ "$last" = 'GREEN: 1 blocking checks' ]; echo $?)"
card rep block 'bash check.sh <arg>' '' 2026-01-01 2026-02-01 2026-09-27
run good.txt
ok "a declared block without fixtures owes debt, yet the gate runs its check" \
  "$([ "$rc" = 1 ] && has '^DEBT  rep: 3 quotes, not block' && has '^ok    rep$' && [ "$last" = 'RED: 1 new debt' ]; echo $?)"

echo "--- the gate runs declared block checks without fixtures (0.19.1)"
mkrepo "$TMP/nofix"; cm 2026-01-01 docs/defects/README.md
card bare block 'bash check.sh <arg>' '' 2026-01-05
card onefx block 'bash check.sh <arg>' '[docs/defects/fixtures/orig.txt]' 2026-01-05
card nock block '' '' 2026-01-05
card gone revoked 'bash check.sh <arg>' '' 2026-01-05
run good.txt
ok "good argument: both declared checks run, GREEN counts them" \
  "$([ "$rc" = 0 ] && has '^ok    bare$' && has '^ok    onefx$' && [ "$last" = 'GREEN: 2 blocking checks' ]; echo $?)"
ok "each is reported as not earned" \
  "$(has '^block bare: block without fixtures (check runs, not earned)' && has '^block onefx: block without fixtures (check runs, not earned)'; echo $?)"
ok "a block without a check and a revoked card run nothing" "$(! has '^ok    nock' && ! has 'gone'; echo $?)"
run bad.txt
ok "bad argument: each declared check is red" \
  "$([ "$rc" = 1 ] && has '^RED   bare' && has '^RED   onefx' && [ "$last" = 'RED: 2 red checks' ]; echo $?)"
run
ok "the audit still runs only earned checks" \
  "$([ "$rc" = 0 ] && ! has '^ok    [a-z]*: fixture' && ! has '^BLIND' && [ "$last" = 'GREEN: 0 blocking checks' ]; echo $?)"

mkrepo "$TMP/uncommitted"
card rep text '' '' 2026-01-01 2026-02-01
run; ok "no README commit + uncommitted card -> quotes are new" "$([ "$rc" = 1 ] && has 'new quote uncommitted'; echo $?)"
cm 2026-01-01 docs/defects/rep.md
run; ok "README not committed yet -> committed quotes predate the library (old debt)" "$([ "$rc" = 0 ] && has '^old debt  rep'; echo $?)"

mkdir -p "$TMP/nogit/defects"
card rep text '' '' 2026-01-01 2026-02-01; cp docs/defects/rep.md "$TMP/nogit/defects/rep.md"
out="$(DEFECTS_DIR="$TMP/nogit/defects" bash scripts/defects-check.sh 2>&1)"; rc=$?
ok "a library outside git -> every quote new, DEBT outside git" "$([ "$rc" = 1 ] && has 'is outside git' && has 'new quote outside git'; echo $?)"

echo "--- card parsing"
mkrepo "$TMP/parse"; cm 2026-01-01 docs/defects/README.md
card crlf block 'bash check.sh <arg>' "$FX" 2026-01-05
card crlftext text '' '' 2026-01-05 2026-01-06
sed_inplace 's/$/\r/' docs/defects/crlf.md
sed_inplace 's/$/\r/' docs/defects/crlftext.md
run
ok "CRLF card: frontmatter and fixtures parsed (effective block, both fixtures fail)" \
  "$([ "$(printf '%s\n' "$out" | grep -c '^ok    crlf: fixture')" = 2 ]; echo $?)"
ok "CRLF card: quote lines counted (2 uncommitted -> DEBT)" "$(has '^DEBT  crlftext: 2 quotes'; echo $?)"
rm -f docs/defects/crlf*.md
card ru text '' '' 2026-01-05 2026-01-06
sed_inplace 's/^## Owner quotes$/## Цитаты владельца/; s/^## Never$/## Нельзя/' docs/defects/ru.md
run
ok "Russian quotes heading accepted" "$(grep -q '^## Цитаты владельца' docs/defects/ru.md && has '^DEBT  ru: 2 quotes'; echo $?)"
card elsewhere text '' '' 2026-01-05
printf '\n## Notes\n- 2026-01-06 · video 1 · 00:10 — «not a quote section»\n' >> docs/defects/elsewhere.md
run; ok "dated lines outside the quotes section are not quotes" "$(! has 'elsewhere'; echo $?)"

echo "--- inline comments in frontmatter (review 0.19 major 2: gate and hooks must agree)"
mkrepo "$TMP/inline"
{ printf -- '---
id: ic
title: Inline   # the class
status: block   # block | text
check: bash check.sh <arg>   # run from root
'
  printf -- 'fixtures: %s   # original + neighbour
---

# ic

## Owner quotes
- 2026-09-01 · v · 0:01 — «a»

## Never
- x
' "$FX"
} > docs/defects/ic.md
run; ok "a block card with inline # comments stays block and both fixtures are caught" "$([ "$rc" = 0 ] && [ "$last" = 'GREEN: 1 blocking checks' ]; echo $?)"
run bad.txt; ok "its check runs in gate mode and goes red on a bad argument" "$([ "$rc" = 1 ]; echo $?)"

echo "--- undeliverable text cards (C5)"
mkrepo "$TMP/undel"; cm 2026-01-01 docs/defects/README.md
card u text '' '' 2026-01-05; sed_inplace '/^paths:/d' docs/defects/u.md
run; ok "a new text card with no paths: -> UNDELIVERABLE, RED" \
  "$([ "$rc" = 1 ] && has '^UNDELIVERABLE  u: text card with no paths:' && [ "$last" = 'RED: 1 undeliverable' ]; echo $?)"
sed_inplace 's/^id: u$/id: u\npaths: []/' docs/defects/u.md
run; ok "neighbour: paths: [] -> UNDELIVERABLE" "$([ "$rc" = 1 ] && has '^UNDELIVERABLE  u:'; echo $?)"
sed_inplace 's/^paths: \[\]$/paths:/' docs/defects/u.md
run; ok "neighbour: a blank paths: -> UNDELIVERABLE" "$([ "$rc" = 1 ] && has '^UNDELIVERABLE  u:'; echo $?)"
sed_inplace 's/^paths:$/paths: ["cmd:edit_build\\\\.py"]/' docs/defects/u.md
run; ok "a cmd:-only paths: is deliverable -> green" "$([ "$rc" = 0 ] && ! has 'UNDELIVERABLE'; echo $?)"
sed_inplace '/^paths:/d; s/^id: u$/id: u\narea: edit/' docs/defects/u.md
run; ok "an area:-only card names area: as a label" "$(has '^UNDELIVERABLE  u: .*(area: is a label, not a glob)'; echo $?)"
card u block 'bash check.sh <arg>' "$FX" 2026-01-05; sed_inplace '/^paths:/d' docs/defects/u.md
run; ok "block with a check: is delivered by its check -> exempt" "$([ "$rc" = 0 ] && ! has 'undeliverable'; echo $?)"
mkrepo "$TMP/undel-old"
card u text '' '' 2026-01-05; sed_inplace '/^paths:/d' docs/defects/u.md; cm 2026-01-01 docs/defects/u.md
cm 2026-01-02 docs/defects/README.md
run; ok "a card older than the library -> old undeliverable, green" \
  "$([ "$rc" = 0 ] && has '^old undeliverable  u:' && [ "$last" = 'GREEN: 0 blocking checks' ]; echo $?)"

echo "--- key overlap (C4)"
mkrepo "$TMP/overlap"; cm 2026-01-01 docs/defects/README.md
card breath text '' '' 2026-01-05; card speech text '' '' 2026-01-05
sed_inplace 's/^keys: .*/keys: [не дышит, вдох]/' docs/defects/breath.md
sed_inplace 's/^keys: .*/keys: ["Не  дышит", обрыв]/' docs/defects/speech.md
cm 2026-01-05 docs/defects/breath.md docs/defects/speech.md
run; ok "one key on two cards (case and spacing differ), newer than the library -> OVERLAP, RED" \
  "$([ "$rc" = 1 ] && has '^OVERLAP  breath, speech: share key "не дышит"' && [ "$last" = 'RED: 1 overlaps' ]; echo $?)"
card speech revoked '' '' 2026-01-05; sed_inplace 's/^keys: .*/keys: [не дышит]/' docs/defects/speech.md
run; ok "a revoked card never overlaps" "$([ "$rc" = 0 ] && ! has 'OVERLAP'; echo $?)"
card speech text '' '' 2026-01-05; sed_inplace 's/^keys: .*/keys: [где не дышит]/' docs/defects/speech.md
run; ok "neighbour: a key inside another card's key -> ambiguous key line only, green" \
  "$([ "$rc" = 0 ] && has '^ambiguous key  breath "не дышит" is inside speech "где не дышит"' && ! has 'OVERLAP'; echo $?)"
mkrepo "$TMP/overlap-old"
card breath text '' '' 2026-01-05; card speech text '' '' 2026-01-05
sed_inplace 's/^keys: .*/keys: [не дышит]/' docs/defects/breath.md
sed_inplace 's/^keys: .*/keys: [не дышит]/' docs/defects/speech.md
cm 2026-01-01 docs/defects/breath.md docs/defects/speech.md; cm 2026-01-02 docs/defects/README.md
run; ok "an overlap older than the library -> old overlap, green" \
  "$([ "$rc" = 0 ] && has '^old overlap  breath, speech: share key "не дышит"'; echo $?)"

echo "--- escape after block (C11)"
mkrepo "$TMP/escape"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card cut block 'bash check.sh <arg>' "$FX" 2026-01-05; cm 2026-01-05 docs/defects/cut.md
run; ok "block card, quotes no newer than its check -> green" "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
card cut block 'bash check.sh <arg>' "$FX" 2026-01-05 2026-01-10; cm 2026-01-10 docs/defects/cut.md
run; ok "a quote committed after the block check, no fixture since -> ESCAPE, RED" \
  "$([ "$rc" = 1 ] && has '^ESCAPE  cut: quote [0-9a-f]\{7\} 2026-01-10' && [ "$last" = 'RED: 1 escapes' ]; echo $?)"
printf 'bad new form\n' >> docs/defects/fixtures/near.txt
run; ok "an uncommitted fixture change counts as newest -> green" "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
cm 2026-01-11 docs/defects/fixtures/near.txt
run; ok "a fixture committed after the quote -> green" "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
card cut block 'bash check.sh <arg>' "$FX" 2026-01-05 2026-01-10 2026-01-12
run; ok "neighbour: an uncommitted quote with committed fixtures -> ESCAPE uncommitted" \
  "$([ "$rc" = 1 ] && has '^ESCAPE  cut: quote uncommitted'; echo $?)"
echo "--- a masking commit listed in .scrub-revs keeps the quote's date"
mkrepo "$TMP/scrub"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card mask block 'bash check.sh <arg>' "$FX" 2026-01-05; sed_inplace 's/«words»/«words at acme-hive»/' docs/defects/mask.md
cm 2026-01-05 docs/defects/mask.md
sed_inplace 's/«words at acme-hive»/«words at <hive>»/' docs/defects/mask.md; cm 2026-01-10 docs/defects/mask.md
scrub="$(git rev-parse HEAD)"
run; ok "neighbour: a quote edited by an unlisted commit -> ESCAPE, RED" \
  "$([ "$rc" = 1 ] && has '^ESCAPE  mask: quote [0-9a-f]\{7\} 2026-01-10'; echo $?)"
printf '# masking commits\n%s # masked a path in a quote\n' "$scrub" > docs/defects/.scrub-revs
run; ok "the masked quote of a commit listed in .scrub-revs keeps its older date -> no ESCAPE, green" \
  "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
ok "the audit names the listed commit in one info line" \
  "$([ "$(printf '%s\n' "$out" | grep -c "^scrub-rev ${scrub:0:7}")" = 1 ]; echo $?)"
# audit-fixes-1113-12: the listed commit keeps a line's older date only when the line differs solely in <...> spans.
mkrepo "$TMP/scrub-words"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card mask block 'bash check.sh <arg>' "$FX" 2026-01-05; cm 2026-01-05 docs/defects/mask.md
sed_inplace 's/«words»/«other words at <hive>»/' docs/defects/mask.md; cm 2026-01-10 docs/defects/mask.md
printf '%s # masked a path in a quote\n' "$(git rev-parse HEAD)" > docs/defects/.scrub-revs
run; ok "neighbour: a listed commit that also changes a quote's words is still an ESCAPE" \
  "$([ "$rc" = 1 ] && has '^ESCAPE  mask: quote [0-9a-f]\{7\} 2026-01-10'; echo $?)"
mkrepo "$TMP/scrub-add"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card mask block 'bash check.sh <arg>' "$FX" 2026-01-05; cm 2026-01-05 docs/defects/mask.md
card mask block 'bash check.sh <arg>' "$FX" 2026-01-05 2026-01-10
sed_inplace 's/^\(- 2026-01-05 .*\)«words»/\1«words at <hive>»/' docs/defects/mask.md; cm 2026-01-10 docs/defects/mask.md
printf '%s # masked a path in a quote\n' "$(git rev-parse HEAD)" > docs/defects/.scrub-revs
run; ok "a listed commit that adds a new quote is still an ESCAPE" \
  "$([ "$rc" = 1 ] && has '^ESCAPE  mask: quote [0-9a-f]\{7\} 2026-01-10'; echo $?)"

mkrepo "$TMP/escape-prep"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card prep text '' '' 2026-01-05 2026-01-06; cm 2026-01-06 docs/defects/prep.md
card prep block 'bash check.sh <arg>' "$FX" 2026-01-05 2026-01-06; cm 2026-01-08 docs/defects/prep.md
run; ok "quotes before the card became block (owner-does-prep) -> green" "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
printf '\n## История\n- 2026-01-09 · v2 · a history line, not a quote\n' >> docs/defects/prep.md; cm 2026-01-09 docs/defects/prep.md
run; ok "a dated line under ## История is never an escape" "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"

echo "--- area folders (rules-tree 01)"
mkrepo "$TMP/area"
card rep text '' '' 2026-01-01 2025-12-31; mkdir -p docs/defects/pay; mv docs/defects/rep.md docs/defects/pay/
cm 2026-01-01 docs/defects/README.md; cm 2026-01-03 docs/defects/pay/rep.md
run
ok "a foldered card is audited under its ref, blamed by its library path -> DEBT pay/rep with sha" \
  "$([ "$rc" = 1 ] && has '^DEBT  pay/rep: 2 quotes, not block, new quote [0-9a-f]\{7\} 2026-01-03' && ! has 'fatal' && [ "$last" = 'RED: 1 new debt' ]; echo $?)"
mkrepo "$TMP/area-old"
card u text '' '' 2026-01-05; sed_inplace '/^paths:/d' docs/defects/u.md; mkdir -p docs/defects/pay; mv docs/defects/u.md docs/defects/pay/
cm 2026-01-01 docs/defects/pay/u.md; cm 2026-01-02 docs/defects/README.md
run; ok "neighbour: git log finds a foldered card's add-commit (older than the root README) -> old undeliverable" \
  "$([ "$rc" = 0 ] && has '^old undeliverable  pay/u:' && ! has 'fatal'; echo $?)"
mkdir -p docs/defects/pay/fixtures
printf -- '---\nid: fx\npaths: ["x"]\n---\n' > docs/defects/pay/fixtures/fx.md
cp docs/defects/pay/fixtures/fx.md docs/defects/fixtures/fx2.md; cp docs/defects/pay/fixtures/fx.md docs/defects/pay/index.md
cp docs/defects/pay/fixtures/fx.md docs/defects/INDEX.md; cp docs/defects/pay/fixtures/fx.md docs/defects/pay/README.md
o="$(dump)"
ok "fixtures/ (root and area), README.md and index.md are not cards" \
  "$([ "$(printf '%s\n' "$o" | grep -c '"ref"')" = 1 ] && printf '%s\n' "$o" | grep -qF '"ref": "pay/u", "id": "u", "area": "pay", "path": "pay/u.md"'; echo $?)"
card root text '' '' 2026-01-05
ok "a root card is area general, ref = id" "$(dump | grep -qF '"ref": "root", "id": "root", "area": "general", "path": "root.md"'; echo $?)"

echo "--- duplicate ids (rules-tree 01)"
mkrepo "$TMP/dup"; cm 2026-01-01 docs/defects/README.md
card dup text '' '' 2026-01-05; mkdir -p docs/defects/a docs/defects/b
sed 's/^keys: .*/keys: [k-a]/' docs/defects/dup.md > docs/defects/a/dup.md
run; ok "a root card and a foldered card with one id -> DUPLICATE, RED, exit 1" \
  "$([ "$rc" = 1 ] && has '^DUPLICATE  dup: a/dup, dup share one id' && [ "$last" = 'RED: 1 duplicate ids' ]; echo $?)"
mv docs/defects/dup.md docs/defects/b/dup.md
run; ok "neighbour: one id in two area folders -> DUPLICATE" "$([ "$rc" = 1 ] && has '^DUPLICATE  dup: a/dup, b/dup'; echo $?)"
mv docs/defects/b/dup.md docs/defects/b/other.md
run; ok "distinct ids -> no DUPLICATE" "$([ "$rc" = 0 ] && ! has 'DUPLICATE'; echo $?)"

echo "--- sections and scope in the parser dump (rules-tree 01)"
mkrepo "$TMP/dump"; mkdir -p docs/defects/pay
cat > docs/defects/pay/refund-ok.md <<'CARD'
---
id: refund-ok
title: Refunds allowed
exception: pay/no-refund   # the cut
passes: [docs/defects/fixtures/clean.txt, "a, b.txt"]
paths: ["src/pay/stripe.py", "tool:WebFetch", "cmd:stripe\\s+refund"]
---

## Можно
- 2026-10-19 · «можно возвращать»
- undated line

## Як треба
- do it this way
  continued

## Не можна
- never this
CARD
o="$(dump)"
ok "exception: parses as a ref (inline comment dropped)" "$(printf '%s\n' "$o" | grep -qF '"exception": "pay/no-refund"'; echo $?)"
ok "passes: parses like fixtures: (a quoted item keeps its comma)" \
  "$(printf '%s\n' "$o" | grep -qF '"passes": ["docs/defects/fixtures/clean.txt", "a, b.txt"]'; echo $?)"
ok "tool:<regex> parses as kind tool, cmd: as cmd, a path as glob" \
  "$(printf '%s\n' "$o" | grep -qF '"scopes": [["glob", "src/pay/stripe.py"], ["tool", "WebFetch"], ["cmd", "stripe\\s+refund"]]'; echo $?)"
ok "ru Allowed, uk How-to and uk Never sections parse; an Allowed line yields its date" \
  "$(printf '%s\n' "$o" | grep -qF '"never": ["never this"], "allowed": ["2026-10-19 · «можно возвращать»", "undated line"], "howto": ["do it this way continued"]' \
     && printf '%s\n' "$o" | grep -qF '"allowed_dates": ["2026-10-19", null]'; echo $?)"
card none text '' '' 2026-01-05
ok "neighbour: a card with no exception: -> null, English sections parse" \
  "$(dump | grep '"ref": "none"' | grep -qF '"exception": null' && dump | grep '"ref": "none"' | grep -qF '"never": ["do it"]'; echo $?)"
ok "specificity: src/pay/stripe.py above src/**, tool:WebFetch above tool:.*" \
  "$("$PYBIN" -c 'import sys; sys.path.insert(0, ".claude/hooks"); from defects_lib import specificity as s; sys.exit(not (s("src/pay/stripe.py") > s("src/**") and s("tool:WebFetch") > s("tool:.*")))'; echo $?)"

echo "--- three branches in the gate (rules-tree 03)"
pcard() { # pcard <id> <paths> <exception> <passes> <dates...> - a permissive card: a quote and a dated Allowed line per date
  local id="$1" pa="$2" ex="$3" ps="$4"; shift 4
  { printf -- '---\nid: %s\ntitle: Allowed %s\nkeys: [p-%s]\npaths: %s\n' "$id" "$id" "$id" "$pa"
    [ -n "$ex" ] && printf 'exception: %s\n' "$ex"
    [ -n "$ps" ] && printf 'passes: %s\n' "$ps"
    printf -- '---\n\n# Allowed %s\n\n## Owner quotes\n\n' "$id"
    for q in "$@"; do printf -- '- %s · v · 00:10 — «words»\n' "$q"; done
    printf '\n## Allowed\n'
    for q in "$@"; do printf -- '- %s · «можно»\n' "$q"; done
  } > "docs/defects/$id.md"
}
mkrepo "$TMP/branches"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
pcard ok '["src/ok/**"]' '' '' 2026-01-05 2026-01-06 2026-01-07
run
ok "a permissive card with 3 quotes and 3 dated Allowed lines is no DEBT -> allowed repeats 2, green" \
  "$([ "$rc" = 0 ] && ! has 'DEBT' && has '^allowed repeats 2 ok$'; echo $?)"
card rep text '' '' 2026-01-05 2026-01-06
run; ok "neighbour: a prohibitive card with 2 quotes is still DEBT" "$([ "$rc" = 1 ] && has '^DEBT  rep: 2 quotes'; echo $?)"
rm -f docs/defects/rep.md docs/defects/ok.md

card never text '' '' 2026-01-05; sed_inplace 's|^paths: .*|paths: ["src/pay/stripe.py"]|' docs/defects/never.md
pcard allow '["src/pay/stripe.py"]' '' '' 2026-01-06
run; ok "identical scope, no exception: -> CONFLICT allow never, RED" \
  "$([ "$rc" = 1 ] && has '^CONFLICT allow never:' && [ "$last" = 'RED: 1 conflicts' ]; echo $?)"
pcard allow '["src/pay/**"]' '' '' 2026-01-06
run; ok "overlap form: allowed src/pay/** over never src/pay/stripe.py, no exception: -> CONFLICT" \
  "$([ "$rc" = 1 ] && has '^CONFLICT allow never:'; echo $?)"
pcard allow '["tool:WebFetch"]' '' '' 2026-01-06; sed_inplace 's|^paths: .*|paths: ["tool:WebFetch"]|' docs/defects/never.md
run; ok "a tool: entry compared as a string -> CONFLICT" "$([ "$rc" = 1 ] && has '^CONFLICT allow never:'; echo $?)"
pcard allow '["src/other/**"]' '' '' 2026-01-06
run; ok "disjoint scopes -> no CONFLICT" "$([ "$rc" = 0 ] && ! has 'CONFLICT'; echo $?)"
pcard allow '["tool:WebFetch"]' never '' 2026-01-06
run; ok "linked by exception: -> green" "$([ "$rc" = 0 ] && ! has 'CONFLICT' && ! has 'EXCEPTION'; echo $?)"
pcard allow '["tool:WebFetch"]' gone '' 2026-01-06
run; ok "exception: naming no live card -> EXCEPTION, RED" \
  "$([ "$rc" = 1 ] && has '^EXCEPTION allow: exception: gone names no live card' && has '^CONFLICT allow never'; echo $?)"
mkrepo "$TMP/branches-old"
card never text '' '' 2026-01-05; sed_inplace 's|^paths: .*|paths: ["src/pay/stripe.py"]|' docs/defects/never.md
pcard allow '["src/pay/**"]' '' '' 2026-01-06; cm 2026-01-01 docs/defects/never.md docs/defects/allow.md
cm 2026-01-02 docs/defects/README.md
run; ok "a conflict older than the library -> old conflict, green" "$([ "$rc" = 0 ] && has '^old conflict allow never'; echo $?)"
mkrepo "$TMP/branches-howto"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card howto text '' '' 2026-01-05; sed_inplace -e 's|^paths: .*|paths: ["src/pay/stripe.py"]|' -e 's|^## Never$|## How-to|' docs/defects/howto.md
pcard allow '["src/pay/**"]' '' '' 2026-01-06
run; ok "a How-to card prohibits nothing: allowed over its scope, no exception: -> no CONFLICT, green" \
  "$([ "$rc" = 0 ] && ! has 'CONFLICT'; echo $?)"

mkrepo "$TMP/passes"; cm 2026-01-01 docs/defects/README.md docs/defects/fixtures check.sh
card never block 'bash check.sh <arg>' "$FX" 2026-01-05
pcard allow '["src/never/**"]' never '[docs/defects/fixtures/clean.txt]' 2026-01-06
run; ok "a linked pair whose passes: fixture the never check exits 0 on -> green" \
  "$([ "$rc" = 0 ] && has '^ok    allow: passes: docs/defects/fixtures/clean.txt passes the check of never'; echo $?)"
pcard allow '["src/never/**"]' never '[docs/defects/fixtures/clean.txt, docs/defects/fixtures/orig.txt]' 2026-01-06
run; ok "a passes: fixture the never check fails on -> EXCEPTION (blind exception), RED" \
  "$([ "$rc" = 1 ] && has '^EXCEPTION allow: passes: docs/defects/fixtures/orig.txt fails the check of never' && [ "$last" = 'RED: 1 exceptions' ]; echo $?)"
run good.txt; ok "the gate with an argument does not run passes: fixtures" "$(! has 'passes:'; echo $?)"
pcard allow '["src/never/**"]' never '' 2026-01-06
run; ok "an exception to a checked never with no passes: fixture -> EXCEPTION, RED"   "$([ "$rc" = 1 ] && has '^EXCEPTION allow: exception: never has a check: and allow lists no passes: fixture' && [ "$last" = 'RED: 1 exceptions' ]; echo $?)"

echo "--- tool-only scope is deliverable (rules-tree 03)"
mkrepo "$TMP/toolscope"; cm 2026-01-01 docs/defects/README.md
card t text '' '' 2026-01-05; sed_inplace 's|^paths: .*|paths: ["tool:WebFetch", "cmd:curl"]|' docs/defects/t.md
run; ok "a text card scoped only tool:/cmd: -> no UNDELIVERABLE" "$([ "$rc" = 0 ] && ! has 'UNDELIVERABLE'; echo $?)"
sed_inplace 's|^paths: .*|paths: ["tool:WebFetch"]|' docs/defects/t.md
run; ok "neighbour: tool: alone -> no UNDELIVERABLE" "$([ "$rc" = 0 ] && ! has 'UNDELIVERABLE'; echo $?)"

echo "--- the generated index (rules-tree 03)"
mkrepo "$TMP/index"; cm 2026-01-01 docs/defects/README.md
card rep text '' '' 2026-01-05 2026-01-06; cm 2026-01-01 docs/defects/rep.md
pcard al '["src/al/**"]' '' '' 2026-01-05 2026-01-08; mkdir -p docs/defects/pay; mv docs/defects/al.md docs/defects/pay/
cm 2026-01-01 docs/defects/pay/al.md
run; ok "no INDEX.md -> one no index line, exit unaffected" \
  "$([ "$rc" = 0 ] && [ "$(printf '%s\n' "$out" | grep -c '^no index')" = 1 ]; echo $?)"
bash scripts/defects-index.sh >/dev/null
ok "the index has three tables, a foldered row and repeats" \
  "$(grep -q '^## Never$' docs/defects/INDEX.md && grep -q '^## Allowed$' docs/defects/INDEX.md && grep -q '^## How-to$' docs/defects/INDEX.md \
     && grep -qF '| pay | [pay/al](pay/al.md) | Allowed al | text | 2 | 2 | 1 | 2026-01-08 |' docs/defects/INDEX.md \
     && grep -qF '| general | [rep](rep.md) | Class rep | text | 1 | 2 | 1 | 2026-01-06 |' docs/defects/INDEX.md; echo $?)"
o="$(bash scripts/defects-index.sh --check)"; irc=$?
run; ok "a fresh index -> --check 0, gate green" "$([ "$irc" = 0 ] && [ -z "$o" ] && [ "$rc" = 0 ] && ! has 'INDEX'; echo $?)"
printf -- '- 2026-01-09 · v · 00:10 — «again»\n' >> docs/defects/rep.md
o="$(bash scripts/defects-index.sh --check)"; irc=$?
ok "a card changed after the index -> --check exit 1, index stale" "$([ "$irc" = 1 ] && printf '%s' "$o" | grep -q '^index stale'; echo $?)"
sed_inplace '/«again»/d' docs/defects/rep.md; sed_inplace 's/Class rep/Class rip/' docs/defects/INDEX.md
run; ok "neighbour: a hand edit of INDEX.md -> gate RED INDEX" "$([ "$rc" = 1 ] && has '^INDEX  index stale' && [ "$last" = 'RED: index stale' ]; echo $?)"
bash scripts/defects-index.sh >/dev/null
o="$(bash scripts/defects-index.sh --grep 'ALLOWED al')"
ok "--grep prints <ref>:<line>: <text>, case-insensitive, cards only" \
  "$([ "$o" = "$(printf 'pay/al:3: title: Allowed al\npay/al:8: # Allowed al')" ]; echo $?)"
o="$(bash scripts/defects-index.sh --counts)"
ok "--counts prints the one-line counts" "$([ "$o" = 'cards 2 · never 1 · allowed 2 · how-to 0 · allowed repeats 1' ]; echo $?)"
mkdir -p "$TMP/nopy"; printf '#!/bin/sh
exit 1
' > "$TMP/nopy/python3"; cp "$TMP/nopy/python3" "$TMP/nopy/python"; chmod +x "$TMP/nopy/"*
cp "$TMP/nopy/python3" "$TMP/nopy/py"   # the Windows launcher is probed too (P9-18)
o="$(VULYK_PY= PATH="$TMP/nopy:$PATH" bash scripts/defects-index.sh --counts 2>&1)"; irc=$?
ok "no python -> defects-index exit 2 like the gate" "$([ "$irc" = 2 ] && printf '%s' "$o" | grep -q 'python 3 not found'; echo $?)"
REALPY="$(command -v "$PYBIN")"
o="$(VULYK_PY="$REALPY" PATH="$TMP/nopy:$PATH" bash scripts/defects-index.sh --counts 2>&1)"
ok "P9-18: defects-index honours VULYK_PY when no python name runs" "$([ "$o" = 'cards 2 · never 1 · allowed 2 · how-to 0 · allowed repeats 1' ]; echo $?)"
mkdir -p "$TMP/pyonly"; cp "$TMP/nopy/python3" "$TMP/nopy/python" "$TMP/pyonly/"
printf '#!/bin/sh
exec "%s" "$@"
' "$REALPY" > "$TMP/pyonly/py"; chmod +x "$TMP/pyonly/"*
o="$(VULYK_PY= PATH="$TMP/pyonly:$PATH" bash scripts/defects-index.sh --counts 2>&1)"
ok "P9-18: defects-index finds py when python3 and python do not run" "$([ "$o" = 'cards 2 · never 1 · allowed 2 · how-to 0 · allowed repeats 1' ]; echo $?)"
run_pyonly="$(VULYK_PY= PATH="$TMP/pyonly:$PATH" bash scripts/defects-check.sh 2>&1)"
ok "P9-18: defects-check finds py too" "$(printf '%s' "$run_pyonly" | grep -q 'python 3 not found'; [ $? -ne 0 ]; echo $?)"

echo "--- defects-check --files: block checks on a story's files (mass-audit 01, D3)"
mkrepo "$TMP/files"; cm 2026-01-01 docs/defects/README.md
printf '#!/usr/bin/env bash\necho "$1" >> calls.log\nif grep -q bad "$1"; then echo "bad in $1"; echo second; exit 1; fi\n' > fcheck.sh
card fcut block 'bash fcheck.sh <arg>' "$FX" 2026-01-05
card fbare block 'bash fcheck.sh <arg>' '' 2026-01-05; sed_inplace 's|^paths: .*|paths: ["src/fbare/*.txt"]|' docs/defects/fbare.md
card fscope block 'bash fcheck.sh <arg>' "$FX" 2026-01-05; sed_inplace 's|^paths: .*|paths: ["cmd:.*", "tool:.*"]|' docs/defects/fscope.md
card ftext text 'bash fcheck.sh <arg>' "$FX" 2026-01-05; sed_inplace 's|^paths: .*|paths: ["src/**"]|' docs/defects/ftext.md
card fgone revoked 'bash fcheck.sh <arg>' "$FX" 2026-01-05; sed_inplace 's|^paths: .*|paths: ["src/**"]|' docs/defects/fgone.md
mkdir -p src/fcut src/other src/fbare
printf 'fine\n' > src/fcut/good.txt; printf 'bad\n' > src/fcut/bad.txt; printf 'bad\n' > src/other/bad.txt; printf 'fine\n' > src/fbare/ok.txt
rm -f calls.log; run --files src/fcut/good.txt src/fbare/ok.txt
ok "defects-check --files: matching files that pass every block check -> exit 0, no red line" \
  "$([ "$rc" = 0 ] && ! has 'fails on'; echo $?)"
ok "defects-check --files: each check ran once per matching file, not on others" \
  "$([ "$(sort calls.log | tr '\n' ' ')" = 'src/fbare/ok.txt src/fcut/good.txt ' ]; echo $?)"
rm -f calls.log; run --files src/fcut/good.txt src/fcut/bad.txt src/other/bad.txt
ok "defects-check --files: a block check failing on one matching file -> exit 1, '<ref> fails on <file>: <first output line>'" \
  "$([ "$rc" = 1 ] && has '^fcut fails on src/fcut/bad.txt: bad in src/fcut/bad.txt$' && [ "$(printf '%s\n' "$out" | grep -c 'fails on')" = 1 ]; echo $?)"
ok "defects-check --files: a file outside every glob, a cmd:/tool: scope, a text and a revoked card run nothing" \
  "$(! grep -q 'src/other' calls.log && [ "$(grep -c . calls.log)" = 2 ]; echo $?)"
ok "defects-check --files: no debt, index or info lines, only red lines" "$([ "$(printf '%s\n' "$out" | grep -c .)" = 1 ]; echo $?)"
run --files; ok "defects-check --files with no file -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
mkdir -p "$TMP/nopyf"; printf '#!/bin/sh\nexit 1\n' > "$TMP/nopyf/python3"
cp "$TMP/nopyf/python3" "$TMP/nopyf/python"; cp "$TMP/nopyf/python3" "$TMP/nopyf/py"; chmod +x "$TMP/nopyf/"*
out="$(VULYK_PY= PATH="$TMP/nopyf:$PATH" bash scripts/defects-check.sh --files src/fcut/bad.txt 2>&1)"; rc=$?
ok "defects-check --files with no python -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
mv .claude/hooks/defects_lib.py .claude/hooks/defects_lib.off
run --files src/fcut/bad.txt; ok "defects-check --files with no parser -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
mv .claude/hooks/defects_lib.off .claude/hooks/defects_lib.py
run
ok "defects-check --files: the audit names a block card with no glob paths: as 'block with no file scope'" \
  "$(has '^block fscope: block with no file scope' && ! has 'fcut: block with no file scope'; echo $?)"
# audit-fixes-1113-12 (from 09): a card's own fixtures: fail its check by design; --files skips them for that card only.
mkrepo "$TMP/ownfx"; cm 2026-01-01 docs/defects/README.md
mkdir -p fx; printf 'bad\n' > fx/fxa-bad.fixture; printf 'fine\n' > fx/fxa-ok.fixture
card fxa block 'bash check.sh <arg>' '[fx/fxa-bad.fixture, fx/fxa-ok.fixture]' 2026-01-05
sed_inplace 's|^paths: .*|paths: ["fx/**"]|' docs/defects/fxa.md
run --files fx/fxa-bad.fixture ./fx/fxa-ok.fixture
ok "defects-check --files: a block card's own fixtures in ## Files are not run through its check (story 04's two fixtures, 2026-11-13)" \
  "$([ "$rc" = 0 ] && ! has 'fails on'; echo $?)"
card fxb block 'bash check.sh <arg>' "$FX" 2026-01-05; sed_inplace 's|^paths: .*|paths: ["fx/**"]|' docs/defects/fxb.md
run --files fx/fxa-bad.fixture
ok "defects-check --files: the same file under a different card is still checked" \
  "$([ "$rc" = 1 ] && has '^fxb fails on fx/fxa-bad.fixture' && ! has 'fxa fails'; echo $?)"

echo "--- usage"
run a b; ok "two arguments -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
run ''; ok "an empty argument -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
cd "$SRC" || exit 1

echo "--- leak-check: any outside path, the hive registry (audit-fixes-1113-04, contract K1)"
# Deterministic lists: no private term file and a fixture registry, never the machine's own.
LK="$TMP/leak"; mkdir -p "$LK"; : > "$LK/noterms"
leak() { # leak <registry> <file>   -> the check's exit code; stdout+stderr in $LK/out
  VULYK_PRIVATE_TERMS="$LK/noterms" VULYK_PRIVATE_TERMS_AUTO="$LK/noterms" VULYK_HIVES_FILE="$1" \
    bash scripts/leak-check.sh "$2" > "$LK/out" 2>&1; echo $?
}
CARDX=docs/defects/host-internals-in-public-repo
for fx in "$CARDX.abspath.fixture" "$CARDX.temppath.fixture" "$CARDX.original.fixture" "$CARDX.neighbour.fixture"; do
  ok "leak-check: $fx -> exit 1" "$([ -f "$fx" ] && [ "$(leak "$LK/noreg" "$fx")" = 1 ]; echo $?)"
done
ok "leak-check: the plain-name fixture with the card's terms -> exit 1" \
  "$([ "$(VULYK_EXTRA_TERMS="$CARDX.terms" leak "$LK/noreg" "$CARDX.plainname.fixture")" = 1 ]; echo $?)"
ok "leak-check: the card lists both new fixtures" \
  "$(grep -q '^fixtures: .*abspath\.fixture.*temppath\.fixture' "$CARDX.md"; echo $?)"
DL=Q   # a stand-in hive root on a drive nobody uses, built from a variable so no literal path sits here
printf '# fixture registry\n%s:/Stand/acme-hive | canary\n' "$DL" > "$LK/reg"
printf 'Its transcripts sit in the folder %s--Stand-acme-hive under the projects dir.\n' "$DL" > "$LK/slug.txt"
ok "leak-check: a file naming a root from the fixture registry -> exit 1" \
  "$([ "$(leak "$LK/reg" "$LK/slug.txt")" = 1 ] && ! grep -q 'acme-hive' "$LK/out"; echo $?)"
ok "leak-check: the same file with no registry -> exit 0, one stderr note" \
  "$([ "$(leak "$LK/noreg" "$LK/slug.txt")" = 0 ] && [ "$(grep -c 'no hive registry' "$LK/out")" = 1 ]; echo $?)"
RW="$(cd "$SRC" && { pwd -W 2>/dev/null || pwd; })"
{ echo 'Run it with #!/usr/bin/env bash and send noise to /dev/null.'
  echo 'The registry is ~/.vulyk/hives; a hive is written <drive>:/<hive>/docs or /home/<user>/<hive>.'
  echo 'See https://github.com/example/repo/blob/main/x.md and file://localhost/etc/hosts.'
  echo 'Git for Windows lives in C:/Program Files/Git/bin and C:\Windows\System32 holds cmd.exe.'
  echo "This repo: $SRC/scripts/lib.sh and $RW/docs/defects/README.md."
  echo 'A stand-in from a variable: $T/acme-hive/docs/specs/x.md.'
} > "$LK/pass.txt"
ok "leak-check: only passing forms -> exit 0" "$([ "$(leak "$LK/reg" "$LK/pass.txt")" = 0 ]; echo $?)"
[ "$(cat "$LK/out")" = "" ] || sed 's/^/        /' "$LK/out"

echo "--- owner guard: only the owner's quoted words record an acceptance (audit-fixes-1113-08, contract O1)"
# Synthetic transcripts and a throwaway spec repo; the hook reads both as it reads a live session's.
OG="$SRC/.claude/hooks/owner-guard.sh"
OD="$TMP/og"; mkdir -p "$OD/repo/docs/specs/acme-demo" "$OD/repo/memory/stats" "$OD/repo/src" "$OD/stubs"
cd "$OD/repo" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@t && git config core.autocrlf false
printf '# Acme plan\n\n**Approved:** <the owner word>\n**Checked:** <written by human-check>\n' > docs/specs/acme-demo/plan.md
git add -A && GIT_AUTHOR_DATE='2026-01-01T10:00:00 +0000' GIT_COMMITTER_DATE='2026-01-01T10:00:00 +0000' \
  git commit -q -m 'vulyk(acme-demo): plan'
printf '{"ts":"2026-01-02T10:00:00Z","spec":"acme-demo","round":1,"verdict":"GREEN"}\n' > memory/stats/council.jsonl
OW="$(pwd -W 2>/dev/null || pwd)"; ODW="$(cd "$OD" && { pwd -W 2>/dev/null || pwd; })"
# Transcript entries, one JSON line each: <ts> then the text (no " or \ in the text, \n is a newline).
t_owner() { printf '{"type":"user","isSidechain":false,"origin":{"kind":"human"},"promptSource":"typed","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$1" "$2"; }
t_meta() { printf '{"type":"user","isSidechain":false,"isMeta":true,"timestamp":"%s","message":{"role":"user","content":[{"type":"text","text":"%s"}]}}\n' "$1" "$2"; }
t_asst() { printf '{"type":"assistant","isSidechain":false,"timestamp":"%s","message":{"role":"assistant","content":[{"type":"text","text":"%s"}]}}\n' "$1" "$2"; }
t_tool() { printf '{"type":"user","isSidechain":false,"timestamp":"%s","toolUseResult":{"stdout":"%s"},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"b1","content":"%s"}]}}\n' "$1" "$2" "$2"; }
t_peer() { printf '{"type":"user","isSidechain":false,"origin":{"kind":"peer","from":"audit-1"},"promptSource":"system","timestamp":"%s","message":{"role":"user","content":"%s"}}\n' "$1" "$2"; }
t_ask() { # t_ask <ts> <id> <question> <first option label> [a second question]
  local q2=''
  [ -n "${5:-}" ] && q2=",{\"question\":\"$5\",\"header\":\"More\",\"multiSelect\":false,\"options\":[{\"label\":\"Yes\",\"description\":\"d\"}]}"
  printf '{"type":"assistant","isSidechain":false,"timestamp":"%s","message":{"role":"assistant","content":[{"type":"tool_use","id":"%s","name":"AskUserQuestion","input":{"questions":[{"question":"%s","header":"Release","multiSelect":false,"options":[{"label":"%s","description":"d"},{"label":"Hold","description":"d"}]}%s]}}]}}\n' \
    "$1" "$2" "$3" "$4" "$q2"
}
t_answer() { # t_answer <ts> <id> <question> <answer>
  printf '{"type":"user","isSidechain":false,"timestamp":"%s","toolUseResult":{"questions":[],"answers":{"%s":"%s"},"annotations":{}},"message":{"role":"user","content":[{"type":"tool_result","tool_use_id":"%s","content":"answered"}]}}\n' \
    "$1" "$3" "$4" "$2"
}
og() { # og <transcript name> <tool> <tool_input JSON> [agent_id] -> deny | allow, the hook output in $OD/why
  local a='' out
  [ -n "${4:-}" ] && a=",\"agent_id\":\"$4\",\"agent_type\":\"worker-code\""
  out="$(printf '{"session_id":"s","transcript_path":"%s/%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s%s}' \
    "$ODW" "$1" "$OW" "$2" "$3" "$a" | env -u CLAUDE_PROJECT_DIR bash "$OG")"
  printf '%s' "$out" > "$OD/why"
  case "$out" in *'"permissionDecision": "deny"'*) echo deny ;; '') echo allow ;; *) echo other ;; esac
}
hc() { printf '{"command":"bash scripts/human-check.sh docs/specs/acme-demo %s \\"%s\\""}' "$1" "$2"; }
ed() { printf '{"file_path":"%s/docs/specs/acme-demo/plan.md","old_string":"%s","new_string":"%s"}' "$OW" "$1" "$2"; }
Q='acme-demo: accept the release?'
# release: the owner picks an option, then types his own words after a second release question
{ t_owner 2026-01-01T12:00:00.000Z 'Old words about the Acme staging build'
  t_ask 2026-01-03T09:00:00.000Z q1 "$Q" 'Accept, ship it (Recommended)'
  t_answer 2026-01-03T09:01:00.000Z q1 "$Q" 'Accept, ship it (Recommended)'
  t_asst 2026-01-03T09:02:00.000Z 'The assistant says the Acme build is ready to ship'
  t_tool 2026-01-03T09:03:00.000Z 'Tool output says the Acme checks all pass'
  t_peer 2026-01-03T09:04:00.000Z 'An agent says the Acme release is approved'
  t_ask 2026-01-03T09:10:00.000Z q2 "$Q" 'Accept'
  t_owner 2026-01-03T09:12:00.000Z 'I looked at the staging site.\nthe Acme login works on a new account'
} > "$OD/rel.jsonl"
SUB=a1
ok "owner guard: a subagent cannot record an acceptance - human-check ACCEPTED" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'Accept, ship it (Recommended)')" "$SUB")" = deny ]; echo $?)"
ok "owner guard: a subagent cannot record an acceptance - the reason says so" \
  "$(grep -q 'a subagent cannot record an acceptance' "$OD/why"; echo $?)"
ok "owner guard: a subagent cannot record an acceptance - human-check REJECTED" \
  "$([ "$(og rel.jsonl Bash "$(hc REJECTED 'Accept, ship it (Recommended)')" "$SUB")" = deny ]; echo $?)"
GO='{"command":"bash scripts/cycle.sh briefed docs/specs/acme-demo --go"}'
ok "owner guard: a subagent cannot record an acceptance - cycle.sh briefed --go" \
  "$([ "$(og rel.jsonl Bash "$GO" "$SUB")" = deny ]; echo $?)"
AP='**Approved:** <the owner word>'
ok "owner guard: a subagent cannot record an acceptance - an Edit adding **Approved:**" \
  "$([ "$(og rel.jsonl Edit "$(ed "$AP" '**Approved:** t, 2026-01-03 (Accept)')" "$SUB")" = deny ]; echo $?)"
ok "owner guard: the picked answer to the release question, quoted whole, passes" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'owner picked «Accept, ship it (Recommended)» for the Acme build')")" = allow ]; echo $?)"
ok "owner guard: a whole line of his next message after the question passes" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'the Acme login works on a new account')")" = allow ]; echo $?)"
ok "owner guard: the same line with other spacing passes" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'the  Acme login   works on a new account')")" = allow ]; echo $?)"
ok "owner guard: REJECTED takes the same rule" \
  "$([ "$(og rel.jsonl Bash "$(hc REJECTED 'I looked at the staging site.')")" = allow ]; echo $?)"
ok "owner guard: a note with no owner text is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'all good, shipping')")" = deny ]; echo $?)"
ok "owner guard: a fragment cut from inside a line is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'Acme login works')")" = deny ]; echo $?)"
ok "owner guard: a quote older than the latest verdict is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'Old words about the Acme staging build')")" = deny ]; echo $?)"
ok "owner guard: text only in an assistant message is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'The assistant says the Acme build is ready to ship')")" = deny ]; echo $?)"
ok "owner guard: text only in a tool result is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'Tool output says the Acme checks all pass')")" = deny ]; echo $?)"
ok "owner guard: text only in an agent's message is denied" \
  "$([ "$(og rel.jsonl Bash "$(hc ACCEPTED 'An agent says the Acme release is approved')")" = deny ]; echo $?)"
# a bare «ок», and an owner message of 8+ letters that answers no release question
{ t_ask 2026-01-03T09:00:00.000Z q1 "$Q" 'Accept'
  t_answer 2026-01-03T09:01:00.000Z q1 "$Q" 'ок'
  t_owner 2026-01-03T09:02:00.000Z 'ок'
} > "$OD/ok.jsonl"
ok "owner guard: a bare «ок» (a typed answer, then a message) is denied" \
  "$([ "$(og ok.jsonl Bash "$(hc ACCEPTED 'ок')")" = deny ]; echo $?)"
{ t_owner 2026-01-03T09:00:00.000Z 'Everything looks right on the Acme staging site'
  t_ask 2026-01-03T09:05:00.000Z q1 'Which Acme logo do you like?' 'Blue'
  t_answer 2026-01-03T09:06:00.000Z q1 'Which Acme logo do you like?' 'The blue logo with round corners'
  t_ask 2026-01-03T09:07:00.000Z q2 "$Q" 'Accept' 'Also bump the Acme version?'
  t_answer 2026-01-03T09:08:00.000Z q2 "$Q" 'Accept it, the Acme build is fine'
} > "$OD/noq.jsonl"
ok "owner guard: an owner message of 8+ letters that answers no release question is denied" \
  "$([ "$(og noq.jsonl Bash "$(hc ACCEPTED 'Everything looks right on the Acme staging site')")" = deny ]; echo $?)"
ok "owner guard: an answer to a question that does not name the spec is denied" \
  "$([ "$(og noq.jsonl Bash "$(hc ACCEPTED 'The blue logo with round corners')")" = deny ]; echo $?)"
ok "owner guard: an answer to a release question asked beside another is denied" \
  "$([ "$(og noq.jsonl Bash "$(hc ACCEPTED 'Accept it, the Acme build is fine')")" = deny ]; echo $?)"
# **Checked:** lines, by an Edit and by a shell command, are judged like the acceptance
CK='**Checked:** <written by human-check>'
ok "owner guard: an Edit writing a **Checked:** line that quotes the owner passes" \
  "$([ "$(og rel.jsonl Edit "$(ed "$CK" '**Checked:** ACCEPTED by t, 2026-01-03 - the Acme login works on a new account')")" = allow ]; echo $?)"
ok "owner guard: an Edit writing a **Checked:** line with no owner quote is denied" \
  "$([ "$(og rel.jsonl Edit "$(ed "$CK" '**Checked:** ACCEPTED by t, 2026-01-03 - looks fine')")" = deny ]; echo $?)"
SHBAD='{"command":"printf %s >> docs/specs/acme-demo/plan.md"}'
SHBAD="$(printf "$SHBAD" "'**Checked:** ACCEPTED by t - looks fine\\\\n'")"
SHGOOD='{"command":"printf %s >> docs/specs/acme-demo/plan.md"}'
SHGOOD="$(printf "$SHGOOD" "'**Checked:** ACCEPTED by t - the Acme login works on a new account\\\\n'")"
ok "owner guard: a shell command writing a **Checked:** line into a plan.md is judged like the Edit" \
  "$([ "$(og rel.jsonl Bash "$SHBAD")" = deny ] && [ "$(og rel.jsonl Bash "$SHGOOD")" = allow ]; echo $?)"
WR="{\"file_path\":\"$OW/docs/specs/acme-demo/plan.md\",\"content\":\"# Acme plan\\n$CK\\n\"}"
ok "owner guard: a marker line left on its template placeholder passes, for a subagent too" \
  "$([ "$(og rel.jsonl Edit "$(ed '# Acme plan' "# Acme plan\\n\\n$AP")" "$SUB")" = allow ] &&
     [ "$(og rel.jsonl Write "$WR" "$SUB")" = allow ]; echo $?)"
ok "owner guard: an edit of plan.md that changes no marker line passes, for a subagent too" \
  "$([ "$(og rel.jsonl Edit "$(ed "# Acme plan\\n\\n$CK" "# Acme plan, revised\\n\\n$CK")" "$SUB")" = allow ]; echo $?)"
# plan approval: the owner's latest message after the plan commit (2026-01-01T10:00Z), at any length
{ t_owner 2026-01-01T09:00:00.000Z 'Approve the Acme plan when it is ready'
  t_owner 2026-01-01T11:00:00.000Z 'Tighten the second Acme story'
  t_owner 2026-01-01T12:00:00.000Z 'Погнали'
} > "$OD/plan.jsonl"
t_owner 2026-01-01T09:30:00.000Z 'Погнали' > "$OD/early.jsonl"
ok "owner guard: an **Approved:** line quoting the owner's latest message after the plan commit passes («Погнали»)" \
  "$([ "$(og plan.jsonl Edit "$(ed "$AP" '**Approved:** t, 2026-01-01 («Погнали»)')")" = allow ]; echo $?)"
ok "owner guard: an **Approved:** line quoting an earlier owner message is denied" \
  "$([ "$(og plan.jsonl Edit "$(ed "$AP" '**Approved:** t, 2026-01-01 («Tighten the second Acme story»)')")" = deny ]; echo $?)"
ok "owner guard: an **Approved:** line whose quote was written before the plan commit is denied" \
  "$([ "$(og early.jsonl Edit "$(ed "$AP" '**Approved:** t, 2026-01-01 («Погнали»)')")" = deny ]; echo $?)"
# the line as it stands after the edit (audit-fixes-1113-15): an edit that leaves the marker out of its strings
ok "owner guard: a subagent's Edit replacing only the placeholder after **Approved:** is denied" \
  "$([ "$(og plan.jsonl Edit "$(ed '<the owner word>' 'yes, ship it')" "$SUB")" = deny ]; echo $?)"
ME="{\"file_path\":\"$OW/docs/specs/acme-demo/plan.md\",\"edits\":[{\"old_string\":\"<written by human-check>\",\"new_string\":\"ACCEPTED by t - looks fine\"}]}"
ok "owner guard: a subagent's MultiEdit replacing only the placeholder after **Checked:** is denied" \
  "$([ "$(og rel.jsonl MultiEdit "$ME" "$SUB")" = deny ]; echo $?)"
ok "owner guard: a main-session Edit of the placeholder alone, quoting the latest message, passes" \
  "$([ "$(og plan.jsonl Edit "$(ed '<the owner word>' 't, 2026-01-01 («Погнали»)')")" = allow ]; echo $?)"
ok "owner guard: a main-session Edit of the placeholder alone, quoting an earlier message, is denied" \
  "$([ "$(og plan.jsonl Edit "$(ed '<the owner word>' 't, 2026-01-01 («Tighten the second Acme story»)')")" = deny ]; echo $?)"
SEDI="sed -i 's/<the owner word>/yes/' docs/specs/acme-demo/plan.md" # portable: hook input text, never run
SEDC="bash -c \\\"sed -i s/x/y/ docs/specs/acme-demo/plan.md\\\"" # portable: hook input text, never run
for c in "$SEDI" "echo yes > docs/specs/acme-demo/plan.md" \
         "cp /tmp/p.md docs/specs/acme-demo/plan.md" "python -c 'x' docs/specs/acme-demo/plan.md" "$SEDC"; do
  ok "owner guard: a subagent's $c (a plan.md with a record line, no marker spelled) is denied" \
    "$([ "$(og plan.jsonl Bash "{\"command\":\"$c\"}" "$SUB")" = deny ]; echo $?)"
  ok "owner guard: main-session $c is denied, naming the Edit tool" \
    "$([ "$(og plan.jsonl Bash "{\"command\":\"$c\"}")" = deny ] && grep -q 'Edit tool' "$OD/why"; echo $?)"
done
for c in "cat docs/specs/acme-demo/plan.md" "grep -n Approved docs/specs/acme-demo/plan.md" \
         "cp docs/specs/acme-demo/plan.md /tmp/p.md" "git show HEAD:docs/specs/acme-demo/plan.md > /tmp/p.md" \
         "sed -n 1,5p docs/specs/acme-demo/plan.md"; do
  ok "owner guard: a subagent's $c (reads a plan.md) passes" \
    "$([ "$(og plan.jsonl Bash "{\"command\":\"$c\"}" "$SUB")" = allow ]; echo $?)"
done
# briefed --go: an owner prompt must carry --go; a command expansion or an assistant line does not count
{ t_owner 2026-01-03T09:00:00.000Z 'Plan the Acme task'
  t_meta 2026-01-03T09:00:01.000Z 'Plan: run straight through with --go when the owner asks'
  t_asst 2026-01-03T09:01:00.000Z 'I will run briefed --go now'
} > "$OD/nogo.jsonl"
t_owner 2026-01-03T09:00:00.000Z '<command-message>vulyk-plan</command-message>\n<command-name>/vulyk-plan</command-name>\n<command-args>--go plan the Acme task</command-args>' > "$OD/go.jsonl"
ok "owner guard: briefed --go with no owner prompt carrying --go is denied" "$([ "$(og nogo.jsonl Bash "$GO")" = deny ]; echo $?)"
ok "owner guard: briefed --go passes when an owner prompt (a slash command's arguments) carries --go" \
  "$([ "$(og go.jsonl Bash "$GO")" = allow ]; echo $?)"
ok "owner guard: an unreadable transcript denies a guarded call, saying why" \
  "$([ "$(og missing.jsonl Bash "$(hc ACCEPTED 'the Acme login works on a new account')")" = deny ] && grep -q 'cannot be read' "$OD/why"; echo $?)"
# no Python: every launcher is a counting stub that runs nothing
for p in python3 python py; do
  printf '#!/bin/sh\necho x >> "%s/count"\nexit 9009\n' "$OD" > "$OD/stubs/$p"; chmod +x "$OD/stubs/$p"
done
nopy() { # nopy <tool> <tool_input JSON> -> the hook's stdout, with python3 / python / py stubbed away
  printf '{"session_id":"s","transcript_path":"%s/rel.jsonl","cwd":"%s","tool_name":"%s","tool_input":%s}' "$ODW" "$OW" "$1" "$2" |
    env -u VULYK_PY -u CLAUDE_PROJECT_DIR PATH="$OD/stubs:$PATH" bash "$OG"
}
o="$(nopy Bash "$(hc ACCEPTED 'the Acme login works on a new account')")"
ok "owner guard: with no Python a guarded call is denied, naming the missing Python" \
  "$(printf '%s' "$o" | grep -q '"deny".*no Python 3'; echo $?)"
o="$(nopy Edit "$(ed '<the owner word>' 'yes, ship it')")"
ok "owner guard: with no Python an Edit of a plan.md that leaves the marker out is denied" \
  "$(printf '%s' "$o" | grep -q '"deny".*no Python 3'; echo $?)"
: > "$OD/count"
EDSRC="{\"file_path\":\"$OW/src/a.py\",\"old_string\":\"a\",\"new_string\":\"b\"}"
o="$(nopy Bash '{"command":"ls src"}')$(nopy Edit "$EDSRC")"
ok "owner guard: with no Python an unrelated Bash or Edit call passes and starts no interpreter" \
  "$([ -z "$o" ] && [ ! -s "$OD/count" ]; echo $?)"
cd "$SRC" || exit 1
OGC=docs/defects/owner-words-by-builder
bash "$OG" --check "$OGC.original.fixture" >/dev/null; a=$?
bash "$OG" --check "$OGC.neighbour.fixture" >/dev/null; b=$?
ok "owner guard --check: both card fixtures exit 1" "$([ "$a" = 1 ] && [ "$b" = 1 ]; echo $?)"
ok "owner guard --check: a file that is no hook input exits 0" \
  "$(bash "$OG" --check docs/defects/README.md >/dev/null && bash "$OG" --check "$OGC.md" >/dev/null; echo $?)"
ok "owner guard: the card is block, the hook its check, its ## Check names what stays open" \
  "$(grep -q '^status: block$' "$OGC.md" && grep -qF 'check: bash .claude/hooks/owner-guard.sh --check <arg>' "$OGC.md" &&
     sed -n '/^## Check/,/^## Never/p' "$OGC.md" | grep -q 'Left open on purpose'; echo $?)"
ok "owner guard: the defect index is current" "$(bash scripts/defects-index.sh --check >/dev/null 2>&1; echo $?)"
# audit-fixes-1113-17 (round 2 review, Major 1): the header names every shell form the plan.md rewrite check leaves open
OGH="$(sed -n '1,/^# The Python half lives/p' "$OG" | tr -d '\r' | sed 's/^# *//' | tr '\n' ' ' | tr -s ' ')"
for n in 'a bare `plan.md` after a `cd`' 'from a cwd inside the spec folder' 'a glob (`docs/specs/*/plan.md`)' \
         'a variable or a substitution' 'a writer outside its list' 'command text a shell reads from a file' \
         'with no Python, every shell rewrite'; do
  hit=1; case "$OGH" in *"$n"*) hit=0 ;; esac
  ok "owner guard: the header names the open plan.md rewrite form: $n" "$hit"
done
hit=0; case "$OGH" in *'sed or awk -i): the hook cannot read'*) hit=1 ;; esac
ok "owner guard: the header no longer says every plan.md rewrite is denied to everyone" "$hit"

echo "--- owner guard: a record row is written only by a command that writes the file (owner-guard-commit-fp)"
# original case, 2026-11-14: committing the row human-check had just written, with ACCEPTED in the message
CM='{"command":"git add docs/specs/acme-demo/plan.md memory/stats/human.jsonl && git commit -m \"vulyk(acme-demo): human check ACCEPTED\""}'
ok "owner guard: a git commit that only names the record file passes - subagent" \
  "$([ "$(og rel.jsonl Bash "$CM" "$SUB")" = allow ]; echo $?)"
ok "owner guard: a git commit that only names the record file passes - main session" \
  "$([ "$(og rel.jsonl Bash "$CM")" = allow ]; echo $?)"
ok "owner guard: git add -u memory/stats passes" \
  "$([ "$(og rel.jsonl Bash '{"command":"git add -u memory/stats && git commit -m \"human check ACCEPTED\""}' "$SUB")" = allow ]; echo $?)"
ok "owner guard: reading the record file passes" \
  "$([ "$(og rel.jsonl Bash '{"command":"grep ACCEPTED memory/stats/human.jsonl"}' "$SUB")" = allow ]; echo $?)"
ok "owner guard: a heredoc to another file that only mentions the record passes" \
  "$([ "$(og rel.jsonl Bash '{"command":"cat > /tmp/acme-brief.md <<X\nnote: memory/stats/human.jsonl holds ACCEPTED rows\nX"}' "$SUB")" = allow ]; echo $?)"
ok "owner guard: a redirect into the record is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"echo {\\\"spec\\\":\\\"acme-demo\\\",\\\"verdict\\\":\\\"ACCEPTED\\\"} >> memory/stats/human.jsonl"}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: tee into the record is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"printf x | tee -a memory/stats/human.jsonl"}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: an interpreter writing the record is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"python -c \"open(\\\"memory/stats/human.jsonl\\\",\\\"a\\\").write(\\\"x\\\")\""}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: a write into the record by its bare name after a cd is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"cd memory/stats && echo x >> human.jsonl"}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: tee into the record by its bare name is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"cd memory/stats; printf x | tee -a human.jsonl"}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: a redirect into a variable in a command naming the record is still denied - subagent" \
  "$([ "$(og rel.jsonl Bash '{"command":"f=memory/stats/human.jsonl; echo x >> \"$f\""}' "$SUB")" = deny ]; echo $?)"
ok "owner guard: git add of the record by its bare name passes" \
  "$([ "$(og rel.jsonl Bash '{"command":"cd memory/stats && git add human.jsonl"}' "$SUB")" = allow ]; echo $?)"
ok "owner guard: a redirect into the record is still denied - main session without a quote" \
  "$([ "$(og rel.jsonl Bash '{"command":"echo {\\\"spec\\\":\\\"acme-demo\\\",\\\"verdict\\\":\\\"ACCEPTED\\\"} >> memory/stats/human.jsonl"}')" = deny ]; echo $?)"

echo "--- this tree's library: green, one info line per .scrub-revs commit (audit-fixes-1113-12)"
run
ok "defects-check on this tree is green, no ESCAPE (story 04's masked quote of command-injection-follows-cwd)" \
  "$([ "$rc" = 0 ] && ! has 'ESCAPE'; echo $?)"
srv_ok=0
for s in $(grep -v '^[[:space:]]*#' docs/defects/.scrub-revs 2>/dev/null | awk 'NF { print $1 }'); do
  [ "$(printf '%s\n' "$out" | grep -c "^scrub-rev ${s:0:7}")" = 1 ] || srv_ok=1
done
ok "the audit of this tree prints one info line per listed commit" "$srv_ok"

if [ "$fail" -eq 0 ]; then echo "defects.test.sh: all checks passed"; else echo "defects.test.sh: FAILED"; fi
exit "$fail"
