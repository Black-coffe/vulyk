#!/usr/bin/env bash
# The cycle's two deterministic gates, driven through every stage on a synthetic spec.
#
#   Usage: bash tests/cycle.test.sh                  # from the VULYK repo root, every part
#          bash tests/cycle.test.sh --part <name>    # one topic on its own fresh fixture repo
#          bash tests/cycle.test.sh --list-parts     # the part names, one per line
#
# Builds a throwaway git repo holding one spec and walks it: nothing confirmed -> approved
# -> branch -> stories closed -> blind gate verdict -> owner rejects -> owner accepts ->
# the record is committed (paperwork: still CURRENT) -> a code commit lands (STALE) -> the
# owner looks again -> READY -> --record. Each step asserts what ship-check.sh and
# human-check.sh must say. Exit 1 on the first wrong answer.
set -u
PARTS="ship hooklog gates manual close bsd safety red" # one topic each; every part rebuilds the shared setup below
PART=''
while [ $# -gt 0 ]; do
  case "$1" in
    --list-parts) printf '%s
' $PARTS; exit 0 ;;
    --part)
      PART="${2:-}"; shift
      case " $PARTS " in
        *" $PART "*) ;;
        *) echo "unknown part '$PART' - parts:" >&2; printf '%s
' $PARTS >&2; exit 1 ;;
      esac ;;
    *) echo "usage: bash tests/cycle.test.sh [--part <name>] [--list-parts]" >&2; exit 2 ;;
  esac
  shift
done
part() { [ -z "$PART" ] || [ "$PART" = "$1" ]; } # `if part <name>; then ... fi` wraps each part
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
MARK="$(mktemp -u)"   # failure marker, outside the fixture repo: `git add -A` there must never see it
trap 'rm -rf "$T" "$MARK"' EXIT
fail=0
expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then echo "  ok    $label"
  else echo "::error::$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fail=1; : > "$MARK"; fi
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

if part ship; then # --- part ship: ship-check stages 01-06, council row vs **Checked:**, the paperwork anchor
echo "stages 01-02: nothing confirmed yet"
ship | expect "no brief is OPEN"                 "01   OPEN"
ship | expect "placeholder Approved is OPEN"     "02   OPEN"
ship | expect "verdict is NOT READY"             "NOT READY"
printf '> build the demo\n' > docs/specs/demo/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-05/' docs/specs/demo/plan.md
git add -A && git commit -qm "approve"
ship | expect "brief closes 01"                  "01   ok"
ship | expect "approval closes 02"               "02   ok"
ship | expect "no branch line is OPEN"           "no **Branch:** line"

echo "stage 03: branch and stories"
git checkout -q -b vulyk/demo
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/demo/plan.md
git add -A && git commit -qm "branch"
ship | expect "open story keeps 03 OPEN"         "still open"
sed_inplace 's/^status: todo/status: done/' docs/specs/demo/demo-01-first.md
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
# A study spec whose report quotes a story template in its body: the quoted lines are not a story (post-043-tails).
mkdir -p docs/specs/study1
printf '> study the template\n' > docs/specs/study1/brief.md
printf '# Study report\n\nThe template reads:\n\nstory: quoted-01\nstatus: todo\n' > docs/specs/study1/report.md
bash scripts/state.sh >/dev/null
st_study="$(sed -n '/"spec": "study1"/,/"stage"/p' .claude/state.json | tr -d ' \n')"
case "$st_study" in
  *'"stories":0,'*'"stage":"study"'*) echo "  ok    state.sh lists no story for a study spec quoting story: lines" ;;
  *) echo "::error::state.sh listed a story for a study spec whose report quotes story: lines: ${st_study:-absent}"; fail=1 ;;
esac
rm -rf docs/specs/study1

# A stale pack (a story cut after the look) reopens 04 and 05 both.
printf -- '---\nstory: demo-02\nspec: demo\nstatus: done\nwave: 2\n---\n# S2\n' > docs/specs/demo/demo-02-repair.md
git add -A && git commit -qm "story(demo-02): repair"
ship | expect "new story stales acceptance"      "STALE - given against pack"
ship | expect "new story stales the check"       "STALE (pack)"

echo "council row closes 04+05 together (ADR-001 D4); **Checked:** still overrides"
mkdir -p docs/specs/council-demo
printf '> build the council demo\n' > docs/specs/council-demo/brief.md
cp "$SRC"/templates/plan.md docs/specs/council-demo/plan.md
sed_inplace 's/^\*\*Briefed:\*\* <.*/**Briefed:** via grill, owner, 2026-01-01/' docs/specs/council-demo/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/council-demo/plan.md
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

echo "post-037-tails: an ACCEPTED override over a GREEN row is current only while verdict_stale says so (the 0.37 miss)"
mkdir -p docs/specs/gate-demo
printf '> build the gate demo\n' > docs/specs/gate-demo/brief.md
cp "$SRC"/templates/plan.md docs/specs/gate-demo/plan.md
sed_inplace 's/^\*\*Briefed:\*\* <.*/**Briefed:** via grill, owner, 2026-01-02/' docs/specs/gate-demo/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/gate-demo/plan.md
printf -- '---\nstory: gate-demo-01\nspec: gate-demo\nstatus: done\nwave: 1\n---\n# S1\n' > docs/specs/gate-demo/gate-demo-01-first.md
git add -A && git commit -qm "gate-demo: setup"
shipg() { bash scripts/ship-check.sh docs/specs/gate-demo; }
gate_rows() { # gate_rows <n>: a GREEN council row, then a later ACCEPTED human row, both at HEAD for this pack
  local h p; h="$(git rev-parse --short HEAD)"; p="$(pack_fingerprint docs/specs/gate-demo)"
  printf '{"ts":"2026-01-02T00:00:%s0Z","spec":"gate-demo","round":%s,"verdict":"GREEN","head":"%s","pack":"%s","asks":1,"red":[],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"GREEN","haiku_model":"sonnet","sonnet":"GREEN","sonnet_model":"sonnet","opus":"GREEN","opus_model":"opus","attempts":1,"escalate":null,"note":""}\n' \
    "$1" "$1" "$h" "$p" >> memory/stats/council.jsonl
  printf '{"ts":"2026-01-02T00:00:%s5Z","spec":"gate-demo","verdict":"ACCEPTED","by":"Test Owner","head":"%s","pack":"%s","note":""}\n' \
    "$1" "$h" "$p" >> memory/stats/human.jsonl
  git add -A && git commit -qm "gate-demo: council GREEN + Checked ACCEPTED ($1)"
}
gate_rows 1
shipg | expect "GREEN + newer ACCEPTED at HEAD is READY" "READY."
printf 'v3\n' > app.txt
git add -A && git commit -qm "a code change after the ACCEPTED override"
G="$(shipg)"
printf '%s' "$G" | expect "code after ACCEPTED: stage 05 is OPEN" "05   OPEN"
printf '%s' "$G" | expect "code after ACCEPTED: 05 names STALE (commit)" "STALE (commit)"
printf '%s' "$G" | expect "code after ACCEPTED: NOT READY" "NOT READY"
gate_rows 2
printf '9.9.9\n' > VERSION; printf '# changelog\n' > CHANGELOG.md
git add -A && git commit -qm "release paperwork after the ACCEPTED override"
shipg | expect "VERSION + CHANGELOG.md after ACCEPTED stays READY" "READY."
gate_rows 3
printf -- '---\nstory: gate-demo-02\nspec: gate-demo\nstatus: done\nwave: 2\n---\n# S2\n' > docs/specs/gate-demo/gate-demo-02-repair.md
git add -A && git commit -qm "story(gate-demo-02): repair after the ACCEPTED override"
G="$(shipg)"
printf '%s' "$G" | expect "a new story after ACCEPTED: 05 names STALE (pack)" "STALE (pack)"
printf '%s' "$G" | expect "a new story after ACCEPTED: NOT READY" "NOT READY"

echo "the paperwork whitelist is anchored to docs/specs/*/ (R23/m-2): a commit under src/council/ or a bare src/journal.md is never paperwork, even though it shares the names"
mkdir -p docs/specs/anchor-demo
cp "$SRC"/templates/plan.md docs/specs/anchor-demo/plan.md
printf '> build the anchor demo\n' > docs/specs/anchor-demo/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/anchor-demo/plan.md
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

fi # part ship

# --- every other part: cycle.sh and the gate scripts on the spec branch, a ## Commands cell
if [ "$PART" != ship ]; then
[ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/demo ] || git checkout -q -b vulyk/demo
cp "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/scope-check.sh "$SRC"/scripts/wave-check.sh "$SRC"/scripts/trace-check.sh scripts/
cp "$SRC"/scripts/py.sh "$SRC"/scripts/run-capped.py scripts/   # lib.sh's run_capped falls back to run-capped.py beside it
cat >> CLAUDE.md <<'EOF'

## Commands

| Purpose | Command |
|---|---|
| Trivial pass | `true` |
EOF
git add -A && git commit -qm "add cycle.sh + a ## Commands cell for the hook-log tests" >/dev/null
fi
if part hooklog; then # --- part hooklog: hook-written stats, commit_paperwork, hive paperwork globs
echo "story 09: memory/stats/anomalies.jsonl (the anomaly-scan Stop hook's log) rides close-story --commit, ship-check stage 03 passes a hook-only-dirty tree, scope-check drops it from out_of_scope - no separate ship-check suite exists, so these cases live here"

mkdir -p docs/specs/hooklog
cp "$SRC"/templates/plan.md docs/specs/hooklog/plan.md
printf '> build the hooklog demo\n' > docs/specs/hooklog/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/hooklog/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/hooklog/plan.md
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

echo "skills-json-exempt: scope-check drops skills.json like all paperwork (A18 reversed 2026-10-16); ship-check stage 03 passes it like the anomaly log"
printf '{"n":1}\n' > memory/stats/skills.json
bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md | expect "scope-check: skills.json dirty and undeclared is not out of scope" "changed 0, out of scope 0"
git checkout -- memory/stats/scope.jsonl   # scope-check logs its run; that log is not this case's dirt
echo "hive paperwork: .claude/vulyk-paperwork globs are paperwork for scope-check; without the file nothing changes"
mkdir -p docs/specs/hooklog/smoke
printf 'ran\n' > docs/specs/hooklog/smoke/run-1.md
bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md | expect "no .claude/vulyk-paperwork: a smoke report still counts" "! docs/specs/hooklog/smoke/run-1.md"
# open-round's dirty check runs before its ## Asks check: hooklog's brief has no ## Asks, so a
# tree that passes the dirty check is refused on the Asks line instead.
bash scripts/cycle.sh open-round docs/specs/hooklog 2>&1 | expect "open-round without the file: the smoke report is dirt" "?? docs/specs/hooklog/smoke/run-1.md"
printf '# smoke reports live in the spec\n\n  docs/specs/*/smoke/*  \r\n docs/specs/*/runs/ \r\n' > .claude/vulyk-paperwork
git add .claude/vulyk-paperwork && git commit -qm "hive paperwork globs" -- .claude/vulyk-paperwork
out="$(bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md)"
printf '%s' "$out" | expect "a hive glob (padded, CRLF) drops the smoke report from scope" "changed 0, out of scope 0"
bash scripts/cycle.sh open-round docs/specs/hooklog 2>&1 | expect "open-round: the hive glob's smoke report is not dirt" "## Asks"
is_paperwork_path '# smoke reports live in the spec' && { echo "::error::a comment line matched as a glob"; fail=1; } \
  || echo "  ok    a # comment line is not a glob"
is_paperwork_path src/app.txt && { echo "::error::a path no glob names became paperwork"; fail=1; } \
  || echo "  ok    a path no glob names stays code"
echo "hive paperwork: a non-ASCII or spaced spec dir and a trailing dir/ glob are paperwork to open-round, ship-check 03 and the staleness rule"
pw_base="$(git rev-parse HEAD)"
mkdir -p "docs/specs/оплата/smoke" "docs/specs/a b/smoke" docs/specs/hooklog/runs
printf 'ran\n' > "docs/specs/оплата/smoke/run-1.md"; printf 'ran\n' > "docs/specs/a b/smoke/run-1.md"
printf 'ran\n' > docs/specs/hooklog/runs/r.md
git checkout -- memory/stats/scope.jsonl
bash scripts/cycle.sh open-round docs/specs/hooklog 2>&1 | expect "open-round: non-ASCII, spaced and dir/ glob paths are not dirt" "## Asks"
shiph | expect "ship-check 03: a tree dirty only in hive glob paths is clean" "clean (hook-written stats pending:"
shiph | expect "ship-check 03 names the non-ASCII path as itself" "docs/specs/оплата/smoke/run-1.md"
pw_paths=("docs/specs/оплата" "docs/specs/a b" docs/specs/hooklog/runs docs/specs/hooklog/smoke)
git add -- ${pw_paths[@]+"${pw_paths[@]}"} && git commit -qm "smoke reports after GREEN" -- ${pw_paths[@]+"${pw_paths[@]}"}
paperwork_only "$PWD" "$pw_base" HEAD && echo "  ok    a commit of only hive glob paths (non-ASCII, spaced, dir/) does not stale a round" \
  || { echo "::error::paperwork_only called $(git diff --name-only "$pw_base" HEAD | tr '\n' ' ') code"; fail=1; }
git mv hook-app.txt docs/specs/hooklog/runs/moved.txt
bash scripts/cycle.sh open-round docs/specs/hooklog 2>&1 | expect "open-round: code renamed into a hive glob path is still dirt" "hook-app.txt"
git mv docs/specs/hooklog/runs/moved.txt hook-app.txt
git rm -rq -- ${pw_paths[@]+"${pw_paths[@]}"} && git commit -qm "drop the smoke reports" -- ${pw_paths[@]+"${pw_paths[@]}"}
rm -rf docs/specs/hooklog/smoke
git rm -q .claude/vulyk-paperwork && git commit -qm "drop the hive paperwork globs" -- .claude/vulyk-paperwork
git checkout -- memory/stats/scope.jsonl
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

echo "story 12: council.jsonl alone dirty also blocks stage 03 - only anomalies.jsonl and skills.json pass through"
printf '{"n":1}\n' > memory/stats/council.jsonl
shiph | expect "council.jsonl alone dirty -> 03 not clean" "working tree is not clean"
rm -f memory/stats/council.jsonl

fi # part hooklog
if part gates; then # --- part gates: scope-check siblings, wave-check, trace-check, the ## Asks parser
# --- 0.18 (ADR-013 D4/D5): the three gate scripts -------------------------------------------
git add -A && git commit -qm "0.18 gates: a clean tree to measure from" >/dev/null 2>&1

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
sed_inplace 's/^status: todo/status: todo\nreturned: DONE/' docs/specs/sib/sib-02-s.md
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

echo "fast-verification-04: wave-check reports a segment naming a round-only row, not its unmarked --part neighbour"
cat > CLAUDE.vulyk.md <<'EOF'
# Sidecar constitution

## Commands

| Purpose | Command |
|---|---|
| Slow suite (round-only) | `bash ro-suite.sh` |
| Slow suite part | `bash ro-suite.sh --part <topic>` |
| Shared text, marked (round-only) | `bash ro-both.sh` |
| Shared text, unmarked | `bash ro-both.sh` |
EOF
mkdir -p docs/specs/wro
wro_story() { # wro_story <nn> <verification-block>
  printf -- '---\nstory: wro-%s\nspec: wro\nstatus: todo\nwave: %s\n---\n# R%s\n\n## Files\n- app.txt\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" > "docs/specs/wro/wro-$1-r.md"
}
wro_story 01 '`bash ro-suite.sh`'
wro_story 02 '`bash ro-suite.sh --part verbs`'
wro_story 03 '`bash ro-suite.sh --part verbs && bash ro-both.sh`'
out="$(bash scripts/wave-check.sh docs/specs/wro)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    wave-check still exits 0 while reporting round-only" || { echo "::error::wave-check exit $ex"; fail=1; }
printf '%s' "$out" | expect "a story naming the marked row is reported" "verify-round-only: wro-01 bash ro-suite.sh"
printf '%s' "$out" | expect "a segment in a marked and an unmarked row is reported" "verify-round-only: wro-03 bash ro-both.sh"
printf '%s' "$out" | grep -qF 'verify-round-only: wro-02' && { echo "::error::the unmarked --part row was reported: $out"; fail=1; } \
  || echo "  ok    the unmarked --part row is not reported"
n="$(printf '%s\n' "$out" | grep -c 'verify-round-only:')"
[ "$n" -eq 2 ] && echo "  ok    exactly two verify-round-only reports" || { echo "::error::verify-round-only count $n: $out"; fail=1; }
printf '%s' "$out" | grep -qF 'verify-cell:' && { echo "::error::a round-only cell was also reported verify-cell: $out"; fail=1; } \
  || echo "  ok    a round-only cell is still a cell (no verify-cell)"
rm -f CLAUDE.vulyk.md
git add -A && git commit -qm "wro fixture" >/dev/null

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

echo "one ## Asks parser (lib.sh brief_asks, read by cycle.sh and trace-check.sh): numbered lines when the block has any, else each > line's text"
mkdir -p docs/specs/qa
cp "$SRC"/templates/plan.md docs/specs/qa/plan.md
printf '## Asks\n1. a numbered ask\n> its quoted copy\n2. another ask  \n' > docs/specs/qa/brief.md
[ "$(brief_asks docs/specs/qa/brief.md | tr '\n' '|')" = "1. a numbered ask|2. another ask|" ] \
  && echo "  ok    a numbered block reads as before: its > lines are not items" \
  || { echo "::error::numbered block: $(brief_asks docs/specs/qa/brief.md | tr '\n' '|')"; fail=1; }
printf '# qa\n\n## Request\n> build the quote demo\n\n## Asks\n> the first ask works  \n>\n> the second ask works\n\n## Answers\n> not an ask\n' > docs/specs/qa/brief.md
[ "$(brief_asks docs/specs/qa/brief.md | tr '\n' '|')" = "the first ask works|the second ask works|" ] \
  && echo "  ok    a block of > lines alone: each non-empty line's text, nothing past the next ## heading" \
  || { echo "::error::quoted block: $(brief_asks docs/specs/qa/brief.md | tr '\n' '|')"; fail=1; }
out="$(bash scripts/cycle.sh briefed docs/specs/qa 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    briefed counts the quoted asks (it refused '## Asks missing or empty' before)" \
  || { echo "::error::briefed on a quoted ## Asks: exit=$ex out=$out"; fail=1; }
rm -rf docs/specs/qa

fi # part gates
if part manual; then # --- part manual: blocked_by manual:<id>, the worker model source
echo "0.19 C: blocked_by manual:<id> - a hand step stops the wave until manual-done records it; no later wave is built past it"
mkdir -p docs/specs/man
cp "$SRC"/templates/plan.md docs/specs/man/plan.md
printf '> build the manual demo\n' > docs/specs/man/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/man/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/man#' docs/specs/man/plan.md
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

echo "one source for a worker's model: a story without model: leaves it to the worker agent's frontmatter"
mkdir -p docs/specs/tpl .claude/agents
sed -e 's/<slug>/tpl/g' -e 's/tpl-NN/tpl-01/' "$SRC"/templates/story.md > docs/specs/tpl/tpl-01-a.md
printf -- '---\nname: worker-code\nmodel: opus\n---\n' > .claude/agents/worker-code.md
bash scripts/cycle.sh status docs/specs/tpl --json | expect "a story from the shipped template carries no model, so a hive's pin in worker-code.md holds" \
  '"story":"tpl-01","worker":"worker-code","model":"","repeat"'
sed_inplace 's/^wave: 2$/wave: 2\nmodel: opus/' docs/specs/man/man-02-m.md
bash scripts/cycle.sh status docs/specs/man --json | expect "the story's own model: line still wins" '"worker":"worker-code","model":"opus"'
git checkout -q -- docs/specs/man/man-02-m.md && rm -rf .claude/agents docs/specs/tpl

fi # part manual
if part close; then # --- part close: close-story scope refusal, own-path commits, odd path names
echo "close-story-scope-refusal: close-story --commit refuses an edit outside ## Files that would leave the tree dirty for open-round"
mkdir -p docs/specs/stray
cp "$SRC"/templates/plan.md docs/specs/stray/plan.md
printf '> build the stray demo\n' > docs/specs/stray/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/stray/plan.md
printf 'v1\n' > stray-app.txt; printf 'v1\n' > stray-other.txt
stray_story() { # stray_story <nn> - one in-progress story declaring stray-app.txt only
  cat > "docs/specs/stray/stray-$1.md" <<EOF
---
story: stray-$1
spec: stray
status: in-progress
returned: DONE
wave: $1
---
# Stray fixture $1

## Files
- stray-app.txt

## Verification
\`true\`
EOF
}
stray_story 01
git add -A && git commit -qm "stray: setup" >/dev/null
printf 'v2\n' > stray-app.txt; printf 'v2\n' > stray-other.txt
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: stray-other.txt"' \
  && echo "  ok    an undeclared tracked edit: exit 4, the JSON error names it" || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(git rev-parse HEAD)" = "$head_before" ] && grep -q '^status: in-progress' docs/specs/stray/stray-01.md \
  && echo "  ok    the refusal commits nothing and leaves status: as it was" || { echo "::error::HEAD moved or status changed"; fail=1; }
printf 'v1\n' > stray-other.txt
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -z "$(git status --porcelain -- stray-app.txt stray-other.txt)" ] \
  && echo "  ok    the edit undone, close-story --commit exits 0 and the tree is clean" || { echo "::error::exit=$ex out=$out"; fail=1; }
stray_story 02
git add -A && git commit -qm "stray: story 02" >/dev/null
printf 'v3\n' > stray-app.txt; printf 'new\n' > stray-new.txt
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'edited outside ## Files: stray-new.txt' \
  && echo "  ok    an undeclared untracked new file refuses the same way" || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f stray-new.txt
printf 'new\n' > "stray new c.txt"
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'edited outside ## Files: stray new c.txt' \
  && echo "  ok    a path with spaces (git C-quotes it in porcelain) refuses too" || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f "stray new c.txt"
mkdir -p memory/stats; printf '{"x":1}\n' > memory/stats/skills.json
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    an out-of-scope paperwork path (memory/stats/skills.json) does not refuse" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f memory/stats/skills.json
stray_story 03
git add -A && git commit -qm "stray: story 03" >/dev/null
printf 'v4\n' > stray-app.txt; printf 'v4\n' > stray-other.txt
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-03.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    without --commit an undeclared edit does not refuse" || { echo "::error::exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "stray: done" >/dev/null
# Two wave-mates in one tree (the driver runs a wave in parallel): B's in-flight scratch file must not
# stop A; the wave's last close (B) refuses it.
stray_story 04; stray_story 05
sed_inplace 's/^wave: 05$/wave: 04/; s/^- stray-app.txt$/- stray-other.txt/' docs/specs/stray/stray-05.md
git add -A && git commit -qm "stray: wave-mates 04 + 05" >/dev/null
printf 'v5\n' > stray-app.txt; printf 'v5\n' > stray-other.txt; printf 'scratch\n' > stray-b-scratch.txt
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-04.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'wave-mate stray-05 is still open' \
  && echo "  ok    an open wave-mate's scratch file does not stop a story; close-story notes it" || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-05.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'edited outside ## Files: stray-b-scratch.txt' \
  && echo "  ok    the wave's last close refuses the scratch file" || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f stray-b-scratch.txt
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-05.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -z "$(git status --porcelain -- stray-app.txt stray-other.txt)" ] \
  && echo "  ok    scratch removed, the last close exits 0 and the tree is clean" || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "close-story commits only its own paths, and a failed commit leaves nothing of the story staged"
stray_story 06
git add -A && git commit -qm "stray: story 06" >/dev/null
printf 'v6\n' > stray-app.txt
mkdir -p memory/stats; printf '{"x":6}\n' > memory/stats/skills.json; git add memory/stats/skills.json   # staged by someone else
mkdir -p .git/hooks; printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-06.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && [ "$(git diff --cached --name-only)" = "memory/stats/skills.json" ] && grep -q '^status: in-progress' docs/specs/stray/stray-06.md \
  && echo "  ok    a failed commit (hook) unstages the story's paths, keeps others' staging and status:" \
  || { echo "::error::exit=$ex staged=$(git diff --cached --name-only | tr '\n' ' ') out=$out"; fail=1; }
rm -f .git/hooks/pre-commit
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-06.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! git show --name-only --format= HEAD | grep -qx 'memory/stats/skills.json' && [ "$(git diff --cached --name-only)" = "memory/stats/skills.json" ] \
  && echo "  ok    close-story's commit leaves a staged path it does not own out of the commit" \
  || { echo "::error::exit=$ex commit=$(git show --name-only --format= HEAD | tr '\n' ' ') out=$out"; fail=1; }
git reset -q -- memory/stats/skills.json; rm -f memory/stats/skills.json

echo "close-story --commit: a non-ASCII name and a [bracket] path commit as themselves; a formatting hook leaves the index in sync"
mkdir -p "докс" "app/[id]"; printf 'v1\n' > "докс/нотатка.md"; printf 'v1\n' > "app/[id]/p.txt"
cat > docs/specs/stray/stray-07.md <<'EOF'
---
story: stray-07
spec: stray
status: in-progress
returned: DONE
wave: 7
---
# Stray fixture 07

## Files
- stray-app.txt
- докс/нотатка.md
- app/[id]/p.txt

## Verification
`true`
EOF
git add -A && git commit -qm "stray: story 07" >/dev/null
printf 'v7\n' > stray-app.txt; printf 'v7\n' > "докс/нотатка.md"; printf 'v7\n' > "app/[id]/p.txt"
printf '#!/bin/sh\nprintf "fmt\\n" >> stray-app.txt && git add stray-app.txt\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-07.md --commit 2>&1)"; ex=$?
rm -f .git/hooks/pre-commit
committed="$(git -c core.quotePath=false show --name-only --format= HEAD)"
[ "$ex" -eq 0 ] && printf '%s\n' "$committed" | grep -qxF "докс/нотатка.md" && printf '%s\n' "$committed" | grep -qxF "app/[id]/p.txt" \
  && echo "  ok    the Cyrillic and [bracket] paths are in the story's commit" || { echo "::error::exit=$ex committed=$committed out=$out"; fail=1; }
[ -z "$(git status --porcelain)" ] && git show HEAD:stray-app.txt | grep -qx fmt \
  && echo "  ok    the hook's rewrite is in the commit and the tree is clean after (index synced)" || { echo "::error::status=$(git status --porcelain | tr '\n' ' ')"; fail=1; }

echo "prompt-check: close-story runs it on a story touching scripts or prompts and refuses only on a finding in the story's own files (docs/specs/prompt-check)"
cp "$SRC"/scripts/prompt-check.sh "$SRC"/scripts/prompt-check.py scripts/
mkdir -p .claude/commands docs/specs/pcs
printf '# A command\n\nRun `bash scripts/cycle.sh close-story <file> --no-such-flag`.\n' > .claude/commands/x.md # the drift, already in the tree
cp "$SRC"/templates/plan.md docs/specs/pcs/plan.md
printf '> build the pcs demo\n' > docs/specs/pcs/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/pcs/plan.md
pcs_story() { # pcs_story <nn> <file> - one in-progress story declaring <file> only
  printf -- '---\nstory: pcs-%s\nspec: pcs\nstatus: in-progress\nreturned: DONE\nwave: %s\n---\n# Pcs %s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$1" "$1" "$2" > "docs/specs/pcs/pcs-$1.md"
}
pcs_story 01 .claude/commands/x.md; pcs_story 02 README.md; pcs_story 03 scripts/helper.sh
git add -A && git commit -qm "pcs: setup" >/dev/null
printf '\nMore prose.\n' >> .claude/commands/x.md
out="$(bash scripts/cycle.sh close-story docs/specs/pcs/pcs-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"prompt-check: ' && printf '%s' "$out" | grep -qF 'prompt-check: error .claude/commands/x.md:3: flag:' \
  && echo "  ok    a story touching the drifted command file: exit 4, the finding named" || { echo "::error::prompt-check refusal: exit=$ex out=$out"; fail=1; }
git checkout -q -- .claude/commands/x.md
printf 'readme\n' > README.md
out="$(bash scripts/cycle.sh close-story docs/specs/pcs/pcs-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -qF 'prompt-check' \
  && echo "  ok    a story touching neither scripts nor prompts: exit 0, prompt-check not run" || { echo "::error::README story: exit=$ex out=$out"; fail=1; }
printf '#!/bin/sh\n' > scripts/helper.sh
out="$(bash scripts/cycle.sh close-story docs/specs/pcs/pcs-03.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'prompt-check: warn .claude/commands/x.md:3: flag:' \
  && echo "  ok    a story touching scripts/ while the drift sits in an untouched prompt: exit 0, the finding as a warn" || { echo "::error::helper story: exit=$ex out=$out"; fail=1; }
# A linter that crashes (exit 1, no `prompt-check: error` line) refuses the story with its own reason (post-043-tails).
printf 'raise RuntimeError("linter boom")\n' > scripts/prompt-check.py
pcs_story 04 scripts/helper4.sh
git add -A && git commit -qm "pcs: a crashing linter" >/dev/null
printf '#!/bin/sh\n' > scripts/helper4.sh
out="$(bash scripts/cycle.sh close-story docs/specs/pcs/pcs-04.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"prompt-check crashed: ' && printf '%s' "$out" | tail -1 | grep -qF 'linter boom' \
  && echo "  ok    a crashing prompt-check: exit 4, the reason names the crash" || { echo "::error::prompt-check crash: exit=$ex out=$out"; fail=1; }
rm -f scripts/helper4.sh; cp "$SRC"/scripts/prompt-check.py scripts/
git add -A && git commit -qm "pcs: the linter restored" >/dev/null

fi # part close
if part bsd; then # --- part bsd: cycle.sh under a BSD sed, conventional subjects, command_cell_exists
echo "cycle.sh under a BSD (macOS) sed, and a Profile whose Commit convention is conventional: chore(...) subjects"
REAL_SED="$(command -v sed)"; BSD="$(mktemp -d)"
cat > "$BSD/sed" <<'EOF'
#!/bin/sh
# A BSD sed stand-in: there a bare -i reads the next argument as its backup suffix and breaks,
# and a basic regex reads `\|` as a literal bar, not alternation (only -E / -r give alternation).
ere=0
for a in "$@"; do
  [ "$a" = "-i" ] && { echo "sed: bare -i (BSD sed takes the next argument as a suffix)" >&2; exit 1; }
  case "$a" in --*) ;; -*[!A-Za-z]*) ;; -*E*|-*r*) ere=1 ;; esac
done
if [ "$ere" -eq 0 ]; then
  for a in "$@"; do
    case "$(printf '%s' "$a" | "$REAL_SED" 's/\\\\//g')" in
      *'\|'*) echo "sed: \\| in a basic regex (BSD sed has no BRE alternation)" >&2; exit 1 ;;
    esac
  done
fi
exec "$REAL_SED" "$@"
EOF
chmod +x "$BSD/sed"
bsd() { REAL_SED="$REAL_SED" PATH="$BSD:$PATH" bash scripts/cycle.sh "$@"; }
cp CLAUDE.md "$BSD/CLAUDE.md.orig"
printf '\n## Profile\n\n| Field | Value |\n|---|---|\n| Commit convention | Conventional Commits, enforced by commitlint |\n' >> CLAUDE.md
mkdir -p docs/specs/conv
cp "$SRC"/templates/plan.md docs/specs/conv/plan.md
printf '> build the conv demo\n\n## Asks\n1. one ask\n' > docs/specs/conv/brief.md
printf 'v1\n' > conv-app.txt
cat > docs/specs/conv/conv-01-first.md <<'EOF'
---
story: conv-01
spec: conv
status: in-progress
returned: DONE
wave: 1
---
# Conv fixture

## Files
- conv-app.txt

## Verification
`true`
EOF
git add -A && git commit -qm "conv: setup, a conventional Commit convention" >/dev/null
out="$(bsd briefed docs/specs/conv --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^\*\*Briefed:\*\* via' docs/specs/conv/plan.md && [ "$(git log -1 --format=%s)" = "chore(vulyk-conv): briefed" ] \
  && echo "  ok    briefed under BSD sed rewrites the Briefed line and commits chore(vulyk-<slug>): briefed" \
  || { echo "::error::exit=$ex subject=$(git log -1 --format=%s) out=$out"; fail=1; }
out="$(bsd branch docs/specs/conv --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -qx '\*\*Branch:\*\* vulyk/conv' docs/specs/conv/plan.md && [ "$(git log -1 --format=%s)" = "chore(vulyk-conv): branch vulyk/conv" ] \
  && echo "  ok    branch under BSD sed rewrites the Branch line and commits chore(vulyk-<slug>): branch" \
  || { echo "::error::exit=$ex subject=$(git log -1 --format=%s) out=$out"; fail=1; }
printf 'v2\n' > conv-app.txt
out="$(bsd close-story docs/specs/conv/conv-01-first.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^status: done' docs/specs/conv/conv-01-first.md && [ "$(git log -1 --format=%s)" = "chore(story-conv-01): Conv fixture" ] \
  && echo "  ok    close-story under BSD sed sets status: done and commits chore(story-<id>): <title>" \
  || { echo "::error::exit=$ex subject=$(git log -1 --format=%s) out=$out"; fail=1; }
[ -z "$(git status --porcelain)" ] && echo "  ok    no sed backup file is left behind" \
  || { echo "::error::left behind: $(git status --porcelain | tr '\n' ' ')"; fail=1; }
git checkout -q -
cp "$BSD/CLAUDE.md.orig" CLAUDE.md
git add -A && git commit -qm "conv: back to the default Commit convention" >/dev/null

echo "cross-platform: the stub refuses BRE alternation; review_verdict_of_text and lib.sh's sed_inplace under it"
( export REAL_SED; PATH="$BSD:$PATH"; printf 'a\n' | sed -n 's/\(a\|b\)/x/p' ) >/dev/null 2>&1 && { echo "::error::the BSD sed stub ran \\| in a basic regex"; fail=1; } || echo "  ok    the stub refuses \\| in a basic regex"  # portable: the BRE alternation is the case fed to the BSD sed stub
[ "$( export REAL_SED; PATH="$BSD:$PATH"; printf 'a\\|b\n' | sed 's/\\|/|/g' )" = 'a|b' ] \
  && echo "  ok    the stub runs an escaped backslash before a bar" || { echo "::error::the BSD sed stub refused 's/\\\\|/|/g'"; fail=1; }
eval "$(sed -n '/^review_verdict_of_text()/,/^}/p' scripts/cycle.sh)"
for rv in 'VERDICT: PASS (asks 1-3)|PASS' 'VERDICT: BLOCK - ask 2|BLOCK'; do
  got="$( export REAL_SED; PATH="$BSD:$PATH"; review_verdict_of_text "${rv%|*}" 2>&1 )"
  [ "$got" = "${rv##*|}" ] && echo "  ok    review_verdict_of_text under BSD sed: ${rv##*|}" \
    || { echo "::error::review_verdict_of_text '${rv%|*}' under BSD sed gave '$got', expected ${rv##*|}"; fail=1; }
done
SI="$(mktemp -d)"; printf 'one\ntwo\n' > "$SI/f.txt"
( export REAL_SED; PATH="$BSD:$PATH"; sed_inplace -E 's/^(t)wo$/\1hree/' "$SI/f.txt" ) 2>/dev/null
[ "$(cat "$SI/f.txt")" = "$(printf 'one\nthree')" ] && [ ! -e "$SI/f.txt.bak" ] \
  && echo "  ok    sed_inplace (lib.sh) edits under BSD sed and leaves no .bak" \
  || { echo "::error::sed_inplace under BSD sed: $(cat "$SI/f.txt" | tr '\n' ' ') $(ls "$SI" | tr '\n' ' ')"; fail=1; }
rm -rf "$SI" "$BSD"

echo "cross-platform: vulyk_python and py.sh past a dead python3 (9009 on Windows, 49 once truncated)"
REAL_PY=""
for p in python3 python py; do
  "$p" -c 'import sys; sys.exit(sys.version_info[0] != 3)' </dev/null >/dev/null 2>&1 && { REAL_PY="$(command -v "$p")"; break; }
done
[ -n "$REAL_PY" ] || { echo "::error::no python 3 on this machine: the helper cases below cannot pass"; fail=1; }
dead_stub() { printf '#!/bin/sh\nexit %s\n' "$3" > "$1/$2"; chmod +x "$1/$2"; } # dead_stub <dir> <name> <exit>
for code in 9009 49; do
  PYD="$(mktemp -d)"
  dead_stub "$PYD" python3 "$code"; dead_stub "$PYD" py 1
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL_PY" > "$PYD/python"; chmod +x "$PYD/python"
  got="$( PATH="$PYD:$PATH"; VULYK_PY=; vulyk_python; printf '%s %s' "$?" "${VULYK_PY:-}" )"
  [ "$got" = "0 python" ] && echo "  ok    a python3 exiting $code: vulyk_python picks python" \
    || { echo "::error::vulyk_python did not pick the next working interpreter (python3 exits $code): got '$got'"; fail=1; }
  got="$(VULYK_PY= PATH="$PYD:$PATH" bash "$SRC/scripts/py.sh" -c 'print(6*7)' 2>&1)"
  [ "$got" = 42 ] && echo "  ok    py.sh runs the picked interpreter" || { echo "::error::py.sh past python3 $code gave '$got'"; fail=1; }
  rm -rf "$PYD"
done
DEAD="$(mktemp -d)"   # no python of any name, no working timeout or gtimeout
for n in python3 python py timeout gtimeout; do dead_stub "$DEAD" "$n" 1; done
got="$( PATH="$DEAD:$PATH"; VULYK_PY=; vulyk_python; printf '%s [%s]' "$?" "${VULYK_PY:-}" )"
[ "$got" = "1 []" ] && echo "  ok    no working interpreter: vulyk_python returns 1, VULYK_PY empty" \
  || { echo "::error::vulyk_python with no interpreter: got '$got'"; fail=1; }
err="$(VULYK_PY= PATH="$DEAD:$PATH" bash "$SRC/scripts/py.sh" -c pass 2>&1 >/dev/null)"; ex=$?
[ "$ex" -eq 2 ] && [ "$err" = "py.sh: no python 3 found (tried python3 python py)" ] \
  && echo "  ok    py.sh with no interpreter: exit 2, one stderr line" || { echo "::error::py.sh no python: exit=$ex err='$err'"; fail=1; }

echo "cross-platform: date_epoch and date_shift"
[ "$(date_epoch 2026-01-02T03:04:05Z)" = 1767323045 ] && echo "  ok    date_epoch of a UTC timestamp" \
  || { echo "::error::date_epoch 2026-01-02T03:04:05Z gave '$(date_epoch 2026-01-02T03:04:05Z)'"; fail=1; }
[ "$(date_epoch 2026-01-02)" = 1767312000 ] && echo "  ok    date_epoch of a day is its UTC midnight" \
  || { echo "::error::date_epoch 2026-01-02 gave '$(date_epoch 2026-01-02)'"; fail=1; }
got="$(date_epoch garbage)"; ex=$?
[ "$ex" -eq 1 ] && [ -z "$got" ] && echo "  ok    date_epoch of garbage: nothing, exit 1" || { echo "::error::date_epoch garbage: exit=$ex out='$got'"; fail=1; }
ds="$(date_shift -7)"; today="$(date -u +%Y-%m-%d)"
case "$ds" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
    [ "$(( $(date_epoch "$today") - $(date_epoch "$ds") ))" -eq 604800 ] && echo "  ok    date_shift -7 is seven days before today" \
      || { echo "::error::date_shift -7 gave $ds, today is $today"; fail=1; } ;;
  *) echo "::error::date_shift -7 gave '$ds', not YYYY-MM-DD"; fail=1 ;;
esac

echo "cross-platform: run_capped past dead timeout and gtimeout binaries"
CAPD="$(mktemp -d)"; dead_stub "$CAPD" timeout 1; dead_stub "$CAPD" gtimeout 1
RC="$(mktemp -d)"; t0="$SECONDS"
( PATH="$CAPD:$PATH"; VULYK_PY=; run_capped 1 bash -c "(sleep 3; : > '$RC/marker') & sleep 5; echo late" ) > "$RC/out" 2>&1; ex=$?
el=$((SECONDS - t0))
[ "$ex" -eq 124 ] && [ "$el" -le 3 ] && ! grep -q late "$RC/out" && echo "  ok    the Python cap: exit 124 in ${el}s, no late output" \
  || { echo "::error::run_capped 1 under dead timeout/gtimeout: exit=$ex after ${el}s, out: $(cat "$RC/out")"; fail=1; }
sleep 3
[ ! -e "$RC/marker" ] && echo "  ok    the grandchild died with its process group" || { echo "::error::run_capped left a grandchild that wrote its marker"; fail=1; }
err="$( PATH="$DEAD:$PATH"; VULYK_PY=; run_capped 1 true 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && [ "$err" = "run_capped: no timeout, gtimeout or python 3 - running true uncapped" ] \
  && echo "  ok    nothing to cap with: runs uncapped and says so" || { echo "::error::run_capped uncapped: exit=$ex err='$err'"; fail=1; }
err="$( PATH="$DEAD:$PATH"; VULYK_PY=; run_capped 0 true 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && [ -z "$err" ] && echo "  ok    run_capped 0: uncapped, silently" || { echo "::error::run_capped 0: exit=$ex err='$err'"; fail=1; }
rm -rf "$RC" "$CAPD" "$DEAD"

echo "cross-platform ask 9: close-story runs the constitution's py.sh Python cell and refuses the old bare python one"
PRE9="$(mktemp)"; cp CLAUDE.md "$PRE9"
grep '^| Python |' "$SRC/CLAUDE.md" | tr -d '\r' >> CLAUDE.md
mkdir -p docs/specs/pyc .claude/hooks
cp "$SRC"/templates/plan.md docs/specs/pyc/plan.md
printf '> build the pyc demo\n' > docs/specs/pyc/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-28/' docs/specs/pyc/plan.md
printf '__pycache__/\n' >> .gitignore
printf 'x = 1\n' > .claude/hooks/ok.py
pyc_story() { # pyc_story <nn> <verification>
  printf -- '---\nstory: pyc-%s\nspec: pyc\nstatus: in-progress\nreturned: DONE\nwave: %s\n---\n# Pyc fixture %s\n\n## Files\n- .claude/hooks/ok.py\n\n## Verification\n`%s`\n' \
    "$1" "$((10#$1))" "$1" "$2" > "docs/specs/pyc/pyc-$1.md"
}
pyc_story 01 'bash scripts/py.sh -m py_compile .claude/hooks/*.py'
pyc_story 02 'python -m py_compile .claude/hooks/*.py'
git add -A && git commit -qm "pyc: setup, the constitution's Python row" >/dev/null
printf 'x = 2\n' > .claude/hooks/ok.py
out="$(bash scripts/cycle.sh close-story docs/specs/pyc/pyc-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^status: done' docs/specs/pyc/pyc-01.md \
  && echo "  ok    close-story accepts and runs the py.sh cell green" || { echo "::error::py.sh cell: exit=$ex $(printf '%s\n' "$out" | tail -3)"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/pyc/pyc-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"verification not in ## Commands: python -m py_compile .claude/hooks/*.py"' \
  && echo "  ok    an old story naming bare python is refused, exit 2" || { echo "::error::old python cell: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
cp "$PRE9" CLAUDE.md; rm -f "$PRE9"
git add -A && git commit -qm "pyc: back to the fixture's ## Commands" >/dev/null

echo "command_cell_exists: each backticked command of a cell, and <name> / [<name>] placeholders without shell control characters"
CELLS="$(mktemp)"
cat > "$CELLS" <<'EOF'
## Commands

| Purpose | Command |
|---|---|
| Defects | `bash scripts/defects-check.sh [<arg>]` |
| One test | `pytest <file>` |
| Two | `bash tests/a.sh` or `bash tests/b.sh` |
| Pipe | `git ls-files '*.sh' \| xargs -n1 bash -n` |
| Unfilled | `<fill in - the quiet variant>` |
| Bare | `<cmd>` |
| Redirect | `sort < in.txt > out.txt` |
| Multi | `make a` or `make b <z>` |
| Syntax | `bash -n <файл>.sh` |
EOF
cell_case() { # cell_case <yes|no> <command>
  local got=no; command_cell_exists "$CELLS" "$2" && got=yes
  [ "$got" = "$1" ] && echo "  ok    $1: $2" || { echo "::error::command_cell_exists '$2': expected $1, got $got"; fail=1; }
}
cell_case yes 'bash scripts/defects-check.sh'
cell_case yes 'bash scripts/defects-check.sh docs/specs/x'
cell_case yes 'pytest tests/a.py tests/b.py'
cell_case no  'pytest'
cell_case no  'pytest a.py; rm -rf x'
cell_case no  'pytest $(id)'
cell_case no  'pytest a.py | tee x'
cell_case yes 'bash tests/b.sh'
cell_case yes "git ls-files '*.sh' | xargs -n1 bash -n"
cell_case no  'bash scripts/defects-checkXsh'
cell_case no  'rm -rf x'
cell_case no  'sort x y out.txt'
cell_case yes 'make b foo'
cell_case no  'make a` or `make b foo'
cell_case no  'pytest -p evil'
cell_case no  'pytest a.py -p evil'
cell_case yes 'bash -n deploy.sh'
rm -f "$CELLS"
command_cell_exists "$SRC/CLAUDE.md" 'bash scripts/py.sh -m py_compile .claude/hooks/*.py' \
  && echo "  ok    yes: the constitution's Python cell is bash scripts/py.sh -m py_compile .claude/hooks/*.py" \
  || { echo "::error::CLAUDE.md has no 'bash scripts/py.sh -m py_compile .claude/hooks/*.py' cell"; fail=1; }
[ "$(tr -d '\r' < "$SRC/CLAUDE.md" | wc -c | tr -d ' ')" -lt 7168 ] && echo "  ok    CLAUDE.md stays under 7168 bytes" \
  || { echo "::error::CLAUDE.md is $(tr -d '\r' < "$SRC/CLAUDE.md" | wc -c | tr -d ' ') bytes, the cap is 7168"; fail=1; }

echo "cross-platform: a BSD (macOS) awk refuses a newline inside a -v value; install.sh's block restore and reopen's insertion under it"
REAL_AWK="$(command -v awk)"; BAWK="$(mktemp -d)"
cat > "$BAWK/awk" <<'EOF'
#!/bin/sh
# A BSD awk stand-in: a -v assignment whose value holds a newline is refused, as macOS awk does.
nl='
'
prev=''
for a in "$@"; do
  v=''
  [ "$prev" = "-v" ] && v="$a"
  case "$a" in -v?*) v="${a#-v}" ;; esac
  case "$v" in *"$nl"*) echo "awk: newline in string ${v%%"$nl"*}..." >&2; exit 2 ;; esac
  prev="$a"
done
exec "$REAL_AWK" "$@"
EOF
chmod +x "$BAWK/awk"
( export REAL_AWK; PATH="$BAWK:$PATH"; awk -v x="$(printf 'a\nb')" 'BEGIN { print x }' ) >/dev/null 2>&1 \
  && { echo "::error::the BSD awk stub ran a -v value holding a newline"; fail=1; } || echo "  ok    the stub refuses a -v value holding a newline"
mblock() { tr -d '\r' < "$1" | sed -n "/$2:START/,/$2:END/p" | sed '1d;$d'; } # mblock <file> <MARKER> - the body between the markers
BROW='| Browser MCP | `<fill in - chrome-devtools \| claude-in-chrome \| none (default); read by the council-haiku seat only, read-only, on a separate test profile>` |'
HV="$(mktemp -d)"
out="$( export REAL_AWK; PATH="$BAWK:$PATH"; bash "$SRC/install.sh" "$HV" --telemetry off 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -q 'newline in string' && grep -q 'VULYK:PROFILE:START' "$HV/CLAUDE.md" \
  && echo "  ok    a fresh install under BSD awk resets both blocks" \
  || { echo "::error::fresh install under BSD awk: exit=$ex out=$(printf '%s' "$out" | grep -i 'awk' | head -3)"; fail=1; }
[ "$(mblock "$HV/CLAUDE.md" VULYK:PROFILE | grep -cxF -- "$BROW")" = 1 ] \
  && echo "  ok    the Browser MCP row keeps \\| byte for byte" \
  || { echo "::error::Browser MCP row after a fresh install: $(mblock "$HV/CLAUDE.md" VULYK:PROFILE | grep 'Browser MCP')"; fail=1; }
mblock "$HV/CLAUDE.md" VULYK:PROFILE > "$BAWK/profile.fresh"; mblock "$HV/CLAUDE.md" VULYK:COMMANDS > "$BAWK/commands.fresh"
tr -d '\r' < "$HV/CLAUDE.md" | sed -n '/^## Profile/,/VULYK:COMMANDS:END/p' > "$BAWK/sections.fresh"
printf '# VULYK Constitution\n\n## Laws\n\n1. A law.\n' > "$HV/CLAUDE.md"
out="$( export REAL_AWK; PATH="$BAWK:$PATH"; bash "$SRC/install.sh" "$HV" --upgrade 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -q 'newline in string' \
  && [ "$(mblock "$HV/CLAUDE.md" VULYK:PROFILE)" = "$(cat "$BAWK/profile.fresh")" ] \
  && [ "$(mblock "$HV/CLAUDE.md" VULYK:COMMANDS)" = "$(cat "$BAWK/commands.fresh")" ] \
  && [ "$(tr -d '\r' < "$HV/CLAUDE.md" | sed -n '/^## Profile/,/VULYK:COMMANDS:END/p')" = "$(cat "$BAWK/sections.fresh")" ] \
  && echo "  ok    install.sh --upgrade under BSD awk restores both blocks, byte for byte as a fresh install writes them" \
  || { echo "::error::--upgrade under BSD awk: exit=$ex out=$(printf '%s' "$out" | grep -i 'awk' | head -3)"; diff "$BAWK/sections.fresh" <(tr -d '\r' < "$HV/CLAUDE.md" | sed -n '/^## Profile/,/VULYK:COMMANDS:END/p') | head -10; fail=1; }
rm -rf "$HV"
mkdir -p docs/specs/bsdawk
cp "$SRC"/templates/plan.md docs/specs/bsdawk/plan.md
printf '> build the bsdawk demo\n\n## Answers\n- an earlier answer\n\n## Asks\n1. one ask\n' > docs/specs/bsdawk/brief.md
printf '{"ts":"2020-01-01T00:00:00Z","spec":"bsdawk","round":1,"verdict":"ESCALATE","head":"aaaaaaa","pack":"p","asks":1,"red":[1],"red_unevidenced":[],"na":0,"review":"","escalate":"ceiling","note":""}\n' >> memory/stats/council.jsonl
out="$( export REAL_AWK; PATH="$BAWK:$PATH"; bash scripts/cycle.sh reopen docs/specs/bsdawk 'keep a \| b' 2>&1 )"; ex=$?
want="$(printf '> build the bsdawk demo\n\n## Answers\n- an earlier answer\n\n\n**After escalation (round 1, %s).**\n> keep a \\| b\n## Asks\n1. one ask' "$(date -u +%Y-%m-%d)")"
[ "$ex" -eq 0 ] && [ "$(cat docs/specs/bsdawk/brief.md)" = "$want" ] \
  && echo "  ok    reopen under BSD awk inserts the decision after ## Answers, \\| byte for byte" \
  || { echo "::error::reopen under BSD awk: exit=$ex out=$(printf '%s' "$out" | head -3) brief:"; cat docs/specs/bsdawk/brief.md; fail=1; }
git add -A && git commit -qm "bsdawk: reopen fixture" >/dev/null
rm -rf "$BAWK"

fi # part bsd
if part safety; then # --- part safety: ship-check merge proof, the spec-branch guard
echo "ship-safety: ship-check stage 03 proves the merge into the default branch (git merge-tree) and the branch it runs on"
SS="$(mktemp -d)"
(
  cd "$SS" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
  mkdir -p scripts docs/specs/ss
  cp "$SRC"/scripts/lib.sh "$SRC"/scripts/ship-check.sh scripts/
  printf '> ship it\n' > docs/specs/ss/brief.md
  cp "$SRC"/templates/plan.md docs/specs/ss/plan.md
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-19/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/ss#' docs/specs/ss/plan.md
  printf -- '---\nstory: ss-01\nspec: ss\nstatus: done\nwave: 1\n---\n# S1\n' > docs/specs/ss/ss-01.md
  printf 'base\n' > app.txt
  git add -A && git commit -qm init
  git checkout -q -b vulyk/ss && printf 'spec\n' > app.txt && git commit -qam "story(ss-01)"
  sss() { bash scripts/ship-check.sh docs/specs/ss; }
  sss | expect "a branch that merges cleanly gets an ok merge line" "vulyk/ss merges into main cleanly"
  git checkout -q -b elsewhere
  sss | expect "a third branch is OPEN, naming both" "on elsewhere, but the spec's commits live on vulyk/ss"
  git checkout -q main
  sss | expect "neighbour: on the default branch it stays a note, not a refusal" "you are on main"
  sss | grep -qF "but the spec's commits live on" && { echo "::error::the default branch was refused as a wrong branch"; : > "$MARK"; }
  printf 'main moved\n' > app.txt && git commit -qam "main touches the same line"
  git checkout -q vulyk/ss
  sss | expect "a conflict is OPEN and names the file" "vulyk/ss conflicts with main in: app.txt"
  sss | expect "a conflict offers the repair" "repair: merge main into vulyk/ss"
  sss | expect "a conflict is NOT READY" "NOT READY"
  sed_inplace 's#^\*\*Branch:\*\* .*#**Branch:** vulyk/gone#' docs/specs/ss/plan.md
  sss | expect "a merge-tree error is 'cannot check', never clean" "cannot check the merge of vulyk/gone into main"
  sss | grep -qF "vulyk/gone merges into main cleanly" && { echo "::error::a merge-tree error was read as clean"; : > "$MARK"; }
  exit 0
)
rm -rf "$SS"

echo "ship-safety: cycle.sh refuses claim, close-story and open-round off the spec branch, and branch refuses an old merged spec branch"
BG_HOME="$(git rev-parse --abbrev-ref HEAD)"
git add -A && git commit -qm "before bguard" >/dev/null 2>&1
git branch -f main HEAD && git checkout -q main   # main must carry scripts/ and CLAUDE.md for the verbs below
mkdir -p docs/specs/bguard
cp "$SRC"/templates/plan.md docs/specs/bguard/plan.md
printf '> guard the branch\n' > docs/specs/bguard/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-19/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/bguard#' docs/specs/bguard/plan.md
cat > docs/specs/bguard/bguard-01.md <<'EOF'
---
story: bguard-01
spec: bguard
status: todo
returned: DONE
wave: 1
---
# Branch guard fixture

## Files
- bguard.txt

## Verification
`true`
EOF
git checkout -q -b vulyk/bguard && git add -A && git commit -qm "bguard: setup" >/dev/null
git checkout -q -b bg-other
printf 'x\n' > bguard.txt
head_before="$(git rev-parse HEAD)"
for bg_verb in close-story open-round claim; do
  case "$bg_verb" in
    close-story) out="$(bash scripts/cycle.sh close-story docs/specs/bguard/bguard-01.md --commit 2>&1)"; ex=$? ;;
    open-round)  out="$(bash scripts/cycle.sh open-round docs/specs/bguard --commit 2>&1)"; ex=$? ;;
    claim)       out="$(bash scripts/cycle.sh claim docs/specs/bguard bgstamp 2>&1)"; ex=$? ;;
  esac
  [ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"on bg-other, spec branch is vulyk/bguard"' \
    && echo "  ok    $bg_verb off the spec branch: exit 2, both branches named" || { echo "::error::$bg_verb exit=$ex out=$out"; fail=1; }
done
[ "$(git rev-parse HEAD)" = "$head_before" ] && [ ! -e docs/specs/bguard/DRIVER ] && grep -q '^status: todo' docs/specs/bguard/bguard-01.md \
  && echo "  ok    the refusals commit nothing, claim writes no DRIVER, status: is untouched" || { echo "::error::a refusal mutated state"; fail=1; }
git checkout -q vulyk/bguard
out="$(bash scripts/cycle.sh close-story docs/specs/bguard/bguard-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    neighbour: on the recorded branch close-story closes as before" || { echo "::error::close-story on its own branch exit=$ex out=$out"; fail=1; }

git checkout -q main
git checkout -q -b vulyk/oldspec && printf 'old\n' > oldspec.txt && git add -A && git commit -qm "old spec work" >/dev/null
git checkout -q main && git merge -q --no-ff vulyk/oldspec -m "merge old spec" >/dev/null
mkdir -p docs/specs/oldspec docs/specs/freshspec
for bg_s in oldspec freshspec; do
  cp "$SRC"/templates/plan.md "docs/specs/$bg_s/plan.md"
  printf '> reuse\n' > "docs/specs/$bg_s/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-19/' "docs/specs/$bg_s/plan.md"
done
git add -A && git commit -qm "two specs" >/dev/null
out="$(bash scripts/cycle.sh branch docs/specs/oldspec 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"vulyk/oldspec already merged into main"' \
  && [ -z "$(marker docs/specs/oldspec/plan.md Branch)" ] && [ "$(git rev-parse --abbrev-ref HEAD)" = main ] \
  && echo "  ok    branch on an old merged spec branch: exit 2, no Branch line, still on main" || { echo "::error::branch reuse exit=$ex out=$out"; fail=1; }
git branch -q vulyk/freshspec main
out="$(bash scripts/cycle.sh branch docs/specs/freshspec 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/freshspec ] \
  && echo "  ok    neighbour: a branch cut at the default tip is fresh, branch checks it out" || { echo "::error::fresh branch exit=$ex out=$out"; fail=1; }
git checkout -q -- . 2>/dev/null; git checkout -q "$BG_HOME"
fi # part safety
if part red; then # --- part red: stamp-red, the close-story receipt gate, repair inherits the mark, wave-check red lines
# Order matters for the red-receipt story's own stamp: the gate cases run last, so the tail of a
# red run ends on the close-story refusal this part expects.
git add -A && git commit -qm "red: a clean tree to start from" >/dev/null 2>&1
cat >> CLAUDE.md <<'EOF'
| Red tests | `bash <file>` |
| Red slow (round-only) | `bash tests/red-slow.sh` |
EOF
mkdir -p docs/specs/red tests src
cp "$SRC"/templates/plan.md docs/specs/red/plan.md
printf 'todo\n' > src/red.txt
red_test_file() { # the sealed fixture test: green once src/red.txt says done
  printf '#!/usr/bin/env bash\ngrep -qx done src/red.txt && exit 0\necho "expected done in src/red.txt, got $(cat src/red.txt)"\nexit 1\n' > tests/red.sh
}
red_test_file
printf 'exit 0\n' > tests/red-pass.sh
printf 'sleep 5\necho "expected done"\nexit 1\n' > tests/red-sleep.sh
printf 'echo "expected done"\nexit 1\n' > tests/red-slow.sh
red_story() { # red_story <nn> <frontmatter-lines> <files-lines> <verification-lines>
  printf -- '---\nstory: red-%s\nspec: red\nstatus: todo\nreturned: DONE\nwave: %s\n%s---\n# Red fixture %s\n\n## Files\n%s\n## Verification\n%s\n' \
    "$1" "$((10#$1))" "$2" "$1" "$3" "$4" > "docs/specs/red/red-$1.md"
}
MK=$'red: required\nred_reason: expected done\n'
FI=$'- tests/red.sh\n- src/red.txt\n'
git add -A && git commit -qm "red: fixtures" >/dev/null

echo "red-receipt: wave-check names a marked story with nothing to seal and a red: value other than required"
mkdir -p docs/specs/redwc
printf -- '---\nstory: redwc-01\nstatus: todo\nwave: 1\nred: required\nred_reason: x\n---\n# W1\n\n## Files\n- src/red.txt\n\n## Verification\n`true`\n' > docs/specs/redwc/redwc-01.md
printf -- '---\nstory: redwc-02\nstatus: todo\nwave: 2\nred: yes\n---\n# W2\n\n## Files\n- src/red.txt\n\n## Verification\n`bash tests/red.sh`\n' > docs/specs/redwc/redwc-02.md
printf -- '---\nstory: redwc-03\nstatus: todo\nwave: 3\n---\n# W3\n\n## Files\n- src/red.txt\n\n## Verification\n`true`\n' > docs/specs/redwc/redwc-03.md
printf -- '---\nstory: redwc-04\nstatus: todo\nwave: 4\nred: required\nred_reason: x\n---\n# W4\n\n## Files\n- tests/red.sh\n- src/red.txt\n\n## Verification\n`bash tests/red.sh`\n' > docs/specs/redwc/redwc-04.md
out="$(bash scripts/wave-check.sh docs/specs/redwc)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    wave-check still exits 0" || { echo "::error::wave-check exit $ex"; fail=1; }
printf '%s' "$out" | expect "a marked story whose verification names no path under ## Files" "red-no-test: redwc-01"
printf '%s' "$out" | expect "a red: value other than required is named with the value" "red-value: redwc-02 yes"
printf '%s' "$out" | grep -E 'red-(no-test|value): redwc-0[34]' && { echo "::error::an unmarked or sealed story got a red line: $out"; fail=1; } \
  || echo "  ok    the unmarked story and the sealed marked story get no red line"
rm -rf docs/specs/redwc

echo "red-receipt: repair passes red: required on from a marked story it unions, and writes today's frontmatter otherwise"
red_rp_spec() { # red_rp_spec <slug> <frontmatter-lines> - a Tier 2 spec, one done story, a RED round 1, its repair
  mkdir -p "docs/specs/$1"
  cp "$SRC/templates/plan.md" "docs/specs/$1/plan.md"
  printf '# %s (brief)\n\n## Request\n> build the thing\n\n## Asks\n1. ask number 1 works\n' "$1" > "docs/specs/$1/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-28/; s#^\*\*Branch:\*\* <.*#**Branch:** '"$(git rev-parse --abbrev-ref HEAD)"'#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' "docs/specs/$1/plan.md"
  printf 'a\n' > "$1-a.txt"
  printf -- '---\nstory: %s-01\nstatus: done\nwave: 1\n%s---\n# A\n\n## Requirements\n> build the thing\n\n## Files\n- %s-a.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$1" > "docs/specs/$1/$1-01-a.md"
  git add -A && git commit -qm "$1: fixture" >/dev/null
  bash scripts/cycle.sh open-round "docs/specs/$1" --commit >/dev/null 2>&1
  printf 'VERDICT: BLOCK\n## Major\n- [ask 1] ask 1 broke: run: t saw: f\n' | bash scripts/cycle.sh record-seat "docs/specs/$1" 1 review >/dev/null 2>&1
  bash scripts/cycle.sh judge "docs/specs/$1" --commit >/dev/null 2>&1
  bash scripts/cycle.sh repair "docs/specs/$1" --commit 2>&1 | tail -1
}
out="$(red_rp_spec redrp "$MK")"
rp=docs/specs/redrp/redrp-02-repair-round-1.md
[ -f "$rp" ] && echo "  ok    the marked spec reached its repair story" || { echo "::error::no repair story: $out"; fail=1; }
sed -n '2,/^---$/p' "$rp" 2>/dev/null | expect "the repair story carries red: required" "red: required"
sed -n '2,/^---$/p' "$rp" 2>/dev/null | grep -qx 'red_reason:' && echo "  ok    and an empty red_reason: line" \
  || { echo "::error::repair frontmatter lacks an empty red_reason: $(sed -n '1,12p' "$rp" 2>/dev/null)"; fail=1; }
out="$(red_rp_spec redrq '')"
rq=docs/specs/redrq/redrq-02-repair-round-1.md
[ "$(sed -n '1,9p' "$rq" 2>/dev/null)" = "$(printf -- '---\nstory: redrq-02\nstatus: todo\nreturned:\nworker: worker-code\nmodel: opus\nwave: 2\nblocked_by: []\n---')" ] \
  && ! grep -q '^red' "$rq" && echo "  ok    an unmarked union writes the frontmatter byte for byte as before" \
  || { echo "::error::unmarked repair frontmatter changed: $(sed -n '1,12p' "$rq" 2>/dev/null) / $out"; fail=1; }

echo "red-receipt: the repair keeps the mark unless every finding names a file and none a marked story's (0.40.1)"
red_rp_two() { # red_rp_two <slug> <major-lines> - done stories 01 (marked, <slug>-a.txt) and 02 (unmarked, <slug>-doc.md), a RED round 1, its repair
  mkdir -p "docs/specs/$1"
  cp "$SRC/templates/plan.md" "docs/specs/$1/plan.md"
  printf '# %s (brief)\n\n## Request\n> build the thing\n\n## Asks\n1. ask number 1 works\n' "$1" > "docs/specs/$1/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-28/; s#^\*\*Branch:\*\* <.*#**Branch:** '"$(git rev-parse --abbrev-ref HEAD)"'#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' "docs/specs/$1/plan.md"
  printf 'a\n' > "$1-a.txt"; printf 'doc\n' > "$1-doc.md"
  printf -- '---\nstory: %s-01\nstatus: done\nwave: 1\n%s---\n# A\n\n## Files\n- %s-a.txt\n\n## Verification\n`true`\n' "$1" "$MK" "$1" > "docs/specs/$1/$1-01-a.md"
  printf -- '---\nstory: %s-02\nstatus: done\nwave: 1\n---\n# D\n\n## Files\n- %s-doc.md\n\n## Verification\n`true`\n' "$1" "$1" > "docs/specs/$1/$1-02-doc.md"
  git add -A && git commit -qm "$1: fixture" >/dev/null
  bash scripts/cycle.sh open-round "docs/specs/$1" --commit >/dev/null 2>&1
  printf 'VERDICT: BLOCK\n## Major\n%s\n' "$2" | bash scripts/cycle.sh record-seat "docs/specs/$1" 1 review >/dev/null 2>&1
  bash scripts/cycle.sh judge "docs/specs/$1" --commit >/dev/null 2>&1
  bash scripts/cycle.sh repair "docs/specs/$1" --commit 2>&1 | tail -1
}
out="$(red_rp_two redpa '- [ask 1] redpa-doc.md:1 the prose is wrong: run: t saw: f')"
rp=docs/specs/redpa/redpa-03-repair-round-1.md
[ -f "$rp" ] && ! sed -n '2,/^---$/p' "$rp" | grep -q '^red' && echo "  ok    findings naming only the unmarked story's file: the repair is unmarked" \
  || { echo "::error::a prose-only repair carries red: required: $(sed -n '1,12p' "$rp" 2>/dev/null) / $out"; fail=1; }
out="$(red_rp_two redpb '- [ask 1] redpb-a.txt:1 the code is wrong: run: t saw: f')"
sed -n '2,/^---$/p' docs/specs/redpb/redpb-03-repair-round-1.md 2>/dev/null | expect "a finding naming the marked story's file keeps the mark" "red: required"
out="$(red_rp_two redpc $'- [ask 1] redpc-doc.md:1 the prose is wrong: run: t saw: f\n- [ask 1] ask 1 broke: run: t saw: f')"
sed -n '2,/^---$/p' docs/specs/redpc/redpc-03-repair-round-1.md 2>/dev/null | expect "a finding that names no file keeps the mark beside an anchored prose one" "red: required"

echo "red-receipt: a red: line in the story body, outside the frontmatter, marks nothing (0.40.1)"
mkdir -p docs/specs/redbody
printf -- '---\nstory: redbody-01\nstatus: todo\nwave: 1\n---\n# B\n\nred: required\n\n## Files\n- src/red.txt\n\n## Verification\n`true`\n' > docs/specs/redbody/redbody-01.md
out="$(bash scripts/wave-check.sh docs/specs/redbody)"
printf '%s' "$out" | grep -E 'red-(no-test|value): redbody-01' && { echo "::error::a body red: line marked the story in wave-check: $out"; fail=1; } \
  || echo "  ok    wave-check prints no red line for a body red: line"
red_story 30 '' $'- src/body.txt\n' '`bash tests/red-pass.sh`'
sed_inplace 's/^# Red fixture 30$/&\n\nred: required/' docs/specs/red/red-30.md
printf 'body\n' > src/body.txt
git add -A && git commit -qm "red: body-line story" >/dev/null
out="$(bash scripts/cycle.sh stamp-red docs/specs/red/red-30.md 2>&1)"
printf '%s\n' "$out" | tail -1 | expect "stamp-red reads the body red: line as unmarked" '"error":"story is not red: required"'
printf 'body2\n' > src/body.txt
out="$(bash scripts/cycle.sh close-story docs/specs/red/red-30.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    close-story asks no receipt of a body red: line" \
  || { echo "::error::a body red: line gated close-story: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }

echo "red-receipt: stamp-red refuses every wrong red - exit 4, the story file untouched"
red_refuses() { # red_refuses <label> <nn> <exit> <error-text> - runs stamp-red on red-<nn>
  local st="docs/specs/red/red-$2.md" before after out ex
  before="$(cat "$st")"
  out="$(bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
  after="$(cat "$st")"
  if [ "$ex" -eq "$3" ] && printf '%s\n' "$out" | tail -1 | grep -qF "\"error\":\"$4" && [ "$before" = "$after" ]; then echo "  ok    $1"
  else echo "::error::$1 - expected exit $3, '$4' and the story unchanged; got exit $ex:"; printf '%s\n' "$out" | tail -3 | sed 's/^/        /'; fail=1; : > "$MARK"; fi
}
red_story 01 '' "$FI" '`bash tests/red.sh`'
red_refuses "an unmarked story" 01 4 "story is not red: required"
red_story 02 $'red: required\nred_reason:   \n' "$FI" '`bash tests/red.sh`'
red_refuses "a marked story with an empty red_reason" 02 4 "red_reason is empty"
red_story 03 "$MK" "$FI" '`true`'
red_refuses "a verification that names no path under ## Files" 03 4 "no test to seal: ## Verification names no path under ## Files"
red_story 04 "$MK" $'- tests/red.sh\n' '`bash tests/red.sh`'
red_refuses "## Files holding only the sealed test" 04 4 "nothing to turn green: ## Files holds only sealed tests"
red_story 05 "$MK" $'- tests/red-pass.sh\n- src/red.txt\n' '`bash tests/red-pass.sh`'
red_refuses "every line exits 0" 05 4 "not red: every verification line exits 0"
red_story 06 "$MK" $'- tests/red.sh\n- tests/red-missing.sh\n- src/red.txt\n' $'`bash tests/red.sh`\n`bash tests/red-missing.sh`'
red_refuses "a missing test (127) refuses even beside a line carrying the reason" 06 4 "not red: bash tests/red-missing.sh exits 127 (launch failure)"
red_story 07 $'red: required\nred_reason: expected something else\n' "$FI" '`bash tests/red.sh`'
red_refuses "a failure without the declared text" 07 4 "red for another reason: red_reason not in the output of bash tests/red.sh"
red_story 09 "$MK" $'- tests/red-slow.sh\n- src/red.txt\n' '`bash tests/red-slow.sh`'
red_refuses "a round-only row: exit 2, close-story's own message" 09 2 "verification is round-only: bash tests/red-slow.sh"
red_story 08 "$MK" $'- tests/red-sleep.sh\n- src/red.txt\n' '`bash tests/red-sleep.sh`'
before="$(cat docs/specs/red/red-08.md)"
out="$(VULYK_VERIFY_TIMEOUT=1 bash scripts/cycle.sh stamp-red docs/specs/red/red-08.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"not red: timed out after 1s' && [ "$before" = "$(cat docs/specs/red/red-08.md)" ] \
  && echo "  ok    a timeout (124) is no red" || { echo "::error::timeout: exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
DEADT="$(mktemp -d)"; printf '#!/bin/sh\nexit 1\n' > "$DEADT/timeout"; cp "$DEADT/timeout" "$DEADT/gtimeout"; chmod +x "$DEADT/timeout" "$DEADT/gtimeout"
out="$(PATH="$DEADT:$PATH" VULYK_VERIFY_TIMEOUT=1 bash scripts/cycle.sh stamp-red docs/specs/red/red-08.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"not red: timed out after 1s' && [ "$before" = "$(cat docs/specs/red/red-08.md)" ] \
  && echo "  ok    a timeout (124) is no red with no timeout or gtimeout either (the Python cap)" \
  || { echo "::error::timeout without timeout/gtimeout: exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
rm -rf "$DEADT"

echo "red-receipt: stamp-red on a red for the declared reason writes the receipt; a second stamp replaces it"
st=docs/specs/red/red-10.md
red_story 10 "$MK" "$FI" $'`true`\n`bash tests/red.sh`'
out="$(bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
last="$(printf '%s\n' "$out" | tail -1)"
[ "$ex" -eq 0 ] && printf '%s' "$last" | grep -qE '^\{"ok":true,"verb":"stamp-red","story":"docs/specs/red/red-10.md","exit":1,"tests":"[0-9a-f]{64}","impl":"[0-9a-f]{64}"\}$' \
  && echo "  ok    exit 0, the last line is the contract's JSON" || { echo "::error::stamp: exit=$ex $(printf '%s\n' "$out" | tail -3)"; fail=1; }
th="$(printf '%s' "$last" | sed -n 's/.*"tests":"\([0-9a-f]*\)".*/\1/p')"
ih="$(printf '%s' "$last" | sed -n 's/.*"impl":"\([0-9a-f]*\)".*/\1/p')"
sed -n '/^red_reason:/{n;p;q;}' "$st" | grep -qE "^red_verified_at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z $th\$" \
  && echo "  ok    red_verified_at follows red_reason: a UTC timestamp and the tests hash" || { echo "::error::red_verified_at: $(grep '^red' "$st")"; fail=1; }
grep -qx -- '- command: bash tests/red.sh' "$st" && grep -qx -- '- exit: 1' "$st" && grep -qx -- "- tests: $th (tests/red.sh)" "$st" \
  && grep -qx -- "- impl: $ih" "$st" && grep -qE -- '^- stamped: [0-9]{4}-' "$st" && grep -qF 'expected done in src/red.txt, got todo' "$st" \
  && echo "  ok    ## Red receipt: command, exit, tests, impl, stamped, the output tail" || { echo "::error::receipt: $(sed -n '/^## Red receipt/,$p' "$st")"; fail=1; }
out="$(bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(grep -c '^## Red receipt' "$st")" -eq 1 ] && [ "$(grep -c '^red_verified_at:' "$st")" -eq 1 ] && [ "$(grep -c '^- command:' "$st")" -eq 1 ] \
  && echo "  ok    a second stamp leaves one red_verified_at and one ## Red receipt" || { echo "::error::re-stamp: exit=$ex $(cat "$st")"; fail=1; }
git add -A && git commit -qm "red: stamp fixtures" >/dev/null

echo "red-receipt: an unmarked story built from templates/story.md closes as before"
sed -e 's/<slug>/red/g' -e 's/red-NN/red-20/' -e 's/^returned:/returned: DONE/' -e 's#^- path/to/file.ext#- src/tpl.txt#' \
  -e 's#^`<exact command that proves the criteria>`#`true`#' -e 's/^wave: 1 /wave: 20 /' "$SRC"/templates/story.md > docs/specs/red/red-20-tpl.md
git add -A && git commit -qm "red: template story" >/dev/null
printf 'tpl\n' > src/tpl.txt
out="$(bash scripts/cycle.sh close-story docs/specs/red/red-20-tpl.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^status: done' docs/specs/red/red-20-tpl.md && git show --name-only --format= HEAD | grep -qx src/tpl.txt \
  && echo "  ok    the template story closes and commits, no receipt asked" || { echo "::error::template close: exit=$ex $(printf '%s\n' "$out" | tail -3)"; fail=1; }

echo "red-receipt: close-story on a marked story - the sealed test edited, no implementation change, then a real change closes"
st=docs/specs/red/red-12.md
red_story 12 "$MK" "$FI" '`bash tests/red.sh`'
git add -A && git commit -qm "red: gate story" >/dev/null
bash scripts/cycle.sh stamp-red "$st" >/dev/null 2>&1 && echo "  ok    red-12 stamped" || { echo "::error::red-12 stamp failed"; fail=1; }
printf '# edited after the stamp\n' >> tests/red.sh
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"test changed after red receipt: re-run stamp-red"' \
  && echo "  ok    a sealed test edited after the stamp: exit 4" || { echo "::error::test edit: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
red_test_file
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"no implementation change since red receipt"' \
  && echo "  ok    the implementation unchanged since the stamp: exit 4" || { echo "::error::no change: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
printf 'done\n' > src/red.txt
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:"$st" | grep -q '^## Red receipt' && git show HEAD:"$st" | grep -q '^status: done' \
  && echo "  ok    receipt + changed implementation + green: closed, the receipt in the commit" || { echo "::error::close: exit=$ex $(printf '%s\n' "$out" | tail -3)"; fail=1; }

echo "red-receipt: close-story on a marked story that was never stamped"
st=docs/specs/red/red-11.md
red_story 11 "$MK" "$FI" '`bash tests/red.sh`'
git add -A && git commit -qm "red: unstamped story" >/dev/null
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(git rev-parse HEAD)" = "$head_before" ] && echo "  ok    the unstamped story: exit 4, nothing committed" \
  || { echo "::error::unstamped story: exit=$ex, head moved: $(git log -1 --format=%s)"; fail=1; }
printf '%s\n' "$out" | tail -1 | expect "the refusal names stamp-red and the story" \
  '"error":"no red receipt: run cycle.sh stamp-red docs/specs/red/red-11.md after writing the failing test"'
fi # part red

[ -e "$MARK" ] && fail=1
exit $fail
