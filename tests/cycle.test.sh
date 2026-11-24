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
PARTS="ship ship2 hooklog paperwork gates manual close close2 scope approved bsd safety red red2 red3 runstate merge-gate" # one topic each; every part rebuilds the shared setup below
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
done_story() { # done_story <story-file> [<printf-format> <args>...] - a `done` fixture story: written from the
  # format (or, with none, its status: line set to done) and committed alone under `story(<id>): <title>`,
  # since a done story without close-story's own commit is in progress (ADR-032 D2)
  local f="$1" fmt id title; shift
  if [ $# -gt 0 ]; then fmt="$1"; shift; printf -- "$fmt" "$@" > "$f"
  else sed_inplace 's/^status: [a-z-]*$/status: done/' "$f"; fi
  id="$(sed -n 's/^story:[[:space:]]*//p' "$f" | head -n 1)"
  title="$(sed -n 's/^# //p' "$f" | head -n 1)"; [ -n "$title" ] || title="$id"
  git add -- "$f" && git commit -qm "story($id): $title" -- "$f" >/dev/null
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
done_story docs/specs/demo/demo-01-first.md
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
ship | expect "no workflow dir: the ci line is not checked, still READY" "ci: not checked - no CI workflow in this repo"

echo "ci (post-045-tails ask 7): with a workflow and a GitHub origin, ship-check wants a green run on HEAD, or on the newest commit with only paperwork after it"
CIR="$(mktemp -d)"; CIBIN="$(mktemp -d)"; mkdir -p "$CIBIN/runs"
# A fake gh: `run list --commit <sha> ...` prints $FAKE_GH_DIR/<sha> as the --jq form (status, conclusion,
# workflow, createdAt, tab-separated); FAKE_GH_RC makes it fail as a logged-out gh does.
printf '#!/bin/sh\n[ -n "${FAKE_GH_RC:-}" ] && { echo "fake gh: HTTP 401" >&2; exit "$FAKE_GH_RC"; }\nsha=""\nwhile [ $# -gt 0 ]; do [ "$1" = --commit ] && sha="$2"; shift; done\n[ -f "$FAKE_GH_DIR/$sha" ] && cat "$FAKE_GH_DIR/$sha"\nexit 0\n' > "$CIBIN/gh"
chmod +x "$CIBIN/gh"
cp -R "$T/." "$CIR/"
cig() { git -C "$CIR" "$@"; }
cis() { (cd "$CIR" && PATH="$CIBIN:$PATH" FAKE_GH_DIR="$CIBIN/runs" bash scripts/ship-check.sh docs/specs/demo); }
mkdir -p "$CIR/.github/workflows"; printf 'on: push\n' > "$CIR/.github/workflows/ci.yml"
cig add -A && cig commit -qm "ci workflow"
W="$(cig rev-parse HEAD)"; w7="$(cig rev-parse --short HEAD)"
(cd "$CIR" && bash scripts/human-check.sh docs/specs/demo ACCEPTED "looked at the ci fixture") >/dev/null
cig add -A && cig commit -qm "record the check"
H="$(cig rev-parse HEAD)"; h7="$(cig rev-parse --short HEAD)"
cis | expect "a workflow and no origin -> ci not checked - no GitHub remote" "ci   ok       ci: not checked - no GitHub remote"
cig remote add origin https://gitlab.com/example/demo.git
cis | expect "a non-GitHub origin -> ci not checked - no GitHub remote" "ci   ok       ci: not checked - no GitHub remote"
cig remote set-url origin https://github.com/example/demo.git
printf 'completed\tsuccess\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$H"
cis | expect "a green run on HEAD -> ci ok" "ci   ok       ci: green on $h7 (CI)"
cis | expect "a green run on HEAD -> READY" "READY."
rm -f "$CIBIN/runs/$H"; printf 'completed\tsuccess\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "a green run on a commit followed only by paperwork -> ci ok" "ci   ok       ci: green on $w7 (CI)"
printf 'completed\tfailure\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "a failed CI run -> ci OPEN naming the workflow" "ci   OPEN     ci: CI failure on $w7"
cis | expect "a failed CI run -> NOT READY" "NOT READY"
printf 'in_progress\t\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "a run still in progress -> ci OPEN" "ci   OPEN     ci: CI in_progress on $w7"
# post-046-tails ask 1: only the newest run of each workflow on the commit is judged; the rows are written
# oldest first, the way gh does not print them, so the order is the script's own sort.
printf 'completed\tfailure\tCI\t2026-11-01T10:00:00Z\ncompleted\tsuccess\tCI\t2026-11-01T11:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "a red run re-dispatched green on the same commit -> ci ok" "ci   ok       ci: green on $w7 (CI)"
printf 'completed\tsuccess\tCI\t2026-11-01T10:00:00Z\ncompleted\tfailure\tCI\t2026-11-01T11:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "a green run followed by a newer red run of the same workflow -> ci OPEN" "ci   OPEN     ci: CI failure on $w7"
printf 'completed\tsuccess\tLint\t2026-11-01T12:00:00Z\ncompleted\tsuccess\tCI\t2026-11-01T10:00:00Z\ncompleted\tfailure\tCI\t2026-11-01T11:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "two workflows, the newest run of one red -> ci OPEN naming only that one" "ci   OPEN     ci: CI failure on $w7"
printf 'completed\tsuccess\tLint\t2026-11-01T12:00:00Z\ncompleted\tsuccess\tCI\t2026-11-01T11:00:00Z\ncompleted\tfailure\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$W"
cis | expect "two workflows, both newest runs green -> ci ok naming both" "ci   ok       ci: green on $w7 (CI, Lint)"
rm -f "$CIBIN/runs/$W"
cis | expect "no run for the head -> ci OPEN no CI run" "ci   OPEN     ci: no CI run for $h7"
printf 'completed\tsuccess\tCI\t2026-11-01T10:00:00Z\n' > "$CIBIN/runs/$W"
(cd "$CIR" && PATH="$CIBIN:$PATH" FAKE_GH_DIR="$CIBIN/runs" FAKE_GH_RC=1 bash scripts/ship-check.sh docs/specs/demo) \
  | expect "gh failing -> ci OPEN cannot confirm CI" "ci   OPEN     ci: cannot confirm CI: gh run list exit 1: fake gh: HTTP 401"
printf 'v3\n' > "$CIR/app.txt"; cig add -A && cig commit -qm "a code change after the green run"
c7="$(cig rev-parse --short HEAD)"
cis | expect "a green run followed by a code commit -> ci OPEN no CI run for the head" "ci   OPEN     ci: no CI run for $c7"
rm -rf "$CIR" "$CIBIN"

echo "defects (tails-1115-09, T100): ship-check runs the repo-wide defect gate; red or unable to run is NOT READY"
DGR="$(mktemp -d)"; DGLIB="$(mktemp -d)"; DGBIN="$(mktemp -d)"
cp -R "$T/." "$DGR/"
dgg() { git -C "$DGR" "$@"; }
dgs() { (cd "$DGR" && bash scripts/ship-check.sh docs/specs/demo); }
mkdir -p "$DGR/.claude/hooks"
cp "$SRC/scripts/defects-check.sh" "$DGR/scripts/" && cp "$SRC/.claude/hooks/defects_lib.py" "$DGR/.claude/hooks/"
dgg add -A && dgg commit -qm "the defect gate"
(cd "$DGR" && bash scripts/human-check.sh docs/specs/demo ACCEPTED "looked at the defect gate fixture") >/dev/null
dgg add -A && dgg commit -qm "record the check"
# The library lives outside the fixture repo (DEFECTS_DIR, absolute): the tree stays clean, every line in it is new.
printf '# Defect library\n' > "$DGLIB/README.md"
DEFECTS_DIR="$DGLIB" dgs | expect "a green defect gate -> defects ok" "defects ok       defects: the defect gate is green - GREEN: 0 blocking checks"
DEFECTS_DIR="$DGLIB" dgs | expect "a green defect gate -> READY as today" "READY."
printf -- '---\nid: dg-red\ntitle: A card no hook can deliver\nstatus: text\n---\n# A card no hook can deliver\n' > "$DGLIB/dg-red.md"
DEFECTS_DIR="$DGLIB" dgs | expect "a red defect gate -> defects OPEN naming the gate" "defects OPEN     defects: the defect gate is RED - RED: 1 undeliverable"
DEFECTS_DIR="$DGLIB" dgs | expect "a red defect gate -> NOT READY" "NOT READY - 1 open confirmation(s)"
rm -f "$DGLIB/dg-red.md"
for p in python3 python py; do printf '#!/bin/sh\nexit 1\n' > "$DGBIN/$p"; chmod +x "$DGBIN/$p"; done
(cd "$DGR" && env -u VULYK_PY PATH="$DGBIN:$PATH" DEFECTS_DIR="$DGLIB" bash scripts/ship-check.sh docs/specs/demo) > "$DGBIN/nopy.out" 2>&1
expect "no Python (the gate exits 2) -> defects OPEN, cannot confirm" \
  "defects OPEN     defects: cannot confirm the defect gate - defects-check.sh exit 2: defects-check: python 3 not found" < "$DGBIN/nopy.out"
expect "no Python -> NOT READY" "NOT READY" < "$DGBIN/nopy.out"
rm -rf "$DGR" "$DGLIB" "$DGBIN"
ship | expect "no scripts/defects-check.sh: the defects line is not checked, still READY" "defects ok       defects: not checked - no scripts/defects-check.sh in this repo"
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
# P9-14: a spec dir with a space is one spec, not two missing ones; a BSD-only stat still reads the mtime.
mkdir -p "docs/specs/a b"
done_story "docs/specs/a b/ab 01 x.md" '---\nstory: ab-01\nspec: a b\nstatus: done\n---\n'
bash scripts/state.sh >/dev/null
st_ab="$(sed -n '/"spec": "a b"/,/"stage"/p' .claude/state.json | tr -d ' \n')"
case "$st_ab" in
  *'"stories":1,"done":1,'*) echo "  ok    state.sh reads a spec dir and a story file with spaces in their names" ;;
  *) echo "::error::state.sh lost the spaced spec: ${st_ab:-absent}"; fail=1 ;;
esac
BSDBIN="$(mktemp -d)"   # date without -r <file> and stat without -c: the BSD pair
printf '#!/bin/sh\ncase " $* " in *" -r "*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v date)" > "$BSDBIN/date"
# -f %m is answered by the real stat as GNU (-c %Y) or, on a Mac, as itself; any other call fails like a BSD stat's
printf '#!/bin/sh\n[ "$1" = -f ] && [ "$2" = %%m ] && { %s -c %%Y "$3" 2>/dev/null || exec %s -f %%m "$3"; exit 0; }\nexit 1\n' \
  "$(command -v stat)" "$(command -v stat)" > "$BSDBIN/stat"
chmod +x "$BSDBIN/date" "$BSDBIN/stat"
touch -t 209901010000 "docs/specs/a b/ab 01 x.md"   # newer than any snapshot
PATH="$BSDBIN:$PATH" bash scripts/state.sh >/dev/null
sed -n '/"spec": "a b"/,/"stage"/p' .claude/state.json | expect "state.sh with a BSD stat: a story newer than the snapshot is stale" '"stale": true'
# P9-15: release-check.sh read the same spaced dir as two missing paths and left it out of the count.
cp "$SRC/scripts/release-check.sh" scripts/
bash scripts/release-check.sh | grep -E '^  a b +no ' >/dev/null && echo "  ok    release-check.sh lists a spec dir with a space in its name" \
  || { echo "::error::release-check.sh lost the spaced spec: $(bash scripts/release-check.sh)"; fail=1; }
rm -f scripts/release-check.sh
rm -rf "docs/specs/a b" "$BSDBIN"
git add -A && git commit -qm "drop the spaced fixture" >/dev/null

# A stale pack (a story cut after the look) reopens 04 and 05 both.
done_story docs/specs/demo/demo-02-repair.md '---\nstory: demo-02\nspec: demo\nstatus: done\nwave: 2\n---\n# S2\n'
ship | expect "new story stales acceptance"      "STALE - given against pack"
ship | expect "new story stales the check"       "STALE (pack)"

echo "council row closes 04+05 together (ADR-001 D4); **Checked:** still overrides"
mkdir -p docs/specs/council-demo
printf '> build the council demo\n' > docs/specs/council-demo/brief.md
cp "$SRC"/templates/plan.md docs/specs/council-demo/plan.md
sed_inplace 's/^\*\*Briefed:\*\* <.*/**Briefed:** via grill, owner, 2026-01-01/' docs/specs/council-demo/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/council-demo/plan.md
done_story docs/specs/council-demo/council-demo-01-first.md '---\nstory: council-demo-01\nspec: council-demo\nstatus: done\nwave: 1\n---\n# S1\n'
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
done_story docs/specs/gate-demo/gate-demo-01-first.md '---\nstory: gate-demo-01\nspec: gate-demo\nstatus: done\nwave: 1\n---\n# S1\n'
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
done_story docs/specs/gate-demo/gate-demo-02-repair.md '---\nstory: gate-demo-02\nspec: gate-demo\nstatus: done\nwave: 2\n---\n# S2\n'
G="$(shipg)"
printf '%s' "$G" | expect "a new story after ACCEPTED: 05 names STALE (pack)" "STALE (pack)"
printf '%s' "$G" | expect "a new story after ACCEPTED: NOT READY" "NOT READY"

echo "the paperwork whitelist is anchored to docs/specs/*/ (R23/m-2): a commit under src/council/ or a bare src/journal.md is never paperwork, even though it shares the names"
mkdir -p docs/specs/anchor-demo
cp "$SRC"/templates/plan.md docs/specs/anchor-demo/plan.md
printf '> build the anchor demo\n' > docs/specs/anchor-demo/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/anchor-demo/plan.md
done_story docs/specs/anchor-demo/anchor-demo-01-first.md '---\nstory: anchor-demo-01\nspec: anchor-demo\nstatus: done\nwave: 1\n---\n# S1\n'
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

if part ship2; then # --- part ship2 (ship, cut at the docs-1115 merge run): --show, the Approved/--go gate, /vulyk-ship pins, tag-push-check, ci.yml
echo "--show (uncommitted-work-guard-02): the pack's change as text, pasted into the reply before ACCEPTED"
(
  mkdir -p "$T/show" && cd "$T/show" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name t && git config core.autocrlf false
  mkdir -p scripts docs/specs/s && cp "$T"/scripts/lib.sh "$T"/scripts/human-check.sh "$T"/scripts/redact.sh scripts/
  printf 'v1\n' > app.txt && git add -A && git commit -qm base
  git checkout -q -b vulyk/s
  cp "$SRC"/templates/plan.md docs/specs/s/plan.md && printf 'v2\n' > app.txt
  git add -A && git commit -qm work
  out="$(bash scripts/human-check.sh --show docs/specs/s)"
  printf '%s' "$out" | expect "--show prints the stat line" "2 files changed"
  printf '%s' "$out" | expect "--show prints the diff" "+v2"
  if printf '%s' "$out" | grep -qF "scripts/lib.sh"; then expect "--show leaves out what the base already had" "<never>" < /dev/null
  else echo "  ok    --show leaves out what the base already had"; fi
  if printf '%s' "$out" | grep -qF "more lines cut"; then expect "--show under the cap cuts nothing" "<never>" < /dev/null
  else echo "  ok    --show under the cap cuts nothing"; fi
  i=0; while [ "$i" -lt 400 ]; do i=$((i + 1)); echo "line $i"; done > big.txt
  git add -A && git commit -qm big
  bash scripts/human-check.sh --show docs/specs/s | tail -n 1 | expect "--show over the cap ends with the cut line" "more lines cut; the rest: git diff"
  out="$(bash scripts/human-check.sh --show docs/specs/nope 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "--show on a missing spec dir names it" "no spec dir 'docs/specs/nope'"
  printf '%s' "$out" | expect "--show on a missing spec dir exits non-zero" "exit=2"
)


echo "ADR-032 D4 (mass-audit-fixes-08): a Tier 2-4 plan opens its build only on **Approved:** or an explicit --go, and ship-check stage 02 wants the same"
(
  mkdir -p "$T/go" && cd "$T/go" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
  mkdir -p scripts memory/stats
  cp "$SRC"/scripts/lib.sh "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/ship-check.sh "$SRC"/scripts/redact.sh scripts/
  for g in t3 t3old t3ship t1 t0; do
    mkdir -p "docs/specs/$g"; cp "$SRC"/templates/plan.md "docs/specs/$g/plan.md"
    printf '# %s\n\n## Request\n> build %s\n\n## Asks\n1. one ask\n' "$g" "$g" > "docs/specs/$g/brief.md"
  done
  for g in t3 t3old t3ship; do sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/' "docs/specs/$g/plan.md"; done
  sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\11/' docs/specs/t1/plan.md
  for g in t3old t3ship; do sed_inplace 's/^\*\*Briefed:\*\* <.*/**Briefed:** via grill, owner, 2026-01-01/' "docs/specs/$g/plan.md"; done
  sed_inplace 's/^\*\*Shipped:\*\* <.*/**Shipped:** v1.0.0, 2026-01-02, at abc1234/' docs/specs/t3ship/plan.md
  git add -A && git commit -qm "go: five plans" >/dev/null
  go_msg='Tier 3 plan needs **Approved:** or an explicit --go'
  out="$(bash scripts/cycle.sh briefed docs/specs/t3 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "briefed on a Tier 3 plan with no Approved: exit 2 - needs **Approved:** or an explicit --go" "exit=2"
  printf '%s' "$out" | expect "briefed on a Tier 3 plan with no Approved names the rule" "$go_msg"
  [ -z "$(marker docs/specs/t3/plan.md Briefed)" ] && echo "  ok    the refusal writes no Briefed line" \
    || expect "the refusal writes no Briefed line" "<never>" < /dev/null
  out="$(bash scripts/cycle.sh branch docs/specs/t3old 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "branch on a Tier 3 plan briefed without --go: exit 2 - needs **Approved:** or an explicit --go" "exit=2"
  printf '%s' "$out" | expect "branch names the same rule" "$go_msg"
  [ "$(git rev-parse --abbrev-ref HEAD)" = main ] && echo "  ok    the refused branch checks nothing out" \
    || expect "the refused branch checks nothing out" "<never>" < /dev/null
  bash scripts/ship-check.sh docs/specs/t3old | expect "ship-check 02 fails a Tier 3 plan briefed without approval or --go" \
    "02   OPEN     plan: Tier 3 was briefed without approval or --go - run cycle.sh briefed <spec> --go --commit if the owner opted out"
  bash scripts/ship-check.sh docs/specs/t3ship | expect "ship-check 02 passes a shipped Tier 3 plan briefed without --go" "02   ok"
  out="$(bash scripts/cycle.sh briefed docs/specs/t3 --go 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "briefed --go on a Tier 3 plan exits 0" "exit=0"
  grep -qE '^\*\*Briefed:\*\* via grill \(--go\), Test Owner|^\*\*Briefed:\*\* via grill \(--go\), ' docs/specs/t3/plan.md \
    && echo "  ok    briefed --go writes via grill (--go)" || expect "briefed --go writes via grill (--go)" "<never>" < /dev/null
  bash scripts/ship-check.sh docs/specs/t3 | expect "ship-check 02 passes a Tier 3 plan briefed with --go" "02   ok       plan: briefed - via grill (--go)"
  out="$(bash scripts/cycle.sh briefed docs/specs/t3old --go 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "briefed --go on an existing Briefed line exits 0" "exit=0"
  bash scripts/cycle.sh briefed docs/specs/t3old --go >/dev/null 2>&1
  [ "$(grep -c '^\*\*Briefed:\*\*' docs/specs/t3old/plan.md)" = 1 ] && grep -q '^\*\*Briefed:\*\* via grill (--go), ' docs/specs/t3old/plan.md \
    && echo "  ok    --go re-stamps the existing Briefed line, one line" || expect "--go re-stamps the existing Briefed line: $(grep '^\*\*Briefed:\*\*' docs/specs/t3old/plan.md)" "<never>" < /dev/null
  [ "$(grep -c 'briefed --go recorded' docs/specs/t3old/journal.md 2>/dev/null)" = 1 ] \
    && echo "  ok    the re-stamp journals briefed --go recorded once (a second --go is idempotent)" \
    || expect "the re-stamp journals briefed --go recorded once: $(cat docs/specs/t3old/journal.md 2>/dev/null)" "<never>" < /dev/null
  out="$(bash scripts/cycle.sh branch docs/specs/t3old 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "branch on the --go plan exits 0" "exit=0"
  git checkout -q main
  out="$(bash scripts/cycle.sh briefed docs/specs/t1 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "a Tier 1 plan: briefed without --go exits 0 as before" "exit=0"
  grep -q '^\*\*Briefed:\*\* via grill, ' docs/specs/t1/plan.md && echo "  ok    the Tier 1 line is the plain via grill" \
    || expect "the Tier 1 line is the plain via grill" "<never>" < /dev/null
  out="$(bash scripts/cycle.sh briefed docs/specs/t0 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "a plan with no tier: briefed without --go exits 0 as before" "exit=0"
  bash scripts/ship-check.sh docs/specs/t1 | expect "ship-check 02 passes a Tier 1 plan briefed without --go" "02   ok"
  bash scripts/ship-check.sh docs/specs/t0 | expect "ship-check 02 passes a no-tier plan briefed without --go" "02   ok"
  out="$(bash scripts/cycle.sh branch docs/specs/t1 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "branch on a Tier 1 plan briefed without --go exits 0 as before" "exit=0"
)

echo "audit-fixes-1113-03: /vulyk-ship pins - the spec-branch push rule, the outward-text review before publish, no skills.json commit"
flat() { tr -d '\r' < "$1" | tr '\n' ' ' | tr -s ' '; }   # the file as one line, CR dropped: a sentence wrapped over lines still matches
SHIPMD="$(flat "$SRC/.claude/commands/vulyk-ship.md")"; PRCARD="$(flat "$SRC/docs/defects/public-release-per-change.md")"
# audit-fixes-1113-17: a stock Git for Windows checkout (core.autocrlf=true) has CRLF in vulyk-ship.md; the flat text is the same
SHIPCRLF="$(mktemp)"; awk '{ printf "%s\r\n", $0 }' "$SRC/.claude/commands/vulyk-ship.md" > "$SHIPCRLF"
[ "$(flat "$SHIPCRLF")" = "$(tr -d '\r' < "$SRC/.claude/commands/vulyk-ship.md" > "$SHIPCRLF.lf"; flat "$SHIPCRLF.lf")" ] \
  && echo "  ok    vulyk-ship pins: a CRLF checkout of the page flattens to the same text as an LF one" \
  || { echo "::error::vulyk-ship pins: the CRLF copy flattens with carriage returns left in"; fail=1; }
rm -f "$SHIPCRLF" "$SHIPCRLF.lf"
pin() { # pin <label> <text> <needle>
  case "$2" in *"$3"*) echo "  ok    $1" ;; *) echo "::error::$1 - '$3' is gone"; fail=1 ;; esac
}
pin "vulyk-ship: the spec branch is pushed only to a private origin" "$SHIPMD" 'A private origin: run it yourself, `git push -u origin <branch>`'
pin "vulyk-ship: a public origin gets a question to the owner, not a push" "$SHIPMD" '`PUBLIC` (or no answer): never push the spec branch there, since it carries every unpublished commit of the default branch; ask the owner'
[ "$(grep -c 'git push -u origin' "$SRC/.claude/commands/vulyk-ship.md")" = 1 ] \
  && grep 'git push -u origin' "$SRC/.claude/commands/vulyk-ship.md" | grep -qF 'A private origin:' \
  && echo "  ok    vulyk-ship: no instruction pushes a spec branch to origin unconditionally" \
  || { echo "::error::vulyk-ship: a push to origin outside the private-origin sentence: $(grep -n 'git push' "$SRC/.claude/commands/vulyk-ship.md")"; fail=1; }
pin "card public-release-per-change: the Never line on spec branches" "$PRCARD" '- Push a spec branch to a public origin for its CI run'
pin "vulyk-ship: the review names the CHANGELOG section" "$SHIPMD" 'the `CHANGELOG.md` section going out'
pin "vulyk-ship: the review names the release notes" "$SHIPMD" 'the release notes, and the `UNASKED:` and Minor lines'
pin "vulyk-ship: the review names the spec folders' UNASKED/Minor lines" "$SHIPMD" 'the `UNASKED:` and Minor lines of the spec folders being published'
pin "vulyk-ship: the review's one rule" "$SHIPMD" 'flag every line that names a gate bypass or a hole not fixed in the version being published'
pin "vulyk-ship: a flagged line moves to private notes" "$SHIPMD" 'moves each flagged line to a private file under `~/.vulyk/` and removes it from the outward text'
pin "vulyk-ship: the publish command only after a clean pass" "$SHIPMD" 'the publish command is printed only after a clean pass'
rv="$(grep -n 'Before the publish command is printed, dispatch `lead-review`' "$SRC/.claude/commands/vulyk-ship.md" | head -1 | cut -d: -f1)"
pb="$(grep -n 'Under a `to publish, run:` heading' "$SRC/.claude/commands/vulyk-ship.md" | head -1 | cut -d: -f1)"
[ -n "$rv" ] && [ -n "$pb" ] && [ "$rv" -lt "$pb" ] && echo "  ok    vulyk-ship: the lead-review step comes before the publish command is printed" \
  || { echo "::error::vulyk-ship: review line=$rv, publish heading line=$pb"; fail=1; }
pin "card public-release-per-change: the Never line on the outward-text review" "$PRCARD" '- Print or run a publish before `lead-review` has passed the outward text clean'
grep -qiE 'skills\.json' "$SRC/.claude/commands/vulyk-ship.md" \
  && { echo "::error::vulyk-ship names skills.json: $(grep -n 'skills' "$SRC/.claude/commands/vulyk-ship.md")"; fail=1; } \
  || echo "  ok    vulyk-ship names no step that stages or commits skills.json"

echo "tails-1115-09 (T26, plan P1): a push carrying a -dev.N tag, or more than one version tag, is refused"
TP="$SRC/scripts/tag-push-check.sh"; Z40=0000000000000000000000000000000000000000; A40=1111111111111111111111111111111111111111
tpc() { # tpc <label> <want-exit> [<pre-push line>...] - feeds the lines to tag-push-check.sh, judges the exit
  local label="$1" want="$2" rc=0 out; shift 2
  out="$( { [ $# -eq 0 ] || printf '%s\n' "$@"; } | bash "$TP" 2>&1)" || rc=$?
  if [ "$rc" = "$want" ] && { [ "$want" = 0 ] || [ -n "$out" ]; }; then echo "  ok    $label"
  else echo "::error::$label - exit $rc (want $want), output: $out"; fail=1; fi
}
tpc "tag-push-check: a dev tag is refused at push (exit 1 with a reason)" 1 "refs/tags/v0.52.0-dev.3 $A40 refs/tags/v0.52.0-dev.3 $Z40"
tpc "tag-push-check: two release tags in one push are refused" 1 \
  "refs/tags/v0.51.0 $A40 refs/tags/v0.51.0 $Z40" "refs/tags/v0.52.0 $A40 refs/tags/v0.52.0 $Z40"
tpc "tag-push-check: one release tag passes" 0 "refs/tags/v0.52.0 $A40 refs/tags/v0.52.0 $Z40"
tpc "tag-push-check: a branch push passes" 0 "refs/heads/main $A40 refs/heads/main $Z40"
tpc "tag-push-check: deleting a leaked dev tag passes" 0 "(delete) $Z40 refs/tags/v0.52.0-dev.3 $A40"
tpc "tag-push-check: empty input passes" 0
tpc "tag-push-check: a dev tag pushed under another name is refused" 1 "refs/tags/v0.52.0-dev.3 $A40 refs/tags/v0.52.0 $Z40"
out="$(printf 'refs/tags/v0.52.0-dev.3 %s refs/tags/v0.52.0-dev.3 %s\n' "$A40" "$Z40" | bash "$TP" 2>&1)"
printf '%s' "$out" | expect "tag-push-check: the reason names the dev tag" "refs/tags/v0.52.0-dev.3"
# the hook through a real push: a bare remote, the hook copied where /vulyk-ship step 2a puts it
HP="$(mktemp -d)"; git init -q --bare "$HP/remote.git"; git init -q -b main "$HP/clone"
hpg() { git -C "$HP/clone" "$@"; }
hpg config user.email t@t && hpg config user.name "Test Owner" && hpg config core.autocrlf false
mkdir -p "$HP/clone/scripts" && cp "$TP" "$HP/clone/scripts/" && printf 'v1\n' > "$HP/clone/app.txt"
hpg add -A && hpg commit -qm init && hpg remote add origin "$HP/remote.git"
cp "$SRC/scripts/git-hooks/pre-push" "$HP/clone/.git/hooks/pre-push" && chmod +x "$HP/clone/.git/hooks/pre-push"
hpg tag v0.52.0-dev.3 && hpg tag v0.52.0
rc=0; hpg push -q origin refs/tags/v0.52.0-dev.3 > "$HP/out" 2>&1 || rc=$?
[ "$rc" != 0 ] && ! git -C "$HP/remote.git" rev-parse -q --verify refs/tags/v0.52.0-dev.3 >/dev/null \
  && echo "  ok    pre-push hook: a real push of a dev tag is refused and the tag never reaches the remote" \
  || { echo "::error::pre-push hook: the dev tag push exited $rc: $(cat "$HP/out")"; fail=1; }
rc=0; hpg push -q origin main refs/tags/v0.52.0 > "$HP/out" 2>&1 || rc=$?
[ "$rc" = 0 ] && echo "  ok    pre-push hook: the branch and one release tag go through" \
  || { echo "::error::pre-push hook: the branch + one tag push exited $rc: $(cat "$HP/out")"; fail=1; }
hpg push -q --no-verify origin refs/tags/v0.52.0-dev.3 >/dev/null 2>&1   # a leak past the hook, the named way off
rc=0; hpg push -q origin :refs/tags/v0.52.0-dev.3 > "$HP/out" 2>&1 || rc=$?
[ "$rc" = 0 ] && ! git -C "$HP/remote.git" rev-parse -q --verify refs/tags/v0.52.0-dev.3 >/dev/null \
  && echo "  ok    pre-push hook: a leaked dev tag can still be deleted from the remote" \
  || { echo "::error::pre-push hook: deleting the leaked dev tag exited $rc: $(cat "$HP/out")"; fail=1; }
rc=0; printf 'refs/heads/main %s refs/heads/main %s\n' "$A40" "$Z40" | (cd "$HP/clone" && bash "$SRC/scripts/git-hooks/pre-push" origin x) >/dev/null 2>&1 || rc=$?
rc2=0; printf 'refs/tags/v1.0.0-dev.1 %s refs/tags/v1.0.0-dev.1 %s\n' "$A40" "$Z40" | (cd "$HP/clone" && bash "$SRC/scripts/git-hooks/pre-push" origin x) >/dev/null 2>&1 || rc2=$?
hrc="$rc $rc2"
[ "$hrc" = "0 1" ] && echo "  ok    pre-push hook: passes its stdin to the check and returns its exit code" \
  || { echo "::error::pre-push hook: exits '$hrc', want '0 1'"; fail=1; }
rm -f "$HP/clone/scripts/tag-push-check.sh"; rc=0
printf 'refs/heads/main %s refs/heads/main %s\n' "$A40" "$Z40" | (cd "$HP/clone" && bash "$SRC/scripts/git-hooks/pre-push" origin x) > "$HP/out" 2>&1 || rc=$?
[ "$rc" = 1 ] && grep -q 'tag-push-check.sh' "$HP/out" && echo "  ok    pre-push hook: with no tag-push-check.sh it refuses and names the script" \
  || { echo "::error::pre-push hook: with no check script exited $rc: $(cat "$HP/out")"; fail=1; }
rm -rf "$HP"
pin "vulyk-ship 2a: the hook is copied where the local tag is made" "$SHIPMD" 'cp scripts/git-hooks/pre-push "$(git rev-parse --git-path hooks)/pre-push"'
pin "vulyk-ship 2a: what the hook refuses" "$SHIPMD" 'refuses a push carrying a `-dev.N` tag or more than one version tag'
pin "vulyk-ship 2a: an existing different pre-push hook is named, not replaced" "$SHIPMD" 'a different `pre-push` hook already there is not replaced: name it to the owner'
pin "card public-release-per-change: names the hook, its test and its way off" "$PRCARD" \
  '`scripts/git-hooks/pre-push`, copied by `/vulyk-ship` step 2a, runs `scripts/tag-push-check.sh` (tests/cycle.test.sh part `ship`); `git push --no-verify` and a clone without the hook switch it off'

echo "tails-1115-09 (S18, T51, T100): ci.yml - actions pinned by SHA, the defect gate in the shell job, a Windows install smoke"
CIY="$SRC/.github/workflows/ci.yml"
unpinned="$(tr -d '\r' < "$CIY" | grep -E '^[[:space:]]*(- )?uses:' | grep -vE 'uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40} # v?[0-9]+(\.[0-9]+)*$')"
[ "$(tr -d '\r' < "$CIY" | grep -cE '^[[:space:]]*(- )?uses:')" -gt 0 ] && [ -z "$unpinned" ] \
  && echo "  ok    ci.yml: every uses: ends in a 40-hex SHA and a # <version> comment" \
  || { echo "::error::ci.yml: uses: lines not pinned by SHA + version comment:"; printf '%s\n' "$unpinned" | sed 's/^/        /'; fail=1; }
job() { tr -d '\r' < "$CIY" | awk -v j="  $1:" '$0 == j { f = 1; next } f && /^  [A-Za-z0-9_-]+:$/ { f = 0 } f'; }
job shell | grep -qE '^[[:space:]]+run: bash scripts/defects-check\.sh$' \
  && echo "  ok    ci.yml: the shell job runs bash scripts/defects-check.sh" \
  || { echo "::error::ci.yml: the shell job does not run bash scripts/defects-check.sh"; fail=1; }
job install-smoke | grep -qE '^[[:space:]]+os: \[.*windows-latest.*\]$' && job install-smoke | grep -qE '^[[:space:]]+shell: bash$' \
  && echo "  ok    ci.yml: install-smoke lists a Windows runner with a bash shell" \
  || { echo "::error::ci.yml: install-smoke has no windows-latest runner with shell: bash"; fail=1; }
fi # part ship2

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

echo "audit-fixes-1113-03 (flips skills-json-exempt): a tracked, modified skills.json is no paperwork - is_paperwork_path says no, scope-check counts it out of scope"
printf '{"n":0}\n' > memory/stats/skills.json
git add -f memory/stats/skills.json && git commit -qm "an old hive still tracks skills.json" -- memory/stats/skills.json >/dev/null
printf '{"n":1}\n' > memory/stats/skills.json
is_paperwork_path memory/stats/skills.json && { echo "::error::is_paperwork_path still calls memory/stats/skills.json paperwork"; fail=1; } \
  || echo "  ok    is_paperwork_path: memory/stats/skills.json is not paperwork"
bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md | expect "scope-check: skills.json dirty and undeclared is out of scope" "! memory/stats/skills.json"
git checkout -- memory/stats/scope.jsonl   # scope-check logs its run; that log is not this case's dirt
git checkout -- memory/stats/skills.json
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
echo "P9-08: a commit renaming code into a paperwork path stales a round, and scope-check still counts the code path"
git commit -qm "code moved into a hive glob path" >/dev/null
paperwork_only "$PWD" "$pw_base" HEAD && { echo "::error::paperwork_only called code renamed into a hive glob path paperwork"; fail=1; } \
  || echo "  ok    a commit renaming code into a hive glob path is not paperwork_only"
bash scripts/scope-check.sh docs/specs/hooklog/hooklog-01-first.md HEAD~1..HEAD | expect "scope-check counts the code path a rename moved away" "changed 1,"
git checkout -- memory/stats/scope.jsonl
git mv docs/specs/hooklog/runs/moved.txt hook-app.txt && git commit -qm "move the code back" >/dev/null
git rm -rq -- ${pw_paths[@]+"${pw_paths[@]}"} && git commit -qm "drop the smoke reports" -- ${pw_paths[@]+"${pw_paths[@]}"}
rm -rf docs/specs/hooklog/smoke
git rm -q .claude/vulyk-paperwork && git commit -qm "drop the hive paperwork globs" -- .claude/vulyk-paperwork
git checkout -- memory/stats/scope.jsonl
rm -f memory/stats/anomalies.jsonl; git checkout -- memory/stats/anomalies.jsonl 2>/dev/null
printf '{"n":2}\n' > memory/stats/skills.json
[ "$(git status --porcelain)" = " M memory/stats/skills.json" ] && echo "  ok    precondition: the tracked skills.json is the only dirty path" \
  || { echo "::error::precondition: dirty paths are $(git status --porcelain | tr '\n' ' ')"; fail=1; }
shiph | expect "skills.json alone dirty -> 03 not clean (no exception for it any more)" "working tree is not clean"
printf '{"ts":"z"}\n' >> memory/stats/anomalies.jsonl
shiph | expect "anomaly log + skills.json dirty -> 03 still not clean" "working tree is not clean"
printf 'v3\n' >> hook-app.txt
shiph | expect "skills.json + real code dirt -> 03 still not clean" "working tree is not clean"
git checkout -- hook-app.txt memory/stats/skills.json
git rm -q memory/stats/skills.json && git commit -qm "the hive stops tracking skills.json" -- memory/stats/skills.json >/dev/null

echo "story 12: council.jsonl alone dirty also blocks stage 03 - only anomalies.jsonl passes through"
printf '{"n":1}\n' > memory/stats/council.jsonl
shiph | expect "council.jsonl alone dirty -> 03 not clean" "working tree is not clean"
rm -f memory/stats/council.jsonl


echo "S5 (mass-audit-fixes-08): a --commit verb commits its own paperwork paths by pathspec, never the whole index"
mkdir -p docs/specs/pwonly
cp "$SRC"/templates/plan.md docs/specs/pwonly/plan.md
printf '> build the pathspec demo\n\n## Asks\n1. one ask\n' > docs/specs/pwonly/brief.md
printf 'foreign\n' > pw-foreign.txt && git add pw-foreign.txt
out="$(bash scripts/cycle.sh briefed docs/specs/pwonly --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    briefed --commit with a foreign file staged exits 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
git show --name-only --format= HEAD | grep -qxF pw-foreign.txt \
  && { echo "::error::the paperwork commit swept in a foreign staged file: $(git show --name-only --format= HEAD | tr '\n' ' ')"; fail=1; } \
  || echo "  ok    the paperwork commit carries only its own paths"
git show --name-only --format= HEAD | grep -qxF docs/specs/pwonly/plan.md && echo "  ok    the paperwork commit carries the plan" \
  || { echo "::error::the paperwork commit lacks the plan: $(git show --name-only --format= HEAD | tr '\n' ' ')"; fail=1; }
git diff --cached --name-only | grep -qxF pw-foreign.txt && echo "  ok    the foreign file is still staged" \
  || { echo "::error::the foreign file is no longer staged: $(git status --porcelain)"; fail=1; }
git rm -q --cached pw-foreign.txt && rm -f pw-foreign.txt
fi # part hooklog
if part paperwork; then # --- part paperwork: in brief.md and plan.md only the lines a cycle script writes are paperwork (P1)
echo "audit-fixes-1113-14 (P1): in brief.md and plan.md only the lines a cycle script writes are paperwork"
mkdir -p docs/specs/pone
cp "$SRC"/templates/plan.md docs/specs/pone/plan.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/; s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-14/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/pone/plan.md
printf '# pone (brief)\n\n## Asks\n1. the first ask works\n2. the second ask works\n\n## Answers\n- none yet\n' > docs/specs/pone/brief.md
printf -- '---\nstory: pone-01\nspec: pone\nstatus: todo\nreturned:\nwave: 1\n---\n# Pone fixture\n\n## Files\n- pone-a.txt\n\n## Verification\n`true`\n' > docs/specs/pone/pone-01.md
printf 'a\n' > pone-a.txt
git add -A && git commit -qm "vulyk(pone): plan" >/dev/null
bash scripts/cycle.sh claim docs/specs/pone p1 >/dev/null 2>&1; bash scripts/cycle.sh release docs/specs/pone p1 >/dev/null 2>&1
P1TMP="$(mktemp)"   # outside the fixture repo
p1_ready() { sed_inplace 's/^returned:$/returned: DONE/' docs/specs/pone/pone-01.md; printf 'a2\n' > pone-a.txt; } # the worker's return
p1_unready() { sed_inplace 's/^returned: DONE$/returned:/' docs/specs/pone/pone-01.md; printf 'a\n' > pone-a.txt; }
p1_close() { bash scripts/cycle.sh close-story docs/specs/pone/pone-01.md --commit 2>&1; }
p1_ready
cp docs/specs/pone/brief.md "$P1TMP"
sed_inplace 's/^2\. the second ask works$/2. the second ask is gone/' docs/specs/pone/brief.md
out="$(p1_close)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: docs/specs/pone/brief.md"' \
  && echo "  ok    a ## Asks line of brief.md changed by hand, dirty at close: exit 4 naming brief.md" \
  || { echo "::error::a hand-edited ## Asks line at close must exit 4 naming brief.md: exit=$ex out=$out"; fail=1; }
cp "$P1TMP" docs/specs/pone/brief.md; cp docs/specs/pone/plan.md "$P1TMP"
sed_inplace 's/^\(\*\*Tier:\*\* \)3/\14/' docs/specs/pone/plan.md
out="$(p1_close)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: docs/specs/pone/plan.md"' \
  && echo "  ok    the **Tier:** line of plan.md changed by hand, dirty at close: exit 4 naming plan.md" \
  || { echo "::error::a hand-edited Tier line at close must exit 4 naming plan.md: exit=$ex out=$out"; fail=1; }
cp "$P1TMP" docs/specs/pone/plan.md
p1_unready
awk '{ print } /^## Stories/ { print "- a story line added by hand" }' docs/specs/pone/plan.md > "$P1TMP" && cp "$P1TMP" docs/specs/pone/plan.md
git commit -qm "a story line by hand" -- docs/specs/pone/plan.md >/dev/null
bash scripts/cycle.sh revise docs/specs/pone/pone-01.md >/dev/null 2>&1   # a record commit that leaves plan.md alone
git show --name-only --format= HEAD | grep -qx docs/specs/pone/plan.md && { echo "::error::precondition: the revise commit touched plan.md"; fail=1; }
p1_ready
out="$(p1_close)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: docs/specs/pone/plan.md"' \
  && echo "  ok    a plan.md hand edit committed after the claim, then a revise record commit that left plan.md alone: still exit 4 naming plan.md" \
  || { echo "::error::a later record commit must not hide an earlier hand edit of plan.md: exit=$ex out=$out"; fail=1; }
p1_unready
sed_inplace 's/^- a story line added by hand$/- a story line, revised/' docs/specs/pone/plan.md
bash scripts/cycle.sh revise docs/specs/pone/pone-01.md >/dev/null 2>&1
git show --name-only --format= HEAD | grep -qx docs/specs/pone/plan.md || { echo "::error::precondition: the revise commit left plan.md out"; fail=1; }
p1_ready
out="$(p1_close)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:docs/specs/pone/pone-01.md | grep -q '^status: done' \
  && echo "  ok    a revise commit of plan.md during the build is accepted by the wave's close" \
  || { echo "::error::a revise commit of plan.md must be accepted by the close: exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "vulyk(pone): journal" >/dev/null
p1_round() { # p1_round <n> - a round opened at HEAD, its ROUND committed as the cycle's own paperwork
  mkdir -p "docs/specs/pone/council/round-$1"
  printf 'head=%s\npack=%s\nopened=2026-11-14T00:00:00Z\nceiling=3\ntier=3\nseats=review\n' \
    "$(git rev-parse --short HEAD)" "$(pack_fingerprint docs/specs/pone)" > "docs/specs/pone/council/round-$1/ROUND"
  git add -- docs/specs/pone/council && git commit -qm "vulyk(pone): open-round $1" -- docs/specs/pone/council >/dev/null
}
p1_status() { bash scripts/cycle.sh status docs/specs/pone --json 2>&1; } # stdout and the stderr note
p1_round 1
sed_inplace 's/^\*\*Council:\*\* <.*/**Council:** GREEN round 0, 2026-11-14, at abc1234, pack x/' docs/specs/pone/plan.md
git commit -qm "a marker line" -- docs/specs/pone/plan.md >/dev/null
awk '{ print } /^- none yet$/ { print ""; print "**After escalation (round 1, 2026-11-14).**"; print "> keep going" }' docs/specs/pone/brief.md > "$P1TMP" && cp "$P1TMP" docs/specs/pone/brief.md
git commit -qm "reopen's answer" -- docs/specs/pone/brief.md >/dev/null
p1_status | expect "commits of only a marker line and reopen's ## Answers lines keep the round current" '"stale":false'
awk '{ print } /^## Stories/ { print "- a second story line added by hand" }' docs/specs/pone/plan.md > "$P1TMP" && cp "$P1TMP" docs/specs/pone/plan.md
git commit -qm "a story line" -- docs/specs/pone/plan.md >/dev/null
out="$(p1_status)"
printf '%s' "$out" | expect "neighbour: a ## Stories line of plan.md committed after ROUND.head stales the round" '"stale":true'
printf '%s' "$out" | expect "status names plan.md and the commit" "docs/specs/pone/plan.md hand-edited in $(git rev-parse --short HEAD)"
p1_round 2
sed_inplace 's/^1\. the first ask works$/1. the first ask is easier/' docs/specs/pone/brief.md
git commit -qm "an ask edited" -- docs/specs/pone/brief.md >/dev/null
out="$(p1_status)"
printf '%s' "$out" | expect "a hand edit of the brief asks stales the round (a ## Asks line committed after ROUND.head)" '"stale":true'
printf '%s' "$out" | expect "status names brief.md and its commit" "docs/specs/pone/brief.md hand-edited in $(git rev-parse --short HEAD)"
p1_round 3
sed_inplace 's/^\(\*\*Tier:\*\* \)3/\14/' docs/specs/pone/plan.md
git commit -qm "tier by hand" -- docs/specs/pone/plan.md >/dev/null
p1_status | expect "the **Tier:** line of plan.md committed after ROUND.head stales the round" '"stale":true'
p1_round 4
sed_inplace 's/^- a story line, revised$/- a story line, revised again/' docs/specs/pone/plan.md
bash scripts/cycle.sh revise docs/specs/pone/pone-01.md >/dev/null 2>&1
out="$(p1_status)"
printf '%s' "$out" | grep -q 'hand-edited' && { echo "::error::status called a revise commit hand-edited: $out"; fail=1; } \
  || echo "  ok    status does not call a revise commit of plan.md hand-edited"
rm -f "$P1TMP"

echo "audit-fixes-1113-14 (P1): a --commit verb commits its named files and leaves a stray file in the spec folder out"
mkdir -p docs/specs/pwname
cp "$SRC"/templates/plan.md docs/specs/pwname/plan.md
printf '# pwname\n\n## Asks\n1. one ask\n' > docs/specs/pwname/brief.md
printf 'my notes\n' > docs/specs/pwname/notes.txt
out="$(bash scripts/cycle.sh briefed docs/specs/pwname --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show --name-only --format= HEAD | grep -qx docs/specs/pwname/plan.md \
  && ! git show --name-only --format= HEAD | grep -qx docs/specs/pwname/notes.txt \
  && [ "$(git status --porcelain -- docs/specs/pwname/notes.txt)" = "?? docs/specs/pwname/notes.txt" ] \
  && echo "  ok    briefed --commit carries its named files; the stray notes.txt stays out, untracked" \
  || { echo "::error::a cycle commit took the spec folder: exit=$ex files=$(git show --name-only --format= HEAD | tr '\n' ' ') out=$out"; fail=1; }
rm -f docs/specs/pwname/notes.txt
fi # part paperwork
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

echo "P9-12: a verification glob that matches nothing is still a path for verify-gap (globstar and nullglob are on)"
mkdir -p docs/specs/wgap src/wgap && printf 'x\n' > src/wgap/a.txt
wgap_story() { # wgap_story <nn> <file> <verification>
  printf -- '---\nstory: wgap-%s\nspec: wgap\nstatus: todo\nwave: %s\n---\n# G%s\n\n## Files\n- %s\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" "$3" > "docs/specs/wgap/wgap-$1-g.md"
}
wgap_story 01 app.txt '`bash nothere/**/*.sh`'
wgap_story 02 src/wgap/a.txt '`cat src/**/*.txt`'
out="$(bash scripts/wave-check.sh docs/specs/wgap)"
printf '%s' "$out" | expect "a glob matching nothing outside ## Files is a verify-gap" "verify-gap: wgap-01's verification"
printf '%s' "$out" | grep -qF "verify-gap: wgap-02" && { echo "::error::a glob covering the story's file was reported: $out"; fail=1; } \
  || echo "  ok    a ** glob covering the story's own file is no verify-gap"
rm -rf docs/specs/wgap src/wgap

echo "tails-1115-05 (T1): a verification token that a ## Files entry names counts as a path though it is not on disk yet"
mkdir -p docs/specs/wnew tests/wnew && printf '#!/bin/sh\nexit 0\n' > tests/wnew/run.sh
wnew_story() { # wnew_story <nn> <files-entry> <verification>
  printf -- '---\nstory: wnew-%s\nspec: wnew\nstatus: todo\nwave: %s\n---\n# N%s\n\n## Files\n- %s\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" "$3" > "docs/specs/wnew/wnew-$1-n.md"
}
wnew_story 01 tests/wnew/a.test.sh '`bash tests/wnew/run.sh tests/wnew/a.test.sh`'
wnew_story 02 'tests/wnew/*.test.sh' '`bash tests/wnew/run.sh tests/wnew/b.test.sh`'
wnew_story 03 app.txt '`bash tests/wnew/run.sh tests/wnew/c.test.sh`'
out="$(bash scripts/wave-check.sh docs/specs/wnew)"
printf '%s' "$out" | grep -qF "verify-gap: wnew-01" && { echo "::error::a test path the story itself creates counts as covered - got a verify-gap: $out"; fail=1; } \
  || echo "  ok    a test path the story itself creates counts as covered"
printf '%s' "$out" | grep -qF "verify-gap: wnew-02" && { echo "::error::a test path a ## Files glob matches counts as covered - got a verify-gap: $out"; fail=1; } \
  || echo "  ok    a test path a ## Files glob matches counts as covered"
printf '%s' "$out" | expect "a token neither on disk nor in ## Files still leaves the runner a verify-gap" "verify-gap: wnew-03's verification"
rm -rf docs/specs/wnew tests/wnew

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

echo "upgrade-findings-01: wave-check matches a noted cell by its span; commands_lint names noted and several rows only"
cat > CLAUDE.vulyk.md <<'EOF'
# Sidecar constitution

## Commands

| Purpose | Command |
|---|---|
| Plain | `sh plain.sh` |
| Bare | sh bare.sh |
| Noted | `sh suite.sh` (a note for Acme, "quoted") |
| Noted slow (round-only) | `sh slow.sh` (the round gate only) |
| Two | `sh a.sh` or `sh b.sh` |
EOF
mkdir -p docs/specs/wnote
wnote_story() { # wnote_story <nn> <verification-block>
  printf -- '---\nstory: wnote-%s\nspec: wnote\nstatus: todo\nwave: %s\n---\n# N%s\n\n## Files\n- app.txt\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" > "docs/specs/wnote/wnote-$1-n.md"
}
wnote_story 01 '`sh suite.sh`'
wnote_story 02 '`sh slow.sh`'
out="$(bash scripts/wave-check.sh docs/specs/wnote)"
printf '%s' "$out" | grep -qF 'verify-cell: wnote-01' && { echo "::error::wave-check: a noted cell runs only the backticked span - wnote-01 reported verify-cell: $out"; fail=1; } \
  || echo "  ok    wave-check: a line equal to a noted cell's span is a cell (no verify-cell)"
printf '%s' "$out" | expect "wave-check: a noted round-only row is still reported round-only" "verify-round-only: wnote-02 sh slow.sh"
want="commands: row 'Noted': text outside the backticked command is read as a note
commands: row 'Noted slow (round-only)': text outside the backticked command is read as a note
commands: row 'Two': 2 backticked commands in one cell (close-story runs one command per cell; split it)"
lint="$(commands_lint CLAUDE.vulyk.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$lint" = "$want" ] && echo "  ok    commands_lint: one line per noted and several row, none for one / none rows, exit 0" \
  || { echo "::error::commands_lint: expected the B1 lines - exit=$ex got: $lint"; fail=1; }
printf '# C\n\n## Commands\n\n| Purpose | Command |\n|---|---|\n' > wnote-empty.md
printf '# C\n\n## Other\n\n| Purpose | Command |\n|---|---|\n| Two | `a` `b` |\n' > wnote-none.md
for lf in wnote-empty.md wnote-none.md wnote-missing.md; do
  lint="$(commands_lint "$lf" 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] && [ -z "$lint" ] && echo "  ok    commands_lint $lf: nothing, exit 0" \
    || { echo "::error::commands_lint $lf: expected nothing, exit 0 - exit=$ex got: $lint"; fail=1; }
done
rm -f CLAUDE.vulyk.md wnote-empty.md wnote-none.md
git add -A && git commit -qm "wnote fixture" >/dev/null

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

echo "mass-audit-fixes-15: a wrapped ## Asks item is read whole (an indented continuation joins it with one space)"
mkdir -p docs/specs/qw
printf '# qw\n\n## Request\n> build the wrap demo\n\n## Asks\n1. the first ask\n   wraps onto a second line\n2. another ask\n' > docs/specs/qw/brief.md
[ "$(brief_asks docs/specs/qw/brief.md | tr '\n' '|')" = "1. the first ask wraps onto a second line|2. another ask|" ] \
  && echo "  ok    a space-indented continuation joins the item above it" \
  || { echo "::error::a wrapped ask item reads as its first line only: $(brief_asks docs/specs/qw/brief.md | tr '\n' '|')"; fail=1; }
printf -- '---\nstory: qw-01\nspec: qw\nstatus: todo\nwave: 1\n---\n# W1\n\n## Requirements\n> 1. the first ask wraps onto a second line\n> 2. another ask\n' > docs/specs/qw/qw-01-w.md
out="$(bash scripts/trace-check.sh docs/specs/qw)"
printf '%s' "$out" | expect "trace-check accepts a quote of the whole joined item" "backward: 0 unfound"
printf '## Asks\n1. a tab ask\n\tcontinues here\n2. a blank ends it\n\n   not part of it\n3. last\n' > docs/specs/qw/brief.md
[ "$(brief_asks docs/specs/qw/brief.md | tr '\n' '|')" = "1. a tab ask continues here|2. a blank ends it|3. last|" ] \
  && echo "  ok    a tab continuation joins; an indented line after a blank line does not" \
  || { echo "::error::neighbour forms: $(brief_asks docs/specs/qw/brief.md | tr '\n' '|')"; fail=1; }
rm -rf docs/specs/qw

echo "ab-run-fixes C6: status and every verb that derives it refuse a story status cycle.sh does not recognise"
mkdir -p docs/specs/ustat
printf -- '---\nstory: ustat-01\nspec: ustat\nstatus: open\nwave: 1\n---\n# U1\n' > docs/specs/ustat/ustat-01-u.md
printf -- '---\nstory: ustat-02\nspec: ustat\nstatus: todo\nwave: 1\n---\n# U2\n' > docs/specs/ustat/ustat-02-u.md
out="$(bash scripts/cycle.sh status docs/specs/ustat --json 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | tail -1 | jq -e '.ok == false and .verb == "status" and .error == "unknown story status '"'open'"' in docs/specs/ustat/ustat-01-u.md"' >/dev/null 2>&1 \
  && echo "  ok    status: an unknown story status is an error (exit 2, the file and the value named)" \
  || { echo "::error::status: an unknown story status is an error - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh repair docs/specs/ustat 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | tail -1 | jq -e '.verb == "repair" and .error == "unknown story status '"'open'"' in docs/specs/ustat/ustat-01-u.md"' >/dev/null 2>&1 \
  && echo "  ok    a verb that derives status (repair) refuses the same way" \
  || { echo "::error::repair on an unknown story status - exit=$ex out=$out"; fail=1; }
kfail=0
for kst in todo in-progress done blocked; do
  sed_inplace "s/^status: .*/status: $kst/" docs/specs/ustat/ustat-01-u.md
  out="$(bash scripts/cycle.sh status docs/specs/ustat --json 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] || { echo "::error::status with a known story status '$kst' - exit=$ex out=$out"; fail=1; kfail=1; }
done
[ "$kfail" -eq 0 ] && echo "  ok    the known values todo, in-progress, done, blocked behave as before"
rm -rf docs/specs/ustat

echo "ab-run-fixes-09: every verb's last JSON line carries now, the epoch seconds the driver checkpoint reads"
nfail=0
for nverb in "status docs/specs/sib" "status docs/specs/no-such-spec"; do
  t0="$(date +%s)"
  out="$(bash scripts/cycle.sh $nverb 2>&1)"
  t1="$(date +%s)"
  printf '%s\n' "$out" | tail -1 | jq -e --argjson a "$((t0 - 5))" --argjson b "$((t1 + 5))" \
    '(.now | type) == "number" and .now == (.now | floor) and .now >= $a and .now <= $b' >/dev/null 2>&1 \
    || { echo "::error::emit: a verb's JSON line carries now in epoch seconds - verb=$nverb out=$out"; fail=1; nfail=1; }
done
[ "$nfail" -eq 0 ] && echo "  ok    an ok and a refused verb both carry an integer now within 5 s of the shell clock"


echo "G3 (mass-audit-fixes-08): scope-check drops a sibling's declared paths only for a not-done sibling of the same wave"
mkdir -p docs/specs/scw src/scw/in
printf 'a\n' > src/scw/a.txt; printf 'b\n' > src/scw/b.txt; printf 'c\n' > src/scw/c.txt; printf 'o\n' > src/scw/out.txt
scw_story() { # scw_story <nn> <file> <wave>
  printf -- '---\nstory: scw-%s\nspec: scw\nstatus: todo\nwave: %s\n---\n# W%s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$3" "$1" "$2" > "docs/specs/scw/scw-$1-s.md"
}
scw_story 01 src/scw/a.txt 1
scw_story 02 src/scw/b.txt 2
scw_story 03 src/scw/c.txt 1
scw_story 04 src/scw/in/ 3
git add -A && git commit -qm "scw: two waves" >/dev/null
printf 'a2\n' > src/scw/a.txt; printf 'b2\n' > src/scw/b.txt; printf 'c2\n' > src/scw/c.txt
out="$(bash scripts/scope-check.sh docs/specs/scw/scw-01-s.md)"
printf '%s' "$out" | expect "a wave-1 edit of a file only a wave-2 todo story declares is out of scope" "! src/scw/b.txt"
printf '%s' "$out" | expect "a same-wave sibling's file is still dropped: changed 2, out of scope 1" "declared 1, changed 2, out of scope 1"
git checkout -q -- src/scw memory/stats/scope.jsonl
echo "G4: a git mv of an out-of-scope file into a declared directory still counts the path it left"
git mv src/scw/out.txt src/scw/in/out.txt
bash scripts/scope-check.sh docs/specs/scw/scw-04-s.md | expect "a rename into a declared dir reports out of scope 1" "out of scope 1"
git mv src/scw/in/out.txt src/scw/out.txt; git checkout -q -- memory/stats/scope.jsonl
git rm -rq docs/specs/scw src/scw && git commit -qm "scw: drop" >/dev/null

echo "G8 (mass-audit-fixes-08): wave-check reports red-seals-impl when a red story seals its one implementation"
mkdir -p docs/specs/rsi tests
printf '#!/usr/bin/env bash\ntrue\n' > scripts/rsi.sh; printf '#!/usr/bin/env bash\ntrue\n' > tests/rsi.test.sh
rsi_story() { # rsi_story <n> <verification>
  printf -- '---\nstory: rsi-%s\nspec: rsi\nstatus: todo\nwave: %s\nred: required\n---\n# R%s\n\n## Files\n- scripts/rsi.sh\n- tests/rsi.test.sh\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" > "docs/specs/rsi/rsi-$1-r.md"
}
rsi_story 1 '`bash tests/rsi.test.sh && bash scripts/rsi.sh`'
rsi_story 2 '`bash tests/rsi.test.sh`'
out="$(bash scripts/wave-check.sh docs/specs/rsi)"
printf '%s' "$out" | expect "a red story whose verification calls its one implementation script: red-seals-impl" "red-seals-impl: rsi-1"
printf '%s' "$out" | grep -qF 'red-seals-impl: rsi-2' && { echo "::error::a suite-only verification was reported red-seals-impl: $out"; fail=1; } \
  || echo "  ok    a suite-only verification is no red-seals-impl"
rm -rf docs/specs/rsi scripts/rsi.sh tests/rsi.test.sh
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
  [ "$2" != done ] || done_story "docs/specs/man/man-$1-m.md"
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

echo "ab-run-fixes ask 18 repro: a ready story in the same wave as a manual:-blocked one is built; the stop comes after it"
mkdir -p docs/specs/manw
cp "$SRC"/templates/plan.md docs/specs/manw/plan.md
printf '> build beside a hand step\n' > docs/specs/manw/brief.md
sed_inplace "s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-09/; s#^\*\*Branch:\*\* <.*#**Branch:** $(git rev-parse --abbrev-ref HEAD)#" docs/specs/manw/plan.md
manw_story() { # manw_story <nn> <status> <blocked_by> - every story in wave 1
  printf -- '---\nstory: manw-%s\nspec: manw\nstatus: %s\nwave: 1\nblocked_by: %s\n---\n# W%s\n\n## Files\n- manw.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$3" "$1" > "docs/specs/manw/manw-$1-w.md"
}
manw_story 01 todo '[manual:tape]'
manw_story 02 todo '[]'
git add -A && git commit -qm "manw fixture" >/dev/null
st="$(bash scripts/cycle.sh status docs/specs/manw --json)"
printf '%s' "$st" | expect "manual wave: the ready wave-mate makes next build:1" '"next":"build:1"'
printf '%s' "$st" | expect "manual wave: wave_stories lists only the ready story" '"wave_stories":[{"file":"docs/specs/manw/manw-02-w.md"'
printf '%s' "$st" | grep -qF 'manw-01-w.md' && { echo "::error::manual wave: the blocked story was listed: $st"; fail=1; } \
  || echo "  ok    manual wave: the manual-blocked story is not dispatched"
bash scripts/cycle.sh advance docs/specs/manw 2>&1 | tail -1 | expect "manual wave: advance stops at build:1, not at the hand step" '"next":"build:1"'
done_story docs/specs/manw/manw-02-w.md
bash scripts/cycle.sh status docs/specs/manw --json | expect "manual wave: once the ready story is done, next is manual:tape" '"next":"manual:tape"'

fi # part manual
if part close || part close2; then # --- the stray fixtures parts close and close2 share
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
fi # stray fixtures
if part close; then # --- part close: close-story scope refusal, own-path commits, odd path names
echo "close-story-scope-refusal: close-story --commit refuses an edit outside ## Files that would leave the tree dirty for open-round"
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
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'edited outside ## Files: memory/stats/skills.json' \
  && echo "  ok    memory/stats/skills.json is no paperwork any more (audit-fixes-1113-03): undeclared, it refuses" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f memory/stats/skills.json
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    skills.json removed, the close exits 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
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
mkdir -p memory/stats; printf '{"x":6}\n' > memory/stats/evolve.jsonl; git add memory/stats/evolve.jsonl   # staged by someone else
mkdir -p .git/hooks; printf '#!/bin/sh\nexit 1\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-06.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && [ "$(git diff --cached --name-only)" = "memory/stats/evolve.jsonl" ] && grep -q '^status: in-progress' docs/specs/stray/stray-06.md \
  && echo "  ok    a failed commit (hook) unstages the story's paths, keeps others' staging and status:" \
  || { echo "::error::exit=$ex staged=$(git diff --cached --name-only | tr '\n' ' ') out=$out"; fail=1; }
rm -f .git/hooks/pre-commit
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-06.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! git show --name-only --format= HEAD | grep -qx 'memory/stats/evolve.jsonl' && [ "$(git diff --cached --name-only)" = "memory/stats/evolve.jsonl" ] \
  && echo "  ok    close-story's commit leaves a staged path it does not own out of the commit" \
  || { echo "::error::exit=$ex commit=$(git show --name-only --format= HEAD | tr '\n' ' ') out=$out"; fail=1; }
git reset -q -- memory/stats/evolve.jsonl; rm -f memory/stats/evolve.jsonl

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

echo "ab-run-fixes C7 + stdin: verify_run gives each line /dev/null for stdin; a non-cell segment names a ready line"
mkdir -p tests
printf 'cat > /dev/null\n' > stdin-eat.sh; printf ': > stdin.mark\n' > stdin-mark.sh
cat >> CLAUDE.md <<'EOF'
| Stdin eater | `bash stdin-eat.sh` |
| Stdin mark | `bash stdin-mark.sh` |
| X part | `bash tests/x.test.sh --part <topic>` |
| X all (round-only) | `bash tests/x.test.sh --all` |
EOF
vfy_story() { # vfy_story <nn> <verification-lines> - one in-progress story declaring stray-app.txt only
  printf -- '---\nstory: stray-%s\nspec: stray\nstatus: in-progress\nreturned: DONE\nwave: %s\n---\n# Stray fixture %s\n\n## Files\n- stray-app.txt\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$2" > "docs/specs/stray/stray-$1.md"
}
vfy_story 08 '`bash stdin-eat.sh`
`bash stdin-mark.sh`'
vfy_story 09 '`bash tests/x.test.sh --part a --verbose`'
vfy_story 10 '`echo nothing-like-a-cell`'
git add -A && git commit -qm "vfy: stdin and hint fixtures" >/dev/null
rm -f stdin.mark
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-08.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f stdin.mark ] \
  && echo "  ok    verify_run: a line that reads stdin leaves the next line its turn" \
  || { echo "::error::verify_run: a line that reads stdin leaves the next line its turn - exit=$ex mark=$([ -f stdin.mark ] && echo yes || echo no) out=$out"; fail=1; }
rm -f stdin.mark
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-09.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | grep -qxF 'try: bash tests/x.test.sh --part <topic>' \
  && printf '%s\n' "$out" | grep -qF 'verification not in ## Commands: bash tests/x.test.sh --part a --verbose' \
  && ! printf '%s\n' "$out" | grep -qF 'try: bash tests/x.test.sh --all' \
  && echo "  ok    close-story: a non-cell segment names a ready line (exit 2 kept, the round-only cell not offered)" \
  || { echo "::error::close-story: a non-cell segment names a ready line - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-10.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | grep -qE '^try: see ## Commands in .*CLAUDE\.md$' \
  && echo "  ok    close-story: a segment like no cell points at the ## Commands table" \
  || { echo "::error::close-story: a segment like no cell points at ## Commands - exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "vfy: done" >/dev/null 2>&1

echo "upgrade-findings-01: close-story admits a noted cell's span alone, either span of a two-span cell, and hints spans only"
printf 'true\n' > noted.sh; printf 'true\n' > two-a.sh; printf 'true\n' > two-b.sh
cat >> CLAUDE.md <<'EOF'
| Noted | `bash noted.sh` (a note for Acme, "quoted") |
| Two spans | `bash two-a.sh` or `bash two-b.sh` |
EOF
vfy_story 11 '`bash noted.sh`'
vfy_story 12 '`(a note for Acme, "quoted")`'
vfy_story 13 '`bash noted.sh (a note for Acme, "quoted")`'
vfy_story 14 '`bash two-a.sh`'
vfy_story 15 '`bash two-b.sh`'
vfy_story 16 '`bash noted.sh --verbose`'
vfy_story 17 '`bash two-a.sh --verbose`'
git add -A && git commit -qm "vfy: noted and two-span fixtures" >/dev/null
for nn in 11 14 15; do
  out="$(bash scripts/cycle.sh close-story "docs/specs/stray/stray-$nn.md" 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] && echo "  ok    close-story: stray-$nn's line is a span of a cell and closes" \
    || { echo "::error::close-story: stray-$nn runs only the backticked span - exit=$ex out=$out"; fail=1; }
  git add -A && git commit -qm "vfy: stray-$nn closed" >/dev/null 2>&1
done
for nn in 12 13; do
  out="$(bash scripts/cycle.sh close-story "docs/specs/stray/stray-$nn.md" 2>&1)"; ex=$?
  [ "$ex" -eq 2 ] && printf '%s\n' "$out" | grep -qF 'verification not in ## Commands: ' \
    && echo "  ok    close-story: stray-$nn (the note, or span plus note) is no cell" \
    || { echo "::error::close-story: stray-$nn names the note - a note is never a command - exit=$ex out=$out"; fail=1; }
done
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-16.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | grep -qxF 'try: bash noted.sh' && ! printf '%s\n' "$out" | grep '^try: ' | grep -qF 'Acme' \
  && echo "  ok    close-story: the try: hint for a noted cell prints its span, never the note" \
  || { echo "::error::close-story: the try: hint runs only the backticked span - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-17.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && ! printf '%s\n' "$out" | grep -q '^try: bash two-' \
  && printf '%s\n' "$out" | grep -qxF "not offered: row 'Two spans': 2 backticked commands in one cell" \
  && echo "  ok    close-story: a two-span row is not offered as a try: line, and the hint says why" \
  || { echo "::error::close-story: a several-span row must be named, not offered - exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "vfy: noted done" >/dev/null 2>&1

echo "tails-1115-01 (T2): close-story and scope-check take an absolute story path as the repo-relative one"
abs_story() { # abs_story <nn> <wave> - an in-progress stray story declaring stray-abs-<nn>.txt, `returned:` not yet written
  printf -- '---\nstory: stray-%s\nspec: stray\nstatus: in-progress\nreturned:\nwave: %s\n---\n# Stray abs %s\n\n## Files\n- stray-abs-%s.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$1" "$1" > "docs/specs/stray/stray-$1.md"
  printf 'v1\n' > "stray-abs-$1.txt"
}
abs_work() { sed_inplace 's/^returned:$/returned: DONE/' "docs/specs/stray/stray-$1.md"; printf 'v2\n' > "stray-abs-$1.txt"; } # abs_work <nn> - its worker's edits
abs_story 60 60; abs_story 61 61; abs_story 62 62; abs_story 63 62; abs_story 64 64
git add -A && git commit -qm "stray: absolute-path stories" >/dev/null
ABSR="$(pwd -P)"
abs_work 60
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-60.md --commit 2>&1)"; ex=$?
rel_paths="$(git show --name-only --format= HEAD | sed 's/60/NN/g' | LC_ALL=C sort | tr '\n' ' ')"
[ "$ex" -eq 0 ] && echo "  ok    the relative path closes (exit 0)" || { echo "::error::the relative path closes - exit=$ex out=$out"; fail=1; }
abs_work 61
out="$(bash scripts/cycle.sh close-story "$ABSR/docs/specs/stray/stray-61.md" --commit 2>&1)"; ex=$?
abs_paths="$(git show --name-only --format= HEAD | sed 's/61/NN/g' | LC_ALL=C sort | tr '\n' ' ')"
[ "$ex" -eq 0 ] && [ "$abs_paths" = "$rel_paths" ] && git show HEAD:docs/specs/stray/stray-61.md | grep -q '^status: done' \
  && echo "  ok    close-story: an absolute story path closes like a relative one (exit 0, the same committed paths)" \
  || { echo "::error::close-story: an absolute story path closes like a relative one - exit=$ex committed=[$abs_paths] relative=[$rel_paths] out=$out"; fail=1; }
git add -A && git commit -qm "stray: after 61" >/dev/null 2>&1
abs_work 62; abs_work 63   # 63 is 62's open wave-mate: its story file and its ## Files are dirty in the same tree
out="$(bash scripts/scope-check.sh "$ABSR/docs/specs/stray/stray-62.md" 2>&1)"
printf '%s\n' "$out" | expect "scope-check: an absolute story path counts its own and its wave-mate's story file as in scope" "stray-62 - declared 1, changed 1, out of scope 0"
out="$(bash scripts/cycle.sh close-story "$ABSR/docs/specs/stray/stray-62.md" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    close-story: an absolute story path with an open wave-mate closes" || { echo "::error::close-story: an absolute story path with an open wave-mate closes - exit=$ex out=$out"; fail=1; }
ABSW="$(pwd -W 2>/dev/null)" || ABSW=""
if [ -n "$ABSW" ] && [ "$ABSW" != "$ABSR" ]; then spell="the drive-letter spelling of the root"; else ABSW="$PWD"; spell="the logical spelling of the root"; fi
out="$(bash scripts/cycle.sh close-story "$ABSW/docs/specs/stray/stray-63.md" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:docs/specs/stray/stray-63.md | grep -q '^status: done' \
  && echo "  ok    close-story: an absolute story path closes like a relative one by $spell too (the wave's last close)" \
  || { echo "::error::close-story: an absolute story path closes like a relative one by $spell ($ABSW) - exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "stray: after 63" >/dev/null 2>&1
ABSO="$(mktemp -d)"; cp docs/specs/stray/stray-64.md "$ABSO/stray-64.md"
sed_inplace 's/^returned:$/returned: DONE/' "$ABSO/stray-64.md"
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story "$ABSO/stray-64.md" --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"story file outside the repo: ' && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    close-story: a story path outside the repo is refused with a reason (exit 2), nothing committed" \
  || { echo "::error::close-story: a story path outside the repo is refused with a reason - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/scope-check.sh "$ABSO/stray-64.md" 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'scope-check: story file outside the repo: ' \
  && echo "  ok    scope-check: a story path outside the repo is refused with a reason (exit 0, it only reports)" \
  || { echo "::error::scope-check: a story path outside the repo is refused with a reason - exit=$ex out=$out"; fail=1; }
rm -rf "$ABSO"; git add -A && git commit -qm "stray: after 65" >/dev/null 2>&1

echo "tails-1115-01 (T3): the close commit's title is the first # line after the frontmatter"
printf -- '---\n# a comment line before the keys\nstory: stray-65\nspec: stray\nstatus: in-progress\nreturned:\nwave: 65\n# red: required   # a commented template line\n---\n# Stray title 65\n\n## Files\n- stray-abs-65.txt\n\n## Verification\n`true`\n' > docs/specs/stray/stray-65.md
printf -- '---\nstory: stray-66\nspec: stray\nstatus: in-progress\nreturned:\nwave: 66\n# red_verified_at:      # written by stamp-red\n---\n\nNo title line here.\n\n## Files\n- stray-abs-66.txt\n\n## Verification\n`true`\n' > docs/specs/stray/stray-66.md
printf 'v1\n' > stray-abs-65.txt; printf 'v1\n' > stray-abs-66.txt
git add -A && git commit -qm "stray: title stories" >/dev/null
abs_work 65
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-65.md --commit 2>&1)"; ex=$?
subj="$(git log -1 --format=%s)"
[ "$ex" -eq 0 ] && [ "$subj" = "story(stray-65): Stray title 65" ] \
  && echo "  ok    close-story: a # comment line elsewhere in the frontmatter is not the title" \
  || { echo "::error::close-story: a # comment line elsewhere in the frontmatter is not the title - exit=$ex subject=$subj out=$out"; fail=1; }
abs_work 66
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-66.md --commit 2>&1)"; ex=$?
subj="$(git log -1 --format=%s)"
[ "$ex" -eq 0 ] && [ "$subj" = "story(stray-66):" ] \
  && echo "  ok    close-story: a story with no title line keeps the bare story(<id>): subject" \
  || { echo "::error::close-story: a story with no title line keeps the bare story(<id>): subject - exit=$ex subject=$subj out=$out"; fail=1; }

echo "tails-1115-01 (T17): with core.fileMode=false the close commit keeps a mode change made only in the index"
FM_BEFORE="$(git config core.fileMode)"; git config core.fileMode false
printf 'a\n' > stray-mode-a.txt; printf 'b\n' > stray-mode-b.txt; printf 'c\n' > stray-mode-c.txt
printf -- '---\nstory: stray-67\nspec: stray\nstatus: in-progress\nreturned:\nwave: 67\n---\n# Stray mode 67\n\n## Files\n- stray-mode-a.txt\n- stray-mode-b.txt\n- stray-mode-c.txt\n\n## Verification\n`true`\n' > docs/specs/stray/stray-67.md
git add -A && git update-index --chmod=+x stray-mode-c.txt && git commit -qm "stray: mode story" >/dev/null
sed_inplace 's/^returned:$/returned: DONE/' docs/specs/stray/stray-67.md
git update-index --chmod=+x stray-mode-a.txt           # +x in the index only, no content change
printf 'b2\n' > stray-mode-b.txt                       # a content change, no mode change
git update-index --chmod=-x stray-mode-c.txt           # -x in the index only
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-67.md --commit 2>&1)"; ex=$?
modes="$(git ls-tree HEAD -- stray-mode-a.txt stray-mode-b.txt stray-mode-c.txt | awk '{ print $1 }' | tr '\n' ' ')"
[ "$ex" -eq 0 ] && [ "$modes" = "100755 100644 100644 " ] && git show HEAD:stray-mode-b.txt | grep -qx b2 \
  && [ -z "$(git status --porcelain -- stray-mode-a.txt stray-mode-b.txt stray-mode-c.txt)" ] \
  && echo "  ok    close-story: an index-only +x is 100755 in the close commit, a content change keeps 100644, an index-only -x is kept, the index agrees" \
  || { echo "::error::close-story: an index-only mode change survives the close commit - exit=$ex modes(a b c)=$modes status=$(git status --porcelain -- stray-mode-a.txt stray-mode-b.txt stray-mode-c.txt | tr '\n' ' ') out=$out"; fail=1; }
if [ -n "$FM_BEFORE" ]; then git config core.fileMode "$FM_BEFORE"; else git config --unset core.fileMode; fi
git add -A && git commit -qm "stray: tails done" >/dev/null 2>&1

fi # part close
if part close2; then # --- part close2: the approved-commit reads, done-only-by-close-story, the block-card gate, the verify resume record (split from close for time)
echo "ADR-032 D1: close-story and stamp-red read ## Verification, ## Files and red: from the story's approved commit"
mkdir -p docs/specs/trust docs/specs/trust1
cp "$SRC"/templates/plan.md docs/specs/trust/plan.md; cp "$SRC"/templates/plan.md docs/specs/trust1/plan.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/trust/plan.md   # branched: claim seeds the records (A1)
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\11/' docs/specs/trust1/plan.md
printf 'v1\n' > trust-app.txt
trust_story() { # trust_story <spec> <nn> <frontmatter-lines> - in progress, `returned:` empty, wave 1, ## Files trust-app.txt, ## Verification `true`
  printf -- '---\nstory: %s-%s\nspec: %s\nstatus: in-progress\nreturned:\nwave: 1\n%s---\n# Trust fixture %s\n\n## Files\n- trust-app.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$1" "$3" "$2" > "docs/specs/$1/$1-$2.md"
}
trust_story trust 01 ''; trust_story trust 02 $'red: required\nred_reason:\n'; trust_story trust 03 ''
git add -A && git commit -qm "vulyk(trust): plan" >/dev/null
bash scripts/cycle.sh claim docs/specs/trust t9 >/dev/null 2>&1; bash scripts/cycle.sh release docs/specs/trust t9 >/dev/null 2>&1   # S1: the Tier 3 wave's claim head; A1: claim seeds each story's record
TSHA="$(git rev-parse --short HEAD)"; TBAK="$(mktemp)"
t1=docs/specs/trust/trust-01.md; t2=docs/specs/trust/trust-02.md; t3=docs/specs/trust/trust-03.md
for f in "$t1" "$t2" "$t3"; do sed_inplace 's/^returned:$/returned: DONE/' "$f"; done
cp "$t1" "$TBAK"
sed_inplace 's/^`true`$/none - reviewed by lead-review/' "$t1"
out="$(bash scripts/cycle.sh close-story "$t1" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"story blocks differ from the approved version ($TSHA): ## Verification\"" && grep -q '^status: in-progress' "$t1" \
  && echo "  ok    a ## Verification line swapped for the none literal: exit 4 naming the block and the short sha" \
  || { echo "::error::a ## Verification swapped for none: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
awk '{ print } /^- trust-app\.txt$/ { print "- trust-other.txt" }' "$TBAK" > "$t1"
out="$(bash scripts/cycle.sh close-story "$t1" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"story blocks differ from the approved version ($TSHA): ## Files\"" \
  && echo "  ok    a widened ## Files: exit 4 naming ## Files" \
  || { echo "::error::a widened ## Files: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
sed_inplace '/^red: required$/d' "$t2"
out="$(bash scripts/cycle.sh close-story "$t2" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"story blocks differ from the approved version ($TSHA): red:\"" \
  && echo "  ok    red: required dropped: close-story exits 4 naming red:" \
  || { echo "::error::red: required dropped: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh stamp-red "$t2" 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"verb\":\"stamp-red\",\"exit\":4,\"next\":\"repair\",\"error\":\"story blocks differ from the approved version ($TSHA): red:\"" \
  && echo "  ok    red: required dropped: stamp-red exits 4 before it runs anything" \
  || { echo "::error::stamp-red with red: dropped: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
git show HEAD:"$t2" > "$t2"; sed_inplace 's/^returned:$/returned: DONE/; s/^red_reason:$/red_reason: boom/' "$t2"
out="$(bash scripts/cycle.sh stamp-red "$t2" 2>&1)"
printf '%s' "$out" | tail -1 | expect "red_reason: and returned: differ freely: stamp-red goes on to its own checks (not: blocks differ from the approved version)" \
  '"error":"no test to seal: ## Verification names no path under ## Files"'
cp "$TBAK" "$t1"; printf '\n## Implementation notes\n- trust-app.txt changed\n\n## Findings\n- none\n' >> "$t1"; printf 'v2\n' > trust-app.txt
out="$(bash scripts/cycle.sh close-story "$t1" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:"$t1" | grep -q '^status: done' \
  && echo "  ok    returned:, ## Findings and notes differ freely: the story closes" \
  || { echo "::error::free fields refused: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
git show HEAD:"$t2" > "$t2"
awk '{ print } /^- trust-app\.txt$/ { print "- trust-b.txt" }' "$t3" > "$TBAK" && cp "$TBAK" "$t3"
sed_inplace 's/^returned: DONE$/returned:/' "$t3"
bash scripts/cycle.sh revise "$t3" >/dev/null 2>&1
sed_inplace 's/^returned:$/returned: DONE/' "$t3"; printf 'b\n' > trust-b.txt
out="$(bash scripts/cycle.sh close-story "$t3" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show --name-only --format= HEAD | grep -qx trust-b.txt \
  && echo "  ok    a story revised through cycle.sh revise closes against the revision" \
  || { echo "::error::the revision is not the baseline: story blocks differ from the approved version - exit=$ex out=$out"; fail=1; }
trust_story trust 04 ''; sed_inplace 's/^returned:$/returned: DONE/' docs/specs/trust/trust-04.md
out="$(bash scripts/cycle.sh close-story docs/specs/trust/trust-04.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"no approved record for docs/specs/trust/trust-04.md: run bash scripts/cycle.sh revise docs/specs/trust/trust-04.md"' \
  && echo "  ok    a Tier 3 story with no approved record: exit 2 no approved record" \
  || { echo "::error::Tier 3 untracked: exit=$ex out=$out"; fail=1; }
rm -f docs/specs/trust/trust-04.md
trust_story trust1 01 ''; sed_inplace 's/^returned:$/returned: DONE/' docs/specs/trust1/trust1-01.md
out="$(bash scripts/cycle.sh close-story docs/specs/trust1/trust1-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c 'no approved record')" -eq 1 ] \
  && echo "  ok    a Tier 1 story with no approved record closes with one stderr note" \
  || { echo "::error::Tier 1 untracked: exit=$ex out=$out"; fail=1; }
rm -f "$TBAK"; git add -A && git commit -qm "trust: done" >/dev/null 2>&1

echo "ADR-032 D2: a done story is closed only by close-story's own story(<id>) commit"
mkdir -p docs/specs/hand
cp "$SRC"/templates/plan.md docs/specs/hand/plan.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-09/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/hand/plan.md
cat >> CLAUDE.md <<'EOF'
| Hand flag | `test -f hand-flag.txt` |
EOF
hand_story() { # hand_story <nn> <wave> <verification> - todo, `returned:` empty, ## Files hand-app.txt
  printf -- '---\nstory: hand-%s\nspec: hand\nstatus: todo\nreturned:\nwave: %s\n---\n# Hand fixture %s\n\n## Files\n- hand-app.txt\n\n## Verification\n%s\n' \
    "$1" "$2" "$1" "$3" > "docs/specs/hand/hand-$1.md"
}
hand_story 01 1 '`true`'; hand_story 02 2 '`test -f hand-flag.txt`'; hand_story 03 2 '`true`'
printf 'v1\n' > hand-app.txt
git add -A && git commit -qm "vulyk(hand): plan" >/dev/null
for f in docs/specs/hand/hand-01.md docs/specs/hand/hand-02.md; do sed_inplace 's/^status: todo$/status: done/; s/^returned:$/returned: DONE/' "$f"; done
git add -A && git commit -qm "hand-marked done" >/dev/null
st="$(bash scripts/cycle.sh status docs/specs/hand --json)"
printf '%s' "$st" | expect "a done story with no close commit counts as in-progress" '"stories":{"todo":1,"in-progress":2,"done":0,"blocked":0}'
printf '%s' "$st" | expect "and next is close-story:<its file>" '"next":"close-story:docs/specs/hand/hand-01.md"'
out="$(bash scripts/cycle.sh close-story docs/specs/hand/hand-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(git log -1 --format=%s)" = "story(hand-01): Hand fixture 01" ] \
  && git show HEAD:docs/specs/hand/journal.md | grep -qF 'close-story hand-01: closed over a hand-committed tree' && [ -z "$(git status --porcelain)" ] \
  && echo "  ok    close-story over a hand-committed done story runs the gates and writes the close commit with its journal line" \
  || { echo "::error::hand-committed close: exit=$ex log=$(git log -1 --format=%s) out=$out"; fail=1; }
st="$(bash scripts/cycle.sh status docs/specs/hand --json)"
printf '%s' "$st" | expect "after the story(<id>) commit the story is done" '"stories":{"todo":1,"in-progress":1,"done":1,"blocked":0}'
printf '%s' "$st" | expect "and the next wave's build lists the hand-marked story too" '"next":"build:2"'
printf '%s' "$st" | expect "wave_stories keeps the hand-marked story" '"file":"docs/specs/hand/hand-02.md"'
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story docs/specs/hand/hand-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"test -f hand-flag.txt"' && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    a hand-marked story whose verification fails: exit 4, not already done" \
  || { echo "::error::hand-marked failing verification: exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/hand/hand-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'already done' && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    a story closed by close-story stays already done" || { echo "::error::second close: exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "hand: done" >/dev/null 2>&1


echo "ADR-032 D3 call site (mass-audit-fixes-08): close-story runs a block card's check on the story's matching files"
mkdir -p docs/specs/blk src/blk docs/defects .claude/hooks
cp "$SRC"/scripts/defects-check.sh scripts/
cp "$SRC"/.claude/hooks/defects_lib.py .claude/hooks/
printf '.claude/hooks/\n' >> .git/info/exclude   # the parser comes and goes below; its absence is no dirt
BLKLOG="$(mktemp -u)"
cp "$SRC"/templates/plan.md docs/specs/blk/plan.md
printf '> build the block demo\n' > docs/specs/blk/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-01-01/' docs/specs/blk/plan.md
printf '# Defect library\n' > docs/defects/README.md
printf '#!/usr/bin/env bash\necho "$1" >> "%s"\n! grep -q bad "$1"\n' "$BLKLOG" > blk-check.sh
blk_card() { # blk_card <status> <paths-glob>
  printf -- '---\nid: blkc\ntitle: Class blkc\nstatus: %s\ncheck: bash blk-check.sh <arg>\nfixtures: [docs/defects/README.md, blk-check.sh]\nkeys: [k-blkc]\npaths: ["%s"]\n---\n\n# Class blkc\nWhat it is.\n\n## Never\n- write bad\n' \
    "$1" "$2" > docs/defects/blkc.md
}
blk_story() { # blk_story <nn>
  printf -- '---\nstory: blk-%s\nspec: blk\nstatus: in-progress\nreturned: DONE\nwave: %s\n---\n# B%s\n\n## Files\n- src/blk/\n\n## Verification\n`true`\n' \
    "$1" "$1" "$1" > "docs/specs/blk/blk-$1-b.md"
}
blk_card block 'src/blk/**'; blk_story 01; printf 'fine\n' > src/blk/ok.txt
git add -A && git commit -qm "blk: setup" >/dev/null
printf 'bad\n' > src/blk/x.txt
head_before="$(git rev-parse HEAD)"; rm -f "$BLKLOG"
out="$(bash scripts/cycle.sh close-story docs/specs/blk/blk-01-b.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"defect card blkc fails on src/blk/x.txt"' && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    a block card failing on a declared file: exit 4 naming the card and the file, nothing committed" \
  || { echo "::error::block card red: exit=$ex out=$out"; fail=1; }
mv .claude/hooks/defects_lib.py .claude/hooks/defects_lib.off
out="$(bash scripts/cycle.sh close-story docs/specs/blk/blk-01-b.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"defect gate could not run"' \
  && echo "  ok    a gate that cannot run (no parser): exit 2 defect gate could not run" \
  || { echo "::error::block gate exit 2: exit=$ex out=$out"; fail=1; }
mv .claude/hooks/defects_lib.off .claude/hooks/defects_lib.py
blk_card block 'lib/nowhere/**'; git add -A docs/defects && git commit -qm "blk: the card scopes elsewhere" -- docs/defects >/dev/null
rm -f "$BLKLOG"
out="$(bash scripts/cycle.sh close-story docs/specs/blk/blk-01-b.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ ! -s "$BLKLOG" ] && echo "  ok    a block card whose paths: match nothing in ## Files runs nothing, the close goes on" \
  || { echo "::error::block card with no match: exit=$ex log=$(cat "$BLKLOG" 2>/dev/null) out=$out"; fail=1; }
blk_card text 'src/blk/**'; blk_story 02; git add -A && git commit -qm "blk: a text card, story 02" >/dev/null
printf 'bad again\n' > src/blk/y.txt
mv .claude/hooks/defects_lib.py .claude/hooks/defects_lib.off   # were the gate to run, it would exit 2
out="$(bash scripts/cycle.sh close-story docs/specs/blk/blk-02-b.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ ! -s "$BLKLOG" ] && echo "  ok    no block card: the gate does not run" \
  || { echo "::error::no block card: exit=$ex out=$out"; fail=1; }
rm -rf .claude/hooks; rm -f "$BLKLOG"

echo "mass-audit-fixes-10 G5: a directory entry in ## Files is hashed by its files, so an edit under it drops a resume mark"
git add -A && git commit -qm "vr: a clean tree to start from" >/dev/null 2>&1
mkdir -p src/vr
VRLOG="$(mktemp -u)"
printf 'printf "x" >> "%s"\ngrep -qx good src/vr/a.txt\n' "$VRLOG" > vr-check.sh
printf 'init\n' > src/vr/a.txt
printf '| VR check | `bash vr-check.sh` |\n' >> CLAUDE.md
printf -- '---\nstory: stray-21\nspec: stray\nstatus: in-progress\nreturned: DONE\nwave: 21\n---\n# Stray fixture 21\n\n## Files\n- src/vr/\n\n## Verification\n`bash vr-check.sh`\n`true`\n' > docs/specs/stray/stray-21.md
git add -A && git commit -qm "vr: setup" >/dev/null
vr_close() { VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh close-story docs/specs/stray/stray-21.md --commit 2>&1; }
printf 'good\n' > src/vr/a.txt
out="$(vr_close)"; ex=$?
[ "$ex" -eq 7 ] && [ -f .vulyk/state/stray/verify.stray-21.close-story ] && ! grep -q '^verify_resume:' docs/specs/stray/stray-21.md \
  && echo "  ok    call 1: line 1 green, paused before line 2, a record written under .vulyk/state" || { echo "::error::vr call 1: exit=$ex out=$out"; fail=1; }
printf 'bad\n' > src/vr/a.txt
head_before="$(git rev-parse HEAD)"
out="$(vr_close)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(git rev-parse HEAD)" = "$head_before" ] && [ "$(wc -c < "$VRLOG" | tr -d ' ')" = 2 ] && grep -q '^status: in-progress' docs/specs/stray/stray-21.md \
  && echo "  ok    an edit under a ## Files directory invalidates the mark: line 1 runs again on the new code and the failing change is not committed" \
  || { echo "::error::an edit under a ## Files directory invalidates the mark - exit=$ex line-1 runs=$(wc -c < "$VRLOG" 2>/dev/null) head moved=$([ "$(git rev-parse HEAD)" = "$head_before" ] && echo no || echo yes) out=$out"; fail=1; }
printf 'good\n' > src/vr/a.txt
out="$(vr_close)"; ex=$?
out2="$(vr_close)"; ex2=$?
[ "$ex" -eq 7 ] && [ "$ex2" -eq 0 ] && [ "$(wc -c < "$VRLOG" | tr -d ' ')" = 3 ] && git show HEAD:docs/specs/stray/stray-21.md | grep -q '^status: done' \
  && echo "  ok    with nothing under the entry changed the mark still resumes: line 1 not run again, the story closes" \
  || { echo "::error::vr resume: exit=$ex/$ex2 line-1 runs=$(wc -c < "$VRLOG" 2>/dev/null) out=$out2"; fail=1; }
[ ! -e .vulyk/state/stray/verify.stray-21.close-story ] && echo "  ok    the finished close-story leaves no record behind" \
  || { echo "::error::a finished close-story left its record: $(cat .vulyk/state/stray/verify.stray-21.close-story 2>&1)"; fail=1; }
rm -f "$VRLOG"

echo "upgrade-findings-03 A1: the resume point lives in .vulyk/state, never in the story file"
VSLOG="$(mktemp -u)"
printf 'printf "x" >> "%s"\n[ ! -f "%s.fail" ]\n' "$VSLOG" "$VSLOG" > vs-count.sh
printf '| VS count | `bash vs-count.sh` |\n| VS other | `echo vs-other` |\n' >> CLAUDE.md
vs_story() { # vs_story <nn> <verification-lines> - an in-progress stray story declaring vs-<nn>.txt only
  printf 'v1\n' > "vs-$1.txt"
  printf -- '---\nstory: stray-%s\nspec: stray\nstatus: in-progress\nreturned: DONE\nwave: %s\n---\n# Stray fixture %s\n\n## Files\n- vs-%s.txt\n\n## Verification\n%s\n' \
    "$1" "$1" "$1" "$1" "$2" > "docs/specs/stray/stray-$1.md"
}
vs_runs() { wc -c < "$VSLOG" 2>/dev/null | tr -d ' '; }
vs_close() { VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh close-story "docs/specs/stray/stray-$1.md" --commit "${@:2}"; }
vs_story 23 $'`bash vs-count.sh`\n`true`'
git add -A && git commit -qm "vs: setup 23" >/dev/null
: > "$VSLOG.fail"   # line 1 fails from here on (the flag sits outside the fixture repo)
awk -v line="verify_resume: close-story 2 $(set_hash vs-23.txt)" 'NR > 1 && /^---$/ && !d { print line; d=1 } { print }' docs/specs/stray/stray-23.md > vs.tmp && cat vs.tmp > docs/specs/stray/stray-23.md && rm -f vs.tmp
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-23.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(vs_runs)" = 1 ] && [ "$(git rev-parse HEAD)" = "$head_before" ] && grep -q '^status: in-progress' docs/specs/stray/stray-23.md \
  && echo "  ok    a hand-written resume mark is ignored: close-story runs line 1, exits 4, commits nothing" \
  || { echo "::error::a hand-written resume mark is ignored - expected exit 4 with line 1 run once and nothing committed: exit=$ex line-1 runs=$(vs_runs) head moved=$([ "$(git rev-parse HEAD)" = "$head_before" ] && echo no || echo yes) out=$out"; fail=1; }
rm -f "$VSLOG.fail" "$VSLOG"
git add -A && git commit -qm "vs: 23 left open" >/dev/null

vs_story 24 $'`bash vs-count.sh`\n`true`'
git add -A && git commit -qm "vs: setup 24" >/dev/null
VSREC=.vulyk/state/stray/verify.stray-24.close-story
out="$(vs_close 24 2>&1)"; ex=$?
[ "$ex" -eq 7 ] && [ -f "$VSREC" ] && ! grep -q '^verify_resume:' docs/specs/stray/stray-24.md && [ -z "$(git status --porcelain | grep -v ' memory/stats/')" ] \
  && grep -q '^line=1 0 [0-9a-f]\{64\}$' "$VSREC" && grep -q '^next=2$' "$VSREC" \
  && echo "  ok    a real pause: exit 7, a record under .vulyk/state/stray/, no verify_resume line, git status shows nothing new" \
  || { echo "::error::real pause: exit=$ex record=$(cat "$VSREC" 2>&1) status=$(git status --porcelain) out=$out"; fail=1; }
out="$(vs_close 24 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(vs_runs)" = 1 ] && git show HEAD:docs/specs/stray/stray-24.md | grep -q '^status: done' && [ ! -e "$VSREC" ] \
  && echo "  ok    the rerun starts at the paused line (line 1 ran once), closes, and removes the record" \
  || { echo "::error::resume from the record: exit=$ex line-1 runs=$(vs_runs) record=$(cat "$VSREC" 2>&1) out=$out"; fail=1; }
rm -f "$VSLOG"

vs_story 25 $'`bash vs-count.sh`\n`true`'
git add -A && git commit -qm "vs: setup 25" >/dev/null
VSREC=.vulyk/state/stray/verify.stray-25.close-story
vs_restart() { # vs_restart <label> <reason> <runs-after> - rerun after a change: line 1 runs again, stderr says why
  out="$(vs_close 25 "${@:4}" 2>&1)"; ex=$?
  [ "$ex" -eq 7 ] && [ "$(vs_runs)" = "$3" ] && printf '%s' "$out" | grep -qF "resume record not used ($2" \
    && echo "  ok    $1: line 1 runs again, stderr says why" \
    || { echo "::error::$1 - expected line 1 to run again (runs $3) with reason '$2': exit=$ex runs=$(vs_runs) out=$out"; fail=1; }
}
out="$(vs_close 25 2>&1)"; ex=$?
[ "$ex" -eq 7 ] || { echo "::error::stray-25 call 1: exit=$ex out=$out"; fail=1; }
grep -v '^line=1 ' "$VSREC" > vs.tmp && cat vs.tmp > "$VSREC" && rm -f vs.tmp
vs_restart "a record without a line=1 0 entry" "no recorded exit 0 for line 1" 2
printf 'v2\n' > stray-other.txt; git add -A && git commit -qm "vs: a code commit lands" >/dev/null
vs_restart "a non-paperwork commit since the pause" "HEAD moved" 3
vs_restart "a different --stamp" "--stamp differs" 4 --stamp other-driver
sed_inplace 's/^`true`$/`echo vs-other`/' docs/specs/stray/stray-25.md
vs_restart "a changed verification line" "## Verification changed" 5 --stamp other-driver
printf '\n- vs paperwork\n' >> docs/specs/stray/journal.md
git add docs/specs/stray/journal.md && git commit -qm "vulyk(stray): journal" -- docs/specs/stray/journal.md >/dev/null
out="$(vs_close 25 --stamp other-driver 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(vs_runs)" = 5 ] && [ ! -e "$VSREC" ] \
  && echo "  ok    a paperwork-only commit between pause and rerun still resumes: line 1 not run again, the story closes" \
  || { echo "::error::paperwork-only commit: exit=$ex runs=$(vs_runs) out=$out"; fail=1; }
rm -f "$VSLOG"

echo "mass-audit-fixes-10 G6: a git add that fails in close-story --commit refuses with exit 2, nothing committed, status: untouched"
printf 'v1\n' > stray-add-fail.txt
printf -- '---\nstory: stray-22\nspec: stray\nstatus: in-progress\nreturned: DONE\nwave: 22\n---\n# Stray fixture 22\n\n## Files\n- stray-app.txt\n- stray-add-fail.txt\n\n## Verification\n`true`\n' > docs/specs/stray/stray-22.md
git add -A && git commit -qm "add-fail: setup" >/dev/null
GSHIM="$(mktemp -d)"
printf '#!/usr/bin/env bash\nif [ "$1" = add ]; then for a in "$@"; do [ "$a" = stray-add-fail.txt ] && { echo "fatal: the shim refuses this add" >&2; exit 128; }; done; fi\nexec "%s" "$@"\n' "$(command -v git)" > "$GSHIM/git"
chmod +x "$GSHIM/git"
printf 'v22\n' > stray-app.txt; printf 'v22\n' > stray-add-fail.txt
head_before="$(git rev-parse HEAD)"
out="$(PATH="$GSHIM:$PATH" bash scripts/cycle.sh close-story docs/specs/stray/stray-22.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && [ "$(git rev-parse HEAD)" = "$head_before" ] && grep -q '^status: in-progress' docs/specs/stray/stray-22.md \
  && [ -z "$(git diff --cached --name-only)" ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"git add failed: stray-add-fail.txt"' \
  && echo "  ok    a failing git add: exit 2 naming the path, nothing committed or left staged, status: untouched" \
  || { echo "::error::a failing git add in close-story - exit=$ex head moved=$([ "$(git rev-parse HEAD)" = "$head_before" ] && echo no || echo yes) staged=$(git diff --cached --name-only | tr '\n' ' ') out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/stray/stray-22.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show --name-only --format= HEAD | grep -qx stray-add-fail.txt \
  && echo "  ok    without the shim the same close commits both files" || { echo "::error::add-fail rerun: exit=$ex out=$out"; fail=1; }
rm -rf "$GSHIM"

echo "tails-1115-01 (T25): commands_lint names the round gate only for the full-suite row; any other several-command row is told to split it"
LINTF="$(mktemp)"
printf '# C\n\n## Commands\n\n| Purpose | Command |\n|---|---|\n| Full suite steps (round-only) | `sh full-a.sh` `sh full-b.sh` |\n| Lint pair | `sh lint-a.sh` or `sh lint-b.sh` |\n' > "$LINTF"
lint="$(commands_lint "$LINTF" 2>&1)"; ex=$?
want="commands: row 'Full suite steps (round-only)': 2 backticked commands in one cell (the round gate refuses it as a full-suite row; split it)
commands: row 'Lint pair': 2 backticked commands in one cell (close-story runs one command per cell; split it)"
[ "$ex" -eq 0 ] && [ "$lint" = "$want" ] \
  && echo "  ok    commands_lint: the full-suite row names the round gate, another several-command row is told close-story runs one command per cell" \
  || { echo "::error::commands_lint: the round gate is named only for the full-suite row - exit=$ex got: $lint"; fail=1; }
rm -f "$LINTF"
fi # part close2
if part scope; then # --- part scope: close-story at Tier 3-4 counts the scope from the head claim recorded for the wave
echo "audit-fixes-1113-09 (S1): at Tier 3 the scope counts from the claim head, committed edits included"
mkdir -p docs/specs/sone docs/specs/sonet
cp "$SRC"/templates/plan.md docs/specs/sone/plan.md; cp "$SRC"/templates/plan.md docs/specs/sonet/plan.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/; s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-14/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/demo#' docs/specs/sone/plan.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\11/' docs/specs/sonet/plan.md
sone_story() { # sone_story <spec> <nn> <wave> <file> - todo, `returned:` empty, ## Files <file>, ## Verification `true`
  printf -- '---\nstory: %s-%s\nspec: %s\nstatus: todo\nreturned:\nwave: %s\n---\n# Sone fixture %s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$2" "$1" "$3" "$2" "$4" > "docs/specs/$1/$1-$2.md"
}
sone_story sone 01 1 sone-a.txt; sone_story sone 02 1 sone-b.txt; sone_story sone 03 2 sone-c.txt; sone_story sonet 01 1 sonet-a.txt
printf 'a\n' > sone-a.txt; printf 'b\n' > sone-b.txt; printf 'c\n' > sone-c.txt; printf 'x\n' > sone-x.txt; printf 't\n' > sonet-a.txt
git add -A && git commit -qm "vulyk(sone): plan" >/dev/null
for n in 01 02 03; do bash scripts/cycle.sh revise "docs/specs/sone/sone-$n.md" >/dev/null 2>&1; done   # A1: each Tier 3 story's approved record
SONE_REC=.vulyk/state/sone/claim
sed_inplace 's/^returned:$/returned: DONE/' docs/specs/sone/sone-03.md; printf 'c2\n' > sone-c.txt
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-03.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"no claim head recorded for wave 2"' && grep -q '^status: todo' docs/specs/sone/sone-03.md \
  && echo "  ok    a Tier 3 close with no claim record: exit 2 no claim head recorded for wave 2" \
  || { echo "::error::a Tier 3 close with no claim record must refuse - exit=$ex out=$out"; fail=1; }
sed_inplace 's/^returned: DONE$/returned:/' docs/specs/sone/sone-03.md; printf 'c\n' > sone-c.txt
sed_inplace 's/^returned:$/returned: DONE/' docs/specs/sonet/sonet-01.md; printf 't2\n' > sonet-a.txt
out="$(bash scripts/cycle.sh close-story docs/specs/sonet/sonet-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(printf '%s\n' "$out" | grep -c 'keeps no claim head: the scope check counts the uncommitted diff only')" -eq 1 ] \
  && echo "  ok    a Tier 1 close passes with one stderr note" || { echo "::error::Tier 1 close with no claim head - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh claim docs/specs/sone s9 2>&1)"; ex=$?
SONE_HEAD="$(git rev-parse HEAD)"
[ "$ex" -eq 0 ] && [ "$(sed -n 's/^wave\.1=//p' "$SONE_REC" 2>/dev/null)" = "$SONE_HEAD" ] \
  && echo "  ok    claim records the head of the wave it builds" || { echo "::error::claim head: exit=$ex out=$out rec=$(cat "$SONE_REC" 2>&1)"; fail=1; }
bash scripts/cycle.sh release docs/specs/sone s9 >/dev/null 2>&1
git commit -q --allow-empty -m "an empty commit moves HEAD" >/dev/null
bash scripts/cycle.sh claim docs/specs/sone s9 >/dev/null 2>&1; bash scripts/cycle.sh release docs/specs/sone s9 >/dev/null 2>&1
[ "$(grep -c '^wave\.1=' "$SONE_REC" 2>/dev/null)" = 1 ] && [ "$(sed -n 's/^wave\.1=//p' "$SONE_REC")" = "$SONE_HEAD" ] \
  && echo "  ok    a second claim of the same wave keeps the first head" || { echo "::error::second claim: $(cat "$SONE_REC" 2>&1)"; fail=1; }
sed_inplace 's/^returned:$/returned: DONE/' docs/specs/sone/sone-02.md; printf 'b2\n' > sone-b.txt
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-02.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    a wave-mate closes first (its close commit lands in the range)" || { echo "::error::wave-mate close: exit=$ex out=$out"; fail=1; }
printf -- '- a note by hand\n' >> docs/specs/sone/journal.md
git add -- docs/specs/sone/journal.md && git commit -qm "vulyk(sone): journal" -- docs/specs/sone/journal.md >/dev/null   # a paperwork commit in the range
sed_inplace 's/^returned:$/returned: DONE/' docs/specs/sone/sone-01.md; printf 'a2\n' > sone-a.txt
printf 'x2\n' > sone-x.txt; git commit -qm "an edit by hand" -- sone-x.txt >/dev/null
head_before="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: sone-x.txt"' && grep -q '^status: todo' docs/specs/sone/sone-01.md \
  && [ "$(git rev-parse HEAD)" = "$head_before" ] \
  && echo "  ok    an edit committed before the close is out of scope: exit 4 naming it, not the wave-mate's close or the paperwork commit" \
  || { echo "::error::an edit committed before the close is out of scope - exit=$ex out=$out"; fail=1; }
git commit -q --allow-empty -m "a later commit" >/dev/null
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: sone-x.txt"' \
  && echo "  ok    an edit committed two commits back is out of scope" || { echo "::error::an edit committed two commits back is out of scope - exit=$ex out=$out"; fail=1; }
printf 'x\n' > sone-x.txt; git commit -qm "the hand edit undone" -- sone-x.txt >/dev/null
printf 'x3\n' > sone-x.txt; git add -- sone-x.txt
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: sone-x.txt"' \
  && echo "  ok    the same edit staged only is out of scope" || { echo "::error::an edit staged only is out of scope - exit=$ex out=$out"; fail=1; }
printf 'x\n' > sone-x.txt; git add -- sone-x.txt
out="$(bash scripts/cycle.sh close-story docs/specs/sone/sone-01.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:docs/specs/sone/sone-01.md | grep -q '^status: done' \
  && echo "  ok    the edit undone: the close passes over the wave-mate's close and the paperwork commit in the range" \
  || { echo "::error::the clean close refused - exit=$ex out=$out"; fail=1; }
fi # part scope
if part approved; then # --- part approved: a story's approved version is a commit cycle.sh made (branch, revise, repair), reanchor
echo "audit-fixes-1113-13 (A1): branch records each story's approved version and wants the plan committed first"
mkdir -p docs/specs/appr
cp "$SRC"/templates/plan.md docs/specs/appr/plan.md
printf '> build the approved demo\n' > docs/specs/appr/brief.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/; s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-14/' docs/specs/appr/plan.md
appr_story() { # appr_story <nn> <file> <frontmatter-lines> - todo, `returned:` empty, wave 1, ## Files <file>, ## Verification `true`
  printf -- '---\nstory: appr-%s\nspec: appr\nstatus: todo\nreturned:\nwave: 1\n%s---\n# Approved fixture %s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$3" "$1" "$2" > "docs/specs/appr/appr-$1.md"
}
appr_story 01 appr-a.txt ''; appr_story 02 appr-b.txt ''; appr_story 03 appr-c.txt $'red: required\nred_reason: x\n'
printf 'a\n' > appr-a.txt; printf 'b\n' > appr-b.txt; printf 'c\n' > appr-c.txt
git add -A && git commit -qm "appr: plan, by hand" >/dev/null
appr_story 04 appr-d.txt ''
out="$(bash scripts/cycle.sh branch docs/specs/appr --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"commit the plan first: docs/specs/appr/appr-04.md"' \
  && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/demo ] && [ -z "$(marker docs/specs/appr/plan.md Branch)" ] \
  && echo "  ok    branch with an untracked story: exit 2 commit the plan first, nothing checked out" \
  || { echo "::error::branch with an untracked story must refuse: commit the plan first - exit=$ex out=$out"; fail=1; }
rm -f docs/specs/appr/appr-04.md
printf '\nA hand note.\n' >> docs/specs/appr/appr-01.md
out="$(bash scripts/cycle.sh branch docs/specs/appr --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"commit the plan first: docs/specs/appr/appr-01.md"' \
  && echo "  ok    branch with a story that differs from HEAD: exit 2 commit the plan first" \
  || { echo "::error::branch with a modified story must refuse: commit the plan first - exit=$ex out=$out"; fail=1; }
git show HEAD:docs/specs/appr/appr-01.md > docs/specs/appr/appr-01.md
out="$(bash scripts/cycle.sh branch docs/specs/appr --commit 2>&1)"; ex=$?
BSHA="$(git rev-parse HEAD)"; BSHA7="$(git rev-parse --short HEAD)"
[ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/appr ] \
  && grep -qx "appr-01=$BSHA" .vulyk/state/appr/approved 2>/dev/null && grep -qx "appr-03=$BSHA" .vulyk/state/appr/approved \
  && grep -qF 'approved records written by branch: 3 stories' docs/specs/appr/journal.md \
  && echo "  ok    branch --commit records every story at its own commit, with a journal line" \
  || { echo "::error::branch records: exit=$ex record=$(cat .vulyk/state/appr/approved 2>&1) out=$out"; fail=1; }
bash scripts/cycle.sh claim docs/specs/appr a1 >/dev/null 2>&1; bash scripts/cycle.sh release docs/specs/appr a1 >/dev/null 2>&1   # S1: the wave's claim head

echo "A1 original case: a story change committed outside cycle.sh leaves the approved version where it was"
a1=docs/specs/appr/appr-01.md; a3=docs/specs/appr/appr-03.md
sed_inplace 's/^`true`$/&\n&/' "$a1"   # a second ## Verification line
git commit -qm "vulyk(appr): revised appr-01" -- "$a1" >/dev/null
sed_inplace 's/^returned:$/returned: DONE/' "$a1"; printf 'a2\n' > appr-a.txt
out="$(bash scripts/cycle.sh close-story "$a1" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"story blocks differ from the approved version ($BSHA7): ## Verification\"" && grep -q '^status: todo' "$a1" \
  && echo "  ok    a hand commit under a vulyk(<slug>): revised subject: the close exits 4 against branch's version" \
  || { echo "::error::a story change committed outside cycle.sh is not approved (vulyk subject, ## Verification) - exit=$ex out=$out"; fail=1; }
sed_inplace '/^red: required$/d' "$a3"
git commit -qm "tidy the story" -- "$a3" >/dev/null
sed_inplace 's/^returned:$/returned: DONE/' "$a3"
out="$(bash scripts/cycle.sh close-story "$a3" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"story blocks differ from the approved version ($BSHA7): red:\"" \
  && echo "  ok    a hand commit under any other subject dropping red: is refused the same way" \
  || { echo "::error::a story change committed outside cycle.sh is not approved (plain subject, red:) - exit=$ex out=$out"; fail=1; }
git show HEAD:"$a3" > "$a3"
sed_inplace 's/^returned: DONE$/returned:/' "$a1"
out="$(bash scripts/cycle.sh revise "$a1" 2>&1)"; ex=$?
RSHA="$(git rev-parse HEAD)"
[ "$ex" -eq 0 ] && [ "$(git log -1 --format=%s)" = "vulyk(appr): revised appr-01" ] && [ "$(sed -n 's/^appr-01=//p' .vulyk/state/appr/approved | tail -n 1)" = "$RSHA" ] \
  && git show --name-only --format= HEAD | grep -qx docs/specs/appr/journal.md \
  && echo "  ok    neighbour: cycle.sh revise commits the story with a journal line and records that commit" \
  || { echo "::error::revise: exit=$ex subject=$(git log -1 --format=%s) record=$(cat .vulyk/state/appr/approved 2>&1) out=$out"; fail=1; }
sed_inplace 's/^returned:$/returned: DONE/' "$a1"
out="$(bash scripts/cycle.sh close-story "$a1" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:"$a1" | grep -q '^status: done' \
  && echo "  ok    the same change through cycle.sh revise is approved and closes" \
  || { echo "::error::a revised story must close against its revise commit - exit=$ex out=$out"; fail=1; }

echo "A1: a Tier 3 story with no record refuses in close-story and stamp-red"
appr_story 05 appr-e.txt $'red: required\nred_reason: x\n'; sed_inplace 's/^returned:$/returned: DONE/' docs/specs/appr/appr-05.md
a5msg='no approved record for docs/specs/appr/appr-05.md: run bash scripts/cycle.sh revise docs/specs/appr/appr-05.md'
out="$(bash scripts/cycle.sh close-story docs/specs/appr/appr-05.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"$a5msg\"" \
  && echo "  ok    close-story: exit 2 no approved record" || { echo "::error::close-story with no record - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh stamp-red docs/specs/appr/appr-05.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF "\"error\":\"$a5msg\"" \
  && echo "  ok    stamp-red: exit 2 no approved record" || { echo "::error::stamp-red with no record - exit=$ex out=$out"; fail=1; }
rm -f docs/specs/appr/appr-05.md

echo "reanchor: a main-session commit between two claims is out of scope until reanchor moves the head"
printf 'hook bits\n' > appr-queen.txt; git add -- appr-queen.txt && git commit -qm "the Queen's hook bits" -- appr-queen.txt >/dev/null
a2=docs/specs/appr/appr-02.md
sed_inplace 's/^returned:$/returned: DONE/' "$a2"; printf 'b2\n' > appr-b.txt
out="$(bash scripts/cycle.sh close-story "$a2" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"edited outside ## Files: appr-queen.txt"' \
  && echo "  ok    before reanchor the main-session commit counts as out of scope" || { echo "::error::before reanchor - exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh reanchor docs/specs/appr 2>&1)"; ex=$?
[ "$ex" -ne 0 ] && echo "  ok    reanchor with no --reason refuses" || { echo "::error::reanchor without a reason passed: $out"; fail=1; }
QSHA="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh reanchor docs/specs/appr --reason "hook bits set by the Queen" 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(sed -n 's/^wave\.1=//p' .vulyk/state/appr/claim | tail -n 1)" = "$QSHA" ] \
  && grep -qF "claim head of wave 1 moved from $BSHA to $QSHA by reanchor: hook bits set by the Queen" docs/specs/appr/journal.md \
  && echo "  ok    reanchor moves the wave's head to HEAD and the journal names the move" \
  || { echo "::error::reanchor: exit=$ex claim=$(cat .vulyk/state/appr/claim 2>&1) journal=$(tail -2 docs/specs/appr/journal.md 2>&1) out=$out"; fail=1; }
out="$(bash scripts/cycle.sh close-story "$a2" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    after reanchor the same close passes" || { echo "::error::after reanchor - exit=$ex out=$out"; fail=1; }

echo "A1 seeding: a spec built before this release gets its records once, from claim, with a journal line"
mkdir -p docs/specs/seed
cp "$SRC"/templates/plan.md docs/specs/seed/plan.md
sed_inplace 's/^\(\*\*Tier:\*\* \)<[^>]*>/\13/; s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-14/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/appr#' docs/specs/seed/plan.md
for n in 01 02; do
  printf -- '---\nstory: seed-%s\nspec: seed\nstatus: todo\nreturned:\nwave: 1\n---\n# Seed %s\n\n## Files\n- seed-%s.txt\n\n## Verification\n`true`\n' "$n" "$n" "$n" > "docs/specs/seed/seed-$n.md"
done
git add -A && git commit -qm "vulyk(seed): plan" >/dev/null
SSHA="$(git rev-parse HEAD)"
out="$(bash scripts/cycle.sh claim docs/specs/seed s1 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -qx "seed-01=$SSHA" .vulyk/state/seed/approved 2>/dev/null && grep -qx "seed-02=$SSHA" .vulyk/state/seed/approved \
  && [ "$(grep -c 'approved records seeded from commit subjects: 2 stories (claim)' docs/specs/seed/journal.md 2>/dev/null)" = 1 ] \
  && echo "  ok    claim seeds each story from the old subject rule and journals it once" \
  || { echo "::error::seeding: exit=$ex record=$(cat .vulyk/state/seed/approved 2>&1) out=$out"; fail=1; }
bash scripts/cycle.sh release docs/specs/seed s1 >/dev/null 2>&1
rm -f .vulyk/state/seed/approved
out="$(bash scripts/cycle.sh claim docs/specs/seed s1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF 'cycle.sh revise' && [ ! -f docs/specs/seed/DRIVER ] \
  && echo "  ok    a record lost after the seeding line: claim exits 2 naming cycle.sh revise" \
  || { echo "::error::a lost record must refuse the claim - exit=$ex out=$out"; fail=1; }

echo "A1: repair records its story at repair's own commit"
mkdir -p docs/specs/apprp
cp "$SRC/templates/plan.md" docs/specs/apprp/plan.md
printf '# apprp (brief)\n\n## Request\n> build the thing\n\n## Asks\n1. ask number 1 works\n' > docs/specs/apprp/brief.md
sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-14/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/appr#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' docs/specs/apprp/plan.md
printf 'a\n' > apprp-a.txt
done_story docs/specs/apprp/apprp-01-a.md '---\nstory: apprp-01\nstatus: done\nwave: 1\n---\n# A\n\n## Requirements\n> build the thing\n\n## Files\n- apprp-a.txt\n\n## Verification\n`true`\n'
git add -A && git commit -qm "apprp: fixture" >/dev/null
bash scripts/cycle.sh open-round docs/specs/apprp --commit >/dev/null 2>&1
printf 'VERDICT: BLOCK\n## Major\n- [ask 1] ask 1 broke: run: t saw: f\n' | bash scripts/cycle.sh record-seat docs/specs/apprp 1 review >/dev/null 2>&1
bash scripts/cycle.sh judge docs/specs/apprp --commit >/dev/null 2>&1
out="$(bash scripts/cycle.sh repair docs/specs/apprp --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f docs/specs/apprp/apprp-02-repair-round-1.md ] && grep -qx "apprp-02=$(git rev-parse HEAD)" .vulyk/state/apprp/approved 2>/dev/null \
  && echo "  ok    repair --commit records the repair story" || { echo "::error::repair record: exit=$ex record=$(cat .vulyk/state/apprp/approved 2>&1) out=$out"; fail=1; }
fi # part approved
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
# post-046-tails ask 4: a 10 s grandchild and a 20 s parent under a 1 s cap, so a box 3x slower still lands
# well inside the window; the marker is read at the end of the part, 12 s after the start, so the wait is
# spent on the cases between.
RC="$(mktemp -d)"; RC_T0="$SECONDS"
( PATH="$CAPD:$PATH"; VULYK_PY=; run_capped 1 bash -c "(sleep 10; : > '$RC/marker') & sleep 20; echo late" ) > "$RC/out" 2>&1; ex=$?
el=$((SECONDS - RC_T0))
[ "$ex" -eq 124 ] && [ "$el" -lt 10 ] && ! grep -q late "$RC/out" && echo "  ok    the Python cap: exit 124 in ${el}s, no late output" \
  || { echo "::error::run_capped 1 under dead timeout/gtimeout: exit=$ex after ${el}s, out: $(cat "$RC/out")"; fail=1; }
err="$( PATH="$DEAD:$PATH"; VULYK_PY=; run_capped 1 true 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && [ "$err" = "run_capped: no timeout, gtimeout or python 3 - running true uncapped" ] \
  && echo "  ok    nothing to cap with: runs uncapped and says so" || { echo "::error::run_capped uncapped: exit=$ex err='$err'"; fail=1; }
LONE="$(mktemp -d)"; cp "$SRC/scripts/lib.sh" "$LONE/"   # a lib.sh with no run-capped.py beside it (macOS: no timeout)
err="$( PATH="$CAPD:$PATH"; VULYK_PY=; bash -c '. "$1/lib.sh"; run_capped 5 true' _ "$LONE" 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    no run-capped.py beside lib.sh: the Python cap is not claimed, the command runs" \
  || { echo "::error::run_capped with no timeout and no run-capped.py beside lib.sh: exit=$ex err='$err'"; fail=1; }
rm -rf "$LONE"
err="$( PATH="$DEAD:$PATH"; VULYK_PY=; run_capped 0 true 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && [ -z "$err" ] && echo "  ok    run_capped 0: uncapped, silently" || { echo "::error::run_capped 0: exit=$ex err='$err'"; fail=1; }
rm -rf "$CAPD" "$DEAD"

echo "cross-platform: load_sample on Windows lists WmiPrvSE and powershell apart from the top five (post-046-tails repair 1)"
# The CIM query is answered by WmiPrvSE inside the powershell.exe the sampler starts: on an idle box they head
# the list (cpu 1%, WmiPrvSE 26% and 21%, measured 2026-11-03). A stub powershell.exe prints the raw rows.
LSD="$(mktemp -d)"
printf '#!/bin/sh\necho MINGW64_NT-10.0-22631\n' > "$LSD/uname"
printf '#!/bin/sh\nprintf "cpu\\t40\\nWmiPrvSE\\t26\\nWmiPrvSE#3\\t21\\nchrome#108\\t13\\npowershell\\t9\\nnode\\t8\\nclaude#13\\t8\\nSystem\\t5\\ngit\\t4\\nbash\\t3\\n"\n' > "$LSD/powershell.exe"
chmod +x "$LSD/uname" "$LSD/powershell.exe"
got="$( PATH="$LSD:$PATH"; load_sample 2>&1 )"; ex=$?
# By name only, so a real powershell or WMI load would hide too: the rows are listed after the top five, not dropped.
[ "$ex" -eq 0 ] && [ "$got" = "cpu 40% top: chrome#108 13%, node 8%, claude#13 8%, System 5%, git 4%; named like the sampler: WmiPrvSE 26%, WmiPrvSE#3 21%, powershell 9%" ] \
  && echo "  ok    WmiPrvSE and powershell are listed apart from the top five" \
  || { echo "::error::WmiPrvSE and powershell are listed apart from the top five - exit=$ex got: $got"; fail=1; }
rm -rf "$LSD"

echo "X-07: off Windows, load_sample reads the load over an interval, not ps's lifetime pcpu"
# macOS: the second sample of top -l 2 (the first has no interval behind it). A stub top prints both.
LSD="$(mktemp -d)"
printf '#!/bin/sh\necho Darwin\n' > "$LSD/uname"
printf '#!/bin/sh\nprintf "Processes: 1\\nCPU usage: 1.0%%%% user, 1.0%%%% sys, 98.0%%%% idle\\nCOMMAND %%%%CPU\\nlifetime 99.0\\nProcesses: 1\\nCPU usage: 20.5%%%% user, 9.0%%%% sys, 70.5%%%% idle\\nCOMMAND          %%%%CPU\\nGoogle Chrome He 31.2\\nkernel_task      12.0\\n"\n' > "$LSD/top"
printf '#!/bin/sh\necho "10:00  up 1 day, load averages: 2.10 1.50 1.20"\n' > "$LSD/uptime"
chmod +x "$LSD/uname" "$LSD/top" "$LSD/uptime"
got="$( PATH="$LSD:$PATH"; load_sample 2>&1 )"; ex=$?
[ "$ex" -eq 0 ] && [ "$got" = "cpu 30% top: Google Chrome He 31.2%, kernel_task 12.0%; load 2.10 1.50 1.20" ] \
  && echo "  ok    macOS: cpu and the top rows come from top's second sample" \
  || { echo "::error::macOS load_sample - exit=$ex got: $got"; fail=1; }
printf '#!/bin/sh\necho "top: illegal option -- l"; exit 1\n' > "$LSD/top"
got="$( PATH="$LSD:$PATH"; load_sample 2>&1 )"; ex=$?
[ "$ex" -ne 0 ] && echo "  ok    macOS: a top with no CPU usage line fails, so the suite says LOAD: unavailable" \
  || { echo "::error::a broken top still gave a load: $got"; fail=1; }
rm -rf "$LSD"
# Linux: busy share of the /proc/stat delta; a process's share of one core from its utime+stime delta. Only a
# pid in both snaps counts (gone and new are left out), a name with spaces and `)` stays whole.
got="$(printf 'T 1000 800\nP\t1\t100\tinit\nP\t42\t50\tmy (odd) name\nP\t7\t10\tgone\nP\t5\t1\tidle\n--\nT 1400 1000\nP\t1\t180\tinit\nP\t42\t250\tmy (odd) name\nP\t9\t30\tnew\nP\t5\t1\tidle\n' | load_from_proc_snaps 4)"
[ "$got" = "cpu 50% top: my (odd) name 200.0%, init 80.0%" ] && echo "  ok    Linux: the load is the interval's delta, per core" \
  || { echo "::error::load_from_proc_snaps got: $got"; fail=1; }
printf 'T 1000 800\n--\nT 1000 800\n' | load_from_proc_snaps 4 >/dev/null && { echo "::error::an empty interval gave a load"; fail=1; } \
  || echo "  ok    Linux: an empty interval is no load"

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
cell_case no  'pytest "-p" evil'        # P9-05: quotes, a backslash, a tab or braces smuggle an option past the class
cell_case no  "pytest '-p' evil"
cell_case no  'pytest \-p evil'
cell_case no  "pytest a.py$(printf '\t')-p evil"
cell_case no  'pytest {-p,evil}'
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

w=$((RC_T0 + 12 - SECONDS)); [ "$w" -gt 0 ] && sleep "$w"
[ ! -e "$RC/marker" ] && echo "  ok    the run_capped grandchild died with its process group (read 12 s after the start)" \
  || { echo "::error::run_capped left a grandchild that wrote its marker"; fail=1; }
rm -rf "$RC"

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
  done_story docs/specs/ss/ss-01.md '---\nstory: ss-01\nspec: ss\nstatus: done\nwave: 1\n---\n# S1\n'
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

echo "ab-run-fixes C9: claim and advance --claim accept leftover edits in a todo wave story's ## Files, and refuse any other dirty path"
git add -A && git commit -qm "lftv: a clean tree to start from" >/dev/null 2>&1
LFTV_BR="$(git rev-parse --abbrev-ref HEAD)"
mkdir -p docs/specs/lftv
cp "$SRC"/templates/plan.md docs/specs/lftv/plan.md
printf '> leave edits behind\n' > docs/specs/lftv/brief.md
sed_inplace "s/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-09/; s#^\*\*Branch:\*\* <.*#**Branch:** $LFTV_BR#" docs/specs/lftv/plan.md
lftv_story() { # lftv_story <nn> <status> <wave> <file>
  printf -- '---\nstory: lftv-%s\nspec: lftv\nstatus: %s\nwave: %s\n---\n# L%s\n\n## Files\n- %s\n\n## Verification\n`true`\n' \
    "$1" "$2" "$3" "$1" "$4" > "docs/specs/lftv/lftv-$1.md"
}
lftv_story 01 todo 1 lftv-a.txt
lftv_story 02 todo 2 lftv-b.txt
git add -A && git commit -qm "lftv fixture" >/dev/null
printf 'half done\n' > lftv-a.txt
printf '\n## Implementation notes\n- half done\n' >> docs/specs/lftv/lftv-01.md
out="$(bash scripts/cycle.sh claim docs/specs/lftv lftvstamp 2>&1)"; ex=$?
if [ "$ex" -eq 0 ] && printf '%s' "$out" | tail -1 | grep -qF '"leftover":["docs/specs/lftv/lftv-01.md"]'; then
  echo "  ok    claim: leftover edits of a wave story are accepted"
else echo "::error::claim: leftover edits of a wave story are accepted - exit=$ex out=$out"; fail=1; fi
bash scripts/cycle.sh release docs/specs/lftv lftvstamp >/dev/null 2>&1
out="$(bash scripts/cycle.sh advance docs/specs/lftv --claim --stamp lftvstamp 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | tail -1 | grep -qF '"leftover":["docs/specs/lftv/lftv-01.md"],"status":{' \
  && printf '%s' "$out" | tail -1 | grep -qF '"next":"build:1"' \
  && echo "  ok    advance --claim carries leftover and walks on to build:1" || { echo "::error::advance --claim leftover: exit=$ex out=$out"; fail=1; }
bash scripts/cycle.sh release docs/specs/lftv lftvstamp >/dev/null 2>&1
for lftv_stray in lftv-b.txt lftv-stray.txt; do # a later wave's ## Files, and a path no story names
  printf 'x\n' > "$lftv_stray"
  out="$(bash scripts/cycle.sh claim docs/specs/lftv lftvstamp 2>&1)"; ex=$?
  [ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"working tree not clean"' && printf '%s' "$out" | grep -qF "$lftv_stray" \
    && [ ! -e docs/specs/lftv/DRIVER ] \
    && echo "  ok    neighbour: a dirty $lftv_stray beside the leftover is still refused, no DRIVER" || { echo "::error::claim with $lftv_stray dirty: exit=$ex out=$out"; fail=1; }
  rm -f "$lftv_stray"
done
rm -f lftv-a.txt docs/specs/lftv/DRIVER
git checkout -q -- docs/specs/lftv/lftv-01.md
out="$(bash scripts/cycle.sh claim docs/specs/lftv lftvstamp 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -qF '"leftover"' \
  && echo "  ok    neighbour: a clean tree claims with no leftover key, the line as before" || { echo "::error::clean claim: exit=$ex out=$out"; fail=1; }
bash scripts/cycle.sh release docs/specs/lftv lftvstamp >/dev/null 2>&1

echo "beta-fixes-1113-04 R1: resume switches a clean tree to the plan's **Branch:**, and only reports a dirty one"
RS_HOME="$(git rev-parse --abbrev-ref HEAD)"
git add -A && git commit -qm "rs: a clean tree to start from" >/dev/null 2>&1
mkdir -p docs/specs/acme docs/specs/acmegone docs/specs/acmenob
for rs_s in acme acmegone acmenob; do
  cp "$SRC"/templates/plan.md "docs/specs/$rs_s/plan.md"
  printf '> resume on the spec branch\n' > "docs/specs/$rs_s/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-13/' "docs/specs/$rs_s/plan.md"
done
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/acme-spec#' docs/specs/acme/plan.md
sed_inplace 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/acme-gone#' docs/specs/acmegone/plan.md
printf -- '---\nstory: acme-01\nspec: acme\nstatus: todo\nreturned: DONE\nwave: 1\n---\n# Acme\n\n## Files\n- acme.txt\n\n## Verification\n`true`\n' > docs/specs/acme/acme-01.md
git add -A && git commit -qm "acme: setup" >/dev/null
git branch -f vulyk/acme-spec HEAD
git branch -f main HEAD && git checkout -q main
rs_pause() { printf 'owner \xc2\xb7 test \xc2\xb7 now\nhead=%s\n' "$(git rev-parse --short HEAD)" > "docs/specs/$1/PAUSE"; } # rs_pause <slug>
rs_head="$(git rev-parse HEAD)"
rs_pause acme
printf 'an edit\n' >> docs/specs/acme/brief.md
out="$(bash scripts/cycle.sh resume docs/specs/acme 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF '"error":"on main, spec branch is vulyk/acme-spec: uncommitted changes in docs/specs/acme/brief.md"' \
  && [ "$(git rev-parse --abbrev-ref HEAD)" = main ] && [ "$(git rev-parse HEAD)" = "$rs_head" ] && grep -qx 'an edit' docs/specs/acme/brief.md \
  && [ -f docs/specs/acme/PAUSE ] \
  && echo "  ok    a tracked edit: exit 2 naming it, HEAD, the file and PAUSE untouched" || { echo "::error::resume dirty tracked: exit=$ex out=$out"; fail=1; }
printf '> resume on the spec branch\n' > docs/specs/acme/brief.md
printf 'stray\n' > acme-stray.txt
out="$(bash scripts/cycle.sh resume docs/specs/acme 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF 'uncommitted changes in acme-stray.txt"' \
  && [ "$(git rev-parse --abbrev-ref HEAD)" = main ] && [ -f acme-stray.txt ] && [ -f docs/specs/acme/PAUSE ] \
  && echo "  ok    an untracked file: exit 2 naming it, HEAD, the file and PAUSE untouched" || { echo "::error::resume dirty untracked: exit=$ex out=$out"; fail=1; }
rm -f acme-stray.txt
rs_pause acmegone
out="$(bash scripts/cycle.sh resume docs/specs/acmegone 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | tail -1 | grep -qF 'vulyk/acme-gone' && [ "$(git rev-parse --abbrev-ref HEAD)" = main ] \
  && [ -f docs/specs/acmegone/PAUSE ] \
  && echo "  ok    a **Branch:** that does not exist: exit 2 naming it, still on main" || { echo "::error::resume missing branch: exit=$ex out=$out"; fail=1; }
rm -f docs/specs/acmegone/PAUSE
out="$(bash scripts/cycle.sh resume docs/specs/acme 2>&1)"; ex=$?
if [ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acme-spec ] \
   && printf '%s' "$out" | tail -1 | grep -qF '"switched":"vulyk/acme-spec"' && [ ! -f docs/specs/acme/PAUSE ]; then
  echo "  ok    a clean tree on main: resume switches to vulyk/acme-spec and says so"
else echo "::error::resume switch: exit=$ex head=$(git rev-parse --abbrev-ref HEAD) out=$out"; fail=1; fi
out="$(bash scripts/cycle.sh claim docs/specs/acme rsstamp 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    the next claim passes the branch guard" || { echo "::error::claim after resume: exit=$ex out=$out"; fail=1; }
bash scripts/cycle.sh release docs/specs/acme rsstamp >/dev/null 2>&1
rs_pause acme
out="$(bash scripts/cycle.sh resume docs/specs/acme 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -qF '"switched"' && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acme-spec ] \
  && echo "  ok    neighbour: already on the spec branch, resume as before" || { echo "::error::resume on branch: exit=$ex out=$out"; fail=1; }
rs_pause acmenob
out="$(bash scripts/cycle.sh resume docs/specs/acmenob 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -qF '"switched"' && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acme-spec ] \
  && echo "  ok    neighbour: no **Branch:** line, resume as before" || { echo "::error::resume no branch line: exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "rs: journals" >/dev/null 2>&1
echo "beta-fixes-1113 (ask 8): resume finds the spec branch that only that branch's plan copy names"
git checkout -q main
mkdir -p docs/specs/acmebr docs/specs/acmestale
for rs_s in acmebr acmestale; do
  cp "$SRC"/templates/plan.md "docs/specs/$rs_s/plan.md"
  printf '> resume on the spec branch\n' > "docs/specs/$rs_s/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-13/' "docs/specs/$rs_s/plan.md"
done
git add -A && git commit -qm "acmebr: plans on main" >/dev/null
git branch -f vulyk/acmestale HEAD   # a branch by the spec's name whose plan copy names no branch
out="$(bash scripts/cycle.sh branch docs/specs/acmebr --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acmebr ] && git switch -q main && [ -z "$(git status --porcelain)" ] \
  && ! grep -q '^\*\*Branch:\*\* vulyk' docs/specs/acmebr/plan.md \
  && echo "  ok    branch --commit wrote the **Branch:** line on vulyk/acmebr only; main is clean" || { echo "::error::branch setup: exit=$ex out=$out"; fail=1; }
out="$(bash scripts/cycle.sh resume docs/specs/acmebr 2>&1)"; ex=$?
if [ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acmebr ] \
   && printf '%s' "$out" | tail -1 | grep -qF '"switched":"vulyk/acmebr"' && ! printf '%s' "$out" | tail -1 | grep -qF '"next":"branch"' \
   && [ "$(git status --porcelain | grep -cv 'docs/specs/acmebr/journal.md')" -eq 0 ]; then
  echo "  ok    a clean tree on main: resume switches to vulyk/acmebr, named only on that branch, next is no longer branch"
else echo "::error::resume did not switch to the spec branch named only on that branch - exit=$ex head=$(git rev-parse --abbrev-ref HEAD) out=$out"; fail=1; fi
out="$(bash scripts/cycle.sh claim docs/specs/acmebr rsbrstamp 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(git rev-parse --abbrev-ref HEAD)" = vulyk/acmebr ] && echo "  ok    the next claim passes the branch guard on vulyk/acmebr" \
  || { echo "::error::claim after a branch-only resume: exit=$ex out=$out"; fail=1; }
bash scripts/cycle.sh release docs/specs/acmebr rsbrstamp >/dev/null 2>&1
git add -A && git commit -qm "rs: acmebr journal" >/dev/null 2>&1
git checkout -q main
out="$(bash scripts/cycle.sh resume docs/specs/acmestale 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && ! printf '%s' "$out" | grep -qF '"switched"' && [ "$(git rev-parse --abbrev-ref HEAD)" = main ] \
  && echo "  ok    neighbour: a vulyk/<slug> whose plan copy names no branch is not switched to" || { echo "::error::resume stale branch: exit=$ex out=$out"; fail=1; }
git add -A && git commit -qm "rs: acmestale journal" >/dev/null 2>&1
git checkout -q "$RS_HOME"
fi # part safety
if part red || part red2 || part red3 || part runstate; then # --- the red fixtures parts red, red2, red3 and runstate share
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
fi # red fixtures
if part red2; then # --- part red2: wave-check red lines, repair inherits the mark, a body red: line (split from red for time)

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
  done_story "docs/specs/$1/$1-01-a.md" '---\nstory: %s-01\nstatus: done\nwave: 1\n%s---\n# A\n\n## Requirements\n> build the thing\n\n## Files\n- %s-a.txt\n\n## Verification\n`true`\n' \
    "$1" "$2" "$1"
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
# narrow-repair-1115-01: a plain RED round's repair is narrow (round_scope) whatever its findings name, so `narrow: true` follows blocked_by
[ "$(sed -n '1,10p' "$rq" 2>/dev/null)" = "$(printf -- '---\nstory: redrq-02\nstatus: todo\nreturned:\nworker: worker-code\nmodel: opus\nwave: 2\nblocked_by: []\nnarrow: true\n---')" ] \
  && ! grep -q '^red' "$rq" && echo "  ok    an unmarked union writes the frontmatter as before plus narrow: true; no red: line" \
  || { echo "::error::unmarked repair frontmatter changed: $(sed -n '1,12p' "$rq" 2>/dev/null) / $out"; fail=1; }

echo "red-receipt: the repair keeps the mark unless every finding names a file and none a marked story's (0.40.1)"
red_rp_two() { # red_rp_two <slug> <major-lines> - done stories 01 (marked, <slug>-a.txt) and 02 (unmarked, <slug>-doc.md), a RED round 1, its repair
  mkdir -p "docs/specs/$1"
  cp "$SRC/templates/plan.md" "docs/specs/$1/plan.md"
  printf '# %s (brief)\n\n## Request\n> build the thing\n\n## Asks\n1. ask number 1 works\n' "$1" > "docs/specs/$1/brief.md"
  sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-10-28/; s#^\*\*Branch:\*\* <.*#**Branch:** '"$(git rev-parse --abbrev-ref HEAD)"'#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' "docs/specs/$1/plan.md"
  printf 'a\n' > "$1-a.txt"; printf 'doc\n' > "$1-doc.md"
  done_story "docs/specs/$1/$1-01-a.md" '---\nstory: %s-01\nstatus: done\nwave: 1\n%s---\n# A\n\n## Files\n- %s-a.txt\n\n## Verification\n`true`\n' "$1" "$MK" "$1"
  done_story "docs/specs/$1/$1-02-doc.md" '---\nstory: %s-02\nstatus: done\nwave: 1\n---\n# D\n\n## Files\n- %s-doc.md\n\n## Verification\n`true`\n' "$1" "$1"
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

fi # part red2
if part red; then # --- part red: stamp-red, the close-story receipt gate
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

echo "red-receipt (post-046-tails ask 3): the receipt carries the red_reason line even when 10+ passing lines follow it"
st=docs/specs/red/red-13.md
{ printf '#!/usr/bin/env bash\necho "expected done in src/red.txt, got $(cat src/red.txt)"\n'
  for i in 1 2 3 4 5 6 7 8 9 10 11 12; do printf 'echo "  ok    passing case %s"\n' "$i"; done
  printf 'exit 1\n'; } > tests/red-long.sh
red_story 13 "$MK" $'- tests/red-long.sh\n- src/red.txt\n' '`bash tests/red-long.sh`'
out="$(bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
rcpt="$(sed -n '/^## Red receipt/,$p' "$st")"
[ "$ex" -eq 0 ] && printf '%s' "$rcpt" | grep -qF 'expected done in src/red.txt, got todo' && printf '%s' "$rcpt" | grep -qF 'passing case 12' \
  && echo "  ok    ## Red receipt holds the red_reason line and the last lines" \
  || { echo "::error::receipt lost the red_reason line: exit=$ex $rcpt $(printf '%s\n' "$out" | tail -1)"; fail=1; }
git add -A && git commit -qm "red: stamp fixtures" >/dev/null

echo "mass-audit-fixes-10 D5: stamp-red --baseline re-stamps against HEAD's implementation and puts the working copy back"
printf 'todo\n' > src/red16.txt
printf '#!/usr/bin/env bash\ngrep -qx done src/red16.txt && [ -f src/red16-new.txt ] && exit 0\necho "expected done in src/red16.txt"\nexit 1\n' > tests/red16.sh
red_story 16 "$MK" $'- tests/red16.sh\n- src/red16.txt\n- src/red16-new.txt\n' '`bash tests/red16.sh`'
red_story 17 $'red: required\nred_reason: expected something else\n' $'- tests/red16.sh\n- src/red16.txt\n- src/red16-new.txt\n' '`bash tests/red16.sh`'
git add -A && git commit -qm "red: baseline stories" >/dev/null
printf 'done\n' > src/red16.txt; printf 'new\r\nbytes\n' > src/red16-new.txt   # the implementation, green and uncommitted
printf '# edited after green\n' >> tests/red16.sh                             # the sealed test, edited after green
wc_before="$(cksum < src/red16.txt) $(cksum < src/red16-new.txt) $(cksum < tests/red16.sh)"
stash_before="$(git stash list | wc -l | tr -d ' ')"
out="$(bash scripts/cycle.sh stamp-red docs/specs/red/red-16.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"not red: every verification line exits 0"' \
  && echo "  ok    without --baseline the green working copy is no red" || { echo "::error::plain stamp on green: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
out="$(bash scripts/cycle.sh stamp-red docs/specs/red/red-17.md --baseline 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"red for another reason' \
  && [ "$(cksum < src/red16.txt) $(cksum < src/red16-new.txt) $(cksum < tests/red16.sh)" = "$wc_before" ] \
  && echo "  ok    --baseline whose stamp exits 4: the working copy is back byte for byte, the new file too" \
  || { echo "::error::stamp-red --baseline exit 4 restore: exit=$ex $(printf '%s\n' "$out" | tail -1) files=$(cat src/red16.txt src/red16-new.txt 2>&1)"; fail=1; }
out="$(bash scripts/cycle.sh stamp-red docs/specs/red/red-16.md --baseline 2>&1)"; ex=$?
sha="$( . scripts/lib.sh; sha256_tool )"   # the receipt's impl hash, worked out by hand for HEAD's state: the new file missing
ih16="$( { printf 'missing src/red16-new.txt\n'; printf '%s  src/red16.txt\n' "$(git show HEAD:src/red16.txt | $sha | cut -c1-64)"; } | $sha | cut -c1-64)"
[ "$ex" -eq 0 ] && grep -qx -- "- impl: $ih16" docs/specs/red/red-16.md && grep -qF 'expected done in src/red16.txt' docs/specs/red/red-16.md \
  && [ "$(cksum < src/red16.txt) $(cksum < src/red16-new.txt) $(cksum < tests/red16.sh)" = "$wc_before" ] \
  && [ "$(git stash list | wc -l | tr -d ' ')" = "$stash_before" ] \
  && echo "  ok    --baseline: the receipt is HEAD's red, the working copy is back byte for byte, no stash entry" \
  || { echo "::error::stamp-red --baseline: exit=$ex $(printf '%s\n' "$out" | tail -2) impl=$(grep -- '^- impl:' docs/specs/red/red-16.md) want=$ih16 files=$(cat src/red16.txt src/red16-new.txt 2>&1) stash=$(git stash list)"; fail=1; }
out="$(bash scripts/cycle.sh close-story docs/specs/red/red-16.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:docs/specs/red/red-16.md | grep -q '^status: done' \
  && echo "  ok    after the --baseline re-stamp the story closes on its green implementation" \
  || { echo "::error::close after --baseline: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
git add -A && git commit -qm "red: baseline done" >/dev/null 2>&1

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

echo "red-receipt (0.48.1): the seal covers the test and the program a line runs, never a plain implementation or lint-config argument"
st=docs/specs/red/red-14.md
mkdir -p tools
printf 'todo\n' > src/red14.txt
printf '#!/usr/bin/env bash\ngrep -qx done src/red14.txt && exit 0\necho "expected done in src/red14.txt"\nexit 1\n' > tests/red14.sh
printf '#!/usr/bin/env bash\n# lints the files it is given, by the config it is given\nexit 0\n' > tools/lint14.sh
printf 'rule: a\n' > src/lint14.cfg
red_story 14 "$MK" $'- tests/red14.sh\n- src/red14.txt\n- src/lint14.cfg\n' $'`bash tests/red14.sh`\n`bash tools/lint14.sh src/lint14.cfg src/red14.txt tests/red14.sh`'
git add -A && git commit -qm "red: seal-scope story" >/dev/null
bash scripts/cycle.sh stamp-red "$st" >/dev/null 2>&1 && echo "  ok    red-14 stamped" || { echo "::error::red-14 stamp failed"; fail=1; }
grep -qE -- '^- tests: [0-9a-f]{64} \(tests/red14\.sh\)$' "$st" \
  && echo "  ok    the receipt seals tests/red14.sh, not the implementation or the lint config" || { echo "::error::sealed set: $(grep -- '^- tests:' "$st")"; fail=1; }
printf 'rule: b\n' > src/lint14.cfg
printf 'done\n' > src/red14.txt
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:"$st" | grep -q '^status: done' \
  && echo "  ok    an edit to the verification-named lint config does not break the seal: closed" \
  || { echo "::error::seal-scope close: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
st=docs/specs/red/red-15.md
printf 'todo\n' > src/red15.txt
printf '#!/usr/bin/env bash\ngrep -qx done src/red15.txt && exit 0\necho "expected done in src/red15.txt"\nexit 1\n' > tests/red15.sh
printf '#!/usr/bin/env bash\nbash "$1"\n' > src/check15.sh
red_story 15 "$MK" $'- src/check15.sh\n- tests/red15.sh\n- src/red15.txt\n' '`bash src/check15.sh tests/red15.sh`'
git add -A && git commit -qm "red: checker story" >/dev/null
bash scripts/cycle.sh stamp-red "$st" >/dev/null 2>&1 && echo "  ok    red-15 stamped" || { echo "::error::red-15 stamp failed"; fail=1; }
grep -qE -- '^- tests: [0-9a-f]{64} \(src/check15\.sh, tests/red15\.sh\)$' "$st" \
  && echo "  ok    the repo script the line runs is sealed beside its test argument" || { echo "::error::checker not sealed: $(grep -- '^- tests:' "$st")"; fail=1; }
printf '#!/usr/bin/env bash\nexit 0\n' > src/check15.sh
printf 'done\n' > src/red15.txt
out="$(bash scripts/cycle.sh close-story "$st" --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"test changed after red receipt: re-run stamp-red"' \
  && echo "  ok    a checker weakened after the stamp: exit 4" || { echo "::error::weakened checker: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
printf '#!/usr/bin/env bash\nbash "$1"\n' > src/check15.sh
printf 'todo\n' > src/red15.txt
git add -A && git commit -qm "red: checker story put back" >/dev/null
( . scripts/lib.sh; sealed_tests 'bash src/chk.sh' $'src/chk.sh\nsrc/x.txt' ) | grep -qx 'src/chk.sh' \
  && echo "  ok    no test-shaped path: the seal falls back to every verification path under ## Files" \
  || { echo "::error::fallback seal lost"; fail=1; }

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

echo "beta-fixes-1113 (ask 7): a quoted red_reason: matches as an unquoted one; an inner or unmatched quote is compared as written"
printf '#!/usr/bin/env bash\ngrep -qx done src/red-acme.txt && exit 0\necho "acme: boom"\necho "it'"'"'s red"\necho "half"\nexit 1\n' > tests/red-acme.sh
printf 'todo\n' > src/red-acme.txt
git add -A && git commit -qm "red: the acme test" >/dev/null
FA=$'- tests/red-acme.sh\n- src/red-acme.txt\n'
red_q() { # red_q <nn> <red_reason value> <label> - stamp-red writes the receipt for this red_reason
  local st="docs/specs/red/red-$1.md" out ex
  red_story "$1" "red: required
red_reason: $2
" "$FA" '`bash tests/red-acme.sh`'
  out="$(bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] && grep -q '^red_verified_at: ' "$st" && grep -qx -- '- command: bash tests/red-acme.sh' "$st" && echo "  ok    $3" \
    || { echo "::error::$3 - exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
}
red_q 40 '"acme: boom"' 'red_reason: "acme: boom" (double quotes) stamps on a line holding acme: boom'
red_q 41 "'acme: boom'" "red_reason: 'acme: boom' (single quotes) stamps on a line holding acme: boom"
red_q 42 'acme: boom' 'red_reason: acme: boom (unquoted) stamps as before'
red_q 43 "it's red" "red_reason: it's red (an inner quote) is compared as written"
red_story 44 $'red: required\nred_reason: "half\n' "$FA" '`bash tests/red-acme.sh`'
red_refuses 'red_reason: "half (an unmatched quote) is compared as written: no line holds "half' 44 4 "red for another reason: red_reason not in the output of bash tests/red-acme.sh"

echo "tails-1115-01 (T23): stamp-red counts red_reason only in the lines of a failing command that are not passing (ok) lines"
printf '#!/usr/bin/env bash\necho "  ok    the case named reason-60"\necho "::error::some other case"\nexit 1\n' > tests/red60.sh
printf '#!/usr/bin/env bash\necho "  ok    some other case"\necho "::error::the case named reason-61"\nexit 1\n' > tests/red61.sh
printf '#!/usr/bin/env bash\necho "  ok    the case named reason-62"\necho "::error::the case named reason-62 again"\nexit 1\n' > tests/red62.sh
printf 'todo\n' > src/red6x.txt
red_story 60 $'red: required\nred_reason: the case named reason-60\n' $'- tests/red60.sh\n- src/red6x.txt\n' '`bash tests/red60.sh`'
red_story 61 $'red: required\nred_reason: the case named reason-61\n' $'- tests/red61.sh\n- src/red6x.txt\n' '`bash tests/red61.sh`'
red_story 62 $'red: required\nred_reason: the case named reason-62\n' $'- tests/red62.sh\n- src/red6x.txt\n' '`bash tests/red62.sh`'
git add -A && git commit -qm "red: passing-line stories" >/dev/null
red_refuses "red_reason only in a passing (ok) line of a failing command: exit 4, nothing written" 60 4 \
  "red for another reason: red_reason only in passing (ok) lines of bash tests/red60.sh"
[ ! -e .vulyk/state/red/verify.red-60.stamp-red.receipt ] && ! grep -q '^red_verified_at:' docs/specs/red/red-60.md \
  && echo "  ok    the refused stamp leaves no receipt and no record" || { echo "::error::red-60 refusal wrote a receipt or a record: $(ls .vulyk/state/red 2>&1 | tr '\n' ' ')"; fail=1; }
for nn in 61 62; do
  out="$(bash scripts/cycle.sh stamp-red "docs/specs/red/red-$nn.md" 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] && grep -q '^red_verified_at: ' "docs/specs/red/red-$nn.md" \
    && echo "  ok    red-$nn: the reason in a failing line (alone, or beside a passing one) stamps as before" \
    || { echo "::error::red-$nn: the reason in a failing line stamps - exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
done
git add -A && git commit -qm "red: passing-line stamps" >/dev/null

echo "tails-1115-01 (T2, T3): stamp-red by an absolute path; a marked story that keeps the template's commented lines closes under its title"
printf '#!/usr/bin/env bash\ngrep -qx done src/red63.txt && exit 0\necho "expected done in src/red63.txt"\nexit 1\n' > tests/red63.sh
printf 'todo\n' > src/red63.txt
red_story 63 $'red: required\nred_reason: expected done in src/red63.txt\n# red_verified_at:      # written by `cycle.sh stamp-red`, never by hand\n' \
  $'- tests/red63.sh\n- src/red63.txt\n' '`bash tests/red63.sh`'
git add -A && git commit -qm "red: template-comment story" >/dev/null
out="$(bash scripts/cycle.sh stamp-red "$(pwd -P)/docs/specs/red/red-63.md" 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^red_verified_at: ' docs/specs/red/red-63.md && printf '%s\n' "$out" | tail -1 | grep -qF '"story":"docs/specs/red/red-63.md"' \
  && echo "  ok    stamp-red: an absolute story path stamps like a relative one" \
  || { echo "::error::stamp-red: an absolute story path stamps like a relative one - exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
ABSO="$(mktemp -d)"; cp docs/specs/red/red-63.md "$ABSO/red-63.md"
out="$(bash scripts/cycle.sh stamp-red "$ABSO/red-63.md" 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"story file outside the repo: ' \
  && echo "  ok    stamp-red: a story path outside the repo is refused with a reason" \
  || { echo "::error::stamp-red: a story path outside the repo is refused with a reason - exit=$ex $(printf '%s\n' "$out" | tail -2)"; fail=1; }
rm -rf "$ABSO"
printf 'done\n' > src/red63.txt
out="$(bash scripts/cycle.sh close-story docs/specs/red/red-63.md --commit 2>&1)"; ex=$?
subj="$(git log -1 --format=%s)"
[ "$ex" -eq 0 ] && [ "$subj" = "story(red-63): Red fixture 63" ] \
  && echo "  ok    close-story: a red story keeping the template's commented frontmatter lines closes as story(<id>): <its title>" \
  || { echo "::error::close-story: a red story keeping the template's commented frontmatter lines closes under its title - exit=$ex subject=$subj $(printf '%s\n' "$out" | tail -1)"; fail=1; }
fi # part red
if part red3; then # --- part red3: stamp-red's resume mark and its stored output (split from red for time)
echo "mass-audit-fixes-10 G5: stamp-red's resume mark hashes a ## Files directory by its files - an edit under it reruns line 1"
st=docs/specs/red/red-18.md
mkdir -p src/r18
printf 'one\n' > src/r18/a.txt
printf '#!/usr/bin/env bash\necho "r18 saw $(cat src/r18/a.txt)"\necho "expected done"\nexit 1\n' > tests/red18.sh
red_story 18 "$MK" $'- tests/red18.sh\n- src/r18/\n' $'`bash tests/red18.sh`\n`bash tests/red-pass.sh`'
git add -A && git commit -qm "red: resume-mark story" >/dev/null
out="$(VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?
[ "$ex" -eq 7 ] && grep -q '^next=2$' .vulyk/state/red/verify.red-18.stamp-red && ! grep -q '^verify_resume:' "$st" && echo "  ok    red-18 call 1 paused after line 1, the record under .vulyk/state" || { echo "::error::red-18 pause: exit=$ex $(printf '%s\n' "$out" | tail -1)"; fail=1; }
printf 'two\n' > src/r18/a.txt
n=0; ex=7
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do
  out="$(VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh stamp-red "$st" 2>&1)"; ex=$?; n=$((n+1))
done
rcpt="$(sed -n '/^## Red receipt/,$p' "$st")"
[ "$ex" -eq 0 ] && printf '%s' "$rcpt" | grep -qF 'r18 saw two' && ! printf '%s' "$rcpt" | grep -qF 'r18 saw one' \
  && echo "  ok    stamp-red: an edit under a ## Files directory invalidates the mark - the receipt is the new code's output" \
  || { echo "::error::stamp-red: an edit under a ## Files directory invalidates the mark - exit=$ex receipt=$rcpt"; fail=1; }
git add -A && git commit -qm "red: resume-mark story stamped" >/dev/null
[ ! -e .vulyk/state/red/verify.red-18.stamp-red ] && echo "  ok    the finished stamp-red leaves no record behind" \
  || { echo "::error::a finished stamp-red left its record: $(cat .vulyk/state/red/verify.red-18.stamp-red 2>&1)"; fail=1; }

echo "upgrade-findings-03 A2: stamp-red's results directory comes from mktemp -d, and only this chain's results are read"
SRLOG="$(mktemp -u)"
sr_fixture() { # sr_fixture <nn> - a red story whose line 1 counts its runs and fails for the declared reason
  printf 'todo\n' > "src/sr$1.txt"
  printf '#!/usr/bin/env bash\nprintf "x" >> "%s"\necho "expected done, sr%s ran"\nexit 1\n' "$SRLOG" "$1" > "tests/sr$1.sh"
  red_story "$1" "$MK" "- tests/sr$1.sh"$'\n'"- src/sr$1.txt"$'\n' "\`bash tests/sr$1.sh\`"$'\n''`bash tests/red-pass.sh`'
}
sr_runs() { wc -c < "$SRLOG" 2>/dev/null | tr -d ' '; }
sr_stamp() { VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh stamp-red "docs/specs/red/red-$1.md" 2>&1; }
sr_outd() { sed -n 's/^outd=//p' ".vulyk/state/red/verify.red-$1.stamp-red" 2>/dev/null | tail -1; }
sr_fixture 31
git add -A && git commit -qm "red: sr31 fixture" >/dev/null
st=docs/specs/red/red-31.md
OLDD="${TMPDIR:-/tmp}/vulyk-sr-$(printf '%s' "$st" | cksum | cut -d' ' -f1)"
rm -rf "$OLDD"; mkdir -p "$OLDD"
printf '1' > "$OLDD/1.code"; printf '%s' 'bash tests/sr31.sh' > "$OLDD/1.line"; printf 'expected done PLANTED\n' > "$OLDD/1.out"
awk -v line="verify_resume: stamp-red 2 $(set_hash src/sr31.txt tests/sr31.sh)" 'NR > 1 && /^---$/ && !d { print line; d=1 } { print }' "$st" > sr.tmp && cat sr.tmp > "$st" && rm -f sr.tmp
n=0; ex=7
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(sr_stamp 31)"; ex=$?; n=$((n+1)); done
rcpt="$(sed -n '/^## Red receipt/,$p' "$st")"
[ "$ex" -eq 0 ] && [ "$(sr_runs)" = 1 ] && printf '%s' "$rcpt" | grep -qF 'sr31 ran' && ! printf '%s' "$rcpt" | grep -qF PLANTED \
  && echo "  ok    a results directory planted at the old predictable path is not trusted: stamp-red runs every line itself" \
  || { echo "::error::a results directory planted at the old predictable path is not trusted - exit=$ex line-1 runs=$(sr_runs) receipt=$rcpt"; fail=1; }
rm -rf "$OLDD" "$SRLOG"
git add -A && git commit -qm "red: sr31 stamped" >/dev/null

sr_fixture 32
git add -A && git commit -qm "red: sr32 fixture" >/dev/null
out="$(sr_stamp 32)"; ex=$?; sro="$(sr_outd 32)"
case "$sro" in "${TMPDIR:-/tmp}"/vulyk-sr-*) sro_old=1 ;; *) sro_old=0 ;; esac
[ "$ex" -eq 7 ] && [ -n "$sro" ] && [ -d "$sro" ] && [ "$sro_old" = 0 ] \
  && echo "  ok    a pause records a results directory that is not the old predictable path" \
  || { echo "::error::sr32 pause: exit=$ex outd=$sro out=$out"; fail=1; }
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) echo "  skip  the 0700 mode check: Git Bash maps no POSIX mode onto an NTFS directory" ;;
  *) [ "$(ls -ld "$sro" | cut -c1-10)" = drwx------ ] && echo "  ok    the results directory is mode 0700" \
       || { echo "::error::results directory mode: $(ls -ld "$sro")"; fail=1; } ;;
esac
grep -v '^line=1 ' ".vulyk/state/red/verify.red-32.stamp-red" > sr.tmp && cat sr.tmp > ".vulyk/state/red/verify.red-32.stamp-red" && rm -f sr.tmp
out="$(sr_stamp 32)"; ex=$?
[ "$ex" -eq 7 ] && [ "$(sr_runs)" = 2 ] && printf '%s' "$out" | grep -qF 'resume record not used (no matching line= entry for line 1' && [ "$(sr_outd 32)" != "$sro" ] \
  && echo "  ok    a stored result with no line= entry is not used: line 1 runs again in a new directory, stderr names the check" \
  || { echo "::error::a stored result with no line= entry is not used - exit=$ex runs=$(sr_runs) outd=$(sr_outd 32) out=$out"; fail=1; }
[ ! -e "$sro" ] || { echo "::error::the dropped results directory was left behind: $sro"; fail=1; }
sro="$(sr_outd 32)"
mv "$sro" "$sro.real" && { MSYS=winsymlinks:nativestrict ln -s "$sro.real" "$sro" 2>/dev/null \
  || { command -v cygpath >/dev/null 2>&1 && cmd //c "mklink /J $(cygpath -w "$sro") $(cygpath -w "$sro.real")" >/dev/null 2>&1; }; } # Git Bash: a junction reads as -L
if [ -L "$sro" ]; then
  out="$(sr_stamp 32)"; ex=$?
  [ "$ex" -eq 7 ] && [ "$(sr_runs)" = 3 ] && printf '%s' "$out" | grep -qF 'is a symlink' && [ "$(sr_outd 32)" != "$sro" ] \
    && echo "  ok    a recorded directory swapped for a symlink is not used: line 1 runs again in a new directory, stderr names the check" \
    || { echo "::error::a recorded directory swapped for a symlink is not used - exit=$ex runs=$(sr_runs) out=$out"; fail=1; }
  rm -f "$sro"
else
  echo "  skip  the symlink swap: this shell cannot make a symlink"; rm -rf "$sro"; mv "$sro.real" "$sro"
fi
rm -rf "$sro.real"
n=0; ex=7; sro=""
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do sro="$(sr_outd 32)"; out="$(sr_stamp 32)"; ex=$?; n=$((n+1)); done
[ "$ex" -eq 0 ] && grep -q '^red_verified_at:' docs/specs/red/red-32.md && [ ! -e .vulyk/state/red/verify.red-32.stamp-red ] \
  && [ -n "$sro" ] && [ ! -e "$sro" ] \
  && echo "  ok    the finished stamp-red leaves no record and no results directory behind" \
  || { echo "::error::finished stamp-red: exit=$ex record=$(cat .vulyk/state/red/verify.red-32.stamp-red 2>&1) out=$(printf '%s\n' "$out" | tail -3)"; fail=1; }
rm -f "$SRLOG"
git add -A && git commit -qm "red: sr32 stamped" >/dev/null

echo "upgrade-findings-07 A2: a stored output rewritten between calls is not trusted"
printf 'todo\n' > src/sr33.txt
printf '#!/usr/bin/env bash\nprintf "x" >> "%s"\necho "sr33 other failure"\nexit 1\n' "$SRLOG" > tests/sr33.sh
red_story 33 "$MK" $'- tests/sr33.sh\n- src/sr33.txt\n' $'`bash tests/sr33.sh`\n`bash tests/red-pass.sh`'
git add -A && git commit -qm "red: sr33 fixture" >/dev/null
out="$(sr_stamp 33)"; ex=$?; sro="$(sr_outd 33)"
[ "$ex" -eq 7 ] && [ -f "$sro/1.out" ] && printf 'expected done PLANTED\n' > "$sro/1.out"
out="$(sr_stamp 33)"; ex=$?
[ "$ex" -eq 7 ] && [ "$(sr_runs)" = 2 ] && printf '%s' "$out" | grep -qF 'resume record not used (the stored result of line 1' \
  && echo "  ok    a results file rewritten after the pause is not trusted: line 1 runs again, stderr names the check" \
  || { echo "::error::a results file rewritten after the pause is trusted - exit=$ex runs=$(sr_runs) out=$out"; fail=1; }
n=0
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(sr_stamp 33)"; ex=$?; n=$((n+1)); done
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'red for another reason' && ! grep -q '^red_verified_at:' docs/specs/red/red-33.md \
  && ! grep -qF PLANTED docs/specs/red/red-33.md \
  && echo "  ok    the rewritten output never reaches a receipt: the chain ends red for another reason" \
  || { echo "::error::a results file rewritten after the pause is trusted - final exit=$ex out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rm -f "$SRLOG"
git add -A && git commit -qm "red: sr33 refused" >/dev/null

echo "A2 minor (Fable re-review): a later verification line rewriting an earlier line's output cannot reach the verdict"
printf 'todo\n' > src/sr34.txt
printf '#!/usr/bin/env bash\necho "sr34 other failure"\nexit 1\n' > tests/sr34.sh
printf '#!/usr/bin/env bash\nod="$(sed -n "s/^outd=//p" .vulyk/state/red/verify.red-34.stamp-red 2>/dev/null | tail -1)"\n[ -n "$od" ] && printf "expected done PLANTED\\n" > "$od/1.out"\nexit 0\n' > tests/sr34-swap.sh
red_story 34 "$MK" $'- tests/sr34.sh\n- src/sr34.txt\n' $'`bash tests/sr34.sh`\n`bash tests/sr34-swap.sh`'
git add -A && git commit -qm "red: sr34 fixture" >/dev/null
n=0; ex=7
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(sr_stamp 34)"; ex=$?; n=$((n+1)); done
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'stored output of line 1 changed after it was checked' \
  && ! grep -q '^red_verified_at:' docs/specs/red/red-34.md && ! grep -qF PLANTED docs/specs/red/red-34.md \
  && echo "  ok    an output rewritten by a later line after its check is refused, never stamped" \
  || { echo "::error::an output rewritten by a later line reached the verdict - exit=$ex calls=$n out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
git add -A && git commit -qm "red: sr34 refused" >/dev/null

echo "A2 minor (Fable re-review): a stored 1.code or 1.line that differs from the record, and a directory the caller does not own, are not used"
for what in code line; do
  nn=35; [ "$what" = line ] && nn=36
  sr_fixture "$nn"
  git add -A && git commit -qm "red: sr$nn fixture" >/dev/null
  : > "$SRLOG"
  out="$(sr_stamp "$nn")"; ex=$?; sro="$(sr_outd "$nn")"
  if [ "$what" = code ]; then printf '0' > "$sro/1.code"; else printf '%s' 'bash tests/red-pass.sh' > "$sro/1.line"; fi
  out="$(sr_stamp "$nn")"; ex=$?
  [ "$ex" -eq 7 ] && [ "$(sr_runs)" = 2 ] && printf '%s' "$out" | grep -qF 'resume record not used (the stored result of line 1' \
    && echo "  ok    a changed 1.$what is not used: line 1 runs again, stderr names the check" \
    || { echo "::error::a changed 1.$what was used - exit=$ex runs=$(sr_runs) out=$out"; fail=1; }
  n=0; while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(sr_stamp "$nn")"; ex=$?; n=$((n+1)); done
  git add -A && git commit -qm "red: sr$nn done" >/dev/null
done
sr_fixture 37
git add -A && git commit -qm "red: sr37 fixture" >/dev/null
: > "$SRLOG"
out="$(sr_stamp 37)"; ex=$?; sro="$(sr_outd 37)"
if [ "$ex" -eq 7 ] && [ -d "$sro" ] && sudo -n chown 0 "$sro" 2>/dev/null; then
  out="$(sr_stamp 37)"; ex=$?
  [ "$ex" -eq 7 ] && [ "$(sr_runs)" = 2 ] && printf '%s' "$out" | grep -qF 'is not owned by the caller' && [ "$(sr_outd 37)" != "$sro" ] \
    && echo "  ok    a results directory the caller does not own is not used: line 1 runs again in a new directory" \
    || { echo "::error::a results directory owned by another user was used - exit=$ex runs=$(sr_runs) out=$out"; fail=1; }
  sudo -n rm -rf "$sro" 2>/dev/null
else
  echo "  skip  the ownership refusal: no passwordless sudo here to give the directory another owner"
fi
n=0; while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(sr_stamp 37)"; ex=$?; n=$((n+1)); done
rm -f "$SRLOG"
git add -A && git commit -qm "red: sr37 done" >/dev/null
fi # part red3
if part runstate; then # --- part runstate (guards-1115-03): the red gate reads stamp-red's own record; stored output is bounded and removed
echo "guards-1115-03: close-story's red gate accepts a receipt only when stamp-red's record carries its hashes"
RSLOG="$(mktemp -u)"
rs_fixture() { # rs_fixture <nn> [<extra verification line>] - a red story whose line 1 counts its runs and fails for the declared reason
  printf 'todo\n' > "src/rs$1.txt"
  printf '#!/usr/bin/env bash\nprintf "x" >> "%s"\ngrep -qx done src/rs%s.txt && exit 0\necho "expected done in src/rs%s.txt"\nexit 1\n' "$RSLOG" "$1" "$1" > "tests/rs$1.sh"
  red_story "$1" "$MK" "- tests/rs$1.sh"$'\n'"- src/rs$1.txt"$'\n' "\`bash tests/rs$1.sh\`${2:+$'\n'$2}"
  git add -A && git commit -qm "runstate: rs$1 fixture" >/dev/null
}
rs_runs() { wc -c < "$RSLOG" 2>/dev/null | tr -d ' '; }
rs_close() { bash scripts/cycle.sh close-story "docs/specs/red/red-$1.md" --commit 2>&1; }
rs_err() { printf '%s\n' "$1" | tail -1 | sed -n 's/.*"error":"\([^"]*\)".*/\1/p'; }
rs_tidy() { git add -A && git commit -qm "runstate: $1" >/dev/null 2>&1; }

rs_fixture 50
st=docs/specs/red/red-50.md
th="$(set_hash tests/rs50.sh)"; ih="$(set_hash src/rs50.txt)"
awk -v l="red_verified_at: 2026-01-01T00:00:00Z $th" '{ print } /^red_reason:/ { print l }' "$st" > rs.tmp && cat rs.tmp > "$st" && rm -f rs.tmp
printf '\n## Red receipt\n- command: bash tests/rs50.sh\n- exit: 1\n- tests: %s (tests/rs50.sh)\n- impl: %s\n- stamped: 2026-01-01T00:00:00Z\n' "$th" "$ih" >> "$st"
git add -A && git commit -qm "runstate: a hand-written receipt" >/dev/null
printf 'done\n' > src/rs50.txt
head_before="$(git rev-parse HEAD)"
out="$(rs_close 50)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(git rev-parse HEAD)" = "$head_before" ] && rs_err "$out" | grep -qF 'stamp-red' \
  && echo "  ok    a receipt with no stamp-red record is refused: exit 4, nothing committed, the message names stamp-red" \
  || { echo "::error::a receipt with no stamp-red record is refused - exit=$ex out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rs_tidy "rs50 refused"

rs_fixture 51
st=docs/specs/red/red-51.md
bash scripts/cycle.sh stamp-red "$st" >/dev/null 2>&1 || { echo "::error::red-51 stamp failed"; fail=1; }
sed_inplace "s/^- impl: .*/- impl: $(printf '%064d' 0 | tr 0 a)/" "$st"
printf 'done\n' > src/rs51.txt
out="$(rs_close 51)"; ex=$?
[ "$ex" -eq 4 ] && rs_err "$out" | grep -qF 'stamp-red' \
  && echo "  ok    a receipt whose impl hash differs from the stamp-red record is refused, the message names stamp-red" \
  || { echo "::error::a receipt whose impl hash differs from the record closed - exit=$ex out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rs_tidy "rs51 refused"

rs_fixture 52
st=docs/specs/red/red-52.md
bash scripts/cycle.sh stamp-red "$st" >/dev/null 2>&1 || { echo "::error::red-52 stamp failed"; fail=1; }
printf '#!/usr/bin/env bash\nexit 0\n' > tests/rs52.sh
sed_inplace "s/^\(red_verified_at: [^ ]*\) .*/\1 $(set_hash tests/rs52.sh)/" "$st"
sed_inplace "s/^\(- tests: \)[0-9a-f]*/\1$(set_hash tests/rs52.sh)/" "$st"
printf 'done\n' > src/rs52.txt
out="$(rs_close 52)"; ex=$?
[ "$ex" -eq 4 ] && rs_err "$out" | grep -qF 'stamp-red' \
  && echo "  ok    a weakened test whose new hash is written into the receipt is refused, the message names stamp-red" \
  || { echo "::error::a receipt rewritten to a weakened test's hash closed - exit=$ex out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rs_tidy "rs52 refused"

echo "guards-1115-03: a story stamped by stamp-red closes as before - one call, and after a pause and resume"
rs_fixture 53
bash scripts/cycle.sh stamp-red docs/specs/red/red-53.md >/dev/null 2>&1 || { echo "::error::red-53 stamp failed"; fail=1; }
printf 'done\n' > src/rs53.txt
out="$(rs_close 53)"; ex=$?
[ "$ex" -eq 0 ] && git show HEAD:docs/specs/red/red-53.md | grep -q '^status: done' \
  && echo "  ok    stamped in one call: the story closes" || { echo "::error::stamped in one call - exit=$ex out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rs_fixture 54 '`bash tests/red-pass.sh`'
n=0; ex=7; first=""
while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do
  out="$(VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh stamp-red docs/specs/red/red-54.md 2>&1)"; ex=$?; n=$((n+1))
  [ -n "$first" ] || first="$ex"
done
printf 'done\n' > src/rs54.txt
out="$(rs_close 54)"; cx=$?
[ "$first" = 7 ] && [ "$ex" -eq 0 ] && [ "$cx" -eq 0 ] && git show HEAD:docs/specs/red/red-54.md | grep -q '^status: done' \
  && echo "  ok    stamped after a pause and a resume: the story closes" \
  || { echo "::error::stamped after a pause - first=$first stamp=$ex close=$cx out=$(printf '%s\n' "$out" | tail -2)"; fail=1; }
rs_tidy "rs53 rs54 closed"

echo "guards-1115-03: a stored-output directory is honoured only directly under the temp root, with stamp-red's prefix, a real directory"
TR="$(mktemp -d)"; ELSE="$(mktemp -d)"
rs_stamp() { TMPDIR="$TR" VULYK_VERIFY_TIMEOUT=5 VULYK_VERIFY_CALL=4 bash scripts/cycle.sh stamp-red "docs/specs/red/red-$1.md" 2>&1; }
rs_rec() { printf '.vulyk/state/red/verify.red-%s.stamp-red' "$1"; }
rs_outd() { sed -n 's/^outd=//p' "$(rs_rec "$1")" 2>/dev/null | tail -1; }
rs_plant() { # rs_plant <nn> <path> - the record of a paused red-<nn> names <path> as its stored output
  { grep -v '^outd=' "$(rs_rec "$1")"; printf 'outd=%s\n' "$2"; } > rs.tmp && cat rs.tmp > "$(rs_rec "$1")" && rm -f rs.tmp
}
rs_outd_case() { # rs_outd_case <nn> <kind> <label>
  local nn="$1" kind="$2" sro p out ex
  rs_fixture "$nn" '`bash tests/red-pass.sh`'
  : > "$RSLOG"
  out="$(rs_stamp "$nn")"; ex=$?; sro="$(rs_outd "$nn")"
  case "$kind" in
    outside)  p="$ELSE/vulyk-sr.out$nn"; mkdir -p "$p" && cp "$sro"/* "$p"/ ;;
    noprefix) p="$TR/other.$nn"; mkdir -p "$p" && cp "$sro"/* "$p"/ ;;
    file)     p="$TR/vulyk-sr.file$nn"; printf 'x\n' > "$p" ;;
    link)     p="$TR/vulyk-sr.lnk$nn"; MSYS=winsymlinks:nativestrict ln -s "$sro" "$p" 2>/dev/null \
                || { command -v cygpath >/dev/null 2>&1 && cmd //c "mklink /J $(cygpath -w "$p") $(cygpath -w "$sro")" >/dev/null 2>&1; } ;;
  esac
  if [ "$kind" = link ] && [ ! -L "$p" ]; then echo "  skip  $3: this shell cannot make a symlink"; return 0; fi
  rs_plant "$nn" "$p"
  out="$(rs_stamp "$nn")"; ex=$?
  [ "$ex" -eq 7 ] && [ "$(rs_runs)" = 2 ] && printf '%s' "$out" | grep -qF 'resume record not used' && [ -e "$p" ] \
    && { [ "$kind" = file ] || [ -f "$p/1.out" ]; } && [ "$(rs_outd "$nn")" != "$p" ] \
    && echo "  ok    $3: neither read nor removed, the record dropped with a stderr reason, line 1 runs again" \
    || { echo "::error::$3 - exit=$ex runs=$(rs_runs) kept=$([ -e "$p" ] && echo yes || echo no) out=$out"; fail=1; }
  n=0; while [ "$ex" -eq 7 ] && [ "$n" -lt 4 ]; do out="$(rs_stamp "$nn")"; ex=$?; n=$((n+1)); done
  [ "$kind" = link ] && rm -f "$p"
  rs_tidy "rs$nn done"
}
rs_outd_case 55 outside "a stored-output directory outside the temp root"
rs_outd_case 56 noprefix "a stored-output directory without stamp-red's prefix"
rs_outd_case 57 file "a stored-output path that is a file"
rs_outd_case 58 link "a stored-output path that is a link"
rs_fixture 59 '`bash tests/red-pass.sh`'
: > "$RSLOG"
out="$(rs_stamp 59)"; ex=$?
out="$(rs_stamp 59)"; ex2=$?
[ "$ex" -eq 7 ] && [ "$ex2" -eq 0 ] && [ "$(rs_runs)" = 1 ] && grep -q '^red_verified_at:' docs/specs/red/red-59.md \
  && echo "  ok    the directory of a real paused run still resumes: line 1 is not run again" \
  || { echo "::error::a real paused run did not resume - exit=$ex then $ex2 runs=$(rs_runs) out=$out"; fail=1; }
rs_tidy "rs59 stamped"

echo "guards-1115-03: stamp-red leaves no stored output on a red, a green or a refusal; a pause keeps it; a day-old one is swept"
rm -rf "$TR"; TR="$(mktemp -d)"
rs_left() { ls -A "$TR" 2>/dev/null | grep -c '^vulyk-sr\.' | tr -d ' '; }
rs_fixture 60
out="$(rs_stamp 60)"; ex=$?
[ "$ex" -eq 0 ] && [ "$(rs_left)" = 0 ] && echo "  ok    a run that ends red leaves no stored output" \
  || { echo "::error::red run left stored output - exit=$ex left=$(ls -A "$TR")"; fail=1; }
red_story 61 "$MK" $'- tests/red-pass.sh\n- src/rs61.txt\n' '`bash tests/red-pass.sh`'
out="$(rs_stamp 61)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(rs_left)" = 0 ] && echo "  ok    a run that ends green leaves no stored output" \
  || { echo "::error::green run left stored output - exit=$ex left=$(ls -A "$TR")"; fail=1; }
red_story 62 $'red: required\nred_reason: expected something else\n' $'- tests/rs60.sh\n- src/rs60.txt\n' '`bash tests/rs60.sh`'
out="$(rs_stamp 62)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(rs_left)" = 0 ] && echo "  ok    a run that ends on a refusal leaves no stored output" \
  || { echo "::error::refused run left stored output - exit=$ex left=$(ls -A "$TR")"; fail=1; }
rs_fixture 63 '`bash tests/red-pass.sh`'
out="$(rs_stamp 63)"; ex=$?
[ "$ex" -eq 7 ] && [ "$(rs_left)" = 1 ] && echo "  ok    a paused run keeps its stored output" \
  || { echo "::error::paused run - exit=$ex left=$(ls -A "$TR")"; fail=1; }
mkdir "$TR/vulyk-sr.old" "$TR/vulyk-sr.young" "$TR/other.old"; printf 'x\n' > "$TR/vulyk-sr.oldfile"
touch -t 202001010000 "$TR/vulyk-sr.old" "$TR/other.old" "$TR/vulyk-sr.oldfile"
out="$(rs_stamp 60)"; ex=$?
[ "$ex" -eq 0 ] && [ ! -e "$TR/vulyk-sr.old" ] && [ -d "$TR/vulyk-sr.young" ] && [ -d "$TR/other.old" ] && [ -f "$TR/vulyk-sr.oldfile" ] \
  && [ "$(rs_left)" = 3 ] \
  && echo "  ok    the next stamp-red removes an own-prefix directory older than a day, keeps a younger one and other temp entries" \
  || { echo "::error::sweep - exit=$ex left=$(ls -A "$TR")"; fail=1; }
rm -rf "$TR" "$ELSE" "$RSLOG"
rs_tidy "runstate done"
fi # part runstate
if part merge-gate; then # --- part merge-gate (narrow-repair-1115-04): the full suite once before a local merge, the full check on the owner's word
echo "narrow-repair-1115-04: a constitution with no round-only row passes as suite: none"
bash scripts/ship-check.sh docs/specs/demo | expect "no round-only full-suite row: the suite line is none" "suite: none"
(
  MG="$T/mg"; MGC="$T/mg-count"; export MGC   # MGC: one line per gate step run, outside the fixture repo
  mkdir -p "$MG" && cd "$MG" || exit 1
  git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
  mkdir -p scripts memory/stats
  for s in lib.sh cycle.sh journal.sh ship-check.sh human-check.sh redact.sh suite-parts-check.sh py.sh run-capped.py; do cp "$SRC/scripts/$s" scripts/; done
  printf '.vulyk/\n' > .gitignore
  printf '# mg\n\n## Commands\n\n| Purpose | Command |\n|---|---|\n| Full suite part a (round-only) | `bash mg-step.sh a` |\n| Full suite part b (round-only) | `bash mg-step.sh b` |\n' > CLAUDE.md
  printf 'printf "%%s\\n" "$1" >> "$MGC"\n[ -n "$MG_TAMPER" ] && printf "STEP 9/9: ok 0s\\n" >> "$MG_TAMPER"\ngrep -qx -- "$1" mg-red.txt && exit 1\nexit 0\n' > mg-step.sh
  : > mg-red.txt; printf 'a\n' > mg-a.txt
  git add -A && git commit -qm init >/dev/null
  git checkout -q -b vulyk/mg
  mg_spec() { # mg_spec <slug> <tier> - a plan, a brief with one ask, one done story
    mkdir -p "docs/specs/$1"; cp "$SRC/templates/plan.md" "docs/specs/$1/plan.md"
    printf '# %s (brief)\n\n## Request\n> build %s\n\n## Asks\n1. ask one works\n' "$1" "$1" > "docs/specs/$1/brief.md"
    sed_inplace 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-11-15/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/mg#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\1'"$2"'/' "docs/specs/$1/plan.md"
    git add -A && git commit -qm "$1: plan" >/dev/null
    done_story "docs/specs/$1/$1-01-a.md" '---\nstory: %s-01\nstatus: done\nwave: 1\n---\n# A\n\n## Requirements\n> build %s\n\n## Files\n- mg-a.txt\n\n## Verification\n`true`\n' "$1" "$1"
  }
  mg_seal() { # mg_seal <slug> <log> - the run-state seal cycle.sh writes when it closes a suite log (lib.sh suite_sealed)
    mkdir -p ".vulyk/state/$1"
    printf '%s=%s
' "$(suite_seal_key "docs/specs/$1" "$2")" "$(suite_log_hash "$2")" >> ".vulyk/state/$1/suite-seal"
  }
  mg_round() { # mg_round <slug> <n> <verdict> <extra ROUND lines> <suite.log body> - a judged round, committed as paperwork
    local rd="docs/specs/$1/council/round-$2" h p; h="$(git rev-parse --short HEAD)"; p="$(pack_fingerprint "docs/specs/$1")"
    mkdir -p "$rd"
    printf 'head=%s\npack=%s\nopened=2026-11-15T00:00:00Z\ncourt=\nceiling=3\ntier=2\nseats=review\n%s' "$h" "$p" "$4" > "$rd/ROUND"
    [ -n "$5" ] && printf "head=%s $5" "$h" > "$rd/suite.log" && mg_seal "$1" "$rd/suite.log"
    printf '{"ts":"2026-11-15T00:00:0%sZ","spec":"%s","round":%s,"verdict":"%s","head":"%s","pack":"%s","asks":1,"red":[],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"","haiku_model":"unknown","sonnet":"","sonnet_model":"unknown","opus":"","opus_model":"unknown","attempts":1,"escalate":null,"note":""}\n' \
      "$2" "$1" "$2" "$3" "$h" "$p" >> memory/stats/council.jsonl
    git add -A && git commit -qm "vulyk($1): round $2 $3" >/dev/null
  }
  mgs() { bash scripts/ship-check.sh "docs/specs/$1"; }
  mgm() { bash scripts/cycle.sh suite "docs/specs/$1" --merge --commit 2>&1 | tail -1; }
  mgn() { grep -c . "$MGC" 2>/dev/null || echo 0; }
  A=full-suite-part-a-round-only; B=full-suite-part-b-round-only

  echo "original case (audit-fixes-1113): a full round RED on the suite, a repair, then a narrow GREEN round that re-ran one step"
  mg_spec mg 2
  mg_round mg 1 RED '' "steps=2\nSTEP 1/2: FAIL 1s\nPART $A FAIL 1s cap 300s\nSTEP 2/2: ok 1s\nPART $B ok 1s cap 300s\nSUITE: FAIL 2s - part $A failed\n"
  printf 'a2\n' > mg-a.txt; git add -A && git commit -qm "fix part a" >/dev/null
  done_story docs/specs/mg/mg-02-repair-round-1.md '---\nstory: mg-02\nstatus: done\nwave: 2\nnarrow: true\n---\n# Repair round 1\n\n## Files\n- mg-a.txt\n\n## Verification\n`true`\n'
  mg_round mg 2 GREEN "since=x\nrepair=mg-02\nnarrow=1\nasks=\nrerun=1\n" "steps=2\nSTEP 1/2: ok 1s\nPART $A ok 1s cap 300s\nSUITE: ok 1s - narrow repair round, steps 1 of 2\n"
  out="$(mgs mg)"
  printf '%s' "$out" | expect "a narrow green round is not merged without the full suite" "suite: no full run at $(git rev-parse --short HEAD) - run bash scripts/cycle.sh suite docs/specs/mg --merge"
  printf '%s' "$out" | expect "the narrow GREEN round closes 04 by itself" "04   ok"
  printf '%s' "$out" | expect "with no merge run: NOT READY" "NOT READY"
  out1="$(mgm mg)"; out2="$(mgm mg)"
  printf '%s' "$out1" | expect "suite --merge: the first call runs step 1 of 2 and says merge" '"verb":"suite","merge":true'
  printf '%s' "$out1" | expect "suite --merge: the first call is not done" '"step":1,"steps":2,"done":false'
  printf '%s' "$out2" | expect "suite --merge: the second call finishes it green" '"step":2,"steps":2,"done":true,"suite":"ok"'
  [ "$(mgn)" = 2 ] && echo "  ok    the merge run ran both steps once" || expect "the merge run ran both steps once: $(mgn)" "<never>" < /dev/null
  head -1 docs/specs/mg/council/merge-suite.log | expect "merge-suite.log is keyed to the head it ran on" "head=$(git rev-parse --short HEAD~1) steps=2"
  [ -z "$(git status --porcelain)" ] && echo "  ok    --commit leaves the merge log committed" || expect "--commit leaves the merge log committed: $(git status --porcelain)" "<never>" < /dev/null
  mgs mg | expect "after the merge run finished green: READY" "READY."
  mgs mg | expect "the suite line names the merge run" "suite: full run green at"
  out3="$(mgm mg)"
  [ "$(mgn)" = 2 ] && echo "  ok    a second merge run on the same head runs no step" || expect "a second merge run runs no step: $(mgn)" "<never>" < /dev/null
  printf '%s' "$out3" | expect "the no-op call says done" '"done":true,"suite":"ok"'

  echo "neighbour: paperwork after the merge log keeps it; code after it does not"
  printf 'note\n' >> docs/specs/mg/journal.md; git add -A && git commit -qm "vulyk(mg): journal" >/dev/null
  mgs mg | expect "paperwork after the merge log: still READY" "READY."
  printf 'a3\n' > mg-a.txt; git add -A && git commit -qm "a code change after the merge run" >/dev/null
  out="$(mgs mg)"
  printf '%s' "$out" | expect "code after the merge log: no full run at the new head" "suite: no full run at $(git rev-parse --short HEAD)"
  printf '%s' "$out" | expect "code after the merge log: NOT READY" "NOT READY"

  echo "a red merge run: NOT READY naming the red part and the cure, never a council round"
  printf 'b\n' > mg-red.txt; git add -A && git commit -qm "part b breaks" >/dev/null
  mgm mg >/dev/null; out2="$(mgm mg)"
  printf '%s' "$out2" | expect "the red merge run finishes FAIL" '"done":true,"suite":"FAIL"'
  out="$(mgs mg)"; r7="$(git rev-parse --short HEAD)"
  printf '%s' "$out" | expect "a red merge run names the red part" "suite: FAIL at $r7 - part $B failed"
  printf '%s' "$out" | expect "a red merge run names its cure" "fix it, commit, then run bash scripts/cycle.sh suite docs/specs/mg --merge again"
  printf '%s' "$out" | expect "a red merge run: NOT READY" "NOT READY"
  printf '%s' "$out" | grep -qF 'open-round --full' && expect "a red merge run never names open-round --full" "<never>" < /dev/null \
    || echo "  ok    a red merge run never names open-round --full"
  n0="$(mgn)"; mgm mg >/dev/null
  [ "$(mgn)" = "$n0" ] && echo "  ok    a red merge log on the same head is not re-run" || expect "a red merge log on the same head is not re-run" "<never>" < /dev/null
  echo "neighbour: the fix turns a green part red - still NOT READY, naming that part"
  printf 'a\n' > mg-red.txt; git add -A && git commit -qm "fix part b, break part a" >/dev/null
  mgm mg >/dev/null; mgm mg >/dev/null
  [ "$(mgn)" = "$((n0 + 2))" ] && echo "  ok    the merge run after a fix runs the whole suite again" || expect "the merge run after a fix runs the whole suite: $(mgn) after $n0" "<never>" < /dev/null
  out="$(mgs mg)"
  printf '%s' "$out" | expect "the newly red part is named" "suite: FAIL at $(git rev-parse --short HEAD) - part $A failed"
  printf '%s' "$out" | grep -qF "part $B failed" && expect "the part fixed since is no longer named" "<never>" < /dev/null \
    || echo "  ok    the part fixed since is no longer named"
  printf '%s' "$out" | expect "the newly red part: NOT READY" "NOT READY"
  : > mg-red.txt; git add -A && git commit -qm "fix part a" >/dev/null
  mgm mg >/dev/null; mgm mg >/dev/null
  [ "$(mgn)" = "$((n0 + 4))" ] && echo "  ok    the merge run after the second fix runs the whole suite" || expect "the second fix runs the whole suite: $(mgn)" "<never>" < /dev/null
  # the code commits above stale the council row (04/05), so the suite line alone is judged here
  mgs mg | expect "one full run on the head all green: the suite line is ok again" "suite ok       suite: full run green at"

  echo "neighbour: a **Checked:** ACCEPTED spec with no full run is NOT READY the same way"
  mg_spec mgc 2
  mg_round mgc 1 RED '' ''
  bash scripts/human-check.sh docs/specs/mgc ACCEPTED "looked at it" >/dev/null
  git add -A && git commit -qm "vulyk(mgc): checked" >/dev/null
  out="$(mgs mgc)"
  printf '%s' "$out" | expect "the ACCEPTED override closes 05" "05   ok"
  printf '%s' "$out" | expect "an ACCEPTED spec with no full run: no full run" "suite: no full run at $(git rev-parse --short HEAD)"
  printf '%s' "$out" | expect "an ACCEPTED spec with no full run: NOT READY" "NOT READY"

  echo "neighbour: a round that ran every step green on the head needs no merge run"
  mg_spec mgr 2
  mg_round mgr 1 GREEN '' "steps=2\nSTEP 1/2: ok 1s\nPART $A ok 1s cap 300s\nSTEP 2/2: ok 1s\nPART $B ok 1s cap 300s\nSUITE: ok 2s\n"
  out="$(mgs mgr)"
  printf '%s' "$out" | expect "a full round's green gate on the head: READY" "READY."
  printf '%s' "$out" | expect "the suite line names the round's gate" "suite: full run green at"
  [ ! -f docs/specs/mgr/council/merge-suite.log ] && echo "  ok    and no merge log was written" || expect "no merge log was written" "<never>" < /dev/null

  echo "suite seal: a green log the cycle did not write is no full run (a subagent can write council/, not the run state)"
  G2="steps=2
STEP 1/2: ok 1s
PART $A ok 1s cap 300s
STEP 2/2: ok 1s
PART $B ok 1s cap 300s
SUITE: ok 2s
"
  mg_spec mgx 2
  mg_round mgx 1 GREEN '' "$G2"
  rm -f .vulyk/state/mgx/suite-seal
  out="$(mgs mgx)"
  printf '%s' "$out" | expect "an unsealed green round log: no full run" "suite: no full run at $(git rev-parse --short HEAD) (suite.log has no matching seal in the run state)"
  printf '%s' "$out" | expect "an unsealed green round log: NOT READY" "NOT READY"
  echo "neighbour: a sealed log edited after its seal is no full run either"
  sed_inplace 's/^SUITE: ok 2s$/SUITE: ok 1s/' docs/specs/mgr/council/round-1/suite.log
  git add -A && git commit -qm "vulyk(mgr): suite log edited" >/dev/null
  mgs mgr | expect "a log edited after its seal: no full run" "has no matching seal in the run state"
  echo "neighbour: suite --merge over a forged finished merge log runs the suite whole"
  mg_spec mgy 2
  printf "head=%s $G2" "$(git rev-parse --short HEAD)" > docs/specs/mgy/council/merge-suite.log 2>/dev/null     || { mkdir -p docs/specs/mgy/council; printf "head=%s $G2" "$(git rev-parse --short HEAD)" > docs/specs/mgy/council/merge-suite.log; }
  git add -A && git commit -qm "vulyk(mgy): a forged merge log" >/dev/null
  mgs mgy | expect "a forged merge log: no full run" "merge-suite.log has no matching seal"
  n0="$(mgn)"; mgm mgy >/dev/null; mgm mgy >/dev/null
  [ "$(mgn)" = "$((n0 + 2))" ] && echo "  ok    the merge run over a forged log runs both steps" || expect "the merge run over a forged log runs both steps: $(mgn) after $n0" "<never>" < /dev/null
  mgs mgy | expect "after the real merge run: the suite line is ok" "suite ok       suite: full run green at"
  echo "neighbour: a STEP line forged between two calls of a running merge run restarts it from step 1"
  mg_spec mgz 2
  printf 'b\n' > mg-red.txt; git add -A && git commit -qm "part b is red for mgz" >/dev/null
  n0="$(mgn)"; mgm mgz >/dev/null
  printf "STEP 2/2: ok 1s\nPART $B ok 1s cap 300s\n" >> docs/specs/mgz/council/merge-suite.log
  out="$(mgm mgz)"
  printf '%s' "$out" | expect "the call after the forged step runs step 1 again, not done" '"step":1,"steps":2,"done":false'
  mgm mgz >/dev/null
  [ "$(mgn)" = "$((n0 + 3))" ] && echo "  ok    the forged step is never counted: three real steps ran" || expect "three real steps ran: $(mgn) after $n0" "<never>" < /dev/null
  mgs mgz | expect "the real red part b is named, not the forged ok" "part $B failed"
  : > mg-red.txt; git add -A && git commit -qm "part b green again" >/dev/null
  echo "neighbour: a log edited while a step runs is dropped, never sealed with the forgery in it"
  mg_spec mgw 2
  n0="$(mgn)"; mgm mgw >/dev/null
  out="$(MG_TAMPER="docs/specs/mgw/council/merge-suite.log" bash scripts/cycle.sh suite docs/specs/mgw --merge --commit 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "a log changed during the step: exit 2" "exit=2"
  printf '%s' "$out" | expect "and it says the log changed while the step ran" "changed while the step ran"
  [ ! -f docs/specs/mgw/council/merge-suite.log ] && echo "  ok    the tampered log is dropped" || expect "the tampered log is dropped: $(cat docs/specs/mgw/council/merge-suite.log)" "<never>" < /dev/null
  mgm mgw >/dev/null; mgm mgw >/dev/null
  grep -q 'STEP 9/9' docs/specs/mgw/council/merge-suite.log && expect "the forged STEP never reaches the rerun log" "<never>" < /dev/null \
    || echo "  ok    the forged STEP never reaches the rerun log"
  mgs mgw | expect "after a clean rerun: the suite line is ok" "suite ok       suite: full run green at"

  echo "solo-gate-1118: a Tier 1-2 round whose gate ran no step (SUITE: none - Tier 1-2) is no full run: the merge run is due"
  mg_spec mgt 2
  mg_round mgt 1 GREEN '' "steps=0\nSUITE: none - Tier 1-2: the stories' checks ran at close-story; the full suite runs once before merge\n"
  out="$(mgs mgt)"
  printf '%s' "$out" | expect "a Tier 1-2 none log on the head is not a full run" "suite: no full run at $(git rev-parse --short HEAD) - run bash scripts/cycle.sh suite docs/specs/mgt --merge"
  printf '%s' "$out" | expect "with no merge run: NOT READY" "NOT READY"

  echo "suite --merge refuses while a round is open"
  mg_spec mgo 2
  mkdir -p docs/specs/mgo/council/round-1
  printf 'head=%s\npack=x\ncourt=\nceiling=3\ntier=2\nseats=review\n' "$(git rev-parse --short HEAD)" > docs/specs/mgo/council/round-1/ROUND
  git add -A && git commit -qm "vulyk(mgo): open round 1" >/dev/null
  n0="$(mgn)"; out="$(bash scripts/cycle.sh suite docs/specs/mgo --merge 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "suite --merge with a round open: exit 2" "exit=2"
  printf '%s' "$out" | expect "and it names the open round" "round 1 is open"
  [ "$(mgn)" = "$n0" ] && echo "  ok    and it runs no step" || expect "suite --merge with a round open runs no step" "<never>" < /dev/null

  echo "open-round --full: the owner's full check - full=asked, the whole roster, no carry, since= the branch base, every step"
  mg_full_fixture() { # mg_full_fixture <slug> - a Tier 3 spec whose round 1 is GREEN with a GREEN opus report
    mg_spec "$1" 3
    local rd="docs/specs/$1/council/round-1"
    mg_round "$1" 1 GREEN '' ''
    sed_inplace 's/^tier=2$/tier=3/; s/^seats=review$/seats=opus review/' "$rd/ROUND"
    printf '<!-- seat: opus · model: opus · round 1 · attempt 1 -->\nVERDICT: GREEN\nASK 1: GREEN run: t saw: ok\n' > "$rd/opus.md"
    printf 'VERDICT: PASS\n' > "$rd/review.md"
    git add -A && git commit -qm "vulyk($1): round 1 seats" >/dev/null
  }
  mg_full_fixture mgf
  base7="$(git rev-parse --short "$(git merge-base main HEAD)")"
  out="$(bash scripts/cycle.sh open-round docs/specs/mgf --full --commit 2>&1; echo "exit=$?")"
  printf '%s' "$out" | expect "open-round --full exits 0" "exit=0"
  R=docs/specs/mgf/council/round-2/ROUND
  grep -qx 'full=asked' "$R" 2>/dev/null && echo "  ok    the full check's ROUND says full=asked" || expect "full=asked in ROUND: $(cat "$R" 2>&1)" "<never>" < /dev/null
  grep -q '^narrow=' "$R" 2>/dev/null && expect "the full check's ROUND has no narrow=1" "<never>" < /dev/null || echo "  ok    the full check's ROUND has no narrow=1"
  grep -qx 'seats=opus review' "$R" 2>/dev/null && echo "  ok    the full check requires the tier's whole roster" || expect "seats=opus review in ROUND: $(cat "$R" 2>&1)" "<never>" < /dev/null
  grep -qx "since=$base7" "$R" 2>/dev/null && echo "  ok    the full check's since= is the branch base" || expect "since=$base7 in ROUND: $(cat "$R" 2>&1)" "<never>" < /dev/null
  [ ! -f docs/specs/mgf/council/round-2/opus.md ] && echo "  ok    the full check carries no seat" || expect "the full check carries no seat" "<never>" < /dev/null
  [ -d .vulyk/court/mgf/round-2 ] && [ ! -e .vulyk/court/mgf/round-2/docs/specs/mgf/round-asks ] && echo "  ok    the court has no round-asks" \
    || expect "the court exists and has no round-asks: $(ls -R .vulyk/court/mgf 2>&1 | head -5)" "<never>" < /dev/null
  n0="$(mgn)"
  bash scripts/cycle.sh suite docs/specs/mgf --commit >/dev/null 2>&1; bash scripts/cycle.sh suite docs/specs/mgf --commit >/dev/null 2>&1
  [ "$(mgn)" = "$((n0 + 2))" ] && tail -1 docs/specs/mgf/council/round-2/suite.log | grep -qx 'SUITE: ok [0-9]*s' \
    && echo "  ok    the full check's gate runs every step" || expect "the full check's gate runs every step: $(cat docs/specs/mgf/council/round-2/suite.log 2>&1)" "<never>" < /dev/null
  echo "neighbour: open-round without --full changes nothing"
  mg_full_fixture mgp
  bash scripts/cycle.sh open-round docs/specs/mgp --commit >/dev/null 2>&1
  R=docs/specs/mgp/council/round-2/ROUND
  ! grep -q '^full=' "$R" 2>/dev/null && grep -q "^since=" "$R" && ! grep -qx "since=$base7" "$R" && [ -f docs/specs/mgp/council/round-2/opus.md ] \
    && echo "  ok    without --full: no full= line, since= round 1's head, the GREEN seat carried" \
    || expect "without --full the round is as before: $(cat "$R" 2>&1)" "<never>" < /dev/null
  git worktree list --porcelain | sed -n 's/^worktree //p' | grep -F /.vulyk/court/ | while IFS= read -r w; do git worktree remove --force "$w" >/dev/null 2>&1; done
)
flat() { tr -d '\r' < "$1" | tr '\n' ' ' | tr -s ' '; }
mgpin() { case "$2" in *"$3"*) echo "  ok    $1" ;; *) echo "::error::$1 - '$3' is gone"; fail=1 ;; esac; }
SHIPMD="$(flat "$SRC/.claude/commands/vulyk-ship.md")"; BUILDMD="$(flat "$SRC/.claude/commands/vulyk-build.md")"; REVMD="$(flat "$SRC/.claude/commands/vulyk-review.md")"
mgpin "vulyk-ship step 1: the merge gate" "$SHIPMD" 'On `suite: no full run at <sha>`, run `bash scripts/cycle.sh suite docs/specs/<slug> --merge --commit`'
mgpin "vulyk-ship step 1: a red merge gate is cured by a fix and the whole suite once more" "$SHIPMD" 'never by a council round'
mgpin "vulyk-ship: the major-version question" "$SHIPMD" 'ask the owner once whether to run the full check first'
mgpin "vulyk-ship: the owner's three triggers" "$SHIPMD" 'a major version (0.5 -> 0.6), about once a month, or when bugs or feedback come in'
mgpin "vulyk-ship: never unasked" "$SHIPMD" 'never open it unasked'
mgpin "vulyk-ship: the owner's way to run it" "$SHIPMD" '`/vulyk-review <slug> --full`'
for md in BUILDMD REVMD; do
  mgpin "$md: the merge run before «Выпускаем?»" "${!md}" 'run `bash scripts/cycle.sh suite docs/specs/<slug> --merge --commit` step by step until `"done":true`, before «Выпускаем?»'
  mgpin "$md: a RED round is followed by a repair and a narrow round" "${!md}" 'A RED round is followed by a repair and a narrow round'
done
mgpin "vulyk-review: --full opens the full check" "$REVMD" 'cycle.sh open-round docs/specs/<slug> --full --commit --stamp $stamp`'
fi # part merge-gate

[ -e "$MARK" ] && fail=1
exit $fail
