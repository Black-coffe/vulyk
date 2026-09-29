#!/usr/bin/env bash
# The cycle's two deterministic gates, driven through every stage on a synthetic spec.
#
#   Usage: bash tests/cycle.test.sh            # from the VULYK repo root
#
# Builds a throwaway git repo holding one spec and walks it: nothing confirmed -> approved
# -> branch -> stories closed -> blind gate verdict -> owner rejects -> owner accepts ->
# the record is committed (paperwork: still CURRENT) -> a code commit lands (STALE) -> the
# owner looks again -> READY -> --record. Each step asserts what ship-check.sh and
# human-check.sh must say. Exit 1 on the first wrong answer.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then echo "  ok    $label"
  else echo "::error::$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fail=1; : > "$T/failed"; fi
}   # `x | expect` runs in a subshell, where fail=1 is lost - the marker file carries it to the exit
ship()  { bash scripts/ship-check.sh docs/specs/demo; }
hcheck(){ bash scripts/human-check.sh --check docs/specs/demo; }

cd "$T" || exit 1
git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
mkdir -p scripts memory/stats docs/specs/demo .claude
cp "$SRC"/scripts/lib.sh "$SRC"/scripts/ship-check.sh "$SRC"/scripts/human-check.sh "$SRC"/scripts/acceptance-log.sh "$SRC"/scripts/redact.sh "$SRC"/scripts/state.sh scripts/
# shellcheck source=scripts/lib.sh
. scripts/lib.sh   # pack_fingerprint(), used below to build council/human fixture rows
cp "$SRC"/templates/plan.md docs/specs/demo/plan.md
printf -- '---\nstory: demo-01\nspec: demo\nstatus: todo\nwave: 1\n---\n# S1\n' > docs/specs/demo/demo-01-first.md
printf 'v1\n' > app.txt
git add -A && git commit -qm init

echo "stages 01-02: nothing confirmed yet"
ship | expect "no brief is OPEN"                 "01   OPEN"
ship | expect "placeholder Approved is OPEN"     "02   OPEN"
ship | expect "verdict is NOT READY"             "NOT READY"
printf '> build the demo\n' > docs/specs/demo/brief.md
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-05/' docs/specs/demo/plan.md
git add -A && git commit -qm "approve"
ship | expect "brief closes 01"                  "01   ok"
ship | expect "approval closes 02"               "02   ok"
ship | expect "no branch line is OPEN"           "no **Branch:** line"

echo "stage 03: branch and stories"
git checkout -q -b vulyk/demo
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/demo/plan.md
git add -A && git commit -qm "branch"
ship | expect "open story keeps 03 OPEN"         "still open"
sed -i 's/^status: todo/status: done/' docs/specs/demo/demo-01-first.md
git add -A && git commit -qm "story(demo-01): first"
ship | expect "all done closes 03"               "stories 1/1 done"
ship | expect "no verdict keeps 04 OPEN"         "no acceptance verdict"

echo "stage 04: the blind gate"
bash scripts/acceptance-log.sh docs/specs/demo ACCEPTED "works" >/dev/null
git add -A && git commit -qm "acceptance"
ship | expect "acceptance closes 04"             "04   ok"
ship | expect "nobody looked keeps 05 OPEN"      "nobody has looked"
hcheck | expect "--check before any look"        "NO HUMAN CHECK RECORDED"

echo "stage 05: the owner looks"
bash scripts/human-check.sh docs/specs/demo REJECTED "button missing" | expect "rejection is recorded" "REJECTED by Test Owner"
grep -q '^\*\*Checked:\*\* REJECTED' docs/specs/demo/plan.md || { echo "::error::plan.md lacks the Checked line"; fail=1; }
grep -q '^\*\*Checked:\*\* <' docs/specs/demo/plan.md && { echo "::error::placeholder survived the first real line"; fail=1; }
git add -A && git commit -qm "record rejection"
ship | expect "rejection keeps 05 OPEN"          "owner REJECTED"
hcheck | expect "--check reports the rejection"  "REJECTED"
bash scripts/human-check.sh docs/specs/demo ACCEPTED "looks right on staging" >/dev/null
ship | expect "dirty tree is OPEN"               "working tree is not clean"
git add -A && git commit -qm "record owner's check"
hcheck | expect "the record commit is paperwork, still CURRENT" "CURRENT"
mkdir -p docs/specs/demo/council/round-1
printf 'head=%s\npack=%s\nopened=2026-01-01T00:00:00Z\ncourt=/tmp/court\nceiling=3\n' \
  "$(git rev-parse --short HEAD)" "$(pack_fingerprint docs/specs/demo)" > docs/specs/demo/council/round-1/ROUND
git add -A && git commit -qm "council: open round 1"
hcheck | expect "a council/ paperwork commit stays CURRENT" "CURRENT"
ship | expect "05 closes on the record commit"   "05   ok"
ship | expect "READY on first full pass"         "READY."
printf 'v2\n' > app.txt
git add -A && git commit -qm "a code change after the look"
hcheck | expect "a code commit after the look is STALE" "STALE (commit)"
ship | expect "stale check keeps 05 OPEN"        "STALE (commit)"
bash scripts/human-check.sh docs/specs/demo ACCEPTED "looked again at v2" >/dev/null
git add -A && git commit -qm "record second check"
hcheck | expect "second look is CURRENT"         "CURRENT"
ship | expect "READY again"                      "READY."

echo "stage 06: record the ship"
bash scripts/ship-check.sh --record docs/specs/demo v1.2.3 "tag pushed, https://example.test" | expect "record writes" "shipped as v1.2.3"
grep -q '^\*\*Shipped:\*\* v1.2.3' docs/specs/demo/plan.md || { echo "::error::plan.md lacks the Shipped line"; fail=1; }
grep -q '"version":"v1.2.3"' memory/stats/ship.jsonl || { echo "::error::ship.jsonl lacks the row"; fail=1; }
git add -A && git commit -qm "record ship"
ship | expect "already shipped is shown"         "06   done"
ship | expect "still READY after the ship record" "READY."
bash scripts/state.sh >/dev/null
grep -q '"stage": "06-shipped"' .claude/state.json || { echo "::error::state.sh did not derive stage 06-shipped:"; cat .claude/state.json; fail=1; }
echo "  ok    state.sh derives the stage"

# A stale pack (a story cut after the look) reopens 04 and 05 both.
printf -- '---\nstory: demo-02\nspec: demo\nstatus: done\nwave: 2\n---\n# S2\n' > docs/specs/demo/demo-02-repair.md
git add -A && git commit -qm "story(demo-02): repair"
ship | expect "new story stales acceptance"      "STALE - given against pack"
ship | expect "new story stales the check"       "STALE (pack)"

echo "council row closes 04+05 together (ADR-001 D4); **Checked:** still overrides"
mkdir -p docs/specs/council-demo
printf '> build the council demo\n' > docs/specs/council-demo/brief.md
cp "$SRC"/templates/plan.md docs/specs/council-demo/plan.md
sed -i 's/^\*\*Briefed:\*\* <.*/**Briefed:** via grill, owner, 2026-01-01/' docs/specs/council-demo/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/council-demo/plan.md
printf -- '---\nstory: council-demo-01\nspec: council-demo\nstatus: done\nwave: 1\n---\n# S1\n' > docs/specs/council-demo/council-demo-01-first.md
git add -A && git commit -qm "council-demo: setup"
C0="$(git rev-parse --short HEAD)"
PACK0="$(pack_fingerprint docs/specs/council-demo)"
shipc() { bash scripts/ship-check.sh docs/specs/council-demo; }
council_row() { # council_row <verdict> <round> <ts>
  printf '{"ts":"%s","spec":"council-demo","round":%s,"verdict":"%s","head":"%s","pack":"%s","asks":1,"red":[],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"GREEN","haiku_model":"sonnet","sonnet":"GREEN","sonnet_model":"sonnet","opus":"GREEN","opus_model":"opus","attempts":1,"escalate":null,"note":""}\n' \
    "$3" "$2" "$1" "$C0" "$PACK0" >> memory/stats/council.jsonl
}
human_row() { # human_row <verdict> <ts>
  printf '{"ts":"%s","spec":"council-demo","verdict":"%s","by":"Test Owner","head":"%s","pack":"%s","note":""}\n' \
    "$2" "$1" "$C0" "$PACK0" >> memory/stats/human.jsonl
}

council_row GREEN 1 "2026-01-01T00:00:01Z"
git add -A && git commit -qm "council: round 1 GREEN"
shipc | expect "Briefed + GREEN council row is READY, no Approved/Checked needed" "READY."

council_row RED 2 "2026-01-01T00:00:02Z"
git add -A && git commit -qm "council: round 2 RED"
shipc | expect "a RED council row is NOT READY"  "NOT READY"

human_row ACCEPTED "2026-01-01T00:00:03Z"
git add -A && git commit -qm "record: Checked ACCEPTED over RED"
shipc | expect "Checked ACCEPTED newer than a RED row overrides to READY" "READY."

council_row GREEN 3 "2026-01-01T00:00:04Z"
git add -A && git commit -qm "council: round 3 GREEN"

human_row REJECTED "2026-01-01T00:00:05Z"
git add -A && git commit -qm "record: Checked REJECTED over GREEN"
shipc | expect "Checked REJECTED newer than a GREEN row overrides to NOT READY" "NOT READY"

echo "a same-second override outranks the row it overrides (m-4): >= on ts, not >"
council_row GREEN 4 "2026-01-01T00:00:06Z"
git add -A && git commit -qm "council: round 4 GREEN"
human_row REJECTED "2026-01-01T00:00:06Z"
git add -A && git commit -qm "record: Checked REJECTED same second as GREEN"
shipc | expect "Checked REJECTED same second as GREEN outranks it to NOT READY" "NOT READY"

council_row RED 5 "2026-01-01T00:00:07Z"
git add -A && git commit -qm "council: round 5 RED"
human_row ACCEPTED "2026-01-01T00:00:07Z"
git add -A && git commit -qm "record: Checked ACCEPTED same second as RED"
shipc | expect "Checked ACCEPTED same second as RED outranks it to READY" "READY."

echo "the paperwork whitelist is anchored to docs/specs/*/ (R23/m-2): a commit under src/council/ or a bare src/journal.md is never paperwork, even though it shares the names"
mkdir -p docs/specs/anchor-demo
cp "$SRC"/templates/plan.md docs/specs/anchor-demo/plan.md
printf '> build the anchor demo\n' > docs/specs/anchor-demo/brief.md
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/anchor-demo/plan.md
printf -- '---\nstory: anchor-demo-01\nspec: anchor-demo\nstatus: done\nwave: 1\n---\n# S1\n' > docs/specs/anchor-demo/anchor-demo-01-first.md
git add -A && git commit -qm "anchor-demo: setup" >/dev/null
bash scripts/human-check.sh docs/specs/anchor-demo ACCEPTED "looks right" >/dev/null
git add -A && git commit -qm "anchor-demo: record check" >/dev/null
bash scripts/human-check.sh --check docs/specs/anchor-demo | expect "CURRENT right after the recorded check" "CURRENT"
mkdir -p src/council
printf 'not a spec file\n' > src/council/x
printf 'not a spec journal either\n' > src/journal.md
git add -A && git commit -qm "a real code change under src/council/ and src/journal.md - not paperwork" >/dev/null
bash scripts/human-check.sh --check docs/specs/anchor-demo | expect "src/council/x and src/journal.md are not paperwork -> STALE" "STALE"

echo "story 09: memory/stats/anomalies.jsonl (the anomaly-scan Stop hook's log) rides close-story --commit, ship-check stage 03 passes a hook-only-dirty tree, scope-check drops it from out_of_scope - no separate ship-check suite exists, so these cases live here"
cp "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/scope-check.sh scripts/
cat >> CLAUDE.md <<'EOF'

## Commands

| Purpose | Command |
|---|---|
| Trivial pass | `true` |
EOF
git add -A && git commit -qm "add cycle.sh + a ## Commands cell for the hook-log tests" >/dev/null

mkdir -p docs/specs/hooklog
cp "$SRC"/templates/plan.md docs/specs/hooklog/plan.md
printf '> build the hooklog demo\n' > docs/specs/hooklog/brief.md
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/hooklog/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/hooklog#' docs/specs/hooklog/plan.md
printf 'v1\n' > hook-app.txt
cat > docs/specs/hooklog/hooklog-01-first.md <<'EOF'
---
story: hooklog-01
spec: hooklog
status: in-progress
returned: DONE
wave: 1
---
# Hook-log fixture

## Files
- hook-app.txt

## Verification
`true`
EOF
git add -A && git commit -qm "hooklog: setup" >/dev/null

# An uncommitted row, as anomaly-scan.sh's Stop hook would leave it - untracked, undeclared.
printf '{"ts":"x"}\n' >> memory/stats/anomalies.jsonl

out="$(bash scripts/cycle.sh close-story docs/specs/hooklog/hooklog-01-first.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    close-story --commit exits 0 with an uncommitted anomalies.jsonl row" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -z "$(git status --porcelain -- memory/stats/anomalies.jsonl)" ] && echo "  ok    anomalies.jsonl is clean after close-story --commit" \
  || { echo "::error::anomalies.jsonl still dirty: $(git status --porcelain -- memory/stats/anomalies.jsonl)"; fail=1; }
git show --stat -1 | grep -qF "memory/stats/anomalies.jsonl" && echo "  ok    close-story's own commit touches anomalies.jsonl" \
  || { echo "::error::the close-story commit did not touch anomalies.jsonl: $(git show --stat -1)"; fail=1; }
grep -F '"story":"hooklog-01-first"' memory/stats/scope.jsonl | tail -1 | grep -qF '"out_of_scope":0' \
  && echo "  ok    scope-check: the hook-written log dirty but undeclared does not count as out_of_scope" \
  || { echo "::error::scope.jsonl row: $(grep -F '"story":"hooklog-01-first"' memory/stats/scope.jsonl | tail -1)"; fail=1; }

echo "commit_paperwork: a verb still commits cleanly when memory/stats/anomalies.jsonl does not exist on disk yet (git add -A -- <path> <missing-path> fails the whole pathspec, not just the missing one)"
git rm -q --cached memory/stats/anomalies.jsonl >/dev/null 2>&1
rm -f memory/stats/anomalies.jsonl
git add -A && git commit -qm "test: drop anomalies.jsonl - no Stop hook has fired yet" >/dev/null
mkdir -p docs/specs/nolog
cp "$SRC"/templates/plan.md docs/specs/nolog/plan.md
printf '> build the nolog demo\n\n## Asks\n1. one ask\n' > docs/specs/nolog/brief.md
out="$(bash scripts/cycle.sh briefed docs/specs/nolog --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    briefed --commit succeeds with no anomalies.jsonl on disk" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^\*\*Briefed:\*\*' docs/specs/nolog/plan.md && echo "  ok    the Briefed line landed (the commit was not skipped)" \
  || { echo "::error::plan.md: $(cat docs/specs/nolog/plan.md)"; fail=1; }

shiph() { bash scripts/ship-check.sh docs/specs/hooklog; }
echo "ship-check stage 03 (no separate ship-check suite - case here): a tree dirty only in hook-written memory/stats/ files is reported clean, not blocked"
printf '{"ts":"y"}\n' >> memory/stats/anomalies.jsonl
shiph | expect "hook log alone -> 03 clean, names the pending path" "clean (hook-written stats pending: memory/stats/anomalies.jsonl)"

echo "ship-check stage 03: a hook-written path plus a real dirty file still blocks, naming neither"
printf 'v2\n' >> hook-app.txt
shiph | expect "hook log + real code dirt -> 03 still not clean" "working tree is not clean"
git checkout -- hook-app.txt

echo "skills-json-exempt: scope-check still counts skills.json; ship-check stage 03 passes it like the anomaly log"
printf '{"n":1}\n' > memory/stats/skills.json
bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md | grep -qF 'memory/stats/skills.json' \
  && echo "  ok    scope-check: skills.json dirty and undeclared is listed as out_of_scope" \
  || { echo "::error::scope-check output: $(bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md)"; fail=1; }
git checkout -- memory/stats/scope.jsonl   # scope-check logs its run; that log is not this case's dirt
rm -f memory/stats/anomalies.jsonl; git checkout -- memory/stats/anomalies.jsonl 2>/dev/null
[ "$(git status --porcelain)" = "?? memory/stats/skills.json" ] && echo "  ok    precondition: skills.json is the only dirty path" \
  || { echo "::error::precondition: dirty paths are $(git status --porcelain | tr '\n' ' ')"; fail=1; }
shiph | expect "skills.json alone dirty -> 03 clean, names it" "clean (hook-written stats pending: memory/stats/skills.json)"
printf '{"ts":"z"}\n' >> memory/stats/anomalies.jsonl
shiph | expect "anomaly log + skills.json dirty -> 03 clean, names both" "memory/stats/anomalies.jsonl, memory/stats/skills.json"
printf 'v3\n' >> hook-app.txt
shiph | expect "skills.json + real code dirt -> 03 still not clean" "working tree is not clean"
git checkout -- hook-app.txt
rm -f memory/stats/skills.json

echo "story 12: council.jsonl alone dirty also blocks stage 03 - only anomalies.jsonl is the pass-through path"
printf '{"n":1}\n' > memory/stats/council.jsonl
shiph | expect "council.jsonl alone dirty -> 03 not clean" "working tree is not clean"
rm -f memory/stats/council.jsonl

# --- 0.18 (ADR-013 D4/D5): the three gate scripts -------------------------------------------
cp "$SRC"/scripts/wave-check.sh "$SRC"/scripts/trace-check.sh scripts/
git add -A && git commit -qm "0.18 gates: wave-check + trace-check, a clean tree to measure from" >/dev/null

echo "ADR-013 D5: scope-check with no range drops a not-done sibling's declared files and its story file; a done sibling's still count; a range drops nothing"
mkdir -p docs/specs/sib src/sib
printf 'a\n' > src/sib/a.txt; printf 'b\n' > src/sib/b.txt; printf 'c\n' > src/sib/c.txt
sib_story() { # sib_story <nn> <file> <status>
  printf -- '---\nstory: sib-%s\nspec: sib\nstatus: %s\nwave: 1\n---\n# S%s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$3" "$1" "$2" > "docs/specs/sib/sib-$1-s.md"
}
sib_story 01 src/sib/a.txt todo
sib_story 02 src/sib/b.txt todo
sib_story 03 src/sib/c.txt done
git add -A && git commit -qm "sib: three stories, 01 and 02 in flight" >/dev/null
printf 'a2\n' > src/sib/a.txt; printf 'b2\n' > src/sib/b.txt; printf 'c2\n' > src/sib/c.txt
sed -i 's/^status: todo/status: todo\nreturned: DONE/' docs/specs/sib/sib-02-s.md
out="$(bash scripts/scope-check.sh docs/specs/sib/sib-01-s.md)"
printf '%s' "$out" | expect "sibling 02 (todo) drops out: changed 2 (a + the done sibling's c), out of scope 1" "declared 1, changed 2, out of scope 1"
printf '%s' "$out" | expect "the done sibling's file still counts" "! src/sib/c.txt"
printf '%s' "$out" | grep -qF 'b.txt' && { echo "::error::a todo sibling's declared file was counted: $out"; fail=1; } \
  || echo "  ok    the todo sibling's declared file is not counted"
printf '%s' "$out" | grep -qF 'sib-02-s.md' && { echo "::error::a todo sibling's own story file was counted: $out"; fail=1; } \
  || echo "  ok    the todo sibling's own story file is not counted"
bash scripts/scope-check.sh docs/specs/sib/sib-01-s.md HEAD | expect "an explicit range excludes nothing - the sibling's file counts" "! src/sib/b.txt"
git checkout -q -- src/sib docs/specs/sib
git add -A && git commit -qm "sib: scope rows" >/dev/null

echo "ADR-013 D5: wave-check reports every ## Verification segment that is not a ## Commands cell, and nothing else"
mkdir -p docs/specs/wcell
wcell_story() { # wcell_story <nn> <wave> <verification-block>
  printf -- '---\nstory: wcell-%s\nspec: wcell\nstatus: todo\nwave: %s\n---\n# W%s\n\n## Files\n- app.txt\n\n## Verification\n%s\n' \
    "$1" "$2" "$1" "$3" > "docs/specs/wcell/wcell-$1-w.md"
}
wcell_story 01 1 '`true`'
wcell_story 02 2 '`true && no-such-cell`'
wcell_story 03 3 'none — reviewed by lead-review'
wcell_story 04 4 "repeat: 2
\`sh -c 'not a cell'\`"
out="$(bash scripts/wave-check.sh docs/specs/wcell)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    wave-check still exits 0 while reporting" || { echo "::error::wave-check exit $ex"; fail=1; }
printf '%s' "$out" | expect "an && segment that is no cell is named" "verify-cell: wcell-02's verification 'no-such-cell' is not a ## Commands cell of CLAUDE.md"
printf '%s' "$out" | expect "a whole line that is no cell is named" "verify-cell: wcell-04's verification 'sh -c 'not a cell''"
n="$(printf '%s\n' "$out" | grep -c 'verify-cell:')"
[ "$n" -eq 2 ] && echo "  ok    exactly two verify-cell reports (a cell, 'none — reviewed by lead-review' and repeat: pass)" \
  || { echo "::error::verify-cell count $n: $out"; fail=1; }

echo "ADR-013 D1: a CLAUDE.vulyk.md sidecar is the constitution wave-check reads, not CLAUDE.md"
cat > CLAUDE.vulyk.md <<'EOF'
# Sidecar constitution

## Commands

| Purpose | Command |
|---|---|
| Sidecar-only | `no-such-cell` |
EOF
out="$(bash scripts/wave-check.sh docs/specs/wcell)"
printf '%s' "$out" | expect "with a sidecar, CLAUDE.md's own cell 'true' is reported against CLAUDE.vulyk.md" "verify-cell: wcell-01's verification 'true' is not a ## Commands cell of CLAUDE.vulyk.md"
printf '%s' "$out" | grep -qF "'no-such-cell'" && { echo "::error::the sidecar's own cell was reported: $out"; fail=1; } \
  || echo "  ok    the sidecar's own cell passes"
rm -f CLAUDE.vulyk.md
git add -A && git commit -qm "wcell fixture" >/dev/null

echo "ADR-013 D4: trace-check accepts a quote equal to a whole ## Asks item (digits, dot, text, whitespace-normalized), and only that"
mkdir -p docs/specs/trc
printf '# trc\n\n## Request\n> build the trace demo\n\n## Asks\n1. the first ask works\n2. the second   ask works\n' > docs/specs/trc/brief.md
trc_story() { # trc_story <nn> <quote>
  printf -- '---\nstory: trc-%s\nspec: trc\nstatus: todo\nwave: 1\n---\n# T%s\n\n## Requirements\n> %s\n' "$1" "$1" "$2" > "docs/specs/trc/trc-$1-t.md"
}
trc_story 01 '2.  the second ask works'
trc_story 02 '2. the second'
trc_story 03 '3. an ask the brief never had'
out="$(bash scripts/trace-check.sh docs/specs/trc)"
printf '%s' "$out" | expect "two quotes unfound: a fragment of an item and an item the brief lacks" "backward: 2 unfound"
printf '%s' "$out" | grep -qF 'trc-01-t.md' && { echo "::error::a whole ask item was not accepted: $out"; fail=1; } \
  || echo "  ok    '> 2. the second ask works' traces to ## Asks item 2"
printf '%s' "$out" | expect "a fragment of an item is not an item" "trc-02-t.md: quote found in NEITHER"

echo "0.19 C: blocked_by manual:<id> - a hand step stops the wave until manual-done records it; no later wave is built past it"
mkdir -p docs/specs/man
cp "$SRC"/templates/plan.md docs/specs/man/plan.md
printf '> build the manual demo\n' > docs/specs/man/brief.md
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/man/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/man#' docs/specs/man/plan.md
man_story() { # man_story <nn> <status> <wave> <blocked_by>
  printf -- '---\nstory: man-%s\nspec: man\nstatus: %s\nwave: %s\nblocked_by: %s   # a comment\n---\n# M%s\n\n## Files\n- app.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$3" "$4" "$1" > "docs/specs/man/man-$1-m.md"
}
man_story 01 done 1 '[]'
man_story 02 todo 2 '[man-01, manual:music]'
man_story 03 todo 3 '[]'
git add -A && git commit -qm "man fixture" >/dev/null
st="$(bash scripts/cycle.sh status docs/specs/man --json)"
printf '%s' "$st" | expect "a todo waiting on an unrecorded hand step -> next manual:music" '"next":"manual:music"'
printf '%s' "$st" | expect "status lists the step under manual, after seats" '"seats":[],"manual":["music"]}'
printf '%s' "$st" | expect "the later wave's ready story is not built past the manual stop" '"wave":null,"wave_stories":[]'
out="$(bash scripts/cycle.sh advance docs/specs/man 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    advance stops at the hand step with exit 0" || { echo "::error::advance exit $ex: $out"; fail=1; }
printf '%s' "$out" | expect "advance names the step and the exact command" "waiting on manual step 'music' - do it, then: bash scripts/cycle.sh manual-done docs/specs/man music"
printf '%s' "$out" | tail -1 | expect "advance's JSON line carries next manual:music" '"ok":true,"verb":"advance","exit":0,"next":"manual:music"'
for bad in '../x' 'a/b' '..' ''; do
  out="$(bash scripts/cycle.sh manual-done docs/specs/man "$bad" 2>&1)"; ex=$?
  [ "$ex" -eq 1 ] && printf '%s' "$out" | tail -1 | grep -qF '"ok":false,"verb":"manual-done"' \
    && echo "  ok    manual-done refuses the id '$bad'" || { echo "::error::manual-done '$bad' exit $ex: $out"; fail=1; }
done
[ -e x ] || [ -e docs/specs/man/manual ] && { echo "::error::a refused id wrote something"; fail=1; } || echo "  ok    a refused id writes nothing"
out="$(bash scripts/cycle.sh manual-done docs/specs/man music bought the track 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(printf '%s\n' "$out" | wc -l)" -eq 1 ] && echo "  ok    manual-done exits 0 with one line" || { echo "::error::manual-done exit $ex: $out"; fail=1; }
printf '%s' "$out" | expect "manual-done's line carries the new next: the wave is ready" '"next":"build:2"'
grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z bought the track$' docs/specs/man/manual/music \
  && echo "  ok    the step file holds a timestamp and the note" || { echo "::error::step file: $(cat docs/specs/man/manual/music)"; fail=1; }
[ -z "$(git status --porcelain -- docs/specs/man/manual)" ] && git log -1 --format=%s | grep -qF "manual(man): music done" \
  && echo "  ok    manual-done commits its file" || { echo "::error::not committed: $(git status --porcelain) / $(git log -1 --format=%s)"; fail=1; }
before="$(cat docs/specs/man/manual/music)"; head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh manual-done docs/specs/man music again 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(cat docs/specs/man/manual/music)" = "$before" ] && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    manual-done is idempotent: a second call changes nothing" || { echo "::error::second manual-done exit $ex: $out"; fail=1; }
bash scripts/cycle.sh status docs/specs/man --json | expect "after manual-done the waiting story is dispatchable" '"file":"docs/specs/man/man-02-m.md"'
out="$(bash scripts/wave-check.sh docs/specs/man)"
printf '%s' "$out" | grep -qF "dangling" && { echo "::error::wave-check called manual:music dangling: $out"; fail=1; } \
  || echo "  ok    wave-check accepts manual:music as a blocker"
printf '%s' "$out" | expect "wave-check lists the declared hand step and its state" "wave-check: manual step 'music' (done)"
man_story 04 todo 4 '[manual:../x]'
bash scripts/wave-check.sh docs/specs/man | expect "wave-check reports a manual id with .." "manual:    man-04 is blocked_by 'manual:../x'"
git add -A && git commit -qm "man: done" >/dev/null

[ -e "$T/failed" ] && fail=1
exit $fail
