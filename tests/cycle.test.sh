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
  else echo "::error::$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fail=1; fi
}
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

exit $fail
