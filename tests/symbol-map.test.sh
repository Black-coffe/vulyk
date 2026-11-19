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
. "$SRC/scripts/lib.sh"   # vulyk_python, for the trace-autopsy step count
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

# --fill-tests (docs/specs/narrow-repair-1115/plan.md T1): a spec's todo stories get the tests that mention
# their files as an `exact` hit, and a ## Commands row for each listed test. Original case: the audit-fixes-1113
# shape, a story's script pinned by a suite the story did not name. Neighbours: a parted suite, a glob line, a
# story that already lists the test; a done story and a repair story are never touched.
echo "--- fill-tests"
FT="$T/ft"; mkdir -p "$FT/scripts" "$FT/tests" "$FT/docs/specs/demo"
printf '#!/usr/bin/env bash\ntails() { echo t; }\n' > "$FT/scripts/tails.sh"
printf '#!/usr/bin/env bash\nparted() { echo p; }\n' > "$FT/scripts/parted.sh"
printf '#!/usr/bin/env bash\nSRC=.\n. "$SRC/scripts/tails.sh"\ntails\n' > "$FT/tests/ship.test.sh"
printf '#!/usr/bin/env bash\necho "the tails word, never a source"\n' > "$FT/tests/words.test.sh"
printf '#!/usr/bin/env bash\nSRC=.\n. "$SRC/scripts/parted.sh"\nparted\n' > "$FT/tests/cycle.test.sh"
cat > "$FT/CLAUDE.md" <<'EOF'
# c

## Commands

| Purpose | Command |
|---|---|
| Shell | `git ls-files '*.sh' \| xargs -n1 bash -n` |
| Ship (round-only) | `bash tests/ship.test.sh --all` |
| Ship | `bash tests/ship.test.sh` |
| Cycle | `bash tests/cycle.test.sh --part <topic>` |
| Words | `bash tests/words.test.sh` |
EOF
ftstory() { # ftstory <file> <id> <status> <title> <files lines> <verification lines>
  printf -- '---\nstory: %s\nstatus: %s\nreturned:\nwave: 1\n---\n\n# %s\n\n## Goal\nx\n\n## Files\n%b\n## Non-goals\n- scripts/tails.sh is named here only\n\n## Verification\n%b\n## Implementation notes\n<!-- n -->\n' \
    "$2" "$3" "$4" "$5" "$6" > "$FT/docs/specs/demo/$1"
}
SHELLROW="\`git ls-files '*.sh' | xargs -n1 bash -n\`\n"
ftstory demo-01.md demo-01 todo "Tails" '- scripts/tails.sh\n' "$SHELLROW"
ftstory demo-02.md demo-02 todo "Parted" '- scripts/parted.sh\n' "$SHELLROW"
ftstory demo-03.md demo-03 todo "Listed" '- scripts/tails.sh\n- `docs/*.md`\n- tests/ship.test.sh\n' '`bash tests/ship.test.sh`\n'
ftstory demo-04.md demo-04 done "Done" '- scripts/tails.sh\n' "$SHELLROW"
ftstory demo-05.md demo-05 todo "Repair round 1" '- scripts/tails.sh\n' "$SHELLROW"
(cd "$FT" && git init -q && git -c core.autocrlf=false add -A) || { echo "::error::cannot init $FT"; exit 1; }
for s in 01 02 03 04 05; do cp "$FT/docs/specs/demo/demo-$s.md" "$T/ft-before-$s.md"; done
(cd "$FT" && bash "$SM" --fill-tests docs/specs/demo) > "$T/ft1.out" 2>&1; RC=$?
D1="$FT/docs/specs/demo/demo-01.md"
sect() { awk -v s="## $2" '$0==s{on=1;next} /^## /{on=0} on' "$1"; } # sect <story> <heading> - the section's lines
sect "$D1" Files > "$T/ft-f1"; sect "$D1" Verification > "$T/ft-v1"
expect "a test that mentions a story file joins its lists (## Files)" "- tests/ship.test.sh" "$T/ft-f1"
expect "a test that mentions a story file joins its lists (## Verification row)" '`bash tests/ship.test.sh`' "$T/ft-v1"
expect_absent "fill-tests: a round-only cell is never the row" "--all" "$D1"
expect_absent "fill-tests: a textual hit is never added" "tests/words.test.sh" "$D1"
got="$(diff "$T/ft-before-01.md" "$D1" | grep '^[<>]' | tr '\n' '|')"
expect_eq "fill-tests: only the two lines are added, nothing else moves" '> - tests/ship.test.sh|> `bash tests/ship.test.sh`|' "$got"
expect_eq "fill-tests: a parted suite left unsettled exits 1" "1" "$RC"
expect "fill-tests: a parted suite prints a pick line" "symbol-map: demo-02: pick a row for tests/cycle.test.sh (bash tests/cycle.test.sh --part <topic>)" "$T/ft1.out"
sect "$FT/docs/specs/demo/demo-02.md" Files > "$T/ft-f2"
expect "fill-tests: the parted suite still joins ## Files" "- tests/cycle.test.sh" "$T/ft-f2"
expect_absent "fill-tests: a part is never guessed" "--part" "$FT/docs/specs/demo/demo-02.md"
for s in 03 04 05; do
  if cmp -s "$T/ft-before-$s.md" "$FT/docs/specs/demo/demo-$s.md"; then ok "fill-tests: demo-$s is unchanged"
  else bad "fill-tests: demo-$s changed:"; diff "$T/ft-before-$s.md" "$FT/docs/specs/demo/demo-$s.md" | sed 's/^/        /'; fi
done
for s in 01 02 03 04 05; do cp "$FT/docs/specs/demo/demo-$s.md" "$T/ft-mid-$s.md"; done
(cd "$FT" && bash "$SM" --fill-tests docs/specs/demo) > "$T/ft2.out" 2>&1; RC=$?
same=1; for s in 01 02 03 04 05; do cmp -s "$T/ft-mid-$s.md" "$FT/docs/specs/demo/demo-$s.md" || same=0; done
expect_eq "fill-tests: a second run changes no byte" "1" "$same"
expect_eq "fill-tests: and still exits 1 on the pick" "1" "$RC"
printf '`bash tests/cycle.test.sh --part parted`\n' > "$T/ft-row"
awk -v r="$(cat "$T/ft-row")" '{print} $0=="## Verification"{print r}' "$FT/docs/specs/demo/demo-02.md" > "$T/ft-02" \
  && cp "$T/ft-02" "$FT/docs/specs/demo/demo-02.md"
(cd "$FT" && bash "$SM" --fill-tests docs/specs/demo) > "$T/ft3.out" 2>&1; RC=$?
expect_eq "fill-tests: every listed test with a row exits 0" "0" "$RC"
expect_absent "fill-tests: a settled pick prints no pick line" "pick a row" "$T/ft3.out"
FV="$T/ftv"; cp -r "$FT" "$FV"
for s in 01 02 03 04 05; do cp "$T/ft-before-$s.md" "$FV/docs/specs/demo/demo-$s.md"; done
sed 's/`bash tests\/ship.test.sh`/`bash tests\/ship.test.sh --fast`/' "$FT/CLAUDE.md" > "$FV/CLAUDE.vulyk.md"
(cd "$FV" && bash "$SM" --fill-tests "$FV/docs/specs/demo") > /dev/null 2>&1
expect "fill-tests: CLAUDE.vulyk.md is the constitution when present" '`bash tests/ship.test.sh --fast`' "$FV/docs/specs/demo/demo-01.md"
(cd "$FT" && bash "$SM" --fill-tests) > /dev/null 2>&1; RC=$?
expect_eq "fill-tests: no spec dir exits 2" "2" "$RC"
(cd "$FT" && bash "$SM" --fill-tests docs/specs/nope) > /dev/null 2>&1; RC=$?
expect_eq "fill-tests: a missing spec dir exits 2" "2" "$RC"
awk '/^7\. Check\./{on=1} /^8\. /{on=0} on' "$SRC/.claude/commands/vulyk-plan.md" | tr -d '\r' > "$T/ft-step7.md"
expect "fill-tests: /vulyk-plan step 7 runs it" "bash scripts/symbol-map.sh --fill-tests docs/specs/<slug>" "$T/ft-step7.md"
fl="$(grep -n -- '--fill-tests' "$T/ft-step7.md" | head -n1 | cut -d: -f1)"; wl="$(grep -n 'wave-check.sh' "$T/ft-step7.md" | head -n1 | cut -d: -f1)"
if [ -n "$fl" ] && [ -n "$wl" ] && [ "$fl" -le "$wl" ]; then ok "fill-tests: step 7 runs it before wave-check.sh"
else bad "fill-tests: step 7 runs it before wave-check.sh (fill at '${fl}', wave-check at '${wl}')"; fi
expect "fill-tests: queen-planner names the step" "--fill-tests" "$SRC/.claude/agents/queen-planner.md"

# narrow-repair-1115-06 (round 1, ask 5): a test that runs a script (`bash <path>`, the copy-and-run form this repo's
# suites use) is an `exact` hit, and one that runs its bash wrapper is exact for the .py the wrapper runs; a test
# that only reads the path stays textual. (Ask 8) A fenced `## Files` is never read by --story or --fill-tests.
echo "--- bash-run scripts, fenced sections"
RS="$T/rs"; mkdir -p "$RS/scripts" "$RS/tests" "$RS/docs/specs/demo"
printf '#!/usr/bin/env bash\necho tool\n' > "$RS/scripts/tool.sh"
printf '#!/usr/bin/env bash\nexec python3 "$(dirname "$0")/core.py" "$@"\n' > "$RS/scripts/wrap.sh"
printf 'print("core")\n' > "$RS/scripts/core.py"
printf '#!/usr/bin/env bash\nSRC="$(cd "$(dirname "$0")/.." && pwd)"\nT="$(mktemp -d)"; cd "$T" || exit 1\nmkdir scripts && cp "$SRC"/scripts/tool.sh scripts/\nrun() { bash scripts/tool.sh; }\nrun\n' > "$RS/tests/tool.test.sh"
printf '#!/usr/bin/env bash\ngrep -q tool scripts/tool.sh && cat scripts/tool.sh\n' > "$RS/tests/peek.test.sh"
printf '#!/usr/bin/env bash\nSRC="$(cd "$(dirname "$0")/.." && pwd)"\nbash "$SRC/scripts/wrap.sh"\n' > "$RS/tests/wrap.test.sh"
cat > "$RS/CLAUDE.md" <<'EOF'
# c

## Commands

| Purpose | Command |
|---|---|
| Tool | `bash tests/tool.test.sh` |
| Wrap | `bash tests/wrap.test.sh` |
EOF
printf -- '---\nstory: demo-01\nstatus: todo\nreturned:\nwave: 1\n---\n\n# Fenced\n\n## Goal\nAn example story, quoted:\n```\n## Files\n- scripts/wrap.sh\n```\n\n## Files\n- scripts/tool.sh\n\n## Verification\n`true`\n\n## Implementation notes\n````\n```\n## Files\n- scripts/core.py\n```\n````\n' > "$RS/docs/specs/demo/demo-01.md"
(cd "$RS" && git init -q && git -c core.autocrlf=false add -A) || { echo "::error::cannot init $RS"; exit 1; }
(cd "$RS" && bash "$SM" --exact scripts/tool.sh) > "$T/rs-tool.out" 2>&1
expect_in "a test that copies and runs a script is exact" "$T/rs-tool.out" tests "  exact    tests/tool.test.sh"
expect_absent "a test that only reads the path is never exact" "exact    tests/peek.test.sh" "$T/rs-tool.out"
(cd "$RS" && bash "$SM" scripts/core.py) > "$T/rs-core.out" 2>&1
expect_in "a test running the bash wrapper of a .py is exact for the .py, via named" "$T/rs-core.out" tests "  exact    tests/wrap.test.sh (via scripts/wrap.sh)"
(cd "$RS" && bash "$SM" --story docs/specs/demo/demo-01.md) > "$T/rs-story.out" 2>&1
expect_eq "--story reads only the ## Files outside fences" "## scripts/tool.sh" "$(grep '^## ' "$T/rs-story.out" | tr '\n' '|' | sed 's/|$//')"
cp "$RS/docs/specs/demo/demo-01.md" "$T/rs-before.md"
(cd "$RS" && bash "$SM" --fill-tests docs/specs/demo) > "$T/rs-fill.out" 2>&1
got="$(diff "$T/rs-before.md" "$RS/docs/specs/demo/demo-01.md" | grep '^[<>]' | tr '\n' '|')"
expect_eq "fill-tests: a copy-and-run test joins the real ## Files and ## Verification, no fenced line moves" \
  '> - tests/tool.test.sh|> `bash tests/tool.test.sh`|' "$got"

# tails-1115-12 (narrow-repair-1115 round 2, ask 5 and the review minors): a direct call written inside a quoted
# command substitution is exact (the original case, `out="$(bash scripts/trace-check.sh x)"`); neighbours: backticks
# are exact, a single-quoted command is data and stays textual, a variable path keeps its answer. A test that only
# sources lib.sh is not an exact test of every script lib.sh runs; one that calls the wrapping function, or runs the
# script itself, is.
echo "--- quoted command substitution, sourced wrappers"
QS="$T/qs"; mkdir -p "$QS/scripts" "$QS/tests" "$QS/docs/specs/demo"
printf '#!/usr/bin/env bash\necho tc\n' > "$QS/scripts/tc.sh"
cat > "$QS/tests/dq.test.sh" <<'EOF'
#!/usr/bin/env bash
out="$(bash scripts/tc.sh x)"
EOF
cat > "$QS/tests/bt.test.sh" <<'EOF'
#!/usr/bin/env bash
out=`bash scripts/tc.sh x`
EOF
cat > "$QS/tests/sq.test.sh" <<'EOF'
#!/usr/bin/env bash
cmd='bash scripts/tc.sh x'; echo "$cmd"
EOF
cat > "$QS/tests/var.test.sh" <<'EOF'
#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")/.." && pwd)"
bash "$HERE/scripts/tc.sh"
EOF
cat > "$QS/scripts/lib.sh" <<'EOF'
#!/usr/bin/env bash
cap() { # cap <secs> <cmd>... - the wrapper of cap.py
  python3 "$(dirname "${BASH_SOURCE[0]}")/cap.py" "$@"
}
outer() { cap "$@"; }
other() { echo other; }
EOF
printf 'print("cap")\n' > "$QS/scripts/cap.py"
cat > "$QS/tests/src.test.sh" <<'EOF'
#!/usr/bin/env bash
SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"
other
EOF
cat > "$QS/tests/call.test.sh" <<'EOF'
#!/usr/bin/env bash
SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"
( cap 1 true )
EOF
cat > "$QS/tests/outer.test.sh" <<'EOF'
#!/usr/bin/env bash
SRC="$(cd "$(dirname "$0")/.." && pwd)"
. "$SRC/scripts/lib.sh"
out="$(outer 1 true)"
EOF
cat > "$QS/tests/runpy.test.sh" <<'EOF'
#!/usr/bin/env bash
python3 scripts/cap.py 1 true
EOF
cat > "$QS/CLAUDE.md" <<'EOF'
# c

## Commands

| Purpose | Command |
|---|---|
| Dq | `bash tests/dq.test.sh` |
| Bt | `bash tests/bt.test.sh` |
| Sq | `bash tests/sq.test.sh` |
| Var | `bash tests/var.test.sh` |
EOF
printf -- '---\nstory: demo-01\nstatus: todo\nreturned:\nwave: 1\n---\n\n# Subst\n\n## Goal\nx\n\n## Files\n- scripts/tc.sh\n\n## Verification\n`true`\n\n## Implementation notes\n<!-- n -->\n' > "$QS/docs/specs/demo/demo-01.md"
(cd "$QS" && git init -q && git -c core.autocrlf=false add -A) || { echo "::error::cannot init $QS"; exit 1; }
(cd "$QS" && bash "$SM" --exact scripts/tc.sh) > "$T/qs-tc.out" 2>&1
got="$(grep '^  exact ' "$T/qs-tc.out" | tr -s ' ' | tr '\n' '|')"
expect_eq "a direct call inside a quoted command substitution is exact (backticks too, a variable path kept, a single-quoted command never)" \
  ' exact tests/bt.test.sh| exact tests/dq.test.sh| exact tests/var.test.sh|' "$got"
(cd "$QS" && bash "$SM" scripts/tc.sh) > "$T/qs-tc-all.out" 2>&1
expect_in "a single-quoted command is data: textual" "$T/qs-tc-all.out" tests "  textual  tests/sq.test.sh"
(cd "$QS" && bash "$SM" --exact scripts/cap.py) > "$T/qs-cap.out" 2>&1
got="$(sed -n '/^tests:$/,/^[a-z][a-z ]*:$/p' "$T/qs-cap.out" | grep '^  exact ' | tr -s ' ' | tr '\n' '|')"
expect_eq "only sourcing lib.sh is not a call of what lib.sh runs; calling its wrapping function, or the script, is" \
  ' exact tests/call.test.sh (via scripts/lib.sh)| exact tests/outer.test.sh (via scripts/lib.sh)| exact tests/runpy.test.sh|' "$got"
cp "$QS/docs/specs/demo/demo-01.md" "$T/qs-before.md"
(cd "$QS" && bash "$SM" --fill-tests docs/specs/demo) > "$T/qs-fill.out" 2>&1
got="$(diff "$T/qs-before.md" "$QS/docs/specs/demo/demo-01.md" | grep '^[<>]' | tr '\n' '|')"
expect_eq "fill-tests: a direct call inside a quoted command substitution is exact, its test and row join the story" \
  '> - tests/bt.test.sh|> - tests/dq.test.sh|> - tests/var.test.sh|> `bash tests/bt.test.sh`|> `bash tests/dq.test.sh`|> `bash tests/var.test.sh`|' "$got"
# this repo: the three scripts a test runs only inside "$(...)" each have an exact test; run-capped.py's exact tests
# all call it (run_capped, capped_by or the .py itself)
for s in scripts/trace-check.sh scripts/defects-check.sh scripts/suite-parts-check.sh; do
  n="$(cd "$SRC" && bash "$SM" --exact "$s" 2>/dev/null | sed -n '/^tests:$/,/^[a-z][a-z ]*:$/p' | grep -c '^  exact ')"
  if [ "$n" -ge 1 ]; then ok "this repo: $s has $n exact tests"
  else bad "this repo: a direct call inside a quoted command substitution is exact - $s has no exact test"; fi
done
(cd "$SRC" && bash "$SM" --exact scripts/run-capped.py) 2>/dev/null | sed -n '/^tests:$/,/^[a-z][a-z ]*:$/p' \
  | sed -n 's/^  exact    \([^ ]*\).*/\1/p' > "$T/rc-tests"
nocall=""; while IFS= read -r q; do
  grep -qE '(^|[^A-Za-z0-9_])(run_capped|run_capped_as|capped_by)([^A-Za-z0-9_]|$)|run-capped\.py' "$SRC/$q" || nocall="$nocall $q"
done < "$T/rc-tests"
expect_eq "this repo: every exact test of scripts/run-capped.py calls it ($(grep -c . "$T/rc-tests") listed)" "" "$nocall"

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
# tails-1115-09 (T29): the speed check counts steps, not time - a loaded box slows a run, it adds no step. A shim
# counts every process trace-autopsy.py starts (each git call goes through subprocess.run), then runs it unchanged.
vulyk_python || true
ta_counted() { # ta_counted <brief> -> runs trace-autopsy.py through the counting shim; the count lands in $T/ta-steps
  PYTHONIOENCODING=utf-8 "$VULYK_PY" -c 'import runpy, subprocess, sys
n = [0]; real = subprocess.run
def counted(*a, **k):
    n[0] += 1
    return real(*a, **k)
subprocess.run = counted
steps = sys.argv[2]
sys.argv = [sys.argv[1], sys.argv[3]]
try:
    runpy.run_path(sys.argv[0], run_name="__main__")
finally:
    open(steps, "w").write(str(n[0]))' "$SRC/scripts/trace-autopsy.py" "$T/ta-steps" "$1"
}
bash "$TA" "$R/docs/specs/py/brief.md" > "$T/ta-py.out" 2>&1; RC=$?
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
# The bound: three setup steps (toplevel, ls-files, HEAD) and two per resolved frame (the code line, its log);
# one more step per frame than that is red. Two frames resolve here: at most 7.
rm -f "$T/ta-steps"; ta_counted "$R/docs/specs/py/brief.md" > "$T/ta-count.out" 2>&1
steps="$(tr -d '\r' < "$T/ta-steps" 2>/dev/null)"
if [ -n "$steps" ] && [ "$steps" -le $(( 3 + 2 * 2 )) ] && cmp -s "$T/ta-count.out" "$T/ta-py.out"; then
  ok "trace-autopsy: a two-frame trace takes $steps process starts (<= 3 + 2 per frame), no clock read"
else bad "trace-autopsy: a two-frame trace takes '${steps}' process starts (> 3 + 2 per frame) or its output changed"; fi

# A traceback followed by plain path:N refs: only the traceback's frames turn innermost-first (post-043-tails).
brief pymix <<'EOF2'
Traceback (most recent call last):
  File "/app/src/app/main.py", line 2, in <module>
  File "/app/src/app/core.py", line 3, in calc
    return a / b
ZeroDivisionError: division by zero
see web/server.js:2, then lib/run.sh:2 and lib/m1.py:1
EOF2
bash "$TA" "$R/docs/specs/pymix/brief.md" > /dev/null 2>&1
touch "$R/docs/specs/pymix/autopsy.md"
first="$(grep -m1 -oE '^[a-z][a-z0-9/._-]*:[0-9]+  ' "$R/docs/specs/pymix/autopsy.md" | sed 's/ *$//')"
if [ "$first" = "src/app/core.py:3" ]; then ok "trace-autopsy: the innermost Python frame is the first shown frame before trailing refs"
else bad "trace-autopsy: the innermost Python frame is not the first shown frame (first: '${first}')"; fi
order="$(grep -oE '^(src/app/core.py:3|src/app/main.py:2|web/server.js:2)  ' "$R/docs/specs/pymix/autopsy.md" | tr -d ' ' | paste -sd' ' -)"
expect_eq "trace-autopsy: the outer Python frame, then the trailing refs in written order" "src/app/core.py:3 src/app/main.py:2 web/server.js:2" "$order"
expect "trace-autopsy: the rest of the trailing refs fold into '... N more'" "... 2 more repo frames" "$R/docs/specs/pymix/autopsy.md"

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
order="$(grep -oE '^(lib/run.sh:2|web/server.js:2)  ' "$R/docs/specs/sh/autopsy.md" | tr -d ' ' | paste -sd' ' -)"
expect_eq "trace-autopsy: a brief with no traceback keeps its written frame order" "lib/run.sh:2 web/server.js:2" "$order"

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
