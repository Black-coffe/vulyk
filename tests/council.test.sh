#!/usr/bin/env bash
# The council's verdict machinery, driven through hand-written fixtures - no model calls.
# Covers scripts/lib.sh's functions (indirectly, through cycle.sh), scripts/cycle.sh's
# `status`/`judge`/`escalate`, scripts/journal.sh, and the verdict table (docs/adr/
# 001-cycle-state-contract.md D4).
#
#   Usage: bash tests/council.test.sh            # from the VULYK repo root
#
# Mirrors tests/cycle.test.sh: a throwaway git repo, `expect()` on stdout substrings, exit 1
# on the first wrong answer. Unlike cycle.test.sh's single spec walked through six stages,
# council verdicts are round-scoped and independent, so each scenario below gets its own spec
# directory (its own `"spec"` key in council.jsonl) instead of one spec reused throughout.
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

cd "$T" || exit 1
git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
mkdir -p scripts memory/stats docs/specs .claude
cp "$SRC"/scripts/lib.sh "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh scripts/
git add -A && git commit -qm init >/dev/null
HEAD7="$(git rev-parse --short HEAD)"
council() { bash scripts/cycle.sh "$@"; }

# --- fixture helpers -------------------------------------------------------------------------

mk_spec() { # mk_spec <slug> <n-asks> - brief.md with an N-item ## Asks, plan.md, one done story
  local slug="$1" n="$2" i
  mkdir -p "docs/specs/$slug"
  cp "$SRC/templates/plan.md" "docs/specs/$slug/plan.md"
  {
    printf '# %s (brief)\n\n## Request\n> build the thing\n\n## Asks\n' "$slug"
    for i in $(seq 1 "$n"); do printf '%d. ask number %d works\n' "$i" "$i"; done
  } > "docs/specs/$slug/brief.md"
  printf -- '---\nstory: %s-01\nspec: %s\nstatus: done\nwave: 1\n---\n# S1\n' "$slug" "$slug" > "docs/specs/$slug/$slug-01-first.md"
  git add -A && git commit -qm "spec($slug): fixture" >/dev/null
}

mk_round() { # mk_round <slug> <round-n> [ceiling] -> prints the round dir path
  local slug="$1" n="$2" ceiling="${3:-3}" rd
  rd="docs/specs/$slug/council/round-$n"
  mkdir -p "$rd"
  {
    printf 'head=%s\n'   "$HEAD7"
    printf 'pack=demo-pack\n'
    printf 'opened=2020-01-01T00:00:00Z\n'   # fixed and old: any human.jsonl "now" row is newer
    printf 'court=%s/court/%s/round-%s\n' "$T" "$slug" "$n"
    printf 'ceiling=%s\n' "$ceiling"
  } > "$rd/ROUND"
  printf '%s' "$rd"
}

seat_report() { # seat_report <seat> <round-n> <pattern> - a C5-shaped report body
  # pattern chars: G=evidenced GREEN, R=evidenced RED, N=N/A (why:), ?=unevidenced RED
  local seat="$1" n="$2" pattern="$3" overall
  case "$pattern" in
    *[R?]*) overall=RED ;;
    *[^N]*) overall=GREEN ;;
    *)      overall=N/A ;;
  esac
  printf 'COUNCIL: demo \xc2\xb7 round %s \xc2\xb7 seat %s\n' "$n" "$seat"
  printf 'MODEL: test-model\nCOURT: %s/court\nVERDICT: %s\n' "$T" "$overall"
  printf 'ASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf '%s' "$pattern" | fold -w1 | { i=0; while IFS= read -r c; do
    i=$((i+1))
    case "$c" in
      N)   printf 'ASK %d: N/A - ask %d - why: not applicable in this configuration\n' "$i" "$i" ;;
      G)   printf 'ASK %d: GREEN - ask %d - run: check-%d saw: ok\n' "$i" "$i" "$i" ;;
      R)   printf 'ASK %d: RED - ask %d - run: check-%d saw: fail\n' "$i" "$i" "$i" ;;
      '?') printf 'ASK %d: RED - ask %d - why: could not verify\n' "$i" "$i" ;;
      *)   printf 'ASK %d: GREEN - ask %d - run: check-%d saw: ok\n' "$i" "$i" "$i" ;;
    esac
  done; }
  printf 'UNASKED: none\nBREACH: none\n'
}

write_seat() { # write_seat <round-dir> <seat> <pattern>
  local rd="$1" seat="$2" pattern="$3" n="${1##*/round-}"
  {
    printf '<!-- seat: %s \xc2\xb7 model: test-%s \xc2\xb7 round: %s \xc2\xb7 head: %s \xc2\xb7 pack: demo-pack \xc2\xb7 attempt: 1 \xc2\xb7 recorded: 2020-01-01T00:00:01Z -->\n' \
      "$seat" "$seat" "$n" "$HEAD7"
    seat_report "$seat" "$n" "$pattern"
  } > "$rd/$seat.md"
}

write_review() { # write_review <round-dir> <PASS|BLOCK>
  local rd="$1" v="$2" n="${1##*/round-}"
  {
    printf '<!-- seat: review \xc2\xb7 model: test \xc2\xb7 round: %s \xc2\xb7 head: %s \xc2\xb7 pack: demo-pack \xc2\xb7 attempt: 1 \xc2\xb7 recorded: 2020-01-01T00:00:01Z -->\n' "$n" "$HEAD7"
    printf '%s\n' "$v"
    printf 'Reviewed the diff against the story files.\n'
  } > "$rd/review.md"
}

write_absent() { printf 'attempt 2, still nothing usable\n' > "$1/$2.attempt-2.md"; } # <round-dir> <seat>

# --- status --json: shape and the next vocabulary ---------------------------------------------

echo "status --json: exactly one JSON object with every C3 key"
mk_spec status1 3
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-12/' docs/specs/status1/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/status1#' docs/specs/status1/plan.md
git add -A && git commit -qm "status1: briefed" >/dev/null

out="$(council status docs/specs/status1 --json)"
lines="$(printf '%s\n' "$out" | grep -c .)"
[ "$lines" -eq 1 ] || { echo "::error::status --json printed $lines lines, expected exactly 1"; fail=1; }
for k in spec slug stage next briefed approved branch head pack stories wave wave_stories round ceiling open court missing stale verdict red round_dir paused shipped; do
  printf '%s' "$out" | jq -e "has(\"$k\")" >/dev/null 2>&1 || { echo "::error::status --json is missing key '$k': $out"; fail=1; }
done
printf '%s' "$out" | jq -e '.stories | has("todo") and has("in-progress") and has("done") and has("blocked")' >/dev/null 2>&1 \
  || { echo "::error::status --json .stories is missing a sub-key: $out"; fail=1; }
[ "$fail" -eq 0 ] && echo "  ok    every C3 key is present, on one line"

printf '%s' "$out" | jq -r .next | expect "no rounds, all stories done -> open-round" "open-round"

echo "status --json: an open round with missing seats"
rd1="$(mk_round status1 1)"
out2="$(council status docs/specs/status1 --json)"
printf '%s' "$out2" | jq -e '.open == true' >/dev/null 2>&1 || { echo "::error::open round not reported open: $out2"; fail=1; }
printf '%s' "$out2" | jq -e '.round == 1' >/dev/null 2>&1 || { echo "::error::round number wrong: $out2"; fail=1; }
printf '%s' "$out2" | jq -r '.missing | sort | join(",")' | expect "missing lists all four absent seats" "haiku,opus,review,sonnet"
printf '%s' "$out2" | jq -r .next | grep -qE '^dispatch:' && echo "  ok    next is dispatch:..." \
  || { echo "::error::next was $(printf '%s' "$out2" | jq -r .next), expected dispatch:..."; fail=1; }

echo "status --json: all four seats present -> judge"
write_seat "$rd1" haiku GGG
write_seat "$rd1" sonnet GGG
write_seat "$rd1" opus GGG
write_review "$rd1" PASS
printf '%s' "$(council status docs/specs/status1 --json)" | jq -r .next | expect "next is judge" "judge"

# --- judge: unanimous green -------------------------------------------------------------------

echo "judge: GGGGGGG x3, review PASS -> GREEN"
jout="$(council judge docs/specs/status1)"; jexit=$?
[ "$jexit" -eq 0 ] || { echo "::error::judge (green) exited $jexit, expected 0"; fail=1; }
printf '%s\n' "$jout" | tail -1 | expect "last stdout line is the JSON contract" '{"ok":true,"verb":"judge","exit":0,"next":"green"}'
row="$(grep '"spec":"status1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"verdict":"GREEN"' && echo "  ok    row verdict GREEN" || { echo "::error::row: $row"; fail=1; }
keys="$(printf '%s' "$row" | grep -oE '"[a-z_]+":' | tr -d '":' | tr '\n' ',')"
[ "$keys" = "ts,spec,round,verdict,head,pack,asks,red,red_unevidenced,na,review,haiku,haiku_model,sonnet,sonnet_model,opus,opus_model,attempts,escalate,note," ] \
  && echo "  ok    row keys are in C4 order" || { echo "::error::row key order: $keys"; fail=1; }
grep -q '^\*\*Council:\*\* GREEN round 1,' docs/specs/status1/plan.md && echo "  ok    plan.md Council line appended" \
  || { echo "::error::Council line missing from plan.md"; fail=1; }
grep -qF '· 04-council:GREEN ·' docs/specs/status1/journal.md && echo "  ok    journal.md carries 04-council:GREEN" \
  || { echo "::error::journal.md missing the council line"; fail=1; }

echo "judge: idempotent restoration"
sed -i '/^\*\*Council:\*\* GREEN round 1,/d' docs/specs/status1/plan.md
council judge docs/specs/status1 >/dev/null
cnt="$(grep -c '^\*\*Council:\*\* GREEN round 1,' docs/specs/status1/plan.md)"
rowcount="$(grep -c '"spec":"status1"' memory/stats/council.jsonl)"
[ "$cnt" -eq 1 ] && [ "$rowcount" -eq 1 ] && echo "  ok    deleting the Council line restores only that line, row not duplicated" \
  || { echo "::error::Council-line restore: line count=$cnt row count=$rowcount"; fail=1; }

sed -i '/04-council:GREEN/d' docs/specs/status1/journal.md
council judge docs/specs/status1 >/dev/null
jcnt="$(grep -c '04-council:GREEN' docs/specs/status1/journal.md)"
rowcount2="$(grep -c '"spec":"status1"' memory/stats/council.jsonl)"
ccnt2="$(grep -c '^\*\*Council:\*\* GREEN round 1,' docs/specs/status1/plan.md)"
[ "$jcnt" -eq 1 ] && [ "$rowcount2" -eq 1 ] && [ "$ccnt2" -eq 1 ] && echo "  ok    deleting the journal line restores only that line" \
  || { echo "::error::journal-line restore: journal=$jcnt row=$rowcount2 council=$ccnt2"; fail=1; }

# --- judge: one evidenced RED -------------------------------------------------------------------

echo "judge: one evidenced RED (ask 2)"
mk_spec red1 3
rd="$(mk_round red1 1)"
write_seat "$rd" haiku GRG
write_seat "$rd" sonnet GGG
write_seat "$rd" opus GGG
write_review "$rd" PASS
jout="$(council judge docs/specs/red1)"; jexit=$?
[ "$jexit" -eq 4 ] || { echo "::error::judge (red) exited $jexit, expected 4"; fail=1; }
printf '%s' "$jout" | expect "next is repair" '"next":"repair"'
row="$(grep '"spec":"red1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"verdict":"RED"' && printf '%s' "$row" | grep -q '"red":\[2\]' \
  && echo "  ok    row verdict RED, red:[2]" || { echo "::error::row: $row"; fail=1; }
grep -qE '^\*\*Council:\*\* RED round 1,.* - red: 2$' docs/specs/red1/plan.md && echo "  ok    plan line ends '- red: 2'" \
  || { echo "::error::plan.md: $(grep '^\*\*Council:\*\*' docs/specs/red1/plan.md)"; fail=1; }

# --- judge: three RED rounds hit the ceiling on the third -------------------------------------

echo "judge: three RED rounds escalate (ceiling) on the third, not the second"
mk_spec ceil1 5
rd1c="$(mk_round ceil1 1 3)"
write_seat "$rd1c" haiku RGGGG; write_seat "$rd1c" sonnet GGGGG; write_seat "$rd1c" opus GGGGG; write_review "$rd1c" PASS
out1="$(council judge docs/specs/ceil1)"; ex1=$?
[ "$ex1" -eq 4 ] && printf '%s' "$out1" | grep -qF '"next":"repair"' && echo "  ok    round 1: RED, repair" \
  || { echo "::error::round 1: exit=$ex1 out=$out1"; fail=1; }

rd2c="$(mk_round ceil1 2 3)"
write_seat "$rd2c" haiku RGGGG; write_seat "$rd2c" sonnet GGGGG; write_seat "$rd2c" opus GGGGG; write_review "$rd2c" PASS
out2="$(council judge docs/specs/ceil1)"; ex2=$?
[ "$ex2" -eq 4 ] && printf '%s' "$out2" | grep -qF '"next":"repair"' && echo "  ok    round 2: RED, still repair - no ceiling yet" \
  || { echo "::error::round 2: exit=$ex2 out=$out2"; fail=1; }

rd3c="$(mk_round ceil1 3 3)"
write_seat "$rd3c" haiku RGGGG; write_seat "$rd3c" sonnet GGGGG; write_seat "$rd3c" opus GGGGG; write_review "$rd3c" PASS
out3="$(council judge docs/specs/ceil1)"; ex3=$?
[ "$ex3" -eq 6 ] && printf '%s' "$out3" | grep -qF '"next":"escalated"' && echo "  ok    round 3: ceiling reached, ESCALATE" \
  || { echo "::error::round 3: exit=$ex3 out=$out3"; fail=1; }
row3="$(grep '"spec":"ceil1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row3" | grep -q '"escalate":"ceiling"' && echo "  ok    row escalate:ceiling" || { echo "::error::row3: $row3"; fail=1; }
grep -q '^## Needs a human' docs/specs/ceil1/plan.md && grep -qF 'reason: ceiling · round 3' docs/specs/ceil1/plan.md \
  && echo "  ok    ## Needs a human names ceiling, round 3" || { echo "::error::plan.md missing/wrong Needs a human section"; fail=1; }

# --- judge: half the asks RED escalates regardless of round -------------------------------------

echo "judge: 4 of 7 asks RED -> ESCALATE half, on round 1 already"
mk_spec half1 7
rdh="$(mk_round half1 1 3)"
write_seat "$rdh" haiku RRRRGGG
write_seat "$rdh" sonnet GGGGGGG
write_seat "$rdh" opus GGGGGGG
write_review "$rdh" PASS
out="$(council judge docs/specs/half1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    half of 7 asks escalates immediately" \
  || { echo "::error::half test: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"half1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"escalate":"half"' && echo "  ok    row escalate:half" || { echo "::error::row: $row"; fail=1; }

# --- judge: three ABSENT seats -------------------------------------------------------------------

echo "judge: three ABSENT council seats -> ESCALATE env"
mk_spec env1 3
rde="$(mk_round env1 1 3)"
write_absent "$rde" haiku
write_absent "$rde" sonnet
write_absent "$rde" opus
write_review "$rde" PASS
out="$(council judge docs/specs/env1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    three ABSENT escalates" \
  || { echo "::error::env test: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"env1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"escalate":"env"' && printf '%s' "$row" | grep -q '"haiku":"ABSENT"' \
  && echo "  ok    row escalate:env, seats ABSENT" || { echo "::error::row: $row"; fail=1; }

# --- judge: every seat N/A, review PASS -----------------------------------------------------------

echo "judge: every seat N/A with why:, review PASS -> GREEN na:3"
mk_spec na1 3
rdn="$(mk_round na1 1 3)"
write_seat "$rdn" haiku NNN
write_seat "$rdn" sonnet NNN
write_seat "$rdn" opus NNN
write_review "$rdn" PASS
out="$(council judge docs/specs/na1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"green"' && echo "  ok    all-N/A + review PASS is GREEN" \
  || { echo "::error::na test: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"na1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"na":3' && printf '%s' "$row" | grep -q '"verdict":"GREEN"' && echo "  ok    row verdict GREEN, na:3" \
  || { echo "::error::row: $row"; fail=1; }

# --- judge: a newer owner REJECTED overrides an all-GREEN round -----------------------------------

echo "judge: memory/stats/human.jsonl REJECTED newer than ROUND.opened forces RED"
mk_spec reject1 2
rdr="$(mk_round reject1 1 3)"
write_seat "$rdr" haiku GG
write_seat "$rdr" sonnet GG
write_seat "$rdr" opus GG
write_review "$rdr" PASS
printf '{"ts":"%s","spec":"reject1","verdict":"REJECTED","by":"Test Owner","head":"%s","pack":"demo-pack","note":"button missing"}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/human.jsonl
out="$(council judge docs/specs/reject1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    owner REJECTED overrides all-GREEN seats" \
  || { echo "::error::reject-override: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"reject1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"verdict":"RED"' && echo "  ok    row verdict RED" || { echo "::error::row: $row"; fail=1; }

# --- judge: a genuinely missing seat (no attempt-2) is a precondition failure ----------------------

echo "judge: a seat with no report and no attempt-2 is a precondition failure, not ABSENT"
mk_spec miss1 2
rdm="$(mk_round miss1 1 3)"
write_seat "$rdm" haiku GG
write_seat "$rdm" sonnet GG
# opus: neither opus.md nor opus.attempt-2.md exists
write_review "$rdm" PASS
out="$(council judge docs/specs/miss1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] || { echo "::error::missing-seat exit=$ex, expected 2"; fail=1; }
printf '%s' "$out" | expect "the error names the missing seat" 'opus'
printf '%s\n' "$out" | tail -1 | expect "JSON contract says ok:false" '"ok":false'
rowcount="$(grep -c '"spec":"miss1"' memory/stats/council.jsonl 2>/dev/null || true)"
[ -z "$rowcount" ] && rowcount=0
[ "$rowcount" -eq 0 ] && echo "  ok    a precondition failure writes no row" || { echo "::error::a row was written despite the precondition failure"; fail=1; }

# --- judge: PAUSE halts every mutating verb --------------------------------------------------------

echo "judge: PAUSE present -> exit 3, next paused, nothing written"
mk_spec pause1 2
rdp="$(mk_round pause1 1 3)"
write_seat "$rdp" haiku GG
write_seat "$rdp" sonnet GG
write_seat "$rdp" opus GG
write_review "$rdp" PASS
printf 'Test Owner · taking the tree back · %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > docs/specs/pause1/PAUSE
out="$(council judge docs/specs/pause1 2>&1)"; ex=$?
[ "$ex" -eq 3 ] || { echo "::error::paused exit=$ex, expected 3"; fail=1; }
printf '%s\n' "$out" | tail -1 | expect "next is paused" '"next":"paused"'
rowcount="$(grep -c '"spec":"pause1"' memory/stats/council.jsonl 2>/dev/null || true)"
[ -z "$rowcount" ] && rowcount=0
[ "$rowcount" -eq 0 ] && [ ! -f docs/specs/pause1/journal.md ] && echo "  ok    PAUSE stops judge before any write" \
  || { echo "::error::judge wrote something despite PAUSE (row=$rowcount, journal exists=$( [ -f docs/specs/pause1/journal.md ] && echo yes || echo no))"; fail=1; }

# --- journal.sh: header, the C9 line, mirrored to stdout ---------------------------------------

echo "journal.sh: header on first use, appends the C9 line, same line on stdout"
mkdir -p docs/specs/jtest
jout="$(bash scripts/journal.sh docs/specs/jtest 03-building "wave 1 dispatched" "close stories")"
head -1 docs/specs/jtest/journal.md | expect "header line" "# Journal: jtest"
grep -qF '· 03-building · wave 1 dispatched · next: close stories' docs/specs/jtest/journal.md \
  && echo "  ok    journal.md carries the C9 line" || { echo "::error::journal.md: $(cat docs/specs/jtest/journal.md)"; fail=1; }
printf '%s' "$jout" | expect "the same line reaches stdout" '· 03-building · wave 1 dispatched · next: close stories'

exit $fail
