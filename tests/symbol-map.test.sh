#!/usr/bin/env bash
# The symbol-map contract (docs/specs/symbol-map/plan.md ## Contracts), driven on committed fixture trees.
#
#   Usage: bash tests/symbol-map.test.sh            # from the VULYK repo root
#
# Fixtures: tests/fixtures/symbol-map/python (a package with a re-exporting __init__, a test, a guard test,
# a doc naming the path, two false friends, a .ts file, a broken .py) and tests/fixtures/symbol-map/bash
# (a script sourcing lib.sh through $(dirname "$0"), a test sourcing it by literal path, two scripts running a
# sibling .py, a tests/fixtures file that must never show) and tests/fixtures/symbol-map/mentions (one dotfile
# named by code, a test, an ADR and the three root docs, for the ranking). Each tree is copied
# into a temp dir and made a git repo there; the cap cases add generated files to their own copy.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
FIX="$SRC/tests/fixtures/symbol-map"
SM="$SRC/scripts/symbol-map.sh"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }

expect() { # expect <label> <needle> <file>
  if grep -qF -- "$2" "$3"; then ok "$1"
  else bad "$1 - expected '$2' in:"; sed 's/^/        /' "$3"; fi
}
expect_absent() { # expect_absent <label> <needle> <file>
  if grep -qF -- "$2" "$3"; then bad "$1 - did not expect '$2' in:"; sed 's/^/        /' "$3"
  else ok "$1"; fi
}
expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 - expected '$2', got '$3'"; fi
}
# after <file> <section> <needle> - the needle is a line of that section (between its header and the next one)
after() {
  awk -v s="$2:" -v n="$3" '
    $0 == s { on = 1; next }
    /^[a-z][a-z ]*:$/ || /^## / { on = 0 }
    on && index($0, n) { found = 1 }
    END { exit !found }' "$1"
}
expect_in() { # expect_in <label> <file> <section> <needle>
  if after "$2" "$3" "$4"; then ok "$1"
  else bad "$1 - expected '$4' under '$3:' in:"; sed 's/^/        /' "$2"; fi
}
tree() { # tree <fixture> <dest> - a tracked copy
  cp -r "$FIX/$1" "$2"
  (cd "$2" && git init -q && git -c core.autocrlf=false add -A) || { echo "::error::cannot init $2"; exit 1; }
}

tree python "$T/py"
tree bash "$T/sh"

echo "--- python: pkg/core.py"
(cd "$T/py" && bash "$SM" pkg/core.py) > "$T/core.out" 2>&1; RC=$?
expect_eq "exit 0" "0" "$RC"
expect_eq "the block opens with the input" "## pkg/core.py" "$(head -n1 "$T/core.out")"
expect_eq "tests: is the first section" "tests:" "$(sed -n 2p "$T/core.out")"
expect_in "a test importing core is exact" "$T/core.out" tests "  exact    tests/test_core.py"
expect_in "a relative importer is exact" "$T/core.out" importers "  exact    pkg/api.py"
expect_in "an importer through the __init__ re-export is exact, via named" "$T/core.out" importers "  exact    app.py (via pkg/__init__.py)"
expect_in "what core imports is exact" "$T/core.out" imported "  exact    pkg/util.py"
expect_in "a repo-walking test is a guard test" "$T/core.out" "guard tests" "  textual  tests/test_tree.py"
expect_in "a doc naming the path is a path mention" "$T/core.out" "path mentions" "  textual  docs/notes.md"
expect_in "the false friend core_v2 is textual" "$T/core.out" importers "  textual  misc/core_v2.py"
expect_in "a file with the word core is textual" "$T/core.out" importers "  textual  misc/words.py"
expect_absent "the false friend core_v2 is never exact" "exact    misc/core_v2.py" "$T/core.out"
expect_absent "the word file is never exact" "exact    misc/words.py" "$T/core.out"
expect_absent "the input never lists itself" "  pkg/core.py" "$T/core.out"
order="$(grep -E '^[a-z][a-z ]*:$' "$T/core.out" | tr '\n' ',')"
expect_eq "sections in contract order" "tests:,importers:,imported:,guard tests:,path mentions:," "$order"

echo "--- other languages, broken input, missing input"
(cd "$T/py" && bash "$SM" src/app.ts) > "$T/ts.out" 2>&1; RC=$?
expect_eq "a .ts input exits 0" "0" "$RC"
expect "a .ts input says imports were not parsed" "  ! imports not parsed for .ts: search callers yourself" "$T/ts.out"
expect_absent "a .ts input gets no importers section" "importers:" "$T/ts.out"
expect_in "a .ts input still gets guard tests" "$T/ts.out" "guard tests" "  textual  tests/test_tree.py"
(cd "$T/py" && bash "$SM" docs/notes.md) > "$T/md.out" 2>&1
expect_absent "a .md input gets no importers" "importers:" "$T/md.out"
expect_absent "a .md input gets no imported" "imported:" "$T/md.out"
expect_in "a .md input gets guard tests" "$T/md.out" "guard tests" "  textual  tests/test_tree.py"
(cd "$T/py" && bash "$SM" misc/broken.py) > "$T/bad.out" 2>&1; RC=$?
expect_eq "a .py with a syntax error exits 0" "0" "$RC"
expect "a .py with a syntax error is reported unparsed" "  ! unparsed" "$T/bad.out"
expect_in "and still gets its textual sections" "$T/bad.out" "guard tests" "  textual  tests/test_tree.py"
(cd "$T/py" && bash "$SM" nope.py pkg/util.py) > "$T/miss.out" 2>&1; RC=$?
expect_eq "a missing input exits 1" "1" "$RC"
expect_eq "a missing input is named and marked" "## nope.py|  ! missing" "$(head -n2 "$T/miss.out" | tr '\n' '|' | sed 's/|$//')"
expect "the other inputs are still printed" "## pkg/util.py" "$T/miss.out"
expect_in "and mapped" "$T/miss.out" importers "  exact    pkg/core.py"
(cd "$T/py" && bash "$SM") > /dev/null 2> "$T/usage.err"; RC=$?
expect_eq "no arguments exits 2" "2" "$RC"
expect "no arguments prints usage" "usage:" "$T/usage.err"
(cd "$T/py" && bash "$SM" --bogus pkg/core.py) > /dev/null 2> "$T/flag.err"; RC=$?
expect_eq "an unknown flag exits 2" "2" "$RC"
expect "an unknown flag prints usage" "usage:" "$T/flag.err"

echo "--- scope"
(cd "$T/py" && bash "$SM" --scope pkg/api.py pkg/core.py) > "$T/scope.out" 2>&1
expect_absent "--scope drops the path" "pkg/api.py" "$T/scope.out"
expect "--scope keeps the rest" "  exact    tests/test_core.py" "$T/scope.out"
printf '# story\n\n## Files\n- pkg/api.py\n- `docs/*.md`\n\n## Non-goals\n- misc/words.py\n' > "$T/py/story.md"
(cd "$T/py" && bash "$SM" --story story.md pkg/core.py) > "$T/story.out" 2>&1
expect_absent "a ## Files path is dropped" "pkg/api.py" "$T/story.out"
expect_absent "a ## Files glob scopes by fnmatch" "docs/notes.md" "$T/story.out"
expect "a list outside ## Files does not scope" "  textual  misc/words.py" "$T/story.out"
printf '# story\n\n## Files\n- pkg/core.py\n- tests/**\n' > "$T/py/story2.md"
(cd "$T/py" && bash "$SM" --story story2.md) > "$T/story2.out" 2>&1; RC=$?
expect_eq "--story alone exits 0" "0" "$RC"
expect_eq "--story alone maps the ## Files lines" "## pkg/core.py" "$(head -n1 "$T/story2.out")"
expect_absent "--story alone: a glob is scope, not an input" "## tests" "$T/story2.out"
expect_absent "--story alone: the glob drops the tests" "tests/test_core.py" "$T/story2.out"

echo "--- bash: lib.sh"
(cd "$T/sh/scripts" && bash "$SM" lib.sh) > "$T/lib.out" 2>&1; RC=$?
expect_eq "exit 0" "0" "$RC"
expect_in "a \$(dirname \"\$0\") source is exact" "$T/lib.out" importers "  exact    scripts/run.sh"
expect_in "a literal-path source from a test is exact" "$T/lib.out" tests "  exact    tests/run.test.sh"
(cd "$T/sh" && bash "$SM" scripts/run.sh) > "$T/run.out" 2>&1
expect_in "what run.sh sources is exact" "$T/run.out" imported "  exact    scripts/lib.sh"

echo "--- bash runs python"
for x in rt:run-tool.sh rh:run-helper.sh tp:tool.py hp:helper.py; do
  (cd "$T/sh" && bash "$SM" "scripts/${x#*:}") > "$T/${x%%:*}.out" 2>&1
done
expect_in "a \"\$(dirname \"\$0\")/tool.py\" run is exact under imported" "$T/rt.out" imported "  exact    scripts/tool.py"
expect_in "a \"\$DIR/helper.py\" run is exact under imported" "$T/rh.out" imported "  exact    scripts/helper.py"
expect_in "the running script is exact under importers of tool.py" "$T/tp.out" importers "  exact    scripts/run-tool.sh"
expect_in "the running script is exact under importers of helper.py" "$T/hp.out" importers "  exact    scripts/run-helper.sh"

echo "--- fixtures never listed"
(cd "$T/sh" && bash "$SM" scripts/lib.sh) > "$T/fx.out" 2>&1
expect_absent "a tests/fixtures file that sources and names the input is never listed" "tests/fixtures/" "$T/fx.out"
expect_in "the real test is still listed" "$T/fx.out" tests "  exact    tests/run.test.sh"
(cd "$SRC" && bash "$SM" scripts/lib.sh) > "$T/own.out" 2>&1
expect_absent "scripts/lib.sh in this repo lists no tests/fixtures path" "tests/fixtures/" "$T/own.out"

echo "--- path mention ranking"
tree mentions "$T/men6"
(cd "$T/men6" && bash "$SM" etc/.toolrc) > "$T/men6.out" 2>&1
got="$(awk '$0=="path mentions:"{on=1;next} /^[a-z][a-z ]*:$/{on=0} on' "$T/men6.out" | sed 's/^ *//' | tr '\n' '|')"
expect_eq "code and tests, then ADR, then the root files; the tail hides a root file" \
  "textual  src/other.py|textual  tests/test_other.py|textual  docs/adr/001-x.md|textual  CHANGELOG.md|textual  CLAUDE.md|... 1 more|" "$got"

echo "--- --exact"
(cd "$T/py" && bash "$SM" --exact pkg/core.py) > "$T/ex.out" 2>&1; RC=$?
expect_eq "--exact exits 0" "0" "$RC"
expect_in "--exact keeps an exact test" "$T/ex.out" tests "  exact    tests/test_core.py"
expect_in "--exact keeps the via importer" "$T/ex.out" importers "  exact    app.py (via pkg/__init__.py)"
expect_in "--exact folds textual importers into a count" "$T/ex.out" importers "  textual  2 not shown"
expect_absent "--exact prints no textual path" "textual  misc/" "$T/ex.out"
got="$(awk '$0=="guard tests:"{on=1;next} /^[a-z][a-z ]*:$/{on=0} on' "$T/ex.out" | tr '\n' '|')"
expect_eq "a textual-only section prints only its count line" "  textual  1 not shown|" "$got"
bash "$SM" --help > "$T/help.out" 2>&1
expect "--help names --exact" "--exact" "$T/help.out"

echo "--- caps"
tree python "$T/mentions"
for i in 1 2 3 4 5 6 7 8; do printf 'see pkg/core.py\n' > "$T/mentions/docs/m$i.md"; done
(cd "$T/mentions" && git -c core.autocrlf=false add -A && bash "$SM" pkg/core.py) > "$T/men.out" 2>&1
n="$(awk '$0=="path mentions:"{on=1;next} /^[a-z][a-z ]*:$/{on=0} on' "$T/men.out" | grep -c .)"
expect_eq "path mentions: 5 lines plus the count line" "6" "$n"
expect "the count line names the rest" "    ... 4 more" "$T/men.out"
tree python "$T/busy"
mkdir -p "$T/busy/many"
for i in $(seq 1 70); do printf 'from pkg import core\n' > "$T/busy/many/user_$i.py"; done
(cd "$T/busy" && git -c core.autocrlf=false add -A && bash "$SM" pkg/core.py pkg/util.py pkg/api.py) > "$T/busy.out" 2>&1
size="$(wc -c < "$T/busy.out" | tr -d ' ')"
if [ "$size" -le 1536 ]; then ok "the whole stdout stays at or under 1536 bytes ($size)"; else bad "stdout is $size bytes > 1536"; fi
expect_eq "exactly one final ... N more line" "1" "$(grep -cE '^\.\.\. [0-9]+ more' "$T/busy.out")"
if tail -n1 "$T/busy.out" | grep -qE '^\.\.\. [0-9]+ more'; then ok "the count line ends the output"
else bad "the count line is not last: $(tail -n1 "$T/busy.out")"; fi
(cd "$T/busy" && bash "$SM" pkg/core.py pkg/util.py nope.sh) > "$T/busym.out" 2>&1; RC=$?
expect_eq "a missing input past the cap exits 1" "1" "$RC"
expect_eq "the missing block opens the output" "## nope.sh|  ! missing" "$(head -n2 "$T/busym.out" | tr '\n' '|' | sed 's/|$//')"
if tail -n1 "$T/busym.out" | grep -qE '^\.\.\. [0-9]+ more'; then ok "and the cap tail still ends it"
else bad "the cap tail is not last: $(tail -n1 "$T/busym.out")"; fi

echo "--- replay runner"
RPY=""
for p in python3 python; do
  if command -v "$p" >/dev/null 2>&1 && "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' >/dev/null 2>&1; then RPY="$p"; break; fi
done
winpath() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
tree python "$T/rp"
printf '# story\n\n## Files\n- pkg/core.py\n' > "$T/rp/story.md"
mkdir -p "$T/norepo"; printf '# story\n' > "$T/norepo/story.md"
printf '{"cases": [{"story_file": "%s", "files": ["pkg/core.py"], "missed": ["tests/test_core.py", "docs/other.md"]}]}\n' \
  "$(winpath "$T/rp/story.md")" > "$T/cases.json"
printf '{"cases": [{"story_file": "%s", "files": ["pkg/core.py"], "missed": []}]}\n' \
  "$(winpath "$T/norepo/story.md")" > "$T/cases-norepo.json"
"$RPY" "$SRC/docs/specs/symbol-map/replay.py" "$(winpath "$T/cases.json")" > "$T/replay.out" 2>&1; RC=$?
expect_eq "the replay exits 0" "0" "$RC"
expect_eq "the replay ends with hits, misses and the fixture's noise" "replay: hits 1/2 noise 9 over 1 stories" "$(tail -n1 "$T/replay.out")"
"$RPY" "$SRC/docs/specs/symbol-map/replay.py" "$(winpath "$T/cases-norepo.json")" > /dev/null 2>&1; RC=$?
expect_eq "a story outside any git repo exits 2" "2" "$RC"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
echo "symbol-map.test.sh: $CHECKS checks, $FAILED failed"
[ "$FAILED" -eq 0 ]
