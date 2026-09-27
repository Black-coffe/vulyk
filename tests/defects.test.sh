#!/usr/bin/env bash
# The defect library gate (contract 0.19 §1-2): scripts/defects-check.sh against throwaway git repos -
# effective status, fixtures (blind = red), the gate with an argument, and debt by git blame commit time.
#
#   Usage: bash tests/defects.test.sh            # from the VULYK repo root
set -u

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "::error::$1"; fail=1; fi; }

mkrepo() { # mkrepo <dir> - a git repo with the gate, a check and good/bad fixtures; README not committed yet
  mkdir -p "$1" && cd "$1" || exit 1
  git init -q -b main . && git config user.name t && git config user.email t@t && git config core.autocrlf false
  mkdir -p scripts docs/defects/fixtures
  cp "$SRC/scripts/defects-check.sh" scripts/
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
  { printf -- '---\nid: %s\ntitle: Class %s\nstatus: %s\ncheck: %s\nfixtures: %s\nkeys: [x]\n---\n\n# Class %s\nWhat it is.\n\n## Owner quotes\n\n' \
      "$id" "$id" "$st" "$ck" "$fx" "$id" "$id"
    for q in "$@"; do printf -- '- %s · video 1 · 00:10 — «words»\n' "$q"; done
    printf '\n## Cause\nWhy.\n\n## Never\n- do it\n'
  } > "docs/defects/$id.md"
}
run() { out="$(bash scripts/defects-check.sh "$@" 2>&1)"; rc=$?; last="$(printf '%s\n' "$out" | tail -1)"; }
has() { printf '%s\n' "$out" | grep -q -- "$1"; }
FX='[docs/defects/fixtures/orig.txt, docs/defects/fixtures/near.txt]'

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
ok "block with one existing fixture -> reported as text" "$(has '^text  onefix: block with <2 fixtures'; echo $?)"
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
sed -i 's/$/\r/' docs/defects/crlf.md docs/defects/crlftext.md
run
ok "CRLF card: frontmatter and fixtures parsed (effective block, both fixtures fail)" \
  "$([ "$(printf '%s\n' "$out" | grep -c '^ok    crlf: fixture')" = 2 ]; echo $?)"
ok "CRLF card: quote lines counted (2 uncommitted -> DEBT)" "$(has '^DEBT  crlftext: 2 quotes'; echo $?)"
rm -f docs/defects/crlf*.md
card ru text '' '' 2026-01-05 2026-01-06
sed -i 's/^## Owner quotes$/## Цитаты владельца/; s/^## Never$/## Нельзя/' docs/defects/ru.md
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

echo "--- usage"
run a b; ok "two arguments -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
run ''; ok "an empty argument -> exit 2" "$([ "$rc" = 2 ]; echo $?)"
cd "$SRC" || exit 1

if [ "$fail" -eq 0 ]; then echo "defects.test.sh: all checks passed"; else echo "defects.test.sh: FAILED"; fi
exit "$fail"
