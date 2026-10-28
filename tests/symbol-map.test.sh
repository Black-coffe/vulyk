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

# trace-autopsy.sh (docs/specs/trace-autopsy/plan.md ## Contracts), the step-2 sibling of symbol-map.sh: a fixture repo
# built here, with two authors so the newest commit on a line is told from the first one.
echo "--- trace-autopsy"
TA="$SRC/scripts/trace-autopsy.sh"
R="$T/ta"; mkdir -p "$R/src/app" "$R/web" "$R/lib" "$R/a" "$R/b"
printf 'def calc(a, b):\n    x = a\n    return a + b\n' > "$R/src/app/core.py"
printf 'from app.core import calc\ncalc(1, 0)\n' > "$R/src/app/main.py"
printf 'const http = 1;\nfunction handler() {\n  const y = 2;\n  throw new Error("boom");\n}\n' > "$R/web/server.js"
printf '#!/usr/bin/env bash\nfoo\n' > "$R/lib/run.sh"
printf 'x = 1\n' > "$R/a/util.py"; printf 'x = 2\n' > "$R/b/util.py"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf 'v = %s\n' "$i" > "$R/lib/m$i.py"; done
git -C "$R" init -q
git -C "$R" add -A && git -C "$R" -c user.name=Ann -c user.email=ann@example.invalid commit -q -m "initial import"
printf 'def calc(a, b):\n    x = a\n    return a / b\n' > "$R/src/app/core.py"
git -C "$R" add -A && git -C "$R" -c user.name=Bob -c user.email=bob@example.invalid commit -q -m "divide instead of add"
HEAD7="$(git -C "$R" rev-parse --short=7 HEAD)"
brief() { mkdir -p "$R/docs/specs/$1"; { printf '# brief\n\n## Request (verbatim)\n'; sed 's/^/> /'; } > "$R/docs/specs/$1/brief.md"; }

brief py <<'EOF'
Traceback (most recent call last):
  File "/app/src/app/main.py", line 2, in <module>
  File "/app/src/app/core.py", line 3, in calc
    return a / b
ZeroDivisionError: division by zero
EOF
t0="$(date +%s%N)"
bash "$TA" "$R/docs/specs/py/brief.md" > "$T/ta-py.out" 2>&1; RC=$?
ms=$(( ($(date +%s%N) - t0) / 1000000 ))
A="$R/docs/specs/py/autopsy.md"
expect_eq "trace-autopsy: a Python traceback exits 0" "0" "$RC"
if [ -f "$A" ]; then ok "trace-autopsy: a Python traceback writes autopsy.md"
else bad "trace-autopsy: a Python traceback writes autopsy.md - got:"; sed 's/^/        /' "$T/ta-py.out"; : > "$A"; fi
expect "trace-autopsy: /app/src/app/core.py resolves by suffix" "src/app/core.py:3" "$A"
expect "trace-autopsy: the code line is read at HEAD" "return a / b" "$A"
expect "trace-autopsy: HEAD is named" "$HEAD7" "$A"
expect "trace-autopsy: the newest commit on the line" "divide instead of add" "$A"
expect "trace-autopsy: its author" "Bob" "$A"
expect "trace-autopsy: labelled as the last touch" "last touched" "$A"
expect_absent "trace-autopsy: never says broke" "broke" "$A"
expect_absent "trace-autopsy: never says сломал" "сломал" "$A"
inner="$(grep -n 'src/app/core.py:3' "$A" | head -n1 | cut -d: -f1)"; outer="$(grep -n 'src/app/main.py:2' "$A" | head -n1 | cut -d: -f1)"
if [ -n "$inner" ] && [ -n "$outer" ] && [ "$inner" -lt "$outer" ]; then ok "trace-autopsy: innermost Python frame first"
else bad "trace-autopsy: innermost Python frame first (core at '${inner}', main at '${outer}')"; fi
if [ "$ms" -lt 1000 ]; then ok "trace-autopsy: a run takes ${ms} ms (< 1000)"; else bad "trace-autopsy: a run takes ${ms} ms (>= 1000)"; fi

brief js <<'EOF'
Error: boom
    at handler (C:\build\web\server.js:4:11)
    at Server.emit (node:events:517:28)
EOF
bash "$TA" "$R/docs/specs/js/brief.md" > /dev/null 2>&1
touch "$R/docs/specs/js/autopsy.md"
expect "trace-autopsy: a Windows path in a Node frame resolves" "web/server.js:4" "$R/docs/specs/js/autopsy.md"
expect "trace-autopsy: the Node frame's code line" 'throw new Error("boom")' "$R/docs/specs/js/autopsy.md"

brief sh <<'EOF'
/opt/svc/lib/run.sh: line 2: foo: command not found
see also web/server.js:2
EOF
bash "$TA" "$R/docs/specs/sh/brief.md" > /dev/null 2>&1
touch "$R/docs/specs/sh/autopsy.md"
expect "trace-autopsy: a bash frame resolves" "lib/run.sh:2" "$R/docs/specs/sh/autopsy.md"
expect "trace-autopsy: a plain path:line resolves" "web/server.js:2" "$R/docs/specs/sh/autopsy.md"

brief marks <<'EOF'
Traceback (most recent call last):
  File "/usr/lib/python3.12/json/decoder.py", line 355, in raw_decode
  File "/srv/util.py", line 1, in <module>
  File "/app/src/app/core.py", line 999, in calc
  File "/app/src/app/core.py", line 2, in calc
  File "/app/web/server.js", line 0, in f
EOF
bash "$TA" "$R/docs/specs/marks/brief.md" > "$T/ta-marks.out" 2>&1; RC=$?
touch "$R/docs/specs/marks/autopsy.md"
expect_eq "trace-autopsy: marks only, still exit 0" "0" "$RC"
expect "trace-autopsy: a frame outside the repo is marked" "outside the repo" "$R/docs/specs/marks/autopsy.md"
expect "trace-autopsy: a suffix two files share is marked" "ambiguous" "$R/docs/specs/marks/autopsy.md"
expect "trace-autopsy: a line past the end is marked" "past end" "$R/docs/specs/marks/autopsy.md"
expect "trace-autopsy: line 0 is marked, not dropped" "web/server.js:0 (no such line)" "$R/docs/specs/marks/autopsy.md"

brief hostile <<'EOF'
-L1,1:lib/run.sh:2
  File "../../etc/passwd", line 1, in x
    at $(touch pwned):2
    at `touch pwned2`.js:3:1
EOF
( cd "$R" && bash "$TA" "$R/docs/specs/hostile/brief.md" > "$T/ta-hostile.out" 2>&1 ); RC=$?
expect_eq "trace-autopsy: a hostile trace exits 0" "0" "$RC"
if [ ! -e "$R/pwned" ] && [ ! -e "$R/pwned2" ] && [ ! -e "$SRC/pwned" ] && [ ! -e "$SRC/pwned2" ]; then
  ok "trace-autopsy: trace text is never run"; else bad "trace-autopsy: trace text was run (a pwned file exists)"; fi
if grep -qE '^(\.\./)*etc/passwd:1 ' "$T/ta-hostile.out"; then bad "trace-autopsy: ../../etc/passwd became a frame"
else ok "trace-autopsy: ../../etc/passwd never becomes a frame"; fi

brief none <<'EOF'
It crashes when I click save. No log.
  File "/usr/lib/python3.12/json/decoder.py", line 355, in raw_decode
EOF
bash "$TA" "$R/docs/specs/none/brief.md" > "$T/ta-none.out" 2>&1; RC=$?
expect_eq "trace-autopsy: no repo frame exits 0" "0" "$RC"
if [ ! -e "$R/docs/specs/none/autopsy.md" ]; then ok "trace-autopsy: no repo frame writes no autopsy.md"
else bad "trace-autopsy: no repo frame writes no autopsy.md"; fi
expect "trace-autopsy: no repo frame says so" "no repo frame" "$T/ta-none.out"

brief stripped <<'EOF'
  File "/app/app/core.py", line 3, in calc
EOF
bash "$TA" "$R/docs/specs/stripped/brief.md" > /dev/null 2>&1
touch "$R/docs/specs/stripped/autopsy.md"
expect "trace-autopsy: a build without src/ resolves by its two-part tail" "src/app/core.py:3" "$R/docs/specs/stripped/autopsy.md"
brief onlyamb <<'EOF'
  File "/srv/util.py", line 1, in <module>
EOF
bash "$TA" "$R/docs/specs/onlyamb/brief.md" > "$T/ta-onlyamb.out" 2>&1
expect "trace-autopsy: no repo frame still names the ambiguous candidates" "a/util.py, b/util.py" "$T/ta-onlyamb.out"

{ printf 'Traceback (most recent call last):\n'; for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf '  File "/app/lib/m%s.py", line 1, in f\n' "$i"; done; } | brief many
bash "$TA" "$R/docs/specs/many/brief.md" > /dev/null 2>&1
touch "$R/docs/specs/many/autopsy.md"
n="$(grep -c '' "$R/docs/specs/many/autopsy.md")"
if [ "$n" -le 15 ] && [ "$n" -gt 0 ]; then ok "trace-autopsy: twelve frames fit in $n lines (<= 15)"; else bad "trace-autopsy: twelve frames give $n lines (want 1-15)"; fi
case "$(tail -n1 "$R/docs/specs/many/autopsy.md")" in
  "... "*more*) ok "trace-autopsy: the overflow folds into a last '... N more' line" ;;
  *) bad "trace-autopsy: the last line is not '... N more': $(tail -n1 "$R/docs/specs/many/autopsy.md")" ;;
esac

bash "$TA" > /dev/null 2>&1; RC=$?
expect_eq "trace-autopsy: no argument exits 2" "2" "$RC"
mkdir -p "$T/ta-norepo"; printf '> lib/run.sh:2\n' > "$T/ta-norepo/brief.md"
bash "$TA" "$T/ta-norepo/brief.md" > /dev/null 2>&1; RC=$?
expect_eq "trace-autopsy: a brief outside any git repo exits 2" "2" "$RC"
# /vulyk-plan step 2 is the only caller: the step, from its number to step 3, must name the script and its output
awk '/^2\. Brief\./{on=1} /^3\. Recon\./{on=0} on' "$SRC/.claude/commands/vulyk-plan.md" > "$T/ta-step2.md"
expect "trace-autopsy: /vulyk-plan step 2 runs it" "bash scripts/trace-autopsy.sh docs/specs/<slug>/brief.md" "$T/ta-step2.md"
expect "trace-autopsy: /vulyk-plan step 2 names autopsy.md" "autopsy.md" "$T/ta-step2.md"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
echo "symbol-map.test.sh: $CHECKS checks, $FAILED failed"
[ "$FAILED" -eq 0 ]
