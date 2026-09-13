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
cp "$SRC"/scripts/lib.sh "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/scope-check.sh scripts/
# Mirrors the real .gitignore (D1: neither is ever committed) - without it, open-round's
# "clean tree" precondition would trip on its own court worktree and PAUSE files.
printf '.vulyk/\ndocs/specs/*/PAUSE\n' > .gitignore
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

set_tier() { # set_tier <slug> <n> - overwrites plan.md's template <2|3|4> placeholder with a
  # concrete tier digit and commits (autonomous-cycle-18, C15 fixtures)
  local slug="$1" n="$2" plan
  plan="docs/specs/$slug/plan.md"
  sed -i "s/^\(\*\*Tier:\*\* \)<2|3|4>/\1$n/" "$plan"
  git add -A && git commit -qm "$slug: tier $n" >/dev/null
}

mk_open_spec() { # mk_open_spec <slug> <n-asks> - mk_spec plus **Approved:**/**Branch:** filled
  # (mirrors the status1 fixture below) so status --json's `next` reaches the open-round
  # branch instead of stopping at "briefed"/"branch"
  local slug="$1" n="$2"
  mk_spec "$slug" "$n"
  sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-12/' "docs/specs/$slug/plan.md"
  sed -i "s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/$slug#" "docs/specs/$slug/plan.md"
  git add -A && git commit -qm "$slug: approved+branch" >/dev/null
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

mk_open_round() { # mk_open_round <slug> <round-n> [ceiling] -> like mk_round, but head=the
  # ACTUAL current HEAD, not the fixed $HEAD7. judge never checks a round's head against
  # current HEAD, so mk_round's fixed value is fine for it; record-seat does (D2), and by
  # the time record-seat's own tests run, many commits separate current HEAD from $HEAD7.
  local slug="$1" n="$2" ceiling="${3:-3}" rd nowhead
  nowhead="$(git rev-parse --short HEAD)"
  rd="docs/specs/$slug/council/round-$n"
  mkdir -p "$rd"
  {
    printf 'head=%s\n'   "$nowhead"
    printf 'pack=demo-pack\n'
    printf 'opened=2020-01-01T00:00:00Z\n'
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
  # `fold -w1 | while read` silently drops the pattern's last char when it has no trailing
  # newline (GNU fold does not add one) - harmless for judge (it never checks ASK coverage
  # against A) but fatal for record-seat's D3 coverage check, so index by position instead.
  local plen=${#pattern} j c i
  for ((j=0; j<plen; j++)); do
    i=$((j+1))
    c="${pattern:j:1}"
    case "$c" in
      N)   printf 'ASK %d: N/A - ask %d - why: not applicable in this configuration\n' "$i" "$i" ;;
      G)   printf 'ASK %d: GREEN - ask %d - run: check-%d saw: ok\n' "$i" "$i" "$i" ;;
      R)   printf 'ASK %d: RED - ask %d - run: check-%d saw: fail\n' "$i" "$i" "$i" ;;
      '?') printf 'ASK %d: RED - ask %d - why: could not verify\n' "$i" "$i" ;;
      *)   printf 'ASK %d: GREEN - ask %d - run: check-%d saw: ok\n' "$i" "$i" "$i" ;;
    esac
  done
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

echo "status --json: wave_stories carries {file,story,worker,repeat} objects, file name order"
mkdir -p docs/specs/wstory
cat > docs/specs/wstory/wstory-01-alpha.md <<'EOF'
---
story: wstory-01
spec: wstory
status: todo
wave: 1
worker: worker-code
---
# Alpha

## Verification
`true`
EOF
cat > docs/specs/wstory/wstory-02-beta.md <<'EOF'
---
story: wstory-02
spec: wstory
status: todo
wave: 1
worker: worker-test
---
# Beta

## Verification
repeat: 3
`true`
EOF
git add -A && git commit -qm "spec(wstory): fixture" >/dev/null

out="$(council status docs/specs/wstory --json)"
printf '%s' "$out" | jq -c '.wave_stories' \
  | expect "wave_stories: worker-code + worker-test objects, file name order, repeat parsed (default 1, explicit 3)" \
    '[{"file":"docs/specs/wstory/wstory-01-alpha.md","story":"wstory-01","worker":"worker-code","repeat":1},{"file":"docs/specs/wstory/wstory-02-beta.md","story":"wstory-02","worker":"worker-test","repeat":3}]'

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

# --- C15: the council scales with tier (autonomous-cycle-18) ---------------------------------

echo "C15: Tier 1 requires sonnet only - status missing/next, judge reaches GREEN on one report"
mk_open_spec tier1a 3
set_tier tier1a 1
rdt1="$(mk_round tier1a 1)"
out="$(council status docs/specs/tier1a --json)"
printf '%s' "$out" | jq -r '.missing | join(",")' | expect "tier 1: missing lists only sonnet" "sonnet"
printf '%s' "$out" | jq -r .next | expect "tier 1: next is dispatch:sonnet" "dispatch:sonnet"
write_seat "$rdt1" sonnet NNN
out="$(council status docs/specs/tier1a --json)"
printf '%s' "$out" | jq -r .next | expect "tier 1: next is judge after the one required seat" "judge"
jout="$(council judge docs/specs/tier1a)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    tier 1: judge GREEN on sonnet alone" \
  || { echo "::error::tier1a judge: exit=$jex out=$jout"; fail=1; }
row="$(grep '"spec":"tier1a"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"na":1' && printf '%s' "$row" | grep -q '"verdict":"GREEN"' \
  && echo "  ok    tier 1: row verdict GREEN, na:1 (one seat, not na:3)" || { echo "::error::row: $row"; fail=1; }

echo "C15: Tier 2 requires sonnet, opus, review - no haiku seat needed"
mk_open_spec tier2a 3
set_tier tier2a 2
rdt2="$(mk_round tier2a 1)"
out="$(council status docs/specs/tier2a --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "tier 2: missing lists opus,review,sonnet - not haiku" "opus,review,sonnet"
write_seat "$rdt2" sonnet GGG
write_seat "$rdt2" opus GGG
write_review "$rdt2" PASS
out="$(council status docs/specs/tier2a --json)"
printf '%s' "$out" | jq -r .next | expect "tier 2: next is judge without a haiku seat" "judge"
jout="$(council judge docs/specs/tier2a)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    tier 2: judge GREEN without haiku" \
  || { echo "::error::tier2a judge: exit=$jex out=$jout"; fail=1; }

echo "C15: Tier 3 requires all four seats"
mk_open_spec tier3a 3
set_tier tier3a 3
mk_round tier3a 1 >/dev/null
out="$(council status docs/specs/tier3a --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "tier 3: missing lists all four seats" "haiku,opus,review,sonnet"

echo "C15: a plan.md without a parsable **Tier:** line behaves as tier 4 and journals it once"
mk_open_spec tierdefault 3
mk_round tierdefault 1 >/dev/null
out="$(council status docs/specs/tierdefault --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "no Tier line: behaves as tier 4 (all four seats)" "haiku,opus,review,sonnet"
grep -qF $' \xc2\xb7 tier:default \xc2\xb7 ' docs/specs/tierdefault/journal.md && echo "  ok    unparsable tier journaled once as a warning" \
  || { echo "::error::journal.md: $(cat docs/specs/tierdefault/journal.md 2>&1)"; fail=1; }
before="$(grep -c 'tier:default' docs/specs/tierdefault/journal.md)"
council status docs/specs/tierdefault --json >/dev/null
after="$(grep -c 'tier:default' docs/specs/tierdefault/journal.md)"
[ "$before" -eq 1 ] && [ "$after" -eq 1 ] && echo "  ok    the tier:default warning is not repeated on later calls" \
  || { echo "::error::tier:default count before=$before after=$after"; fail=1; }

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

# --- briefed --------------------------------------------------------------------------------

echo "briefed: missing ## Asks section -> exit 2, no Briefed line written"
mk_spec briefnoask 3
sed -i '/^## Asks$/,$d' docs/specs/briefnoask/brief.md
out="$(council briefed docs/specs/briefnoask 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'Asks' && echo "  ok    missing ## Asks -> exit 2" \
  || { echo "::error::missing Asks: exit=$ex out=$out"; fail=1; }
grep -qE '^\*\*Briefed:\*\* via ' docs/specs/briefnoask/plan.md && { echo "::error::Briefed line written despite missing ## Asks"; fail=1; } \
  || echo "  ok    no Briefed line written"

echo "briefed: empty ## Asks section (present, zero items) -> exit 2"
mk_spec briefempty 0
out="$(council briefed docs/specs/briefempty 2>&1)"; ex=$?
[ "$ex" -eq 2 ] || { echo "::error::empty Asks: exit=$ex out=$out"; fail=1; }
[ "$ex" -eq 2 ] && echo "  ok    empty ## Asks -> exit 2"

echo "briefed: writes **Briefed:** via grill, <owner>, <date>, journals, next branch"
mk_spec brief1 3
out="$(council briefed docs/specs/brief1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"branch"' && echo "  ok    briefed exits 0, next branch" \
  || { echo "::error::briefed: exit=$ex out=$out"; fail=1; }
grep -qE '^\*\*Briefed:\*\* via grill, .+, [0-9]{4}-[0-9]{2}-[0-9]{2}$' docs/specs/brief1/plan.md \
  && echo "  ok    Briefed line has the C7 shape" || { echo "::error::plan.md: $(grep '^\*\*Briefed:\*\*' docs/specs/brief1/plan.md)"; fail=1; }
grep -qF '02-approved' docs/specs/brief1/journal.md && echo "  ok    journal records the briefed event" \
  || { echo "::error::journal.md: $(cat docs/specs/brief1/journal.md)"; fail=1; }

echo "briefed: --mode mini-brief / assumed select the C7 variant"
mk_spec brief2 1
council briefed docs/specs/brief2 --mode mini-brief >/dev/null
grep -qF '**Briefed:** via mini-brief,' docs/specs/brief2/plan.md && echo "  ok    --mode mini-brief writes 'via mini-brief'" \
  || { echo "::error::$(grep '^\*\*Briefed:\*\*' docs/specs/brief2/plan.md)"; fail=1; }

mk_spec brief3 1
council briefed docs/specs/brief3 --mode assumed >/dev/null
grep -qF '**Briefed:** via grill (assumed),' docs/specs/brief3/plan.md && echo "  ok    --mode assumed writes 'via grill (assumed)'" \
  || { echo "::error::$(grep '^\*\*Briefed:\*\*' docs/specs/brief3/plan.md)"; fail=1; }

echo "briefed --commit: commits as vulyk(<slug>): briefed"
mk_spec brief4 1
council briefed docs/specs/brief4 --commit >/dev/null
git log -1 --format=%s | grep -qF 'vulyk(brief4): briefed' && echo "  ok    --commit creates the paperwork commit" \
  || { echo "::error::$(git log -1 --format=%s)"; fail=1; }

# --- branch -----------------------------------------------------------------------------------

echo "branch: exits 2 without Briefed or Approved"
mk_spec branchnobrief 2
out="$(council branch docs/specs/branchnobrief 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && echo "  ok    branch without Briefed/Approved exits 2" || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "branch: creates/checks out vulyk/<slug>, writes **Branch:**, journal, next build:1"
mk_spec branch1 2
council briefed docs/specs/branch1 >/dev/null
out="$(council branch docs/specs/branch1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"build:1"' && echo "  ok    branch exits 0, next build:1" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qF '**Branch:** vulyk/branch1' docs/specs/branch1/plan.md && echo "  ok    Branch line written" \
  || { echo "::error::$(grep '^\*\*Branch:\*\*' docs/specs/branch1/plan.md)"; fail=1; }
[ "$(git rev-parse --abbrev-ref HEAD)" = "vulyk/branch1" ] && echo "  ok    checked out vulyk/branch1" \
  || { echo "::error::current branch: $(git rev-parse --abbrev-ref HEAD)"; fail=1; }
grep -qF 'build:1' docs/specs/branch1/journal.md && echo "  ok    journal records the branch event" \
  || { echo "::error::journal.md: $(cat docs/specs/branch1/journal.md)"; fail=1; }
git checkout -q main

echo "branch --commit: commits as vulyk(<slug>): branch vulyk/<slug>"
mk_spec branch2 1
council briefed docs/specs/branch2 >/dev/null
council branch docs/specs/branch2 --commit >/dev/null
git log -1 --format=%s | grep -qF 'vulyk(branch2): branch vulyk/branch2' && echo "  ok    --commit creates the paperwork commit" \
  || { echo "::error::$(git log -1 --format=%s)"; fail=1; }
git checkout -q main

# --- record-seat: preconditions (open round, HEAD match) -------------------------------------

echo "record-seat: no open round -> exit 2"
mk_spec rseat1 3
out="$(seat_report haiku 1 GGG | council record-seat docs/specs/rseat1 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && echo "  ok    no open round -> exit 2" || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: a valid C5 report writes <seat>.md with the C4 header, attempt 1, exit 0"
rd_rs1="$(mk_open_round rseat1 1)"
out="$(seat_report haiku 1 GGG | council record-seat docs/specs/rseat1 1 haiku)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qE '"next":"dispatch:' && echo "  ok    valid report recorded, exit 0" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
head -1 "$rd_rs1/haiku.md" | grep -qE '^<!-- seat: haiku .* attempt: 1 .* -->$' && echo "  ok    C4 header, attempt 1" \
  || { echo "::error::header: $(head -1 "$rd_rs1/haiku.md")"; fail=1; }

echo "record-seat: stale round (a real, non-paperwork commit moved HEAD since ROUND.head) -> exit 5"
mk_spec rseat2 2
mk_open_round rseat2 1 >/dev/null
echo "real code change" > rseat2-code.txt
git add -A && git commit -qm "advance head with a real code change" >/dev/null
out="$(seat_report sonnet 1 GG | council record-seat docs/specs/rseat2 1 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 5 ] && printf '%s' "$out" | grep -qF '"next":"stale"' && echo "  ok    stale round -> exit 5" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: NOT stale when HEAD only advanced by the cycle's own paperwork since ROUND.head"
mk_spec pwseat1 3
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-12/' docs/specs/pwseat1/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/pwseat1#' docs/specs/pwseat1/plan.md
git add -A && git commit -qm "pwseat1: briefed, branch" >/dev/null
council open-round docs/specs/pwseat1 --commit >/dev/null   # open-round's own commit moves HEAD
rdpw1="docs/specs/pwseat1/council/round-1"
out="$(seat_report haiku 1 GGG | council record-seat docs/specs/pwseat1 1 haiku)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:sonnet,opus,review"' && echo "  ok    record-seat right after open-round --commit is not stale" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rdpw1/haiku.md" ] && echo "  ok    haiku.md written at attempt 1" || { echo "::error::missing $rdpw1/haiku.md"; fail=1; }
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == false' >/dev/null 2>&1 && echo "  ok    status --json stale:false right after open-round's own commit" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -r .next | grep -qE '^dispatch:' && echo "  ok    next still lists the missing seats" \
  || { echo "::error::next was $(printf '%s' "$out" | jq -r .next)"; fail=1; }

echo "record-seat: still NOT stale after a further paperwork-only commit (a driver committing council/*)"
git add -- "$rdpw1/haiku.md" && git commit -qm "vulyk(pwseat1): record-seat haiku round 1" >/dev/null
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == false' >/dev/null 2>&1 && echo "  ok    status --json stale:false after a paperwork-only commit" \
  || { echo "::error::status: $out"; fail=1; }

echo "record-seat: stale (exit 5) once a real non-paperwork file lands on top"
echo "real code change" > pwseat1-code.txt
git add -A && git commit -qm "real code change while pwseat1 round 1 is open" >/dev/null
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == true' >/dev/null 2>&1 && echo "  ok    status --json stale:true once real code moved" \
  || { echo "::error::status: $out"; fail=1; }
out="$(seat_report sonnet 1 GGG | council record-seat docs/specs/pwseat1 1 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 5 ] && printf '%s' "$out" | grep -qF '"next":"stale"' && echo "  ok    record-seat exit 5 once real code moved" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

# --- record-seat: D3 MALFORMED cases (exit 4, kept as attempt-1.md, never <seat>.md) ----------

echo "record-seat: a missing label -> exit 4 MALFORMED, kept as attempt-1.md"
mk_spec rseat3 2
rd_rs3="$(mk_open_round rseat3 1)"
report_missing_label() {
  printf 'MODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - a - run: c saw: ok\nASK 2: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_missing_label | council record-seat docs/specs/rseat3 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF '"error":"MALFORMED:' && echo "  ok    missing label -> exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rd_rs3/haiku.attempt-1.md" ] && [ ! -f "$rd_rs3/haiku.md" ] && echo "  ok    kept as attempt-1.md, not haiku.md" \
  || { echo "::error::files: $(ls "$rd_rs3")"; fail=1; }

echo "record-seat: ASK numbers not exactly 1..A -> exit 4"
mk_spec rseat4 3
mk_open_round rseat4 1 >/dev/null
report_bad_numbers() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - a - run: c saw: ok\nASK 3: GREEN - a - run: c saw: ok\nASK 4: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_bad_numbers | council record-seat docs/specs/rseat4 1 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'ASK numbers' && echo "  ok    bad ASK numbering -> exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: N/A without why: -> exit 4"
mk_spec rseat5 2
mk_open_round rseat5 1 >/dev/null
report_na_no_why() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: N/A\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: N/A - a - no reason given\nASK 2: N/A - a - why: not applicable\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_na_no_why | council record-seat docs/specs/rseat5 1 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'without why' && echo "  ok    N/A without why: -> exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: VERDICT inconsistent with ASK lines -> exit 4"
mk_spec rseat6 2
mk_open_round rseat6 1 >/dev/null
report_verdict_mismatch() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - a - run: c saw: ok\nASK 2: RED - a - run: c saw: fail\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_verdict_mismatch | council record-seat docs/specs/rseat6 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'inconsistent' && echo "  ok    VERDICT inconsistent -> exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: a body naming <slug>-NN, plan.md, journal.md or council/ -> tainted"
mk_spec demo 2
rd_demo1="$(mk_open_round demo 1)"
report_taint() { # report_taint <phrase>
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - %s - run: c saw: ok\nASK 2: GREEN - a - run: c saw: ok\n' "$1"
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_taint 'looked at demo-01' | council record-seat docs/specs/demo 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>-NN (demo-01) in body -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'checked plan.md' | council record-seat docs/specs/demo 1 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    plan.md in body -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'checked journal.md' | council record-seat docs/specs/demo 1 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    journal.md in body -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo2="$(mk_open_round demo 2)"
out="$(report_taint 'looked under council/' | council record-seat docs/specs/demo 2 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    council/ in body -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

# --- record-seat: GREEN/RED without evidence - attempt 1 rejects, attempt 2's leniency --------

echo "record-seat: unevidenced RED -> exit 4 on attempt 1, accepted on attempt 2, excluded from half"
mk_spec runev 3
rd_runev="$(mk_open_round runev 1)"
out="$(seat_report haiku 1 'G?G' | council record-seat docs/specs/runev 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && echo "  ok    attempt 1: unevidenced RED rejected" || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rd_runev/haiku.attempt-1.md" ] && echo "  ok    kept as attempt-1.md" || { echo "::error::no attempt-1.md"; fail=1; }
out2="$(seat_report haiku 1 'G?G' | council record-seat docs/specs/runev 1 haiku)"; ex2=$?
[ "$ex2" -eq 0 ] && echo "  ok    attempt 2: unevidenced RED accepted" || { echo "::error::exit=$ex2 out=$out2"; fail=1; }
grep -qF 'unevidenced: 2' "$rd_runev/haiku.md" && echo "  ok    header carries unevidenced: 2" \
  || { echo "::error::header: $(head -1 "$rd_runev/haiku.md")"; fail=1; }
seat_report sonnet 1 GGG | council record-seat docs/specs/runev 1 sonnet >/dev/null
seat_report opus 1 GGG | council record-seat docs/specs/runev 1 opus >/dev/null
printf 'Reviewed.\nPASS\n' | council record-seat docs/specs/runev 1 review >/dev/null
jout="$(council judge docs/specs/runev)"; jex=$?
[ "$jex" -eq 4 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    judge: RED (not escalated by an unevidenced-only red)" \
  || { echo "::error::jex=$jex jout=$jout"; fail=1; }
row="$(grep '"spec":"runev"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"red":[]' && printf '%s' "$row" | grep -qF '"red_unevidenced":[2]' \
  && echo "  ok    row: red:[], red_unevidenced:[2]" || { echo "::error::row: $row"; fail=1; }

echo "record-seat: unevidenced GREEN -> rewritten N/A - why: unevidenced on attempt 2"
mk_spec rgreen 2
rd_rgreen="$(mk_open_round rgreen 1)"
report_green_noeq() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - ask one - run: c saw: ok\nASK 2: GREEN - ask two - looked fine\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
report_green_noeq | council record-seat docs/specs/rgreen 1 sonnet >/dev/null; ex1=$?
[ "$ex1" -eq 4 ] || { echo "::error::attempt1 exit=$ex1, expected 4"; fail=1; }
report_green_noeq | council record-seat docs/specs/rgreen 1 sonnet >/dev/null; ex2=$?
[ "$ex2" -eq 0 ] || { echo "::error::attempt2 exit=$ex2, expected 0"; fail=1; }
grep -qF 'ASK 2: N/A - ask two - why: unevidenced on attempt 2' "$rd_rgreen/sonnet.md" \
  && echo "  ok    unevidenced GREEN rewritten to N/A" || { echo "::error::sonnet.md: $(cat "$rd_rgreen/sonnet.md")"; fail=1; }

echo "record-seat: a third attempt exits 2 - the seat is ABSENT"
mk_spec rabsent 2
rd_rabsent="$(mk_open_round rabsent 1)"
printf 'garbage\n'  | council record-seat docs/specs/rabsent 1 haiku >/dev/null 2>&1
printf 'garbage2\n' | council record-seat docs/specs/rabsent 1 haiku >/dev/null 2>&1
out="$(printf 'garbage3\n' | council record-seat docs/specs/rabsent 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'ABSENT' && echo "  ok    third attempt -> exit 2, ABSENT" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -f "$rd_rabsent/haiku.md" ] && [ -f "$rd_rabsent/haiku.attempt-2.md" ] && echo "  ok    no final haiku.md, attempt-2.md remains" \
  || { echo "::error::files: $(ls "$rd_rabsent")"; fail=1; }

# --- record-seat: review seat, any shape, PASS/BLOCK extracted -------------------------------

echo "record-seat review: any shape accepted, PASS/BLOCK extracted into header verdict:"
mk_spec rrev 2
rd_rrev="$(mk_open_round rrev 1)"
out="$(printf 'Looked at everything.\nBLOCK - missing a guard on line 40.\n' | council record-seat docs/specs/rrev 1 review)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    review with BLOCK anywhere -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qF 'verdict: BLOCK' "$rd_rrev/review.md" && echo "  ok    header carries verdict: BLOCK" \
  || { echo "::error::$(head -1 "$rd_rrev/review.md")"; fail=1; }

echo "record-seat review: neither PASS nor BLOCK -> exit 4"
mk_spec rrev2 2
mk_open_round rrev2 1 >/dev/null
out="$(printf 'Just some prose, no verdict token.\n' | council record-seat docs/specs/rrev2 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'MALFORMED' && echo "  ok    review without PASS/BLOCK -> exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

# --- record-seat: model resolution (--model > report's MODEL: > unknown) ----------------------

echo "record-seat: --model overrides the report's MODEL: line; falls back to unknown"
mk_spec rmodel 1
rd_rmodel="$(mk_open_round rmodel 1)"
seat_report haiku 1 G | council record-seat docs/specs/rmodel 1 haiku --model claude-opus-5 >/dev/null
grep -qF 'model: claude-opus-5' "$rd_rmodel/haiku.md" && echo "  ok    --model overrides the report's MODEL: line" \
  || { echo "::error::header: $(head -1 "$rd_rmodel/haiku.md")"; fail=1; }

mk_spec rmodel2 1
rd_rmodel2="$(mk_open_round rmodel2 1)"
printf 'COUNCIL: x\nMODEL: \nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\nASK 1: GREEN - a - run: c saw: ok\nUNASKED: none\nBREACH: none\n' \
  | council record-seat docs/specs/rmodel2 1 sonnet >/dev/null
grep -qF 'model: unknown' "$rd_rmodel2/sonnet.md" && echo "  ok    falls back to unknown when neither is given" \
  || { echo "::error::header: $(head -1 "$rd_rmodel2/sonnet.md")"; fail=1; }

# --- PAUSE guard: every mutating verb refuses before touching anything ------------------------

echo "PAUSE: briefed, branch, record-seat, close-story, open-round, reopen all exit 3"
mk_spec pauseall 2
printf 'Test Owner \xc2\xb7 blocking \xc2\xb7 %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > docs/specs/pauseall/PAUSE
out="$(council briefed docs/specs/pauseall 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    briefed paused" \
  || { echo "::error::briefed: exit=$ex out=$out"; fail=1; }
out="$(council branch docs/specs/pauseall 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    branch paused" \
  || { echo "::error::branch: exit=$ex out=$out"; fail=1; }
out="$(printf 'x\n' | council record-seat docs/specs/pauseall 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    record-seat paused" \
  || { echo "::error::record-seat: exit=$ex out=$out"; fail=1; }
# close-story takes a story-file (not a spec-dir) and reopen needs a decision string - the
# PAUSE guard must still be the very first thing each hits, ahead of its own usage checks.
out="$(council close-story docs/specs/pauseall/pauseall-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    close-story paused" \
  || { echo "::error::close-story: exit=$ex out=$out"; fail=1; }
for v in open-round; do
  out="$(council "$v" docs/specs/pauseall 2>&1)"; ex=$?
  [ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    $v paused" \
    || { echo "::error::$v: exit=$ex out=$out"; fail=1; }
done
out="$(council reopen docs/specs/pauseall "the owner's call" 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    reopen paused" \
  || { echo "::error::reopen: exit=$ex out=$out"; fail=1; }
grep -qE '^\*\*Briefed:\*\* via ' docs/specs/pauseall/plan.md && { echo "::error::Briefed line written despite PAUSE"; fail=1; } \
  || echo "  ok    PAUSE stopped every verb before it touched anything"

# --- pause / resume ----------------------------------------------------------------------------

echo "pause: creates PAUSE (who · why · ts as its first line) and journals"
mk_spec pz1 2
out="$(council pause docs/specs/pz1 "taking it back")"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    pause exits 0, next paused" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f docs/specs/pz1/PAUSE ] && head -1 docs/specs/pz1/PAUSE | grep -qF 'taking it back' && echo "  ok    PAUSE file's first line carries the reason" \
  || { echo "::error::PAUSE: $(cat docs/specs/pz1/PAUSE 2>&1)"; fail=1; }
grep -qF 'paused' docs/specs/pz1/journal.md && echo "  ok    journal records paused" \
  || { echo "::error::journal.md missing"; fail=1; }

echo "resume: removes PAUSE, journals, stale:true when HEAD moved while paused"
git commit --allow-empty -qm "moved while paused" >/dev/null
out="$(council resume docs/specs/pz1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"stale":true' && echo "  ok    resume reports stale:true after HEAD moved" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -f docs/specs/pz1/PAUSE ] && echo "  ok    PAUSE removed" || { echo "::error::PAUSE still present"; fail=1; }
grep -qF 'resumed' docs/specs/pz1/journal.md && echo "  ok    journal records resumed" \
  || { echo "::error::journal.md missing resumed"; fail=1; }

echo "resume: stale:false when HEAD is unchanged since pause"
mk_spec pz2 2
council pause docs/specs/pz2 "brb" >/dev/null
out="$(council resume docs/specs/pz2)"
printf '%s' "$out" | grep -qF '"stale":false' && echo "  ok    resume reports stale:false when HEAD is unchanged" \
  || { echo "::error::$out"; fail=1; }

echo "pause / resume are themselves exempt from the PAUSE guard"
mk_spec pz3 2
council pause docs/specs/pz3 "first" >/dev/null
out="$(council pause docs/specs/pz3 "second" 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    pause while already paused still succeeds" || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(council resume docs/specs/pz3 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    resume succeeds while paused" || { echo "::error::exit=$ex out=$out"; fail=1; }

# --- close-story: scope-check + ## Verification gate status:done, --commit writes story(<id>) ---

echo "close-story: red verification -> exit 4, story stays open; green -> done"
mkdir -p docs/specs/cstory1
cat > docs/specs/cstory1/cstory1-01-first.md <<'EOF'
---
story: cstory1-01
spec: cstory1
status: todo
wave: 1
---
# Close-story fixture

## Files
- docs/specs/cstory1/flag.txt

## Verification
`test -f docs/specs/cstory1/flag.txt`
EOF
git add -A && git commit -qm "spec(cstory1): fixture" >/dev/null

out="$(council close-story docs/specs/cstory1/cstory1-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    red verification -> exit 4, next repair" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: todo' docs/specs/cstory1/cstory1-01-first.md && echo "  ok    status stays todo on red" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory1/cstory1-01-first.md)"; fail=1; }
grep -qF '"story":"cstory1-01-first"' memory/stats/scope.jsonl && echo "  ok    scope-check.sh ran (scope.jsonl has an entry)" \
  || { echo "::error::scope.jsonl: $(cat memory/stats/scope.jsonl 2>&1)"; fail=1; }

printf 'ok\n' > docs/specs/cstory1/flag.txt
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    green verification -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: done' docs/specs/cstory1/cstory1-01-first.md && echo "  ok    status becomes done" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory1/cstory1-01-first.md)"; fail=1; }
git log -1 --format=%s | grep -qF 'story(cstory1-01):' && echo "  ok    --commit writes story(<id>): <title>" \
  || { echo "::error::$(git log -1 --format=%s)"; fail=1; }

echo "close-story: exit 2 on an already-done story"
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && echo "  ok    already done -> exit 2" || { echo "::error::exit=$ex out=$out"; fail=1; }

# --- open-round: preconditions, the court, D1 idempotency/staleness, orphan cleanup ------------

echo "open-round: preconditions - no Branch line -> exit 2"
mk_spec oround1 3
out="$(council open-round docs/specs/oround1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'branch' && echo "  ok    missing Branch -> exit 2" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oround1#' docs/specs/oround1/plan.md
git add -A && git commit -qm "oround1: branch" >/dev/null

echo "open-round: preconditions - dirty tree -> exit 2"
echo stray > docs/specs/oround1/stray.txt
out="$(council open-round docs/specs/oround1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'clean' && echo "  ok    dirty tree -> exit 2" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -f docs/specs/oround1/stray.txt

echo "open-round: opens round 1 - ROUND file, court reduced to brief.md, journal, next dispatch:..."
out="$(council open-round docs/specs/oround1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:haiku,sonnet,opus,review"' && echo "  ok    round 1 opens, next dispatch:..." \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd1o="docs/specs/oround1/council/round-1"
[ -f "$rd1o/ROUND" ] && grep -q '^ceiling=3$' "$rd1o/ROUND" && echo "  ok    ROUND file written, ceiling=3 (default)" \
  || { echo "::error::ROUND: $(cat "$rd1o/ROUND" 2>&1)"; fail=1; }
grep -q '^tier=4$' "$rd1o/ROUND" && echo "  ok    ROUND file freezes tier=4 (no parsable Tier line -> default)" \
  || { echo "::error::ROUND: $(cat "$rd1o/ROUND" 2>&1)"; fail=1; }
court1="$(sed -n 's/^court=//p' "$rd1o/ROUND")"
[ -d "$court1" ] && echo "  ok    court worktree exists on disk" || { echo "::error::no court at $court1"; fail=1; }
courtfiles="$(ls -A "$court1/docs/specs/oround1" 2>/dev/null)"
[ "$courtfiles" = "brief.md" ] && echo "  ok    the court holds brief.md and nothing else under docs/specs/oround1/" \
  || { echo "::error::court contents: $courtfiles"; fail=1; }
grep -qF '04-council:open' docs/specs/oround1/journal.md && echo "  ok    journal records the open" \
  || { echo "::error::journal.md: $(cat docs/specs/oround1/journal.md)"; fail=1; }
git log -1 --format=%s | grep -qF 'vulyk(oround1): open-round 1' && echo "  ok    --commit writes vulyk(<slug>): open-round N" \
  || { echo "::error::$(git log -1 --format=%s)"; fail=1; }

echo "open-round: idempotent - HEAD unchanged -> no-op, next lists only missing seats"
out="$(council open-round docs/specs/oround1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:haiku,sonnet,opus,review"' && echo "  ok    HEAD unchanged, no seats yet -> still all four missing" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

write_seat "$rd1o" haiku GGG
out="$(council open-round docs/specs/oround1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:sonnet,opus,review"' && echo "  ok    HEAD unchanged, one seat present -> next lists only the missing three" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "open-round: a manual code commit on an open round with a seat file -> STALE row + round N+1"
echo "code change" > oround1-manual-code.txt
git add -A && git commit -qm "manual code change while oround1 round 1 is open" >/dev/null
out="$(council open-round docs/specs/oround1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:haiku,sonnet,opus,review"' && echo "  ok    stale round folded, round 2 opened, next dispatch:..." \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
row1="$(grep '"spec":"oround1"' memory/stats/council.jsonl | grep '"round":1' | tail -1)"
printf '%s' "$row1" | grep -q '"verdict":"STALE"' && echo "  ok    round 1 got a STALE row" || { echo "::error::row1: $row1"; fail=1; }
grep -qE '^\*\*Council:\*\* STALE round 1,' docs/specs/oround1/plan.md && echo "  ok    plan.md records STALE round 1" \
  || { echo "::error::plan.md: $(grep '^\*\*Council:\*\*' docs/specs/oround1/plan.md)"; fail=1; }
rd2o="docs/specs/oround1/council/round-2"
[ -f "$rd2o/ROUND" ] && echo "  ok    round 2 opened" || { echo "::error::round-2 missing"; fail=1; }

echo "judge: removes the court after judging"
court2="$(sed -n 's/^court=//p' "$rd2o/ROUND")"
[ -d "$court2" ] && echo "  ok    round 2's court exists before judging" || { echo "::error::no court2 at $court2"; fail=1; }
write_seat "$rd2o" haiku GGG
write_seat "$rd2o" sonnet GGG
write_seat "$rd2o" opus GGG
write_review "$rd2o" PASS
council judge docs/specs/oround1 --commit >/dev/null
[ ! -d "$court2" ] && echo "  ok    judge removed the court directory" || { echo "::error::court2 still present: $(ls "$court2" 2>&1)"; fail=1; }
git worktree list | grep -qF "$court2" && { echo "::error::git worktree list still lists $court2"; fail=1; } \
  || echo "  ok    git worktree list no longer lists it"

echo "open-round: exit 6 at the ceiling, next escalated - no new round created"
mk_spec oceil1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oceil1#' docs/specs/oceil1/plan.md
mkdir -p docs/specs/oceil1/council
printf '1\n' > docs/specs/oceil1/council/CEILING
git add -A && git commit -qm "oceil1: branch, ceiling 1" >/dev/null
mk_round oceil1 1 1 >/dev/null
printf '{"ts":"%s","spec":"oceil1","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":2,"red":[1],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"RED","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":4,"escalate":null,"note":""}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
# A real round 1 would already be committed (judge --commit sweeps its own row + seat files) -
# fabricate that same clean-after-judging state so the ceiling gate is what's under test here.
git add -A && git commit -qm "oceil1: fabricated round 1, already judged RED" >/dev/null
out="$(council open-round docs/specs/oceil1 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    ceiling reached -> exit 6, next escalated" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -d docs/specs/oceil1/council/round-2 ] && echo "  ok    no round-2 was created" || { echo "::error::round-2 exists despite the ceiling"; fail=1; }

# --- reopen: ceiling +3 after ESCALATE, then a fourth round opens ------------------------------

echo "reopen: three RED rounds escalate (ceiling) on the third, reopen bumps ceiling to 6, a 4th round opens"
mk_spec oreopen1 5
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oreopen1#' docs/specs/oreopen1/plan.md
git add -A && git commit -qm "oreopen1: branch" >/dev/null

for n in 1 2 3; do
  council open-round docs/specs/oreopen1 --commit >/dev/null
  rdn="docs/specs/oreopen1/council/round-$n"
  write_seat "$rdn" haiku RGGGG
  write_seat "$rdn" sonnet GGGGG
  write_seat "$rdn" opus GGGGG
  write_review "$rdn" PASS
  jout="$(council judge docs/specs/oreopen1 --commit)"; jex=$?
  if [ "$n" -lt 3 ]; then
    [ "$jex" -eq 4 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    round $n: RED, repair" \
      || { echo "::error::round $n: exit=$jex out=$jout"; fail=1; }
  else
    [ "$jex" -eq 6 ] && printf '%s' "$jout" | grep -qF '"next":"escalated"' && echo "  ok    round $n: ceiling reached, ESCALATE" \
      || { echo "::error::round $n: exit=$jex out=$jout"; fail=1; }
  fi
done

out="$(council reopen docs/specs/oreopen1 "ship it after manual review" --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"open-round"' && echo "  ok    reopen exits 0, next open-round" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(cat docs/specs/oreopen1/council/CEILING)" = "6" ] && echo "  ok    ceiling is now 6" \
  || { echo "::error::CEILING: $(cat docs/specs/oreopen1/council/CEILING 2>&1)"; fail=1; }
grep -qF '**After escalation (round 3,' docs/specs/oreopen1/brief.md && grep -qF '> ship it after manual review' docs/specs/oreopen1/brief.md \
  && echo "  ok    brief.md ## Answers records the escalation decision" \
  || { echo "::error::brief.md: $(cat docs/specs/oreopen1/brief.md)"; fail=1; }

out="$(council open-round docs/specs/oreopen1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:haiku,sonnet,opus,review"' && echo "  ok    a fourth round opens past the old ceiling" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -d docs/specs/oreopen1/council/round-4 ] && echo "  ok    round-4 directory exists" || { echo "::error::round-4 missing"; fail=1; }

exit $fail
