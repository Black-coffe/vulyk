#!/usr/bin/env bash
# The council's verdict machinery, driven through hand-written fixtures - no model calls.
# Covers scripts/lib.sh's functions (indirectly, through cycle.sh), scripts/cycle.sh's
# `status`/`judge`/`escalate`, scripts/journal.sh, and the verdict table (docs/adr/
# 001-cycle-state-contract.md D4).
#
#   Usage: bash tests/council.test.sh            # from the VULYK repo root - the release gate
#          bash tests/council.test.sh --quick    # the contract in a few minutes (ADR-013 D5)
#
# Mirrors tests/cycle.test.sh: a throwaway git repo, `expect()` on stdout substrings, exit 1
# on the first wrong answer. Unlike cycle.test.sh's single spec walked through six stages,
# council verdicts are round-scoped and independent, so each scenario below gets its own spec
# directory (its own `"spec"` key in council.jsonl) instead of one spec reused throughout.
#
# --quick keeps one case per verb and rule and every 0.18 case, and skips what re-proves a
# shipped fix a kept case already exercises: the variant batteries (anchored BLOCK, taint,
# evidence, review layout, ceilings), the per-story regression walks (stories 14-17, C5) and
# every replay against a pinned commit. On Windows each cycle.sh call costs about a second of
# process spawns, so the full run is ~10 minutes and stays the release gate.
set -u
QUICK=0
case "${1:-}" in
  --quick) QUICK=1 ;;
  '') ;;
  *) echo "usage: bash tests/council.test.sh [--quick]" >&2; exit 2 ;;
esac
full() { [ "$QUICK" -eq 0 ]; } # `if full; then ... fi` wraps each block --quick skips
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
cp "$SRC"/scripts/lib.sh "$SRC"/scripts/cycle.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/scope-check.sh "$SRC"/scripts/redact.sh scripts/
# Mirrors the real .gitignore (D1: neither is ever committed) - without it, open-round's
# "clean tree" precondition would trip on its own court worktree and PAUSE files. Story 17
# adds DRIVER (ADR-004/K3): a claim must leave the fixture repo's tree clean too.
printf '.vulyk/\ndocs/specs/*/PAUSE\ndocs/specs/*/DRIVER\n' > .gitignore
# A minimal CLAUDE.md `## Commands` table (R11/C-4, autonomous-cycle-21): close-story now
# refuses a verification command that is not a literal cell of this table, so every fixture
# below that calls close-story must have its command listed here first.
cat > CLAUDE.md <<'EOF'
# Fixture hive

## Commands

| Purpose | Command |
|---|---|
| Close-story fixture (flag file) | `test -f docs/specs/cstory1/flag.txt` |
| Fixture: always fails | `false` |
| Fixture: always succeeds | `true` |
| Fixture: quoted command that fails | `sh -c "exit 1"` |
| Fixture: backslash command that fails | `sh -c 'echo a\b; exit 1'` |
| r2m9 fixture: a cell that is itself an &&-joined command | `sh -c 'true && true'` |
EOF
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

set_tier() { # set_tier <slug> <n> - overwrites plan.md's template `**Tier:** <...>` placeholder
  # with a concrete tier digit and commits (autonomous-cycle-18, C15 fixtures). Matches any
  # bracketed placeholder (`<1|2|3|4>` today, story 25's template) rather than one literal
  # spelling, so a template wording change elsewhere on the branch does not silently no-op this.
  local slug="$1" n="$2" plan
  plan="docs/specs/$slug/plan.md"
  sed -i "s/^\(\*\*Tier:\*\* \)<[^>]*>/\1$n/" "$plan"
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
for k in spec slug stage next briefed approved branch head pack stories wave wave_stories round ceiling tier open court missing stale verdict review red round_dir paused shipped since seat_attempt seats; do
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
    '[{"file":"docs/specs/wstory/wstory-01-alpha.md","story":"wstory-01","worker":"worker-code","model":"opus","repeat":1},{"file":"docs/specs/wstory/wstory-02-beta.md","story":"wstory-02","worker":"worker-test","model":"opus","repeat":3}]'

echo "status --json: an open round with missing seats"
rd1="$(mk_open_round status1 1)"
out2="$(council status docs/specs/status1 --json)"
printf '%s' "$out2" | jq -e '.open == true' >/dev/null 2>&1 || { echo "::error::open round not reported open: $out2"; fail=1; }
printf '%s' "$out2" | jq -e '.round == 1' >/dev/null 2>&1 || { echo "::error::round number wrong: $out2"; fail=1; }
printf '%s' "$out2" | jq -r '.missing | sort | join(",")' | expect "missing lists the tier 3-4 roster without a Client path (ADR-013 D1): opus, review" "opus,review"
printf '%s' "$out2" | jq -r .next | grep -qE '^dispatch:' && echo "  ok    next is dispatch:..." \
  || { echo "::error::next was $(printf '%s' "$out2" | jq -r .next), expected dispatch:..."; fail=1; }

echo "status --json: all four seats present -> judge"
write_seat "$rd1" haiku GGG
write_seat "$rd1" sonnet GGG
write_seat "$rd1" opus GGG
write_review "$rd1" PASS
printf '%s' "$(council status docs/specs/status1 --json)" | jq -r .next | expect "next is judge" "judge"

# --- C15: the council scales with tier (autonomous-cycle-18) ---------------------------------

echo "ADR-013 D1: Tier 1 requires review only - status missing/next, judge reaches GREEN on the one report"
mk_open_spec tier1a 3
set_tier tier1a 1
rdt1="$(mk_open_round tier1a 1)"
out="$(council status docs/specs/tier1a --json)"
printf '%s' "$out" | jq -r '.missing | join(",")' | expect "tier 1: missing lists only review" "review"
printf '%s' "$out" | jq -r .next | expect "tier 1: next is dispatch:review" "dispatch:review"
write_review "$rdt1" PASS
out="$(council status docs/specs/tier1a --json)"
printf '%s' "$out" | jq -r .next | expect "tier 1: next is judge after the one required seat" "judge"
jout="$(council judge docs/specs/tier1a)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    tier 1: judge GREEN on review alone" \
  || { echo "::error::tier1a judge: exit=$jex out=$jout"; fail=1; }
row="$(grep '"spec":"tier1a"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"na":0' && printf '%s' "$row" | grep -q '"verdict":"GREEN"' && printf '%s' "$row" | grep -q '"sonnet":""' \
  && echo "  ok    tier 1: row verdict GREEN, na:0, no blind seat asked (sonnet '', not ABSENT)" || { echo "::error::row: $row"; fail=1; }

echo "ADR-013 D1: Tier 2 requires review only - no blind seat at all"
mk_open_spec tier2a 3
set_tier tier2a 2
rdt2="$(mk_open_round tier2a 1)"
out="$(council status docs/specs/tier2a --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "tier 2: missing lists review - not sonnet, not haiku, not opus" "review"
write_seat "$rdt2" sonnet GGG   # an old-roster seat is still accepted and counted (record-seat keeps sonnet)
write_review "$rdt2" PASS
out="$(council status docs/specs/tier2a --json)"
printf '%s' "$out" | jq -r .next | expect "tier 2: next is judge without a haiku or opus seat" "judge"
write_seat "$rdt2" opus GGG   # a recorded non-required seat is still accepted and counted (ADR-002)
out="$(council status docs/specs/tier2a --json)"
printf '%s' "$out" | jq -r '.missing | length' | expect "tier 2: an extra opus report is accepted, missing stays empty" "0"
printf '%s' "$out" | jq -r .next | expect "tier 2: next is still judge with the extra seat" "judge"
jout="$(council judge docs/specs/tier2a)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    tier 2: judge GREEN without haiku" \
  || { echo "::error::tier2a judge: exit=$jex out=$jout"; fail=1; }

echo "ADR-013 D1: Tier 3 requires opus and review - haiku only with a filled Client path (this fixture has none), sonnet never"
mk_open_spec tier3a 3
set_tier tier3a 3
mk_round tier3a 1 >/dev/null
out="$(council status docs/specs/tier3a --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "tier 3: missing lists opus, review" "opus,review"

echo "C15: a plan.md without a parsable **Tier:** line -> status tier:null, still dispatches the tier 3-4 roster, never writes (R21/m-1)"
mk_open_spec tierdefault 3
mk_round tierdefault 1 >/dev/null
out="$(council status docs/specs/tierdefault --json)"
printf '%s' "$out" | jq -e '.tier == null' >/dev/null 2>&1 && echo "  ok    tier:null - no default, no silent 4 (R21)" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "no Tier line still dispatches the largest (safe) roster" "opus,review"
[ ! -f docs/specs/tierdefault/journal.md ] && echo "  ok    status never wrote journal.md (tier_of no longer journals, m-1)" \
  || { echo "::error::journal.md was created by a read-only status call: $(cat docs/specs/tierdefault/journal.md)"; fail=1; }

echo "open-round: an unparsable **Tier:** line refuses (exit 2, names the line) instead of buying the largest court (M-10/R21)"
mk_spec notier1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/notier1#' docs/specs/notier1/plan.md
git add -A && git commit -qm "notier1: branch, Tier line left as the template placeholder" >/dev/null
out="$(council open-round docs/specs/notier1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'tier' && echo "  ok    unparsable Tier line -> exit 2, error names Tier" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -d docs/specs/notier1/council/round-1 ] && echo "  ok    no round was opened" \
  || { echo "::error::round-1 exists despite the refusal"; fail=1; }

# --- judge: unanimous green -------------------------------------------------------------------

echo "judge: GGGGGGG x3, review PASS -> GREEN"
jout="$(council judge docs/specs/status1)"; jexit=$?
[ "$jexit" -eq 0 ] || { echo "::error::judge (green) exited $jexit, expected 0"; fail=1; }
# C5 (driver-hardening-03): the exit-0 line keeps its four keys in order and now appends the
# post-verb status object last - the needle below is the whole line up to that appended key.
printf '%s\n' "$jout" | tail -1 | expect "last stdout line is the JSON contract" '{"ok":true,"verb":"judge","exit":0,"next":"green","status":{'
row="$(grep '"spec":"status1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"verdict":"GREEN"' && echo "  ok    row verdict GREEN" || { echo "::error::row: $row"; fail=1; }
keys="$(printf '%s' "$row" | grep -oE '"[a-z_]+":' | tr -d '":' | tr '\n' ',')"
[ "$keys" = "ts,spec,round,verdict,head,pack,asks,red,red_unevidenced,review_asks,na,review,haiku,haiku_model,sonnet,sonnet_model,opus,opus_model,attempts,escalate,note," ] \
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
[ "$jexit" -eq 0 ] || { echo "::error::judge (red) exited $jexit, expected 0 (R24: RED is a successful judgement)"; fail=1; }
printf '%s' "$jout" | expect "next is repair" '"next":"repair"'
printf '%s' "$jout" | grep -qF '{"ok":true,"verb":"judge","exit":0,"next":"repair","status":{' \
  && echo "  ok    RED judge output shape: ok:true, exit:0, next:repair (R24)" || { echo "::error::jout: $jout"; fail=1; }
row="$(grep '"spec":"red1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"verdict":"RED"' && printf '%s' "$row" | grep -q '"red":\[2\]' \
  && echo "  ok    row verdict RED, red:[2]" || { echo "::error::row: $row"; fail=1; }
grep -qE '^\*\*Council:\*\* RED round 1,.* - red: 2$' docs/specs/red1/plan.md && echo "  ok    plan line ends '- red: 2'" \
  || { echo "::error::plan.md: $(grep '^\*\*Council:\*\*' docs/specs/red1/plan.md)"; fail=1; }

if full; then # --quick skips: the anchored-BLOCK variants, the multi-round ceiling, no-progress and half walks
# --- judge: an anchored review BLOCK (convergent-judge-02, D4) ------------------------------

write_review_body() { # write_review_body <round-dir> <body...> - a BLOCK review with a given finding line
  local rd="$1" n="${1##*/round-}"; shift
  {
    printf '<!-- seat: review \xc2\xb7 model: test \xc2\xb7 round: %s \xc2\xb7 head: %s \xc2\xb7 pack: demo-pack \xc2\xb7 attempt: 1 \xc2\xb7 recorded: 2020-01-01T00:00:01Z -->\n' "$n" "$HEAD7"
    printf 'VERDICT: BLOCK\n'
    printf '%s\n' "$@"
  } > "$rd/review.md"
}

echo "judge: review BLOCK anchored [ask 2], seats GREEN -> RED/repair, review_asks:[2]"
mk_spec anch1 3
rd="$(mk_round anch1 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' '- major [ask 2]: the guard on line 40 is missing'
jout="$(council judge docs/specs/anch1)"; jexit=$?
[ "$jexit" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    anchored BLOCK -> next repair" \
  || { echo "::error::anch1 judge: exit=$jexit out=$jout"; fail=1; }
row="$(grep '"spec":"anch1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"verdict":"RED"' && printf '%s' "$row" | grep -qF '"red_unevidenced":[],"review_asks":[2],' \
  && printf '%s' "$row" | grep -qF '"review":"BLOCK"' && echo "  ok    row RED, review BLOCK, review_asks:[2] after red_unevidenced" \
  || { echo "::error::row: $row"; fail=1; }

echo "judge: review BLOCK anchored [regression] only -> RED/repair, review_asks:[]"
mk_spec anchreg 3
rd="$(mk_round anchreg 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Critical' '- critical [regression]: base passes t.sh, head fails it'
jout="$(council judge docs/specs/anchreg)"; jexit=$?
row="$(grep '"spec":"anchreg"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"RED"' && printf '%s' "$row" | grep -qF '"review_asks":[]' \
  && echo "  ok    [regression] holds the BLOCK" || { echo "::error::anchreg: exit=$jexit row=$row"; fail=1; }

# convergent-judge-05: a tag anchors only on a list line under a critical/major heading.
echo "judge: [regression] in prose under ## Major does not anchor -> GREEN, unanchored"
mk_spec anchprose 3
rd="$(mk_round anchprose 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' 'No [regression] found - base and head both pass t.sh.' '- major [unanchored]: naming is confusing'
jout="$(council judge docs/specs/anchprose)"; jexit=$?
row="$(grep '"spec":"anchprose"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"note":"review BLOCK unanchored"' \
  && echo "  ok    prose [regression] under ## Major is not an anchor" || { echo "::error::anchprose: exit=$jexit row=$row"; fail=1; }

echo "judge: [ask 2] on a ## Minor list line does not anchor -> GREEN, unanchored"
mk_spec anchminor 3
rd="$(mk_round anchminor 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' '- major [unanchored]: naming is confusing' '## Minor' '- minor [ask 2]: a nit on the guard'
jout="$(council judge docs/specs/anchminor)"; jexit=$?
row="$(grep '"spec":"anchminor"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"review_asks":[]' \
  && printf '%s' "$row" | grep -qF '"note":"review BLOCK unanchored"' \
  && echo "  ok    [ask 2] on a ## Minor line is not an anchor" || { echo "::error::anchminor: exit=$jexit row=$row"; fail=1; }

echo "judge: [ask 2] on a numbered ## major (lower-case) list line still anchors -> RED, review_asks:[2]"
mk_spec anchnum 3
rd="$(mk_round anchnum 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## major' '1. `x.sh:4` - [ask 2] - the guard is missing' '## Minor' '- minor [ask 3]: nit'
jout="$(council judge docs/specs/anchnum)"; jexit=$?
row="$(grep '"spec":"anchnum"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"RED"' && printf '%s' "$row" | grep -qF '"review_asks":[2],' \
  && echo "  ok    numbered ## major list line anchors [ask 2] only" || { echo "::error::anchnum: exit=$jexit row=$row"; fail=1; }

echo "judge: review BLOCK unanchored, seats GREEN -> GREEN, review PASS, note names it"
mk_spec unanch1 3
rd="$(mk_round unanch1 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' '- major [unanchored]: naming of the helper is confusing'
jout="$(council judge docs/specs/unanch1)"; jexit=$?
[ "$jexit" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    unanchored BLOCK -> next green" \
  || { echo "::error::unanch1 judge: exit=$jexit out=$jout"; fail=1; }
row="$(grep '"spec":"unanch1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"review":"PASS"' \
  && printf '%s' "$row" | grep -qF '"review_asks":[]' && printf '%s' "$row" | grep -qF '"note":"review BLOCK unanchored"' \
  && echo "  ok    row GREEN, review PASS, review_asks:[], note 'review BLOCK unanchored'" || { echo "::error::row: $row"; fail=1; }

echo "judge: review BLOCK tagged [ask 9] on a 3-ask brief -> unanchored -> GREEN"
mk_spec unanch9 3
rd="$(mk_round unanch9 1)"
write_seat "$rd" haiku GGG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' '- major [ask 9]: out of range' '- major [ask 0]: also out of range'
jout="$(council judge docs/specs/unanch9)"; jexit=$?
row="$(grep '"spec":"unanch9"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"review_asks":[]' \
  && printf '%s' "$row" | grep -qF '"note":"review BLOCK unanchored"' \
  && echo "  ok    out-of-range [ask 9] / [ask 0] count as unanchored" || { echo "::error::unanch9: exit=$jexit row=$row"; fail=1; }

echo "judge: unanchored BLOCK does not mask a seat RED -> still RED"
mk_spec unanchr 3
rd="$(mk_round unanchr 1)"
write_seat "$rd" haiku GRG; write_seat "$rd" sonnet GGG; write_seat "$rd" opus GGG
write_review_body "$rd" '## Major' '- major [unanchored]: no anchor at all' # convergent-judge-07: tagged, record-seat's shape
jout="$(council judge docs/specs/unanchr)"; jexit=$?
row="$(grep '"spec":"unanchr"' memory/stats/council.jsonl | tail -1)"
[ "$jexit" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"RED"' && printf '%s' "$row" | grep -qF '"review":"PASS"' \
  && echo "  ok    seat RED still repairs; review recorded PASS" || { echo "::error::unanchr: exit=$jexit row=$row"; fail=1; }

echo "status: an older row without review_asks still parses"
mk_open_spec oldrow1 2
printf '{"ts":"2020-01-01T00:00:00Z","spec":"oldrow1","round":1,"verdict":"GREEN","head":"%s","pack":"demo-pack","asks":2,"red":[],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"GREEN","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":4,"escalate":null,"note":""}\n' \
  "$HEAD7" >> memory/stats/council.jsonl
out="$(council status docs/specs/oldrow1 --json)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | jq -e '.review == "PASS"' >/dev/null 2>&1 \
  && echo "  ok    status reads a pre-review_asks row" || { echo "::error::oldrow1: exit=$ex out=$out"; fail=1; }

# --- judge: three RED rounds hit the ceiling on the third -------------------------------------

echo "judge: three RED rounds (a different ask each) escalate (ceiling) on the third, not the second"
mk_spec ceil1 5
rd1c="$(mk_round ceil1 1 3)"
write_seat "$rd1c" haiku RGGGG; write_seat "$rd1c" sonnet GGGGG; write_seat "$rd1c" opus GGGGG; write_review "$rd1c" PASS
out1="$(council judge docs/specs/ceil1)"; ex1=$?
[ "$ex1" -eq 0 ] && printf '%s' "$out1" | grep -qF '"next":"repair"' && echo "  ok    round 1: RED, repair" \
  || { echo "::error::round 1: exit=$ex1 out=$out1"; fail=1; }

rd2c="$(mk_round ceil1 2 3)"
write_seat "$rd2c" haiku GRGGG; write_seat "$rd2c" sonnet GGGGG; write_seat "$rd2c" opus GGGGG; write_review "$rd2c" PASS
out2="$(council judge docs/specs/ceil1)"; ex2=$?
[ "$ex2" -eq 0 ] && printf '%s' "$out2" | grep -qF '"next":"repair"' && echo "  ok    round 2: RED, still repair - no ceiling yet" \
  || { echo "::error::round 2: exit=$ex2 out=$out2"; fail=1; }

rd3c="$(mk_round ceil1 3 3)"
write_seat "$rd3c" haiku GGRGG; write_seat "$rd3c" sonnet GGGGG; write_seat "$rd3c" opus GGGGG; write_review "$rd3c" PASS
out3="$(council judge docs/specs/ceil1)"; ex3=$?
[ "$ex3" -eq 6 ] && printf '%s' "$out3" | grep -qF '"next":"escalated"' && echo "  ok    round 3: ceiling reached, ESCALATE" \
  || { echo "::error::round 3: exit=$ex3 out=$out3"; fail=1; }
row3="$(grep '"spec":"ceil1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row3" | grep -q '"escalate":"ceiling"' && echo "  ok    row escalate:ceiling" || { echo "::error::row3: $row3"; fail=1; }
grep -q '^## Needs a human' docs/specs/ceil1/plan.md && grep -qF 'reason: ceiling · round 3' docs/specs/ceil1/plan.md \
  && echo "  ok    ## Needs a human names ceiling, round 3" || { echo "::error::plan.md missing/wrong Needs a human section"; fail=1; }

# --- judge: the same ask RED two rounds running escalates no-progress (convergent-judge-04) ----

echo "judge: ask 3 RED in rounds 1 and 2 -> round 2 ESCALATE no-progress (ceiling 3)"
mk_open_spec noprog1 5
rd="$(mk_round noprog1 1 3)"
write_seat "$rd" haiku GGRGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG; write_review "$rd" PASS
out="$(council judge docs/specs/noprog1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    round 1: RED, repair"   || { echo "::error::noprog1 round 1: exit=$ex out=$out"; fail=1; }
rd="$(mk_round noprog1 2 3)"
write_seat "$rd" haiku GGRGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG; write_review "$rd" PASS
out="$(council judge docs/specs/noprog1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    round 2: ESCALATE, next escalated"   || { echo "::error::noprog1 round 2: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"noprog1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"round":2,"verdict":"ESCALATE"' && printf '%s' "$row" | grep -qF '"escalate":"no-progress"'   && echo "  ok    row escalate:no-progress" || { echo "::error::noprog1 row: $row"; fail=1; }
grep -qF 'reason: no-progress · round 2' docs/specs/noprog1/plan.md && grep -qF -- '- no progress: ask 3 RED in rounds 1 and 2' docs/specs/noprog1/plan.md   && echo "  ok    ## Needs a human names no-progress and ask 3" || { echo "::error::noprog1 plan: $(sed -n '/## Needs a human/,$p' docs/specs/noprog1/plan.md)"; fail=1; }
out="$(council status docs/specs/noprog1 --json)"
printf '%s' "$out" | jq -e '.next == "escalated"' >/dev/null 2>&1 && echo "  ok    status next escalated"   || { echo "::error::noprog1 status: $out"; fail=1; }

echo "judge: ask 2 RED then ask 5 RED -> round 2 RED/repair, no trigger"
mk_spec noprog2 5
rd="$(mk_round noprog2 1 3)"
write_seat "$rd" haiku GRGGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG; write_review "$rd" PASS
council judge docs/specs/noprog2 >/dev/null
rd="$(mk_round noprog2 2 3)"
write_seat "$rd" haiku GGGGR; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG; write_review "$rd" PASS
out="$(council judge docs/specs/noprog2)"; ex=$?
row="$(grep '"spec":"noprog2"' memory/stats/council.jsonl | tail -1)"
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && printf '%s' "$row" | grep -qF '"round":2,"verdict":"RED"'   && echo "  ok    different asks: RED, repair" || { echo "::error::noprog2: exit=$ex row=$row"; fail=1; }

echo "judge: round N-1 STALE with ask 3 -> round 2 RED/repair, no trigger"
mk_spec noprog3 5
printf '{"ts":"2020-01-01T00:00:00Z","spec":"noprog3","round":1,"verdict":"STALE","head":"%s","pack":"demo-pack","asks":5,"red":[3],"red_unevidenced":[],"review_asks":[3],"na":0,"review":"ABSENT","haiku":"ABSENT","haiku_model":"m","sonnet":"ABSENT","sonnet_model":"m","opus":"ABSENT","opus_model":"m","attempts":1,"escalate":null,"note":"code moved after dispatch"}
'   "$HEAD7" >> memory/stats/council.jsonl
rd="$(mk_round noprog3 2 3)"
write_seat "$rd" haiku GGRGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG; write_review "$rd" PASS
out="$(council judge docs/specs/noprog3)"; ex=$?
row="$(grep '"spec":"noprog3"' memory/stats/council.jsonl | tail -1)"
[ "$ex" -eq 0 ] && printf '%s' "$row" | grep -qF '"round":2,"verdict":"RED"'   && echo "  ok    STALE N-1 never triggers" || { echo "::error::noprog3: exit=$ex row=$row"; fail=1; }

echo "judge: review [ask 4] BLOCK in rounds 1 and 2, seats GREEN -> round 2 ESCALATE no-progress"
mk_spec noprog4 5
rd="$(mk_round noprog4 1 3)"
write_seat "$rd" haiku GGGGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG
write_review_body "$rd" '## Major' '- major [ask 4]: the guard is missing'
council judge docs/specs/noprog4 >/dev/null
rd="$(mk_round noprog4 2 3)"
write_seat "$rd" haiku GGGGG; write_seat "$rd" sonnet GGGGG; write_seat "$rd" opus GGGGG
write_review_body "$rd" '## Major' '- major [ask 4]: the guard is still missing'
out="$(council judge docs/specs/noprog4)"; ex=$?
row="$(grep '"spec":"noprog4"' memory/stats/council.jsonl | tail -1)"
[ "$ex" -eq 6 ] && printf '%s' "$row" | grep -qF '"round":2,"verdict":"ESCALATE"' && printf '%s' "$row" | grep -qF '"escalate":"no-progress"'   && grep -qF -- '- no progress: ask 4 RED in rounds 1 and 2' docs/specs/noprog4/plan.md   && echo "  ok    review-anchored repeat triggers no-progress" || { echo "::error::noprog4: exit=$ex row=$row"; fail=1; }

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

echo "judge: half floor = max(2, ceil(A/2)) - a 1-ask brief's one evidenced RED repairs, never escalates (R10)"
mk_spec halffloor1 1
rdf1="$(mk_round halffloor1 1 3)"
write_seat "$rdf1" haiku R
write_seat "$rdf1" sonnet G
write_seat "$rdf1" opus G
write_review "$rdf1" PASS
out="$(council judge docs/specs/halffloor1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    A=1: one evidenced RED repairs, not escalate" \
  || { echo "::error::A=1: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"halffloor1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":null' && echo "  ok    A=1 row escalate:null" || { echo "::error::row: $row"; fail=1; }

echo "judge: half floor - a 2-ask brief needs BOTH asks RED to escalate, not just one (R10)"
mk_spec halffloor2 2
rdf2a="$(mk_round halffloor2 1 3)"
write_seat "$rdf2a" haiku RG
write_seat "$rdf2a" sonnet GG
write_seat "$rdf2a" opus GG
write_review "$rdf2a" PASS
out="$(council judge docs/specs/halffloor2)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    A=2: one of two RED repairs" \
  || { echo "::error::A=2 one-red: exit=$ex out=$out"; fail=1; }

mk_spec halffloor2b 2
rdf2b="$(mk_round halffloor2b 1 3)"
write_seat "$rdf2b" haiku RR
write_seat "$rdf2b" sonnet GG
write_seat "$rdf2b" opus GG
write_review "$rdf2b" PASS
out="$(council judge docs/specs/halffloor2b)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    A=2: both asks RED escalates half" \
  || { echo "::error::A=2 both-red: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"halffloor2b"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":"half"' && echo "  ok    A=2 both-red row escalate:half" || { echo "::error::row: $row"; fail=1; }

fi # --quick: end of the judge-variant skip
# --- judge: three ABSENT seats -------------------------------------------------------------------

echo "judge: every blind seat exhausted -> ESCALATE env; only the required one (opus) is ABSENT in the row"
mk_spec env1 3
rde="$(mk_round env1 1 3)"
write_absent "$rde" haiku
write_absent "$rde" sonnet
write_absent "$rde" opus
write_review "$rde" PASS
out="$(council judge docs/specs/env1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    the required seat ABSENT escalates" \
  || { echo "::error::env test: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"env1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -q '"escalate":"env"' && printf '%s' "$row" | grep -q '"opus":"ABSENT"' && printf '%s' "$row" | grep -q '"haiku":""' \
  && echo "  ok    row escalate:env, opus ABSENT, haiku '' (not required, ADR-013 D1)" || { echo "::error::row: $row"; fail=1; }

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
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    owner REJECTED overrides all-GREEN seats" \
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

if full; then # --quick skips: the R17 git-failure proofs (index.lock, a checked-out branch, a failed worktree add)
# --- git failures are never swallowed into a false success (R17/M-6) -------------------------

echo "branch: checkout fails (branch already checked out in another worktree) -> exit 2, no **Branch:** line (R17/M-6)"
mk_spec branchfail1 1
council briefed docs/specs/branchfail1 >/dev/null
git branch vulyk/branchfail1 >/dev/null
git worktree add -q "$T-wt" vulyk/branchfail1 >/dev/null 2>&1
out="$(council branch docs/specs/branchfail1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'checkout' && echo "  ok    checkout failure -> exit 2, error names checkout" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qF '**Branch:** vulyk/branchfail1' docs/specs/branchfail1/plan.md && { echo "::error::a Branch line was written despite the failed checkout"; fail=1; } \
  || echo "  ok    no **Branch:** line was written (the template placeholder is untouched)"
git worktree remove --force "$T-wt" >/dev/null 2>&1
git branch -D vulyk/branchfail1 >/dev/null 2>&1

echo "git failures: a --commit whose git commit fails (index.lock present) -> exit 2 naming git commit, paperwork stays on disk, re-run after unlocking commits it (R17/M-6)"
mk_spec lockfail1 1
touch .git/index.lock
out="$(council briefed docs/specs/lockfail1 --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'git commit' && echo "  ok    locked index -> exit 2, error names git commit" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qE '^\*\*Briefed:\*\* via grill,' docs/specs/lockfail1/plan.md && echo "  ok    the Briefed line is still on disk, uncommitted" \
  || { echo "::error::plan.md: $(cat docs/specs/lockfail1/plan.md)"; fail=1; }
[ -n "$(git status --porcelain -- docs/specs/lockfail1)" ] && echo "  ok    the tree is dirty (paperwork not committed)" \
  || { echo "::error::tree unexpectedly clean"; fail=1; }
rm -f .git/index.lock
out="$(council briefed docs/specs/lockfail1 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    re-run after unlocking succeeds" || { echo "::error::exit=$ex out=$out"; fail=1; }
git log -1 --format=%s | grep -qF 'vulyk(lockfail1): briefed' && echo "  ok    the re-run committed the paperwork" \
  || { echo "::error::$(git log -1 --format=%s)"; fail=1; }

echo "open-round: leaves no ROUND file when git worktree add fails (R17/M-6) - ROUND is written last"
mk_open_spec wtfail1 2
set_tier wtfail1 3
# clean_court() rm -rf's .vulyk/court/<slug>/ before every attempt, so a file planted there
# directly would just be swept away - plant the blocker one level up, at .vulyk/court itself
# (a plain file instead of a directory), so mkdir -p (then worktree add) fails underneath it.
mkdir -p .vulyk
touch .vulyk/court
out="$(council open-round docs/specs/wtfail1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'worktree' && echo "  ok    worktree add failure -> exit 2" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -d docs/specs/wtfail1/council/round-1 ] && echo "  ok    no round-1 directory (and no ROUND file) was left behind" \
  || { echo "::error::round-1 exists despite the worktree failure: $(ls docs/specs/wtfail1/council/round-1 2>&1)"; fail=1; }
rm -f .vulyk/court

fi # --quick: end of the git-failure skip
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
set_tier pwseat1 3
council open-round docs/specs/pwseat1 --commit >/dev/null   # open-round's own commit moves HEAD
rdpw1="docs/specs/pwseat1/council/round-1"
out="$(seat_report opus 1 GGG | council record-seat docs/specs/pwseat1 1 opus)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:review"' && echo "  ok    record-seat right after open-round --commit is not stale" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rdpw1/opus.md" ] && echo "  ok    opus.md written at attempt 1" || { echo "::error::missing $rdpw1/opus.md"; fail=1; }
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == false' >/dev/null 2>&1 && echo "  ok    status --json stale:false right after open-round's own commit" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -r .next | grep -qE '^dispatch:' && echo "  ok    next still lists the missing seats" \
  || { echo "::error::next was $(printf '%s' "$out" | jq -r .next)"; fail=1; }

echo "record-seat: still NOT stale after a further paperwork-only commit (a driver committing council/*)"
git add -- "$rdpw1/opus.md" && git commit -qm "vulyk(pwseat1): record-seat opus round 1" >/dev/null
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == false' >/dev/null 2>&1 && echo "  ok    status --json stale:false after a paperwork-only commit" \
  || { echo "::error::status: $out"; fail=1; }

echo "record-seat: still NOT stale after a commit touching only skills.json + memory/learnings/*.md (C2)"
mkdir -p memory/learnings
echo '{"x":1}' > memory/stats/skills.json
echo 'note' > memory/learnings/2026-09-15-pwseat1.md
git add -- memory/stats/skills.json memory/learnings/2026-09-15-pwseat1.md && git commit -qm "hook writes: skills.json, learnings" >/dev/null
out="$(council status docs/specs/pwseat1 --json)"
printf '%s' "$out" | jq -e '.stale == false' >/dev/null 2>&1 && echo "  ok    status --json stale:false after a skills.json + learnings-only commit" \
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

if full; then # --quick skips: the taint battery and the evidence re-ask rules
echo "record-seat: taint is path-anchored on the slug, not the bare words (R9)"
mk_spec demo 2
rd_demo1="$(mk_open_round demo 1)"
report_taint() { # report_taint <phrase>
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - %s - run: c saw: ok\nASK 2: GREEN - a - run: c saw: ok\n' "$1"
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_taint 'looked at demo-01' | council record-seat docs/specs/demo 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    bare <slug>-NN (demo-01) in body -> accepted, not tainted (C4: synthesized id)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'checked plan.md' | council record-seat docs/specs/demo 1 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    bare plan.md (no slug prefix) -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'checked journal.md' | council record-seat docs/specs/demo 1 opus 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    bare journal.md (no slug prefix) -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo2="$(mk_open_round demo 2)"
out="$(report_taint 'looked under council/' | council record-seat docs/specs/demo 2 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    bare council/ (no slug prefix) -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'read demo/plan.md for context' | council record-seat docs/specs/demo 2 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>/plan.md -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'read demo/journal.md for context' | council record-seat docs/specs/demo 2 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>/journal.md -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo3="$(mk_open_round demo 3)"
out="$(report_taint 'looked under demo/council/round-1' | council record-seat docs/specs/demo 3 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>/council/ -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'read docs/specs/demo/plan.md for context' | council record-seat docs/specs/demo 3 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    docs/specs/<slug>/plan.md -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'saw demo-1 mentioned once' | council record-seat docs/specs/demo 3 opus 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    <slug>-N (one digit) -> accepted, not tainted (needs two digits)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo4="$(mk_open_round demo 4)"
out="$(report_taint 'per vulyk-plan.md step 9' | council record-seat docs/specs/demo 4 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    vulyk-plan.md (command file) -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'journal.sh appends to <spec>/journal.md' | council record-seat docs/specs/demo 4 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    literal <spec>/journal.md placeholder -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'compare docs/specs/other/plan.md' | council record-seat docs/specs/demo 4 opus 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    another spec's docs/specs/other/plan.md -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo5="$(mk_open_round demo 5)"
out="$(report_taint 'read demo-01.md for context' | council record-seat docs/specs/demo 5 haiku 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>-NN.md (demo-01.md) -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'looked under demo/demo-14 for context' | council record-seat docs/specs/demo 5 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>/<slug>-NN (demo/demo-14) -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'read docs/specs/demo/demo-14.md for context' | council record-seat docs/specs/demo 5 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    docs/specs/<slug>/<slug>-NN.md -> tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo6="$(mk_open_round demo 6)"
report_round6() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - checked the recorder - run: bash scripts/telemetry.sh record x 1 0 --story demo-14 saw: {"story":"demo-14"}\n'
  printf 'ASK 2: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_round6 | council record-seat docs/specs/demo 6 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    round-6 shape (bare id in a run: and a saw: JSON echo) -> accepted, not tainted" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
# C4 revised (Major 1): every story file in the repo is <slug>-NN-<title>.md, not <slug>-NN.md.
out="$(report_taint 'read demo-14-title.md for context' | council record-seat docs/specs/demo 6 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    <slug>-NN-<title>.md (demo-14-title.md, the repo's real shape) -> tainted (C4 revised)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'read docs/specs/demo/demo-14-title.md for context' | council record-seat docs/specs/demo 6 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    docs/specs/<slug>/<slug>-NN-<title>.md -> tainted (C4 revised)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_demo7="$(mk_open_round demo 7)"
out="$(report_taint 'the story is demo-14-title, no suffix' | council record-seat docs/specs/demo 7 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    <slug>-NN-<title> without .md -> accepted, not tainted (C4 revised)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(report_taint 'the story is demo-14' | council record-seat docs/specs/demo 7 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    a bare <slug>-NN stays clean under the revised pattern (C4 revised)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: the live round-1 false positives no longer taint under the real slug (R9 live proof)"
mk_spec autonomous-cycle 2
rd_ac1="$(mk_open_round autonomous-cycle 1)"
report_ac_fp() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - mini-grill only, then no wait to commit - url: .claude/commands/vulyk-plan.md:16 saw: "there is no wait here"\n'
  printf 'ASK 2: GREEN - journal on disk + terminal - run: cat scripts/journal.sh saw: appends one line to `<spec>/journal.md`\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_ac_fp | council record-seat docs/specs/autonomous-cycle 1 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    vulyk-plan.md and <spec>/journal.md text accepted, not tainted (R9)" \
  || { echo "::error::live-proof accept: exit=$ex out=$out"; fail=1; }

rd_ac2="$(mk_open_round autonomous-cycle 2)"
report_ac_real() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - read the plan - run: cat docs/specs/autonomous-cycle/plan.md saw: Tier 4\nASK 2: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_ac_real | council record-seat docs/specs/autonomous-cycle 2 sonnet 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    a real hive path (docs/specs/autonomous-cycle/plan.md) still tainted" \
  || { echo "::error::live-proof reject: exit=$ex out=$out"; fail=1; }

rd_ac3="$(mk_open_round autonomous-cycle 3)"
report_ac_storyid() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - read story 07 - run: cat docs/specs/autonomous-cycle/autonomous-cycle-07-x.md saw: story text\nASK 2: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_ac_storyid | council record-seat docs/specs/autonomous-cycle 3 opus 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'tainted' && echo "  ok    a real story file (autonomous-cycle/autonomous-cycle-07-x.md) still tainted" \
  || { echo "::error::live-proof storyid reject: exit=$ex out=$out"; fail=1; }

rd_ac4="$(mk_open_round autonomous-cycle 4)"
report_ac_bareid() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - read story 07 - run: cat docs/specs/autonomous-cycle-07-*.md saw: story text\nASK 2: GREEN - a - run: c saw: ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_ac_bareid | council record-seat docs/specs/autonomous-cycle 4 haiku 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    a bare story id glob (autonomous-cycle-07-*.md, no <slug>/ prefix, no literal .md) -> accepted, not tainted (C4)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "record-seat: evidence with an interior ' - ' inside saw: is not truncated (R8)"
mk_spec dashev 2
rd_dashev="$(mk_open_round dashev 1)"
report_dash_evidence() {
  printf 'COUNCIL: x\nMODEL: t\nCOURT: /x\nVERDICT: GREEN\nASSUMED CONFIG: none given\nRAN: nothing\nPATH: none named\n'
  printf 'ASK 1: GREEN - ask one - run: c saw: ok\nASK 2: GREEN - suite - run: bash t.sh saw: READY - 6/6 ok\n'
  printf 'UNASKED: none\nBREACH: none\n'
}
out="$(report_dash_evidence | council record-seat docs/specs/dashev 1 haiku)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    accepted at attempt 1 despite an interior ' - ' inside saw:" \
  || { echo "::error::dashev record-seat: exit=$ex out=$out"; fail=1; }
grep -qF 'unevidenced' "$rd_dashev/haiku.md" && { echo "::error::header wrongly carries unevidenced: $(head -1 "$rd_dashev/haiku.md")"; fail=1; } \
  || echo "  ok    header carries no unevidenced list"
write_seat "$rd_dashev" sonnet GG
write_seat "$rd_dashev" opus GG
printf 'VERDICT: PASS\nReviewed.\n' | council record-seat docs/specs/dashev 1 review >/dev/null
jout="$(council judge docs/specs/dashev)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    judged GREEN (not downgraded by the interior dash)" \
  || { echo "::error::dashev judge: exit=$jex out=$jout"; fail=1; }
row="$(grep '"spec":"dashev"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"red_unevidenced":[]' && echo "  ok    row red_unevidenced:[] agrees with the header (R8)" \
  || { echo "::error::row: $row"; fail=1; }

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
printf 'VERDICT: PASS\nReviewed.\n' | council record-seat docs/specs/runev 1 review >/dev/null
jout="$(council judge docs/specs/runev)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    judge: RED (not escalated by an unevidenced-only red)" \
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

fi # --quick: end of the taint/evidence skip
# --- record-seat: review seat, verdict read from line 1 only (C5 amended, story 27/R28,N-m4) --

echo "record-seat review: VERDICT: BLOCK on line 1 -> recorded BLOCK"
mk_spec rrev 2
rd_rrev="$(mk_open_round rrev 1)"
out="$(printf 'VERDICT: BLOCK\n## Major\n- x.sh:40 [ask 1] worker - the guard on line 40 must exist\n' | council record-seat docs/specs/rrev 1 review)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    VERDICT: BLOCK on line 1 -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qF 'verdict: BLOCK' "$rd_rrev/review.md" && echo "  ok    header carries verdict: BLOCK" \
  || { echo "::error::$(head -1 "$rd_rrev/review.md")"; fail=1; }

echo "record-seat review: VERDICT: PASS on line 1 wins over a distracting BLOCK later in the body"
mk_spec rrevb 2
rd_rrevb="$(mk_open_round rrevb 1)"
out="$(printf 'VERDICT: PASS\nPASS/BLOCK decision: BLOCK\n' | council record-seat docs/specs/rrevb 1 review)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    VERDICT: PASS on line 1 -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qF 'verdict: PASS' "$rd_rrevb/review.md" && echo "  ok    header carries verdict: PASS - the body's BLOCK token is not read" \
  || { echo "::error::$(head -1 "$rd_rrevb/review.md")"; fail=1; }

echo "record-seat review: a prose first line is MALFORMED even with VERDICT: PASS on line 3, attempt-1.md kept; a second rejection (the driver's NO VERDICT fold shape) -> attempt-2.md, review ABSENT, ESCALATE env (the envpartial2 shape)"
mk_open_spec rrev3 2
set_tier rrev3 3
rd_rrev3="$(mk_open_round rrev3 1 3)"
out="$(printf 'Prose first line, no token.\nsecond line.\nVERDICT: PASS\n' | council record-seat docs/specs/rrev3 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'MALFORMED: review: first line is not VERDICT: PASS|BLOCK' \
  && echo "  ok    prose first line with VERDICT: PASS on line 3 -> exit 4" || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rd_rrev3/review.attempt-1.md" ] && grep -qF 'VERDICT: PASS' "$rd_rrev3/review.attempt-1.md" \
  && echo "  ok    attempt-1.md keeps the rejected report" || { echo "::error::files: $(ls "$rd_rrev3")"; fail=1; }

out="$(printf 'NO VERDICT: top=(no report) \xc2\xb7 second=VERDICT: PASS\n(no report)\nVERDICT: PASS\n' | council record-seat docs/specs/rrev3 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'MALFORMED' && echo "  ok    the driver's NO VERDICT fold first line is also MALFORMED (second rejection)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f "$rd_rrev3/review.attempt-2.md" ] && [ ! -f "$rd_rrev3/review.md" ] && echo "  ok    attempt-2.md written, no review.md - review is ABSENT" \
  || { echo "::error::files: $(ls "$rd_rrev3")"; fail=1; }

out="$(council status docs/specs/rrev3 --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "status: missing excludes the exhausted review seat" "opus"

write_seat "$rd_rrev3" haiku GG
write_seat "$rd_rrev3" sonnet GG
write_seat "$rd_rrev3" opus GG
out="$(council judge docs/specs/rrev3)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    review exhausted (ABSENT) with every other seat GREEN -> ESCALATE env" \
  || { echo "::error::rrev3: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"rrev3"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":"env"' && printf '%s' "$row" | grep -qF '"review":"ABSENT"' \
  && echo "  ok    row escalate:env, review ABSENT" || { echo "::error::row: $row"; fail=1; }

if full; then # --quick skips: the review layout variants
# --- review layout at record-seat (convergent-judge-07): a BLOCK needs a tagged finding line --
# (plan ## Contracts: review.md finding line) - otherwise MALFORMED, exit 4, re-asked once.

echo "record-seat review layout: [ask 2] under **Major** (bold, not H2) -> exit 4, attempt-1 kept, no review.md"
mk_open_spec rlaybold 3
set_tier rlaybold 2
rd_rl="$(mk_open_round rlaybold 1)"
out="$(printf 'VERDICT: BLOCK\n**Major**\n- major [ask 2]: the guard on line 40 is missing\n' | council record-seat docs/specs/rlaybold 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'MALFORMED: review: BLOCK has no tagged finding' \
  && [ -f "$rd_rl/review.attempt-1.md" ] && [ ! -f "$rd_rl/review.md" ] \
  && echo "  ok    **Major** heading -> exit 4, review.attempt-1.md, no review.md" \
  || { echo "::error::rlaybold: exit=$ex out=$out files=$(ls "$rd_rl")"; fail=1; }
out="$(printf 'VERDICT: BLOCK\n### Major\n- major [ask 2]: still the same layout\n' | council record-seat docs/specs/rlaybold 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ -f "$rd_rl/review.attempt-2.md" ] && [ ! -f "$rd_rl/review.md" ] \
  && echo "  ok    second bad layout (### Major) -> exit 4, attempt-2.md, review ABSENT (two-attempt rule)" \
  || { echo "::error::rlaybold attempt 2: exit=$ex out=$out files=$(ls "$rd_rl")"; fail=1; }

echo "record-seat review layout: the same [ask 2] under ## Major -> accepted, judge RED, review_asks:[2]"
mk_open_spec rlayh2 3
set_tier rlayh2 2
rd_rl="$(mk_open_round rlayh2 1)"
out="$(printf 'VERDICT: BLOCK\n## Major\n- major [ask 2]: the guard on line 40 is missing\n' | council record-seat docs/specs/rlayh2 1 review 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f "$rd_rl/review.md" ] && echo "  ok    ## Major list line tagged [ask 2] -> exit 0" \
  || { echo "::error::rlayh2 record: exit=$ex out=$out"; fail=1; }
write_seat "$rd_rl" sonnet GGG
jout="$(council judge docs/specs/rlayh2)"; jex=$?
row="$(grep '"spec":"rlayh2"' memory/stats/council.jsonl | tail -1)"
[ "$jex" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"RED"' && printf '%s' "$row" | grep -qF '"review_asks":[2],' \
  && echo "  ok    judge -> RED, review_asks:[2]" || { echo "::error::rlayh2 judge: exit=$jex row=$row"; fail=1; }

echo "record-seat review layout: the only tag on a continuation line under ## Major -> exit 4"
mk_open_spec rlaywrap 3
rd_rl="$(mk_open_round rlaywrap 1)"
out="$(printf 'VERDICT: BLOCK\n## Major\n- major: the guard on line 40 is missing,\n  which breaks [ask 2]\n' | council record-seat docs/specs/rlaywrap 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ -f "$rd_rl/review.attempt-1.md" ] && [ ! -f "$rd_rl/review.md" ] \
  && echo "  ok    wrapped finding -> exit 4" || { echo "::error::rlaywrap: exit=$ex out=$out"; fail=1; }

echo "record-seat review layout: [regression] in prose only under ## Major (anchprose shape) -> exit 4"
mk_open_spec rlayprose 3
rd_rl="$(mk_open_round rlayprose 1)"
out="$(printf 'VERDICT: BLOCK\n## Major\nNo [regression] found - base and head both pass t.sh.\n' | council record-seat docs/specs/rlayprose 1 review 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ -f "$rd_rl/review.attempt-1.md" ] && [ ! -f "$rd_rl/review.md" ] \
  && echo "  ok    prose [regression] -> exit 4 at record-seat" || { echo "::error::rlayprose: exit=$ex out=$out"; fail=1; }

echo "record-seat review layout: [unanchored] list lines only -> accepted; judge -> review PASS, note"
mk_open_spec rlayun 3
set_tier rlayun 2
rd_rl="$(mk_open_round rlayun 1)"
out="$(printf 'VERDICT: BLOCK\n## Critical\nNone.\n## Major\n1. x.sh:4 [unanchored] worker - naming must match the helper\n## Minor\nNone.\n' | council record-seat docs/specs/rlayun 1 review 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f "$rd_rl/review.md" ] && echo "  ok    [unanchored] ## Major line -> exit 0" \
  || { echo "::error::rlayun record: exit=$ex out=$out"; fail=1; }
write_seat "$rd_rl" sonnet GGG
jout="$(council judge docs/specs/rlayun)"; jex=$?
row="$(grep '"spec":"rlayun"' memory/stats/council.jsonl | tail -1)"
[ "$jex" -eq 0 ] && printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"review":"PASS"' \
  && printf '%s' "$row" | grep -qF '"note":"review BLOCK unanchored"' \
  && echo "  ok    judge -> GREEN, review PASS, note 'review BLOCK unanchored'" || { echo "::error::rlayun judge: exit=$jex row=$row"; fail=1; }

fi # --quick: end of the review-layout skip
if full; then # --quick skips: the model-resolution precedence
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

fi # --quick: end of the model-resolution skip
# --- record-seat --file: report from a path instead of stdin (C1) ------------------------------

echo "record-seat --file: a report read from a file records a body byte-identical to the stdin-recorded twin"
mk_spec rfile1 2
rd_rfile1="$(mk_open_round rfile1 1)"
seat_report sonnet 1 GG | council record-seat docs/specs/rfile1 1 sonnet >/dev/null
mkdir -p .vulyk/reports
seat_report sonnet 1 GG > .vulyk/reports/opus.md
out="$(council record-seat docs/specs/rfile1 1 opus --file .vulyk/reports/opus.md)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qE '"next":"dispatch:' && echo "  ok    record-seat --file exits 0, recorded" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
diff <(tail -n +2 "$rd_rfile1/sonnet.md") <(tail -n +2 "$rd_rfile1/opus.md") >/dev/null \
  && echo "  ok    --file body is byte-identical to the stdin-recorded twin" \
  || { echo "::error::--file body differs from the stdin twin: $(diff <(tail -n +2 "$rd_rfile1/sonnet.md") <(tail -n +2 "$rd_rfile1/opus.md"))"; fail=1; }

echo "record-seat --file: a missing path exits 2 with error exactly 'file: <path>', writes no attempt file"
out="$(council record-seat docs/specs/rfile1 1 haiku --file .vulyk/reports/does-not-exist.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF '"error":"file: .vulyk/reports/does-not-exist.md"' \
  && [ ! -e "$rd_rfile1/haiku.md" ] && [ ! -e "$rd_rfile1/haiku.attempt-1.md" ] \
  && echo "  ok    missing --file path: exit 2, error names the path verbatim, no attempt file" \
  || { echo "::error::--file missing: exit=$ex out=$out"; fail=1; }

echo "record-seat --file: an empty file behaves as missing"
: > .vulyk/reports/empty.md
out="$(council record-seat docs/specs/rfile1 1 haiku --file .vulyk/reports/empty.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF '"error":"file: .vulyk/reports/empty.md"' \
  && [ ! -e "$rd_rfile1/haiku.md" ] && [ ! -e "$rd_rfile1/haiku.attempt-1.md" ] \
  && echo "  ok    empty --file path behaves as missing: exit 2, no attempt file" \
  || { echo "::error::--file empty: exit=$ex out=$out"; fail=1; }

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
returned: DONE
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

echo "close-story: an already-done story with a clean tree -> exit 0, already done (ADR-013 D5, was exit 2)"
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'already done' && echo "  ok    already done -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "close-story: self-marked status: done with an uncommitted diff -> proceeds, journals the self-mark once with the story's own wave (C3 revised)"
sed -i -E 's/^wave:.*/wave: 2/' docs/specs/cstory1/cstory1-01-first.md   # Minor 5: a wave-2 story
printf 'again\n' > docs/specs/cstory1/flag.txt
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    self-marked done + dirty diff -> exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
smlines="$(grep -cF 'worker marked status: done itself' docs/specs/cstory1/journal.md)"
[ "$smlines" -eq 1 ] && echo "  ok    journal.md gained exactly one self-mark line" \
  || { echo "::error::self-mark lines=$smlines journal.md: $(cat docs/specs/cstory1/journal.md)"; fail=1; }
grep -F 'worker marked status: done itself' docs/specs/cstory1/journal.md | grep -qF 'next: build:2' \
  && echo "  ok    the self-mark line's next is build:<the story's wave> (Minor 5)" \
  || { echo "::error::journal.md: $(cat docs/specs/cstory1/journal.md)"; fail=1; }
grep -q '^status: done' docs/specs/cstory1/cstory1-01-first.md && echo "  ok    status: still done" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory1/cstory1-01-first.md)"; fail=1; }
flagcommits="$(git log --oneline -- docs/specs/cstory1/flag.txt | wc -l)"
[ "$flagcommits" -eq 2 ] && echo "  ok    a second story(<id>) commit landed, containing flag.txt" \
  || { echo "::error::commits touching flag.txt: $flagcommits"; fail=1; }

echo "close-story: self-marked done, dirty diff, but returned: absent -> exit 4 returned: missing, no commit, journal.md untouched (C3 revised, Minor 6)"
sed -i -E 's/^returned:.*/returned:/' docs/specs/cstory1/cstory1-01-first.md
headbefore="$(git rev-parse HEAD)"
jbefore="$(cat docs/specs/cstory1/journal.md)"
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'returned: missing' && echo "  ok    returned: absent -> exit 4, returned: missing" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
headafter="$(git rev-parse HEAD)"
[ "$headbefore" = "$headafter" ] && echo "  ok    no commit landed" || { echo "::error::HEAD moved: $headbefore -> $headafter"; fail=1; }
[ "$(cat docs/specs/cstory1/journal.md)" = "$jbefore" ] && echo "  ok    journal.md byte-identical after the exit-4 attempt (no second self-mark line)" \
  || { echo "::error::journal.md changed on exit 4: $(cat docs/specs/cstory1/journal.md)"; fail=1; }
git checkout -- docs/specs/cstory1/cstory1-01-first.md

echo "close-story: a third call once the tree is clean again -> exit 0 already done, no new journal line (C3 revised, ADR-013 D5)"
git checkout -- docs/specs/cstory1/flag.txt
jbefore="$(cat docs/specs/cstory1/journal.md)"
out="$(council close-story docs/specs/cstory1/cstory1-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'already done' && echo "  ok    clean tree after a green close -> exit 0 already done" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(cat docs/specs/cstory1/journal.md)" = "$jbefore" ] && echo "  ok    journal.md unchanged by the already-done close" \
  || { echo "::error::journal.md changed: $(cat docs/specs/cstory1/journal.md)"; fail=1; }

# --- close-story: the ## Commands gate and one-line-at-a-time execution (R11/R18/C-4/M-3) -----

echo "close-story: a verification command not in CLAUDE.md's ## Commands -> exit 2, names the segment (R11/C-4)"
mkdir -p docs/specs/cstory3
cat > docs/specs/cstory3/cstory3-01-first.md <<'EOF'
---
story: cstory3-01
spec: cstory3
status: todo
returned: DONE
wave: 1
---
# Close-story disallowed-command fixture

## Verification
`echo not-allowed-anywhere`
EOF
git add -A && git commit -qm "spec(cstory3): fixture" >/dev/null
out="$(council close-story docs/specs/cstory3/cstory3-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'verification not in ## Commands: echo not-allowed-anywhere' \
  && echo "  ok    disallowed command -> exit 2, names it" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: todo' docs/specs/cstory3/cstory3-01-first.md && echo "  ok    status stays todo (never executed)" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory3/cstory3-01-first.md)"; fail=1; }

echo "close-story: an &&-joined line passes when every segment is its own ## Commands cell"
mkdir -p docs/specs/cstory4
cat > docs/specs/cstory4/cstory4-01-first.md <<'EOF'
---
story: cstory4-01
spec: cstory4
status: todo
returned: DONE
wave: 1
---
# Close-story &&-segment fixture

## Verification
`true && true`
EOF
git add -A && git commit -qm "spec(cstory4): fixture" >/dev/null
out="$(council close-story docs/specs/cstory4/cstory4-01-first.md --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    both && segments matched ## Commands, ran, exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "close-story: a multi-command block runs one line at a time - false before true -> exit 4 naming the failing line (R18/M-3)"
mkdir -p docs/specs/cstory2
cat > docs/specs/cstory2/cstory2-01-first.md <<'EOF'
---
story: cstory2-01
spec: cstory2
status: todo
returned: DONE
wave: 1
---
# Close-story multi-line fixture

## Verification
`false`
`true`
EOF
git add -A && git commit -qm "spec(cstory2): fixture" >/dev/null
out="$(council close-story docs/specs/cstory2/cstory2-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF '"error":"false"' && echo "  ok    the first (failing) line is named, exit 4" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: todo' docs/specs/cstory2/cstory2-01-first.md && echo "  ok    status stays todo" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory2/cstory2-01-first.md)"; fail=1; }

echo "close-story: emit escapes a failing command's quotes so the last line stays parsable (R33/N-M4)"
mkdir -p docs/specs/cstoryq
cat > docs/specs/cstoryq/cstoryq-01-first.md <<'EOF'
---
story: cstoryq-01
spec: cstoryq
status: todo
returned: DONE
wave: 1
---
# emit-escape fixture, a quoted command

## Verification
`sh -c "exit 1"`
EOF
git add -A && git commit -qm "spec(cstoryq): fixture" >/dev/null
out="$(council close-story docs/specs/cstoryq/cstoryq-01-first.md 2>&1)"; ex=$?
lastline="$(printf '%s\n' "$out" | tail -1)"
[ "$ex" -eq 4 ] && printf '%s' "$lastline" | jq -e . >/dev/null 2>&1 && echo "  ok    quoted-command failure -> exit 4, last line is valid JSON" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(printf '%s' "$lastline" | jq -r .error)" = 'sh -c "exit 1"' ] && echo "  ok    error equals the ## Commands cell text byte for byte" \
  || { echo "::error::error field: $(printf '%s' "$lastline" | jq -r .error) from: $lastline"; fail=1; }

echo "close-story: emit escapes a failing command's backslash the same way (R33/N-M4)"
mkdir -p docs/specs/cstorybs
cat > docs/specs/cstorybs/cstorybs-01-first.md <<'EOF'
---
story: cstorybs-01
spec: cstorybs
status: todo
returned: DONE
wave: 1
---
# emit-escape fixture, a backslash command

## Verification
`sh -c 'echo a\b; exit 1'`
EOF
git add -A && git commit -qm "spec(cstorybs): fixture" >/dev/null
out="$(council close-story docs/specs/cstorybs/cstorybs-01-first.md 2>&1)"; ex=$?
lastline="$(printf '%s\n' "$out" | tail -1)"
[ "$ex" -eq 4 ] && printf '%s' "$lastline" | jq -e . >/dev/null 2>&1 && echo "  ok    backslash-command failure -> exit 4, last line is valid JSON" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(printf '%s' "$lastline" | jq -r .error)" = "sh -c 'echo a\\b; exit 1'" ] && echo "  ok    error equals the ## Commands cell text byte for byte" \
  || { echo "::error::error field: $(printf '%s' "$lastline" | jq -r .error) from: $lastline"; fail=1; }

echo "close-story: the literal 'none - reviewed by lead-review' runs nothing, but scope-check still runs"
mkdir -p docs/specs/cstory5
cat > docs/specs/cstory5/cstory5-01-first.md <<MDEOF
---
story: cstory5-01
spec: cstory5
status: todo
returned: DONE
wave: 1
---
# Close-story none fixture

## Files
- docs/specs/cstory5/cstory5-01-first.md

## Verification
\`none — reviewed by lead-review\`
MDEOF
git add -A && git commit -qm "spec(cstory5): fixture" >/dev/null
out="$(council close-story docs/specs/cstory5/cstory5-01-first.md --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    literal none runs nothing, exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: done' docs/specs/cstory5/cstory5-01-first.md && echo "  ok    status becomes done" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstory5/cstory5-01-first.md)"; fail=1; }
grep -qF '"story":"cstory5-01-first"' memory/stats/scope.jsonl && echo "  ok    scope-check.sh still ran for the none story" \
  || { echo "::error::scope.jsonl missing cstory5 entry"; fail=1; }

echo "close-story --commit: stages memory/stats/scope.jsonl, and open-round right after needs no intervening git add -A (R4/C-3(b))"
mk_open_spec cstory6 1
set_tier cstory6 1
cat > docs/specs/cstory6/cstory6-02-second.md <<'EOF'
---
story: cstory6-02
spec: cstory6
status: todo
returned: DONE
wave: 1
---
# Close-story scope.jsonl commit fixture

## Files
- docs/specs/cstory6/cstory6-02-second.md

## Verification
`true`
EOF
git add -A && git commit -qm "cstory6: second story fixture" >/dev/null
out="$(council close-story docs/specs/cstory6/cstory6-02-second.md --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    close-story --commit exits 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
git show --name-only --format= HEAD | grep -qF 'memory/stats/scope.jsonl' && echo "  ok    scope.jsonl rode in the story's own commit" \
  || { echo "::error::commit files: $(git show --name-only --format= HEAD)"; fail=1; }
[ -z "$(git status --porcelain)" ] && echo "  ok    tree is clean after close-story --commit (no lingering scope.jsonl)" \
  || { echo "::error::tree dirty: $(git status --porcelain)"; fail=1; }
out="$(council open-round docs/specs/cstory6 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    open-round right after close-story --commit (no intervening git add -A) still opens (R4)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -z "$(git status --porcelain)" ] && echo "  ok    tree is clean after both verbs" \
  || { echo "::error::tree dirty: $(git status --porcelain)"; fail=1; }

if full; then # --quick skips: the story 08 fix proofs (returned:, r2m2, LR31, r2m9)
# --- story 16: the four story 08 fixes - cstoryr1..r4 (M3/ADR-006 returned: gate), r2m2 -------
# (close-story --commit owns its commit), LR31 (wave_stories lists only ready stories), r2m9 --
# (a ## Commands cell with its own && matches whole) ------------------------------------------

echo "close-story: cstoryr1 - returned: DONE, verification true -> exit 0, status: done, exactly one new commit (M3)"
mkdir -p docs/specs/cstoryr1
cat > docs/specs/cstoryr1/cstoryr1-01-first.md <<'EOF'
---
story: cstoryr1-01
spec: cstoryr1
status: todo
returned: DONE
wave: 1
---
# R1

## Files
- docs/specs/cstoryr1/cstoryr1-01-first.md

## Verification
`true`
EOF
git add -A && git commit -qm "spec(cstoryr1): fixture" >/dev/null
commits_before="$(git rev-list --count HEAD)"
out="$(council close-story docs/specs/cstoryr1/cstoryr1-01-first.md --commit)"; ex=$?
commits_after="$(git rev-list --count HEAD)"
[ "$ex" -eq 0 ] && echo "  ok    cstoryr1: exit 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: done' docs/specs/cstoryr1/cstoryr1-01-first.md && echo "  ok    cstoryr1: status: done" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstoryr1/cstoryr1-01-first.md)"; fail=1; }
[ "$((commits_after - commits_before))" -eq 1 ] && echo "  ok    cstoryr1: exactly one new commit" \
  || { echo "::error::commits before=$commits_before after=$commits_after"; fail=1; }

echo "close-story: cstoryr2 - returned: WALL, verification 'none' -> exit 4, last line names returned WALL, status stays in-progress, no commit (M3)"
mkdir -p docs/specs/cstoryr2
cat > docs/specs/cstoryr2/cstoryr2-01-first.md <<MDEOF
---
story: cstoryr2-01
spec: cstoryr2
status: in-progress
returned: WALL
wave: 1
---
# R2

## Verification
none — reviewed by lead-review
MDEOF
git add -A && git commit -qm "spec(cstoryr2): fixture" >/dev/null
commits_before="$(git rev-list --count HEAD)"
out="$(council close-story docs/specs/cstoryr2/cstoryr2-01-first.md --commit 2>&1)"; ex=$?
commits_after="$(git rev-list --count HEAD)"
lastline="$(printf '%s\n' "$out" | tail -1)"
[ "$ex" -eq 4 ] && printf '%s' "$lastline" | grep -qF '"error":"returned WALL"' && printf '%s' "$lastline" | grep -qF '"next":"repair"' \
  && echo "  ok    cstoryr2: exit 4, last line names returned WALL, next:repair" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: in-progress' docs/specs/cstoryr2/cstoryr2-01-first.md && echo "  ok    cstoryr2: status stays in-progress" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstoryr2/cstoryr2-01-first.md)"; fail=1; }
[ "$commits_after" -eq "$commits_before" ] && echo "  ok    cstoryr2: no new commit" \
  || { echo "::error::commits before=$commits_before after=$commits_after"; fail=1; }

echo "close-story: cstoryr3 - returned: absent -> exit 4, error returned: missing (M3)"
mkdir -p docs/specs/cstoryr3
cat > docs/specs/cstoryr3/cstoryr3-01-first.md <<'EOF'
---
story: cstoryr3-01
spec: cstoryr3
status: todo
wave: 1
---
# R3

## Verification
`true`
EOF
git add -A && git commit -qm "spec(cstoryr3): fixture" >/dev/null
out="$(council close-story docs/specs/cstoryr3/cstoryr3-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && printf '%s\n' "$out" | tail -1 | grep -qF '"error":"returned: missing"' && echo "  ok    cstoryr3: exit 4, error returned: missing" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "close-story: cstoryr4 - returned: NEEDS_CONTEXT -> exit 4 before the command runs, flag file stays absent (M3)"
mkdir -p docs/specs/cstoryr4
cat > docs/specs/cstoryr4/cstoryr4-01-first.md <<'EOF'
---
story: cstoryr4-01
spec: cstoryr4
status: todo
returned: NEEDS_CONTEXT
wave: 1
---
# R4

## Verification
`touch docs/specs/cstoryr4/flag.txt`
EOF
git add -A && git commit -qm "spec(cstoryr4): fixture" >/dev/null
out="$(council close-story docs/specs/cstoryr4/cstoryr4-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && echo "  ok    cstoryr4: exit 4" || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -f docs/specs/cstoryr4/flag.txt ] && echo "  ok    cstoryr4: flag file absent - the verification command never ran" \
  || { echo "::error::flag.txt exists: the verification command ran"; fail=1; }

echo "close-story --commit: r2m2 - a locked index leaves the story todo|in-progress on disk (never an uncommitted 'done'); the retry closes and commits"
mkdir -p docs/specs/cstorylock1
cat > docs/specs/cstorylock1/cstorylock1-01-first.md <<'EOF'
---
story: cstorylock1-01
spec: cstorylock1
status: todo
returned: DONE
wave: 1
---
# Lock

## Files
- docs/specs/cstorylock1/cstorylock1-01-first.md

## Verification
`true`
EOF
git add -A && git commit -qm "spec(cstorylock1): fixture" >/dev/null
touch .git/index.lock
out="$(council close-story docs/specs/cstorylock1/cstorylock1-01-first.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'commit' && echo "  ok    r2m2: locked index -> exit 2, error names the commit" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -qE '^status: (todo|in-progress)$' docs/specs/cstorylock1/cstorylock1-01-first.md && echo "  ok    r2m2: story still reads todo|in-progress on disk" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstorylock1/cstorylock1-01-first.md)"; fail=1; }
statusout="$(council status docs/specs/cstorylock1 --json)"
printf '%s' "$statusout" | jq -e '.next != "open-round"' >/dev/null 2>&1 && echo "  ok    r2m2: status --json does not say next:open-round while the tree is dirty" \
  || { echo "::error::status: $statusout"; fail=1; }
rm -f .git/index.lock
commits_before="$(git rev-list --count HEAD)"
out="$(council close-story docs/specs/cstorylock1/cstorylock1-01-first.md --commit)"; ex=$?
commits_after="$(git rev-list --count HEAD)"
[ "$ex" -eq 0 ] && echo "  ok    r2m2: retry after the lock is removed exits 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
grep -q '^status: done' docs/specs/cstorylock1/cstorylock1-01-first.md && echo "  ok    r2m2: retry writes status: done" \
  || { echo "::error::status: $(grep '^status:' docs/specs/cstorylock1/cstorylock1-01-first.md)"; fail=1; }
[ "$((commits_after - commits_before))" -eq 1 ] && echo "  ok    r2m2: retry lands exactly one commit" \
  || { echo "::error::commits before=$commits_before after=$commits_after"; fail=1; }

echo "status --json: LR31 - a ready todo A and a not-ready todo B (blocked_by a not-done C) share wave 1; wave_stories names only A; once C is done, both A and B are listed"
mkdir -p docs/specs/lr31w
cat > docs/specs/lr31w/lr31w-01-a.md <<'EOF'
---
story: lr31w-01
spec: lr31w
status: todo
wave: 1
---
# A (ready)

## Verification
`true`
EOF
cat > docs/specs/lr31w/lr31w-02-c.md <<'EOF'
---
story: lr31w-02
spec: lr31w
status: blocked
wave: 1
---
# C (the blocker)

## Verification
`true`
EOF
cat > docs/specs/lr31w/lr31w-03-b.md <<'EOF'
---
story: lr31w-03
spec: lr31w
status: todo
wave: 1
blocked_by: [lr31w-02]
---
# B (not ready)

## Verification
`true`
EOF
git add -A && git commit -qm "spec(lr31w): fixture" >/dev/null
out="$(council status docs/specs/lr31w --json)"
printf '%s' "$out" | jq -c '.wave_stories' | expect "LR31: ready A and not-ready B (blocked_by todo/blocked C) -> wave_stories names only A" \
  '[{"file":"docs/specs/lr31w/lr31w-01-a.md","story":"lr31w-01","worker":"worker-code","model":"opus","repeat":1}]'
sed -i 's/^status: blocked/status: done/' docs/specs/lr31w/lr31w-02-c.md
git add -A && git commit -qm "lr31w: blocker C done" >/dev/null
out="$(council status docs/specs/lr31w --json)"
printf '%s' "$out" | jq -c '.wave_stories' | expect "LR31: blocker C done -> both A and B are listed" \
  '[{"file":"docs/specs/lr31w/lr31w-01-a.md","story":"lr31w-01","worker":"worker-code","model":"opus","repeat":1},{"file":"docs/specs/lr31w/lr31w-03-b.md","story":"lr31w-03","worker":"worker-code","model":"opus","repeat":1}]'

echo "close-story: r2m9 - a ## Commands cell with its own && matches whole; adding a further && true is refused, naming the segment"
mkdir -p docs/specs/cstoryr2m9
cat > docs/specs/cstoryr2m9/cstoryr2m9-01-first.md <<'EOF'
---
story: cstoryr2m9-01
spec: cstoryr2m9
status: todo
returned: DONE
wave: 1
---
# R2M9

## Files
- docs/specs/cstoryr2m9/cstoryr2m9-01-first.md

## Verification
`sh -c 'true && true'`
EOF
git add -A && git commit -qm "spec(cstoryr2m9): fixture" >/dev/null
out="$(council close-story docs/specs/cstoryr2m9/cstoryr2m9-01-first.md --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    r2m9: the && cell matches whole and runs" || { echo "::error::exit=$ex out=$out"; fail=1; }

mkdir -p docs/specs/cstoryr2m9b
cat > docs/specs/cstoryr2m9b/cstoryr2m9b-01-first.md <<'EOF'
---
story: cstoryr2m9b-01
spec: cstoryr2m9b
status: todo
returned: DONE
wave: 1
---
# R2M9B

## Verification
`sh -c 'true && true' && true`
EOF
git add -A && git commit -qm "spec(cstoryr2m9b): fixture" >/dev/null
out="$(council close-story docs/specs/cstoryr2m9b/cstoryr2m9b-01-first.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF "verification not in ## Commands: sh -c 'true" \
  && echo "  ok    r2m9: an extra && true segment is refused, naming the segment" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

fi # --quick: end of the story 16 skip
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

echo "open-round: preconditions - only skills.json/learnings dirty -> not refused as unclean (C2 + addendum)"
# C2 addendum: with nothing tracked under memory/learnings/, `git status --porcelain` collapses
# the whole directory to one `?? memory/learnings/` line unless -uall is passed - the hive shape
# the guard has to survive. Drop the tracked fixture learnings file first.
git rm -q --cached memory/learnings/2026-09-15-pwseat1.md >/dev/null 2>&1
rm -f memory/learnings/2026-09-15-pwseat1.md
git commit -qm "untrack the learnings fixture (C2 addendum)" >/dev/null
mkdir -p memory/learnings
echo '{}' > memory/stats/skills.json
echo 'note' > memory/learnings/2026-09-15-x.md
out="$(council open-round docs/specs/oround1 2>&1)"; ex=$?
{ [ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'tier' \
  && ! printf '%s' "$out" | grep -qF 'working tree not clean' \
  && ! printf '%s' "$out" | grep -qF "outside the cycle's own paperwork"; } \
  && echo "  ok    skills.json + an untracked memory/learnings/*.md in an otherwise untracked dir do not trip 'working tree not clean' (Minor 12)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
mkdir -p memory/learnings/sub
echo 'note' > memory/learnings/sub/x.md
out="$(council open-round docs/specs/oround1 2>&1)"; ex=$?
{ [ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'working tree not clean'; } \
  && echo "  ok    memory/learnings/sub/x.md -> still refused (the one-level rule holds under -uall)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rm -rf memory/learnings/sub
rm -f memory/stats/skills.json memory/learnings/2026-09-15-x.md

echo "open-round: preconditions - no parsable **Tier:** line -> exit 2 (M-10/R21)"
out="$(council open-round docs/specs/oround1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'tier' && echo "  ok    unparsable Tier line -> exit 2, naming Tier" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
set_tier oround1 4

echo "open-round: opens round 1 - ROUND file, court reduced to brief.md, journal, next dispatch:..."
out="$(council open-round docs/specs/oround1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:opus,review"' && echo "  ok    round 1 opens, next dispatch:opus,review" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd1o="docs/specs/oround1/council/round-1"
[ -f "$rd1o/ROUND" ] && grep -q '^ceiling=3$' "$rd1o/ROUND" && echo "  ok    ROUND file written, ceiling=3 (default)" \
  || { echo "::error::ROUND: $(cat "$rd1o/ROUND" 2>&1)"; fail=1; }
grep -q '^tier=4$' "$rd1o/ROUND" && echo "  ok    ROUND file freezes tier=4 (from plan.md's explicit Tier line)" \
  || { echo "::error::ROUND: $(cat "$rd1o/ROUND" 2>&1)"; fail=1; }
grep -qx 'seats=opus review' "$rd1o/ROUND" && ! grep -q '^since=' "$rd1o/ROUND" \
  && echo "  ok    ROUND freezes seats=opus review, no since= on round 1 (ADR-013 D3)" || { echo "::error::ROUND: $(cat "$rd1o/ROUND" 2>&1)"; fail=1; }
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
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:opus,review"' && echo "  ok    HEAD unchanged, no seats yet -> still both missing" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

write_seat "$rd1o" opus GGG
out="$(council open-round docs/specs/oround1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:review"' && echo "  ok    HEAD unchanged, one seat present -> next lists only the missing one" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "open-round: a manual code commit on an open round with a seat file -> STALE row + round N+1, which carries the GREEN opus (ADR-013 D3)"
echo "code change" > oround1-manual-code.txt
git add -A && git commit -qm "manual code change while oround1 round 1 is open" >/dev/null
out="$(council open-round docs/specs/oround1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:review"' && printf '%s' "$out" | grep -qF 'carried from round 1: opus' \
  && echo "  ok    stale round folded, round 2 opened with opus carried, next dispatch:review" \
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
write_review "$rd2o" PASS
council judge docs/specs/oround1 --commit >/dev/null
[ ! -d "$court2" ] && echo "  ok    judge removed the court directory" || { echo "::error::court2 still present: $(ls "$court2" 2>&1)"; fail=1; }
git worktree list | grep -qF "$court2" && { echo "::error::git worktree list still lists $court2"; fail=1; } \
  || echo "  ok    git worktree list no longer lists it"

echo "open-round: exit 6 at the ceiling, next escalated - no new round created"
mk_spec oceil1 2
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-13/' docs/specs/oceil1/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oceil1#' docs/specs/oceil1/plan.md
set_tier oceil1 3
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

echo "open-round: the ceiling gate itself writes the ESCALATE record - row, plan line, Needs a human, journal (R5/C-3(a))"
row_esc="$(grep '"spec":"oceil1"' memory/stats/council.jsonl | grep '"round":1' | grep '"verdict":"ESCALATE"')"
[ -n "$row_esc" ] && printf '%s' "$row_esc" | grep -qF '"escalate":"ceiling"' \
  && echo "  ok    open-round's own ceiling gate wrote an ESCALATE row for round 1" \
  || { echo "::error::no ESCALATE row for oceil1 round 1: $(grep '\"spec\":\"oceil1\"' memory/stats/council.jsonl)"; fail=1; }
grep -qE '^\*\*Council:\*\* ESCALATE round 1,' docs/specs/oceil1/plan.md && echo "  ok    plan.md records ESCALATE round 1" \
  || { echo "::error::plan.md: $(grep '^\*\*Council:\*\*' docs/specs/oceil1/plan.md)"; fail=1; }
grep -qF 'reason: ceiling · round 1' docs/specs/oceil1/plan.md && echo "  ok    ## Needs a human names ceiling, round 1" \
  || { echo "::error::plan.md: $(cat docs/specs/oceil1/plan.md)"; fail=1; }
grep -qF 'ESCALATE' docs/specs/oceil1/journal.md && echo "  ok    journal.md records the ceiling escalation" \
  || { echo "::error::journal.md: $(cat docs/specs/oceil1/journal.md 2>&1)"; fail=1; }
out="$(council status docs/specs/oceil1 --json)"
printf '%s' "$out" | jq -e '.next == "escalated"' >/dev/null 2>&1 && echo "  ok    status --json says escalated after the ceiling gate wrote its own record" \
  || { echo "::error::status: $out"; fail=1; }

echo "open-round: a second call at the ceiling adds nothing (idempotent)"
rowcount_before="$(grep -c '"spec":"oceil1"' memory/stats/council.jsonl)"
council open-round docs/specs/oceil1 >/dev/null 2>&1
rowcount_after="$(grep -c '"spec":"oceil1"' memory/stats/council.jsonl)"
[ "$rowcount_before" -eq "$rowcount_after" ] && echo "  ok    no new row was added" \
  || { echo "::error::row count: before=$rowcount_before after=$rowcount_after"; fail=1; }

echo "open-round --commit: at the ceiling, commits the ESCALATE record (clean tree afterward)"
mk_spec oceilc1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oceilc1#' docs/specs/oceilc1/plan.md
set_tier oceilc1 3
mkdir -p docs/specs/oceilc1/council
printf '1\n' > docs/specs/oceilc1/council/CEILING
git add -A && git commit -qm "oceilc1: branch, ceiling 1" >/dev/null
mk_round oceilc1 1 1 >/dev/null
printf '{"ts":"%s","spec":"oceilc1","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":2,"red":[1],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"RED","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":4,"escalate":null,"note":""}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
git add -A && git commit -qm "oceilc1: fabricated round 1, already judged RED" >/dev/null
out="$(council open-round docs/specs/oceilc1 --commit 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    --commit at the ceiling still exits 6, next escalated" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -z "$(git status --porcelain)" ] && echo "  ok    --commit at the ceiling committed the ESCALATE record (clean tree)" \
  || { echo "::error::tree dirty after --commit: $(git status --porcelain)"; fail=1; }

# --- escalate: a verb of its own, not an alias of judge (R5/C-3) ------------------------------

echo "escalate: an open round with seats missing -> ESCALATE row (reason defaults to env), court removed, exit 6"
mk_open_spec esc1 2
set_tier esc1 3
rde1="$(mk_open_round esc1 1)"
write_seat "$rde1" haiku GG
write_seat "$rde1" sonnet GG
# opus, review: never dispatched - missing
court_e1="$(sed -n 's/^court=//p' "$rde1/ROUND")"
mkdir -p "$court_e1"
out="$(council escalate docs/specs/esc1 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    escalate on missing seats -> exit 6" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"esc1"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"verdict":"ESCALATE"' && printf '%s' "$row" | grep -qF '"escalate":"env"' \
  && echo "  ok    row verdict ESCALATE, escalate:env (default reason)" || { echo "::error::row: $row"; fail=1; }
printf '%s' "$row" | grep -qE '"note":"[^"]*(opus|review)[^"]*"' && echo "  ok    row note names a missing seat" \
  || { echo "::error::row note: $row"; fail=1; }
[ ! -d "$court_e1" ] && echo "  ok    the court was removed" || { echo "::error::court still present: $court_e1"; fail=1; }
grep -qF 'reason: env · round 1' docs/specs/esc1/plan.md && echo "  ok    ## Needs a human names env, round 1" \
  || { echo "::error::plan.md: $(cat docs/specs/esc1/plan.md)"; fail=1; }
grep -qF 'ESCALATE' docs/specs/esc1/journal.md && echo "  ok    journal.md records the escalation" \
  || { echo "::error::journal.md: $(cat docs/specs/esc1/journal.md 2>&1)"; fail=1; }

echo "escalate: --reason and a note override the default"
mk_open_spec esc2 2
set_tier esc2 1
mk_open_round esc2 1 >/dev/null
# review (the only required seat at tier 1) never dispatched - missing
out="$(council escalate docs/specs/esc2 --reason half "manual call, two of four RED" 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && echo "  ok    escalate with explicit reason/note -> exit 6" || { echo "::error::exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"esc2"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":"half"' && printf '%s' "$row" | grep -qF '"note":"manual call, two of four RED"' \
  && echo "  ok    row uses the given reason and note" || { echo "::error::row: $row"; fail=1; }

echo "escalate: nothing missing -> behaves exactly like judge"
mk_open_spec esc3 3
set_tier esc3 1
rde3="$(mk_open_round esc3 1)"
write_review "$rde3" PASS
out="$(council escalate docs/specs/esc3)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"verb":"escalate"' && printf '%s' "$out" | grep -qF '"next":"green"' \
  && echo "  ok    nothing missing -> judged like judge (GREEN here), verb label stays escalate" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "escalate: PAUSE present -> exit 3"
mk_open_spec esc4 2
mk_open_round esc4 1 >/dev/null
printf 'Test Owner \xc2\xb7 taking the tree back \xc2\xb7 %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > docs/specs/esc4/PAUSE
out="$(council escalate docs/specs/esc4 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    PAUSE -> exit 3" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

if full; then # --quick skips: the R15 court-reduction proof
# --- open-round: the court's reduction is committed inside the worktree (R15/M-1,M-2) ---------

echo "open-round: the court's reduction is committed inside the worktree - clean status, HEAD:plan.md no longer resolves, stays inside the court (R15)"
mk_open_spec courtred1 2
set_tier courtred1 3
out="$(council open-round docs/specs/courtred1 --commit)"; ex=$?
[ "$ex" -eq 0 ] || { echo "::error::open-round: exit=$ex out=$out"; fail=1; }
rdcr="docs/specs/courtred1/council/round-1"
courtcr="$(sed -n 's/^court=//p' "$rdcr/ROUND")"
[ -z "$(git -C "$courtcr" status --porcelain 2>/dev/null)" ] && echo "  ok    the court's orientation git status is clean" \
  || { echo "::error::court status: $(git -C "$courtcr" status --porcelain)"; fail=1; }
git -C "$courtcr" show "HEAD:docs/specs/courtred1/plan.md" >/dev/null 2>&1 \
  && { echo "::error::HEAD:docs/specs/courtred1/plan.md still resolves inside the court"; fail=1; } \
  || echo "  ok    HEAD:docs/specs/courtred1/plan.md no longer resolves inside the court"
git log -1 --format=%s | grep -qF "vulyk(courtred1): open-round 1" \
  && echo "  ok    the main repo's HEAD carries only open-round's own commit - the court's reduction commit stayed inside the court" \
  || { echo "::error::main repo HEAD commit message: $(git log -1 --format=%s)"; fail=1; }

fi # --quick: end of the court-reduction skip
if full; then # --quick skips from here to the 0.18 section: the reopen walk, the ceiling variants, the committed-verb walks, stories 14-17, every pinned-commit replay, the C5 block
# --- reopen: ceiling +3 after ESCALATE, then a fourth round opens ------------------------------

echo "reopen: three RED rounds escalate (ceiling) on the third, reopen bumps ceiling to 6, a 4th round opens"
mk_spec oreopen1 5
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/oreopen1#' docs/specs/oreopen1/plan.md
git add -A && git commit -qm "oreopen1: branch" >/dev/null
set_tier oreopen1 3

for n in 1 2 3; do
  council open-round docs/specs/oreopen1 --commit >/dev/null
  rdn="docs/specs/oreopen1/council/round-$n"
  # a different ask RED each round, so no-progress (convergent-judge-04) never fires first
  case "$n" in 1) pat=RGGGG ;; 2) pat=GRGGG ;; *) pat=GGRGG ;; esac
  write_seat "$rdn" haiku "$pat"
  write_seat "$rdn" sonnet GGGGG
  write_seat "$rdn" opus GGGGG
  write_review "$rdn" PASS
  jout="$(council judge docs/specs/oreopen1 --commit)"; jex=$?
  if [ "$n" -lt 3 ]; then
    [ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    round $n: RED, repair" \
      || { echo "::error::round $n: exit=$jex out=$jout"; fail=1; }
  else
    [ "$jex" -eq 6 ] && printf '%s' "$jout" | grep -qF '"next":"escalated"' && echo "  ok    round $n: ceiling reached, ESCALATE" \
      || { echo "::error::round $n: exit=$jex out=$jout"; fail=1; }
  fi
done

out="$(council reopen docs/specs/oreopen1 "ship it after manual review" --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | tail -1 | grep -qF '"next":"repair"' && echo "  ok    reopen exits 0, next repair (a ceiling ESCALATE, ADR-013 D3)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ "$(cat docs/specs/oreopen1/council/CEILING)" = "6" ] && echo "  ok    ceiling is now 6" \
  || { echo "::error::CEILING: $(cat docs/specs/oreopen1/council/CEILING 2>&1)"; fail=1; }
grep -qF '**After escalation (round 3,' docs/specs/oreopen1/brief.md && grep -qF '> ship it after manual review' docs/specs/oreopen1/brief.md \
  && echo "  ok    brief.md ## Answers records the escalation decision" \
  || { echo "::error::brief.md: $(cat docs/specs/oreopen1/brief.md)"; fail=1; }

out="$(council open-round docs/specs/oreopen1 --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:review"' && printf '%s' "$out" | grep -qF 'carried from round 3: sonnet, opus' \
  && echo "  ok    a fourth round opens past the old ceiling, round 3's GREEN sonnet and opus carried (haiku was RED)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -d docs/specs/oreopen1/council/round-4 ] && echo "  ok    round-4 directory exists" || { echo "::error::round-4 missing"; fail=1; }

# --- tier-scaled ceiling (convergent-judge ask 1): 1 for Tier 1, 2 for Tier 2, 3 for Tier 3-4;
# reopen raises it by the same amount. Tier 3 at 3 is the oreopen1 block above, Tier 4 at 3 is
# oround1's ROUND ceiling=3.

echo "tier ceiling: Tier 1 - ROUND ceiling=1, a RED round 1 escalates (ceiling)"
mk_spec tceil1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tceil1#' docs/specs/tceil1/plan.md
git add -A && git commit -qm "tceil1: branch" >/dev/null
set_tier tceil1 1
council open-round docs/specs/tceil1 --commit >/dev/null
rdn="docs/specs/tceil1/council/round-1"
grep -q '^ceiling=1$' "$rdn/ROUND" && echo "  ok    tier 1: ROUND ceiling=1" \
  || { echo "::error::ROUND: $(cat "$rdn/ROUND" 2>&1)"; fail=1; }
write_seat "$rdn" sonnet RG; write_review "$rdn" PASS # tier 1 requires review; the recorded sonnet still counts
jout="$(council judge docs/specs/tceil1 --commit)"; jex=$?
[ "$jex" -eq 6 ] && printf '%s' "$jout" | grep -qF '"next":"escalated"' \
  && grep '"spec":"tceil1"' memory/stats/council.jsonl | grep '"round":1' | grep -qF '"escalate":"ceiling"' \
  && echo "  ok    tier 1: RED round 1 -> ESCALATE ceiling" \
  || { echo "::error::tier 1 judge: exit=$jex out=$jout"; fail=1; }

echo "tier ceiling: Tier 2 - round 1 RED repairs, round 2 RED escalates (ceiling), reopen gives 4"
mk_spec tceil2 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tceil2#' docs/specs/tceil2/plan.md
git add -A && git commit -qm "tceil2: branch" >/dev/null
set_tier tceil2 2
for n in 1 2; do
  council open-round docs/specs/tceil2 --commit >/dev/null
  rdn="docs/specs/tceil2/council/round-$n"
  grep -q '^ceiling=2$' "$rdn/ROUND" && echo "  ok    tier 2 round $n: ROUND ceiling=2" \
    || { echo "::error::ROUND: $(cat "$rdn/ROUND" 2>&1)"; fail=1; }
  if [ "$n" -eq 1 ]; then write_seat "$rdn" sonnet RG; else write_seat "$rdn" sonnet GR; fi # distinct asks: no no-progress
  write_review "$rdn" PASS
  jout="$(council judge docs/specs/tceil2 --commit)"; jex=$?
  if [ "$n" -lt 2 ]; then
    [ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    tier 2 round 1: RED, repair" \
      || { echo "::error::tier 2 round 1: exit=$jex out=$jout"; fail=1; }
  else
    [ "$jex" -eq 6 ] && printf '%s' "$jout" | grep -qF '"next":"escalated"' \
      && grep '"spec":"tceil2"' memory/stats/council.jsonl | grep '"round":2' | grep -qF '"escalate":"ceiling"' \
      && echo "  ok    tier 2 round 2: RED -> ESCALATE ceiling" \
      || { echo "::error::tier 2 round 2: exit=$jex out=$jout"; fail=1; }
  fi
done
council reopen docs/specs/tceil2 "owner: one more pass" --commit >/dev/null
[ "$(cat docs/specs/tceil2/council/CEILING 2>&1)" = "4" ] && echo "  ok    tier 2: reopen raises the ceiling to 4" \
  || { echo "::error::CEILING: $(cat docs/specs/tceil2/council/CEILING 2>&1)"; fail=1; }

# --- judged-rounds ceiling (convergent-judge-05): a STALE-folded round does not consume the
# tier's budget - the ceiling counts rounds with a non-STALE council.jsonl row only.

echo "judged ceiling: Tier 1 - round 1 goes STALE, round 2 opens (exit 0), round 2 RED escalates (ceiling)"
mk_spec tstale1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tstale1#' docs/specs/tstale1/plan.md
git add -A && git commit -qm "tstale1: branch" >/dev/null
set_tier tstale1 1
council open-round docs/specs/tstale1 --commit >/dev/null
write_seat docs/specs/tstale1/council/round-1 sonnet RG
echo "code change" > tstale1-code.txt
git add -A && git commit -qm "code commit while tstale1 round 1 is open" >/dev/null
out="$(council open-round docs/specs/tstale1 --commit 2>&1)"; ex=$?
row1="$(grep '"spec":"tstale1"' memory/stats/council.jsonl | grep '"round":1,' | tail -1)"
[ "$ex" -eq 0 ] && printf '%s' "$row1" | grep -qF '"verdict":"STALE"' && [ -f docs/specs/tstale1/council/round-2/ROUND ] \
  && echo "  ok    tier 1: STALE row for round 1, round 2 opened, exit 0 (not 6)" \
  || { echo "::error::tstale1 open-round: exit=$ex row1=$row1 out=$out"; fail=1; }
write_seat docs/specs/tstale1/council/round-2 sonnet RG; write_review docs/specs/tstale1/council/round-2 PASS
jout="$(council judge docs/specs/tstale1 --commit)"; jex=$?
[ "$jex" -eq 6 ] && grep '"spec":"tstale1"' memory/stats/council.jsonl | grep '"round":2,' | grep -qF '"escalate":"ceiling"' \
  && echo "  ok    tier 1: round 2 RED -> ESCALATE ceiling (the one judged round)" \
  || { echo "::error::tstale1 judge: exit=$jex out=$jout"; fail=1; }

echo "judged ceiling: Tier 2 - STALE, RED (repair), RED (ESCALATE ceiling); after reopen the next RED is repair"
mk_spec tstale2 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tstale2#' docs/specs/tstale2/plan.md
git add -A && git commit -qm "tstale2: branch" >/dev/null
set_tier tstale2 2
council open-round docs/specs/tstale2 --commit >/dev/null
write_seat docs/specs/tstale2/council/round-1 sonnet RG
echo "code change" > tstale2-code.txt
git add -A && git commit -qm "code commit while tstale2 round 1 is open" >/dev/null
out="$(council open-round docs/specs/tstale2 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep '"spec":"tstale2"' memory/stats/council.jsonl | grep '"round":1,' | grep -qF '"verdict":"STALE"' \
  && echo "  ok    tier 2: round 1 STALE, round 2 opened" || { echo "::error::tstale2 fold: exit=$ex out=$out"; fail=1; }
rdn="docs/specs/tstale2/council/round-2"
write_seat "$rdn" sonnet RG; write_review "$rdn" PASS
jout="$(council judge docs/specs/tstale2 --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    tier 2: round 2 RED -> repair (first judged round)" \
  || { echo "::error::tstale2 round 2: exit=$jex out=$jout"; fail=1; }
out="$(council open-round docs/specs/tstale2 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f docs/specs/tstale2/council/round-3/ROUND ] && echo "  ok    tier 2: round 3 opens (one judged round < 2)" \
  || { echo "::error::tstale2 open 3: exit=$ex out=$out"; fail=1; }
rdn="docs/specs/tstale2/council/round-3"
write_seat "$rdn" sonnet GR; write_review "$rdn" PASS # a different ask: no no-progress
jout="$(council judge docs/specs/tstale2 --commit)"; jex=$?
[ "$jex" -eq 6 ] && grep '"spec":"tstale2"' memory/stats/council.jsonl | grep '"round":3,' | grep -qF '"escalate":"ceiling"' \
  && echo "  ok    tier 2: round 3 RED -> ESCALATE ceiling (second judged round)" \
  || { echo "::error::tstale2 round 3: exit=$jex out=$jout"; fail=1; }
council reopen docs/specs/tstale2 "owner: one more pass" --commit >/dev/null
out="$(council open-round docs/specs/tstale2 --commit 2>&1)"; ex=$?
rdn="docs/specs/tstale2/council/round-4"
[ "$ex" -eq 0 ] && [ -f "$rdn/ROUND" ] || { echo "::error::tstale2 open 4: exit=$ex out=$out"; fail=1; }
write_seat "$rdn" sonnet RG; write_review "$rdn" PASS
jout="$(council judge docs/specs/tstale2 --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    tier 2: after reopen (ceiling 4), round 4 RED -> repair" \
  || { echo "::error::tstale2 round 4: exit=$jex out=$jout"; fail=1; }

# --- RED-rounds ceiling (convergent-judge-07): only rounds that ended RED count - a GREEN round
# followed by a code commit opens the next round instead of escalating.

echo "RED ceiling: Tier 1 - round 1 GREEN, a code commit, round 2 opens (exit 0); round 2 RED escalates (ceiling)"
mk_spec tgreen1 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tgreen1#' docs/specs/tgreen1/plan.md
git add -A && git commit -qm "tgreen1: branch" >/dev/null
set_tier tgreen1 1
council open-round docs/specs/tgreen1 --commit >/dev/null
write_seat docs/specs/tgreen1/council/round-1 sonnet GG; write_review docs/specs/tgreen1/council/round-1 PASS
jout="$(council judge docs/specs/tgreen1 --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' || { echo "::error::tgreen1 round 1: exit=$jex out=$jout"; fail=1; }
echo "code change" > tgreen1-code.txt
git add -A && git commit -qm "code commit after tgreen1 round 1 GREEN" >/dev/null
out="$(council open-round docs/specs/tgreen1 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'round 2 opened' && printf '%s' "$out" | tail -1 | grep -qF '"next":"dispatch:review"' \
  && ! grep '"spec":"tgreen1"' memory/stats/council.jsonl | grep -qF '"verdict":"ESCALATE"' \
  && echo "  ok    tier 1: GREEN then a commit -> round 2 opened, next dispatch:review, no ESCALATE row" \
  || { echo "::error::tgreen1 open 2: exit=$ex out=$out"; fail=1; }
write_seat docs/specs/tgreen1/council/round-2 sonnet RG; write_review docs/specs/tgreen1/council/round-2 PASS
jout="$(council judge docs/specs/tgreen1 --commit)"; jex=$?
[ "$jex" -eq 6 ] && grep '"spec":"tgreen1"' memory/stats/council.jsonl | grep '"round":2,' | grep -qF '"escalate":"ceiling"' \
  && echo "  ok    tier 1: round 2 RED -> ESCALATE ceiling (the one RED round)" \
  || { echo "::error::tgreen1 judge 2: exit=$jex out=$jout"; fail=1; }

echo "RED ceiling: Tier 2 - GREEN, RED (repair), RED (ESCALATE ceiling); after reopen (C=4) RED (repair), RED (ESCALATE ceiling)"
mk_spec tgreen2 2
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/tgreen2#' docs/specs/tgreen2/plan.md
git add -A && git commit -qm "tgreen2: branch" >/dev/null
set_tier tgreen2 2
tg2_round() { # tg2_round <n> <sonnet-pattern> <expected-exit> <label> - commit code (n>1), open, seat, judge
  local n="$1" pat="$2" want="$3" label="$4" rdn="docs/specs/tgreen2/council/round-$1" o e
  if [ "$n" -gt 1 ]; then
    echo "code change $n" > tgreen2-code.txt
    git add -A && git commit -qm "tgreen2: code before round $n" >/dev/null
  fi
  o="$(council open-round docs/specs/tgreen2 --commit 2>&1)"; e=$?
  [ "$e" -eq 0 ] && [ -f "$rdn/ROUND" ] || { echo "::error::tgreen2 open $n: exit=$e out=$o"; fail=1; return; }
  write_seat "$rdn" sonnet "$pat"; write_review "$rdn" PASS
  o="$(council judge docs/specs/tgreen2 --commit)"; e=$?
  [ "$e" -eq "$want" ] && echo "  ok    $label" || { echo "::error::tgreen2 round $n: exit=$e out=$o"; fail=1; }
}
tg2_round 1 GG 0 "tier 2: round 1 GREEN"
tg2_round 2 RG 0 "tier 2: round 2 RED -> repair (first RED round)"
tg2_round 3 GR 6 "tier 2: round 3 RED -> ESCALATE ceiling (second RED round)"
grep '"spec":"tgreen2"' memory/stats/council.jsonl | grep '"round":3,' | grep -qF '"escalate":"ceiling"' \
  || { echo "::error::tgreen2 round 3 is not ESCALATE ceiling"; fail=1; }
council reopen docs/specs/tgreen2 "owner: one more pass" --commit >/dev/null
tg2_round 4 RG 0 "tier 2 after reopen (C=4): round 4 RED -> repair (the escalated round 3 counted)"
tg2_round 5 GR 6 "tier 2 after reopen: round 5 RED -> ESCALATE ceiling (exactly two more RED rounds)"
grep '"spec":"tgreen2"' memory/stats/council.jsonl | grep '"round":5,' | grep -qF '"escalate":"ceiling"' \
  || { echo "::error::tgreen2 round 5 is not ESCALATE ceiling"; fail=1; }

# --- status --json after committed verbs (autonomous-cycle-19: R1, R2, R3, R7, R25) -----------
# The council round found the suite asserted only each verb's own emit, never `status --json`
# afterward - which is exactly the seam where `--commit` (used by both drivers, always) moved
# HEAD past what plain-equality checks expected. These walk the real verb sequence with
# --commit throughout and assert `status` after each step, the same way a driver reads it.

echo "status --json: real --commit sequence - RED judge -> repair, a code commit -> open-round, ceiling -> escalated, reopen -> repair (ADR-013 D3), round 4 opens (R1/C-1, R7/M-4, R25)"
mk_open_spec realverbs 3
set_tier realverbs 2
# convergent-judge: Tier 2's own ceiling is 2; this walk needs three rounds before the ceiling,
# so it pins council/CEILING at 3 (the file still wins over the tier default). reopen adds 2 -> 5.
mkdir -p docs/specs/realverbs/council && printf '3\n' > docs/specs/realverbs/council/CEILING
git add -A && git commit -qm "realverbs: ceiling 3" >/dev/null
council open-round docs/specs/realverbs --commit >/dev/null
seat_report sonnet 1 GRG | council record-seat docs/specs/realverbs 1 sonnet >/dev/null
seat_report opus 1 GGG | council record-seat docs/specs/realverbs 1 opus >/dev/null
printf 'VERDICT: PASS\nReviewed the diff against the story files.\n' | council record-seat docs/specs/realverbs 1 review >/dev/null
jout="$(council judge docs/specs/realverbs --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    round 1 judged RED --commit (one evidenced RED, ask 2)" \
  || { echo "::error::round 1 judge: exit=$jex out=$jout"; fail=1; }

out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.next == "repair"' >/dev/null 2>&1 && echo "  ok    status --json next:repair right after the committed RED judge (not open-round)" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -e '.verdict == "RED"' >/dev/null 2>&1 && echo "  ok    status --json verdict:RED" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -e '.red == [2]' >/dev/null 2>&1 && echo "  ok    status --json red:[2]" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -e '.round_dir == "docs/specs/realverbs/council/round-1"' >/dev/null 2>&1 && echo "  ok    status --json round_dir names round 1" \
  || { echo "::error::status: $out"; fail=1; }

mkdir -p src
echo "a real code change" > src/x.txt
git add -A && git commit -qm "real code change on realverbs" >/dev/null
out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.next == "open-round"' >/dev/null 2>&1 && echo "  ok    a real (non-paperwork) commit flips next from repair to open-round" \
  || { echo "::error::status: $out"; fail=1; }

for n in 2 3; do
  council open-round docs/specs/realverbs --commit >/dev/null
  seat_report sonnet "$n" GRG | council record-seat docs/specs/realverbs "$n" sonnet >/dev/null
  seat_report opus "$n" GGG | council record-seat docs/specs/realverbs "$n" opus >/dev/null
  printf 'VERDICT: PASS\nReviewed the diff.\n' | council record-seat docs/specs/realverbs "$n" review >/dev/null
  council judge docs/specs/realverbs --commit >/dev/null
done
out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.next == "escalated"' >/dev/null 2>&1 && echo "  ok    three committed RED rounds hit the ceiling -> status next:escalated" \
  || { echo "::error::status: $out"; fail=1; }

council reopen docs/specs/realverbs "owner: fix and re-round" --commit >/dev/null
[ -f docs/specs/realverbs/council/REOPEN ] && grep -qE '^round=3 ' docs/specs/realverbs/council/REOPEN \
  && echo "  ok    council/REOPEN names round 3 (C4)" || { echo "::error::REOPEN: $(cat docs/specs/realverbs/council/REOPEN 2>&1)"; fail=1; }
out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.next == "repair"' >/dev/null 2>&1 && echo "  ok    status --json next:repair after reopen (ADR-013 D3), not stuck on escalated" \
  || { echo "::error::status: $out"; fail=1; }

out="$(council open-round docs/specs/realverbs --commit)"; ex=$?
[ "$ex" -eq 0 ] && [ -d docs/specs/realverbs/council/round-4 ] && echo "  ok    open-round opens round 4 past the raised ceiling" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }

echo "status --json: review key - the newest row's review verdict verbatim (R30/C3)"
seat_report sonnet 4 GGG | council record-seat docs/specs/realverbs 4 sonnet >/dev/null
seat_report opus 4 GGG | council record-seat docs/specs/realverbs 4 opus >/dev/null
printf 'VERDICT: BLOCK\n## Major\n- major [ask 2]: still missing coverage.\n' | council record-seat docs/specs/realverbs 4 review >/dev/null
jout="$(council judge docs/specs/realverbs --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"repair"' && echo "  ok    round 4 judged RED --commit (review BLOCK, both seats GREEN)" \
  || { echo "::error::round 4 judge: exit=$jex out=$jout"; fail=1; }
out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.review == "BLOCK" and .red == [] and .next == "repair"' >/dev/null 2>&1 \
  && echo "  ok    status --json review:BLOCK, red:[], next:repair" || { echo "::error::status: $out"; fail=1; }

council open-round docs/specs/realverbs --commit >/dev/null
seat_report sonnet 5 GGG | council record-seat docs/specs/realverbs 5 sonnet >/dev/null
seat_report opus 5 GGG | council record-seat docs/specs/realverbs 5 opus >/dev/null
printf 'VERDICT: PASS\nEverything checks out.\n' | council record-seat docs/specs/realverbs 5 review >/dev/null
jout="$(council judge docs/specs/realverbs --commit)"; jex=$?
[ "$jex" -eq 0 ] && printf '%s' "$jout" | grep -qF '"next":"green"' && echo "  ok    round 5 judged GREEN --commit (review PASS, both seats GREEN)" \
  || { echo "::error::round 5 judge: exit=$jex out=$jout"; fail=1; }
out="$(council status docs/specs/realverbs --json)"
printf '%s' "$out" | jq -e '.review == "PASS"' >/dev/null 2>&1 && echo "  ok    status --json review:PASS after a GREEN round" \
  || { echo "::error::status: $out"; fail=1; }

mk_spec freshreview 1
out="$(council status docs/specs/freshreview --json)"
printf '%s' "$out" | jq -e '.review == null' >/dev/null 2>&1 && echo "  ok    status --json review:null on a fresh spec with no council row" \
  || { echo "::error::status: $out"; fail=1; }

echo "status --json: an open round gone stale before any seat is recorded, and with one already present (R2)"
mk_open_spec stalerd1 2
set_tier stalerd1 1
council open-round docs/specs/stalerd1 --commit >/dev/null
echo "code change" > stalerd1-code.txt
git add -A && git commit -qm "real code change while stalerd1 round 1 is open, no seat recorded yet" >/dev/null
out="$(council status docs/specs/stalerd1 --json)"
printf '%s' "$out" | jq -e '.stale == true' >/dev/null 2>&1 && echo "  ok    stale:true with no seat file recorded yet" \
  || { echo "::error::status: $out"; fail=1; }
printf '%s' "$out" | jq -e '.next == "open-round"' >/dev/null 2>&1 && echo "  ok    next:open-round, never dispatch:/judge, while stale" \
  || { echo "::error::status: $out"; fail=1; }

rds1="docs/specs/stalerd1/council/round-1"
write_seat "$rds1" sonnet GG
out="$(council status docs/specs/stalerd1 --json)"
printf '%s' "$out" | jq -e '.stale == true and .next == "open-round"' >/dev/null 2>&1 \
  && echo "  ok    same result once a seat file is already present" \
  || { echo "::error::status: $out"; fail=1; }

echo "status --json: an exhausted seat (both attempts malformed) drops out of missing, next reaches judge (R3/C-2)"
mk_open_spec exhaust1 2
set_tier exhaust1 3
council open-round docs/specs/exhaust1 --commit >/dev/null
printf 'garbage attempt 1\n' | council record-seat docs/specs/exhaust1 1 opus >/dev/null 2>&1
printf 'garbage attempt 2\n' | council record-seat docs/specs/exhaust1 1 opus >/dev/null 2>&1
rdex="docs/specs/exhaust1/council/round-1"
[ -f "$rdex/opus.attempt-2.md" ] && [ ! -f "$rdex/opus.md" ] && echo "  ok    opus exhausted both attempts on disk" \
  || { echo "::error::files: $(ls "$rdex")"; fail=1; }
out="$(council status docs/specs/exhaust1 --json)"
printf '%s' "$out" | jq -r '.missing | sort | join(",")' | expect "missing excludes the exhausted opus seat" "review"

seat_report sonnet 1 GG | council record-seat docs/specs/exhaust1 1 sonnet >/dev/null
printf 'VERDICT: PASS\nReviewed.\n' | council record-seat docs/specs/exhaust1 1 review >/dev/null
out="$(council status docs/specs/exhaust1 --json)"
printf '%s' "$out" | jq -r .next | expect "every other required seat recorded -> next reaches judge" "judge"

council judge docs/specs/exhaust1 >/dev/null 2>&1
row="$(grep '"spec":"exhaust1"' memory/stats/council.jsonl | tail -1)"
[ -n "$row" ] && printf '%s' "$row" | grep -q '"opus":"ABSENT"' \
  && echo "  ok    judge ran and the row carries opus:ABSENT" || { echo "::error::row: $row"; fail=1; }
printf '%s' "$row" | grep -qF '"verdict":"ESCALATE"' && printf '%s' "$row" | grep -qF '"escalate":"env"' \
  && echo "  ok    Tier 3, opus ABSENT + sonnet GREEN + review PASS -> ESCALATE env, not RED with nothing to repair (R16/M-5)" \
  || { echo "::error::row: $row"; fail=1; }
printf '%s' "$row" | grep -qE '"note":"[^"]*opus[^"]*"' && echo "  ok    row note names the absent seat" \
  || { echo "::error::row note: $row"; fail=1; }
grep -qF 'opus.attempt-2.md' docs/specs/exhaust1/plan.md && echo "  ok    ## Needs a human points at opus's attempt-2.md" \
  || { echo "::error::plan.md: $(grep -A6 '^## Needs a human' docs/specs/exhaust1/plan.md)"; fail=1; }

echo "judge: Tier 3, review ABSENT, haiku+sonnet+opus GREEN -> ESCALATE env, not RED with red:[] (R16/M-5, minor 32)"
mk_open_spec envpartial2 2
set_tier envpartial2 3
rdp2="$(mk_open_round envpartial2 1 3)"
write_seat "$rdp2" haiku GG
write_seat "$rdp2" sonnet GG
write_seat "$rdp2" opus GG
write_absent "$rdp2" review
out="$(council judge docs/specs/envpartial2)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | grep -qF '"next":"escalated"' && echo "  ok    review ABSENT with every seat GREEN -> ESCALATE env" \
  || { echo "::error::envpartial2: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"envpartial2"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":"env"' && printf '%s' "$row" | grep -qF '"review":"ABSENT"' \
  && echo "  ok    row escalate:env, review ABSENT" || { echo "::error::row: $row"; fail=1; }

echo "judge: Tier 3, haiku ABSENT but ask 2 RED elsewhere -> RED repair, not ESCALATE env (R16 boundary)"
mk_open_spec envpartial3 2
set_tier envpartial3 3
rdp3="$(mk_open_round envpartial3 1 3)"
write_absent "$rdp3" haiku
write_seat "$rdp3" sonnet GR
write_seat "$rdp3" opus GG
write_review "$rdp3" PASS
out="$(council judge docs/specs/envpartial3)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    ABSENT haiku + a real RED elsewhere -> RED repair, not env" \
  || { echo "::error::envpartial3: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"envpartial3"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"escalate":null' && echo "  ok    row escalate:null (not env)" || { echo "::error::row: $row"; fail=1; }

echo "open-round: the STALE fold writes '' for a seat the round's tier does not require, not ABSENT (R21/minor 20)"
mk_open_spec stalenr1 2
set_tier stalenr1 2
council open-round docs/specs/stalenr1 --commit >/dev/null
write_seat "docs/specs/stalenr1/council/round-1" sonnet GG   # has_seat=1 so the fold (not an in-place re-stamp) fires
echo "code change" > stalenr1-code.txt
git add -A && git commit -qm "real code change on stalenr1 round 1, sonnet already recorded" >/dev/null
council open-round docs/specs/stalenr1 --commit >/dev/null
row="$(grep '"spec":"stalenr1"' memory/stats/council.jsonl | grep '"round":1' | tail -1)"
printf '%s' "$row" | grep -qF '"haiku":""' && echo "  ok    STALE row: haiku (not required at tier 2) is '', not ABSENT" \
  || { echo "::error::row: $row"; fail=1; }
printf '%s' "$row" | grep -qF '"opus":""' && echo "  ok    STALE row: opus (not required at tier 2 either) is ''" \
  || { echo "::error::row: $row"; fail=1; }
[ -d docs/specs/stalenr1/council/round-2 ] && echo "  ok    round 2 opened (the fold path, not an in-place re-stamp)" \
  || { echo "::error::round-2 missing - the has_seat=0 re-stamp path fired instead of the fold"; fail=1; }

# ============================================================================================
# Story 14: one scenario per story 01 criterion (LR19, LR21/r2m1, LR25, m-4, m-10, N-m7)
# ============================================================================================

echo "judge: attempts counts every stored file per seat - a re-ask counts 2, not 1 (LR19, cmd_judge)"
mk_open_spec lr19a 2
set_tier lr19a 1
rd19a="$(mk_open_round lr19a 1)"
write_review "$rd19a" PASS
cp "$rd19a/review.md" "$rd19a/review.attempt-1.md"   # a re-asked seat: attempt-1 + the final .md both on disk
out="$(council judge docs/specs/lr19a)"; ex=$?
[ "$ex" -eq 0 ] || { echo "::error::lr19a judge: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"lr19a"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"attempts":2' && echo "  ok    attempts:2 for one seat's .md + .attempt-1.md" \
  || { echo "::error::row: $row"; fail=1; }

echo "escalate: attempts counts a re-asked seat's files too, across the seats it does see (LR19, write_escalate_row_for_round)"
mk_open_spec lr19b 2
set_tier lr19b 3
rd19b="$(mk_open_round lr19b 1)"
write_seat "$rd19b" haiku GG
cp "$rd19b/haiku.md" "$rd19b/haiku.attempt-1.md"     # haiku re-asked: 2 files
write_seat "$rd19b" sonnet GG                         # sonnet: 1 file
write_seat "$rd19b" opus GG                           # opus: 1 file
# review (required at tier 3) never dispatched -> escalate has a real missing seat
out="$(council escalate docs/specs/lr19b 2>&1)"; ex=$?
[ "$ex" -eq 6 ] || { echo "::error::lr19b escalate: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"lr19b"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"attempts":4' && echo "  ok    attempts:4 (haiku 2 + sonnet 1 + opus 1 + review 0)" \
  || { echo "::error::row: $row"; fail=1; }

echo "open-round: the STALE fold's attempts also counts a re-asked seat's attempt-1 file (LR19, write_stale_row)"
mk_open_spec lr19c 2
set_tier lr19c 2
council open-round docs/specs/lr19c --commit >/dev/null
rd19c="docs/specs/lr19c/council/round-1"
write_seat "$rd19c" sonnet GG
cp "$rd19c/sonnet.md" "$rd19c/sonnet.attempt-1.md"
echo "code change" > lr19c-code.txt
git add -A && git commit -qm "real code change on lr19c round 1" >/dev/null
council open-round docs/specs/lr19c --commit >/dev/null
row="$(grep '"spec":"lr19c"' memory/stats/council.jsonl | grep '"round":1,' | tail -1)"
printf '%s' "$row" | grep -qF '"attempts":2' && echo "  ok    STALE row attempts:2 (sonnet .md + .attempt-1.md)" \
  || { echo "::error::row: $row"; fail=1; }

echo "judge: round-number match is exact - a closed round 10's row never satisfies round 1 (LR21/r2m1)"
mk_open_spec lr21a 2
set_tier lr21a 1
printf '{"ts":"2020-01-01T00:00:00Z","spec":"lr21a","round":10,"verdict":"ESCALATE","head":"aaaaaaa","pack":"demo-pack","asks":2,"red":[],"red_unevidenced":[],"na":0,"review":"","haiku":"","haiku_model":"unknown","sonnet":"","sonnet_model":"unknown","opus":"","opus_model":"unknown","attempts":0,"escalate":"ceiling","note":""}\n' >> memory/stats/council.jsonl
rd21a="$(mk_open_round lr21a 1)"
write_review "$rd21a" PASS
out="$(council status docs/specs/lr21a --json)"
printf '%s' "$out" | jq -e '.open == true and .round == 1' >/dev/null 2>&1 && echo "  ok    status --json: round 1 reported open despite a round-10 row on record" \
  || { echo "::error::status: $out"; fail=1; }
out="$(council judge docs/specs/lr21a)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"green"' && echo "  ok    judge round 1 -> green, not short-circuited by round 10's row" \
  || { echo "::error::lr21a judge: exit=$ex out=$out"; fail=1; }
n_round1_rows="$(grep -c '"spec":"lr21a".*"round":1,' memory/stats/council.jsonl)"
[ "$n_round1_rows" -eq 1 ] && echo "  ok    exactly one round-1 row was written (round 10's row did not block it)" \
  || { echo "::error::round-1 row count: $n_round1_rows"; fail=1; }

echo "judge: **Council:** replaces the template placeholder in place, before **Shipped:**, not at file EOF (LR25/C7)"
mk_open_spec lr25a 2
set_tier lr25a 1
rd25a="$(mk_open_round lr25a 1)"
write_review "$rd25a" PASS
council judge docs/specs/lr25a >/dev/null
cln1="$(grep -n '^\*\*Council:\*\*' docs/specs/lr25a/plan.md | tail -1 | cut -d: -f1)"
shln1="$(grep -n '^\*\*Shipped:\*\*' docs/specs/lr25a/plan.md | head -1 | cut -d: -f1)"
[ -n "$cln1" ] && [ -n "$shln1" ] && [ "$cln1" -lt "$shln1" ] && echo "  ok    round 1's Council line sits before Shipped, not appended after it" \
  || { echo "::error::plan.md order: council@$cln1 shipped@$shln1"; fail=1; }
before_ct="$(grep -c '^\*\*Council:\*\*' docs/specs/lr25a/plan.md)"
council judge docs/specs/lr25a >/dev/null
after_ct="$(grep -c '^\*\*Council:\*\*' docs/specs/lr25a/plan.md)"
[ "$before_ct" -eq "$after_ct" ] && echo "  ok    a second judge on the same round adds no new Council line (idempotent)" \
  || { echo "::error::before=$before_ct after=$after_ct"; fail=1; }

echo "judge: with a prior round's Council line already on record, the next round's line inserts right after it, not at EOF (LR25/C7)"
mk_open_spec lr25b 2
set_tier lr25b 1
sed -i 's/^\*\*Council:\*\* <.*/**Council:** GREEN round 1, 2020-01-01, at 1234567, pack demo-pack/' docs/specs/lr25b/plan.md
git add -A && git commit -qm "lr25b: seed a round-1 Council line" >/dev/null
rd25b="$(mk_open_round lr25b 2)"
write_review "$rd25b" PASS
council judge docs/specs/lr25b >/dev/null
shln2="$(grep -n '^\*\*Shipped:\*\*' docs/specs/lr25b/plan.md | head -1 | cut -d: -f1)"
newest_cln2="$(grep -n '^\*\*Council:\*\*' docs/specs/lr25b/plan.md | tail -1 | cut -d: -f1)"
[ -n "$newest_cln2" ] && [ -n "$shln2" ] && [ "$newest_cln2" -lt "$shln2" ] && echo "  ok    round 2's Council line inserts before Shipped, right after round 1's" \
  || { echo "::error::council lines vs shipped@$shln2: newest@$newest_cln2"; fail=1; }
grep -A1 -F '**Council:** GREEN round 1' docs/specs/lr25b/plan.md | tail -1 | grep -qF 'round 2' \
  && echo "  ok    round 2's line sits directly after round 1's line, not at file EOF" \
  || { echo "::error::plan.md: $(cat docs/specs/lr25b/plan.md)"; fail=1; }
marker_fn="$(awk '/^marker\(\)/{flag=1} flag{print} flag && /^}/{exit}' scripts/cycle.sh)"
eval "$marker_fn"
marker_val="$(marker docs/specs/lr25b/plan.md Council)"
printf '%s' "$marker_val" | grep -qF 'round 2' && echo "  ok    marker \"\$PLAN\" Council returns the newest (round 2) line" \
  || { echo "::error::marker returned: $marker_val"; fail=1; }

echo "judge: a human.jsonl REJECTED row timestamped the same second as ROUND.opened still overrides (m-4, >= not >)"
mk_open_spec m4a 2
set_tier m4a 1
rd4a="$(mk_open_round m4a 1)"
opened_ts="$(sed -n 's/^opened=//p' "$rd4a/ROUND")"
write_review "$rd4a" PASS
printf '{"ts":"%s","spec":"m4a","verdict":"REJECTED","by":"Test Owner","head":"%s","pack":"demo-pack","note":"same-second override"}\n' \
  "$opened_ts" "$HEAD7" >> memory/stats/human.jsonl
out="$(council judge docs/specs/m4a)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"repair"' && echo "  ok    a same-second REJECTED still overrides an all-GREEN round" \
  || { echo "::error::m4a judge: exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"m4a"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"verdict":"RED"' && echo "  ok    row verdict RED (override wins, not the round's own GREEN)" \
  || { echo "::error::row: $row"; fail=1; }

echo "council.jsonl: each ledger row writer does exactly one printf ... >> per row - structural proof, no partial-write path (m-10)"
sites="$(grep -c '>> memory/stats/council.jsonl' scripts/cycle.sh)"
[ "$sites" -eq 3 ] && echo "  ok    exactly 3 append sites (cmd_judge, write_stale_row, write_escalate_row_for_round), one printf each" \
  || { echo "::error::found $sites append sites to council.jsonl, expected 3"; fail=1; }

echo "escalate: a note carrying a token-shaped string lands masked via redact_note - raw string never reaches the ledger or plan.md (N-m7)"
mk_open_spec nm7a 2
set_tier nm7a 1
mk_open_round nm7a 1 >/dev/null   # sonnet (the only required seat at tier 1) never dispatched
secret="sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
out="$(council escalate docs/specs/nm7a --reason ceiling "leaked token $secret" 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && echo "  ok    escalate with a token-shaped note -> exit 6" || { echo "::error::exit=$ex out=$out"; fail=1; }
row="$(grep '"spec":"nm7a"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF "$secret" && { echo "::error::raw token leaked into council.jsonl: $row"; fail=1; } \
  || echo "  ok    raw token absent from council.jsonl"
printf '%s' "$row" | grep -qF '[VULYK:REDACTED]' && echo "  ok    row note masked by redact.sh" || { echo "::error::row not masked: $row"; fail=1; }
grep -qF "$secret" docs/specs/nm7a/plan.md && { echo "::error::raw token leaked into plan.md"; fail=1; } \
  || echo "  ok    raw token absent from plan.md"
grep -qF '[VULYK:REDACTED]' docs/specs/nm7a/plan.md && echo "  ok    plan.md's ## Needs a human note is masked too" \
  || { echo "::error::plan.md: $(cat docs/specs/nm7a/plan.md)"; fail=1; }

# --- regression proof: the same six checks run against 3e200bb's cycle.sh (no working-tree ---
# checkout/stash - a second fixture copy per story 14's own instruction) and against the
# branch's own scripts/cycle.sh, so ## Implementation notes can quote observed FAIL/ok labels.
# A `[branch]` result other than ok now sets $fail (C5); a pinned `[<sha>]` result only sets
# $fail when the probe's name is listed in $PIN_MUST_FAIL for that run - empty by default, so
# the pre-fix runs above stay print-only exactly as before unless a story explicitly pins one.

pin_cycle() { # pin_cycle <sha> <dest> - wraps `git -C "$SRC" show <sha>:scripts/cycle.sh`
  # (C5): on a non-zero exit or an empty result, prints "  [<sha>] unavailable: <reason>",
  # sets $fail, and returns 1 so the caller skips that block's probes instead of running them
  # against a truncated/empty cycle.sh.
  local sha="$1" dest="$2" errfile reason gex
  errfile="$(mktemp)"
  git -C "$SRC" show "$sha:scripts/cycle.sh" > "$dest" 2>"$errfile"; gex=$?
  if [ "$gex" -ne 0 ] || [ ! -s "$dest" ]; then
    reason="$(head -1 "$errfile")"
    [ -n "$reason" ] || reason="empty"
    echo "  [$sha] unavailable: $reason"
    fail=1
    rm -f "$errfile"
    return 1
  fi
  rm -f "$errfile"
  return 0
}

check_probe_result() { # check_probe_result <wlabel> <probe-name> <result> (C5) - branch: any
  # non-ok result sets $fail; a pinned label: only probes named in $PIN_MUST_FAIL must be FAIL.
  local wlabel="$1" name="$2" result="$3"
  if [ "$wlabel" = branch ]; then
    [ "$result" = ok ] || { echo "::error::[$wlabel] $name: expected ok, got $result"; fail=1; }
  else
    case " ${PIN_MUST_FAIL:-} " in
      *" $name "*) [ "$result" = FAIL ] || { echo "::error::[$wlabel] $name: expected FAIL (PIN_MUST_FAIL), got $result"; fail=1; } ;;
    esac
  fi
}

echo "=== regression proof: story 14's six checks replayed against 3e200bb's cycle.sh vs. the branch's ==="
OLDCYCLE="$(mktemp)"
PIN_MUST_FAIL=""
pin_cycle 3e200bb "$OLDCYCLE" || OLDCYCLE=""

probe_lr19() {
  mk_open_spec plr19 2; set_tier plr19 1 >/dev/null
  local rd; rd="$(mk_open_round plr19 1)"
  # sonnet (Tier 1's seat before 0.18) and review (its seat since, ADR-013 D1) both present, so
  # the probe reads the same on a pinned pre-0.18 cycle.sh and on the branch: review re-asked
  # (2 files) + sonnet (1) = 3, where a re-ask counted once would give 2.
  write_seat "$rd" sonnet GG
  write_review "$rd" PASS
  cp "$rd/review.md" "$rd/review.attempt-1.md"
  council judge docs/specs/plr19 >/dev/null 2>&1
  local row; row="$(grep '"spec":"plr19"' memory/stats/council.jsonl | tail -1)"
  printf '%s' "$row" | grep -qF '"attempts":3' && echo ok || echo FAIL
}
probe_lr21() {
  mk_open_spec plr21 2; set_tier plr21 1 >/dev/null
  printf '{"ts":"2020-01-01T00:00:00Z","spec":"plr21","round":10,"verdict":"ESCALATE","head":"aaaaaaa","pack":"demo-pack","asks":2,"red":[],"red_unevidenced":[],"na":0,"review":"","haiku":"","haiku_model":"unknown","sonnet":"","sonnet_model":"unknown","opus":"","opus_model":"unknown","attempts":0,"escalate":"ceiling","note":""}\n' >> memory/stats/council.jsonl
  local rd; rd="$(mk_open_round plr21 1)"
  write_seat "$rd" sonnet GG; write_review "$rd" PASS # both rosters' Tier 1 seat (see probe_lr19)
  council judge docs/specs/plr21 >/dev/null 2>&1
  local n; n="$(grep -c '"spec":"plr21".*"round":1,' memory/stats/council.jsonl)"
  [ "$n" -eq 1 ] && echo ok || echo FAIL
}
probe_lr25() {
  mk_open_spec plr25 2; set_tier plr25 1 >/dev/null
  local rd; rd="$(mk_open_round plr25 1)"
  write_seat "$rd" sonnet GGG; write_review "$rd" PASS # both rosters' Tier 1 seat (see probe_lr19)
  council judge docs/specs/plr25 >/dev/null 2>&1
  local cln shln
  cln="$(grep -n '^\*\*Council:\*\*' docs/specs/plr25/plan.md | tail -1 | cut -d: -f1)"
  shln="$(grep -n '^\*\*Shipped:\*\*' docs/specs/plr25/plan.md | head -1 | cut -d: -f1)"
  [ -n "$cln" ] && [ -n "$shln" ] && [ "$cln" -lt "$shln" ] && echo ok || echo FAIL
}
probe_m4() {
  mk_open_spec pm4 2; set_tier pm4 1 >/dev/null
  local rd; rd="$(mk_open_round pm4 1)"
  local opened; opened="$(sed -n 's/^opened=//p' "$rd/ROUND")"
  write_seat "$rd" sonnet GG; write_review "$rd" PASS # both rosters' Tier 1 seat (see probe_lr19)
  printf '{"ts":"%s","spec":"pm4","verdict":"REJECTED","by":"t","head":"%s","pack":"demo-pack","note":"x"}\n' "$opened" "$HEAD7" >> memory/stats/human.jsonl
  local out; out="$(council judge docs/specs/pm4 2>&1)"
  printf '%s' "$out" | grep -qF '"next":"repair"' && echo ok || echo FAIL
}
probe_m10() {
  local sites; sites="$(grep -c '>> memory/stats/council.jsonl' scripts/cycle.sh)"
  [ "$sites" -eq 3 ] && echo ok || echo FAIL
}
probe_nm7() {
  mk_open_spec pnm7 2; set_tier pnm7 1 >/dev/null
  mk_open_round pnm7 1 >/dev/null
  local secret="sk-ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  council escalate docs/specs/pnm7 --reason ceiling "leaked token $secret" >/dev/null 2>&1
  local row; row="$(grep '"spec":"pnm7"' memory/stats/council.jsonl | tail -1)"
  if printf '%s' "$row" | grep -qF "$secret"; then echo FAIL
  else printf '%s' "$row" | grep -qF '[VULYK:REDACTED]' && echo ok || echo FAIL
  fi
}

run_wall_probes() { # run_wall_probes <label> <cycle.sh-path> [extra-probe-fn ...] - a scratch
  # hive with the given cycle.sh swapped in, reusing this suite's own mk_spec/mk_round/
  # write_seat/council helpers (they only touch $T/$HEAD7/cwd) by rebinding those two globals
  # for the duration. Story 14's own six probes always run; story 15 extends this same runner
  # with a second pinned version (b9f36e8) by passing its own probe function names as extra
  # args, rather than writing a second copy of this scaffolding.
  local wlabel="$1" cyclesrc="$2" wt; shift 2
  wt="$(mktemp -d)"
  local save_t="$T" save_head7="$HEAD7" save_pwd="$PWD"
  T="$wt"
  cd "$wt" || { echo "::error::wall probe [$wlabel]: cannot cd to $wt"; fail=1; return; }
  git init -q -b main . && git config user.email t@t && git config user.name "Test Owner" && git config core.autocrlf false
  mkdir -p scripts memory/stats docs/specs .claude
  cp "$SRC"/scripts/lib.sh "$SRC"/scripts/journal.sh "$SRC"/scripts/scope-check.sh "$SRC"/scripts/redact.sh scripts/
  cp "$cyclesrc" scripts/cycle.sh
  # Story 17 adds DRIVER here too: without it, an untracked DRIVER file dirties open-round's
  # whole-tree "clean" precondition (L1778) and probe_gated's matching-stamp call fails for an
  # unrelated reason instead of proceeding.
  printf '.vulyk/\ndocs/specs/*/PAUSE\ndocs/specs/*/DRIVER\n' > .gitignore
  # Story 16's close-story probes (returned:/r2m2/r2m9) need a ## Commands table too - the six
  # story 14/15 probes above never call close-story, so this was never needed until now.
  cat > CLAUDE.md <<'MDEOF'
# Fixture hive

## Commands

| Purpose | Command |
|---|---|
| Fixture: always succeeds | `true` |
| r2m9 fixture: a cell that is itself an &&-joined command | `sh -c 'true && true'` |
MDEOF
  git add -A && git commit -qm init >/dev/null
  HEAD7="$(git rev-parse --short HEAD)"

  local r
  r="$(probe_lr19)";  echo "  [$wlabel] LR19 attempts (cmd_judge):        $r"; check_probe_result "$wlabel" probe_lr19 "$r"
  r="$(probe_lr21)";  echo "  [$wlabel] LR21/r2m1 round-number match:      $r"; check_probe_result "$wlabel" probe_lr21 "$r"
  r="$(probe_lr25)";  echo "  [$wlabel] LR25/C7 Council line placement:    $r"; check_probe_result "$wlabel" probe_lr25 "$r"
  r="$(probe_m4)";    echo "  [$wlabel] m-4 same-second override:          $r"; check_probe_result "$wlabel" probe_m4 "$r"
  r="$(probe_m10)";   echo "  [$wlabel] m-10 atomic ledger append:         $r"; check_probe_result "$wlabel" probe_m10 "$r"
  r="$(probe_nm7)";   echo "  [$wlabel] N-m7 note through redact:          $r"; check_probe_result "$wlabel" probe_nm7 "$r"

  local extra
  for extra in "$@"; do
    r="$($extra)"
    echo "  [$wlabel] $extra:  $r"
    check_probe_result "$wlabel" "$extra" "$r"
  done

  cd "$save_pwd" || true
  T="$save_t"; HEAD7="$save_head7"
  rm -rf "$wt"
}

if [ -n "$OLDCYCLE" ]; then
  run_wall_probes "3e200bb" "$OLDCYCLE"
  rm -f "$OLDCYCLE"
fi
run_wall_probes "branch"  "$SRC/scripts/cycle.sh"

# ============================================================================================
# Story 15: one scenario per story 05 criterion (r2m3, r2m16, N-m3, r2m5/r2m6 x2, r2m7/N-m2 x2,
# r2m4/N-m1 structural). The code is already on the branch (story 05); this proves it.
# ============================================================================================

echo "=== Story 15: one scenario per story 05 criterion ==="

echo "open-round --commit: r2m3 - a failed first commit (index.lock) leaves ROUND/journal.md uncommitted; the second --commit finishes them, not a silent no-op"
mk_open_spec r2m3a 2
set_tier r2m3a 3
touch .git/index.lock
out="$(council open-round docs/specs/r2m3a --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qiF 'git commit' && echo "  ok    first --commit fails on the locked index" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
rd_r2m3="docs/specs/r2m3a/council/round-1"
[ -f "$rd_r2m3/ROUND" ] && echo "  ok    ROUND was written to disk despite the failed commit" \
  || { echo "::error::no ROUND at $rd_r2m3"; fail=1; }
[ -n "$(git status --porcelain -- docs/specs/r2m3a)" ] && echo "  ok    the round's paperwork is left uncommitted" \
  || { echo "::error::tree unexpectedly clean"; fail=1; }
rm -f .git/index.lock
out="$(council open-round docs/specs/r2m3a --commit)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    second --commit exits 0" || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -z "$(git status --porcelain -- docs/specs/r2m3a)" ] && echo "  ok    docs/specs/r2m3a is clean afterward" \
  || { echo "::error::tree dirty: $(git status --porcelain -- docs/specs/r2m3a)"; fail=1; }
git show HEAD:"$rd_r2m3/ROUND" >/dev/null 2>&1 && git show HEAD:docs/specs/r2m3a/journal.md >/dev/null 2>&1 \
  && echo "  ok    ROUND and journal.md are committed, not left behind by a silent no-op" \
  || { echo "::error::ROUND or journal.md not committed"; fail=1; }

echo "open-round: r2m16 - a status: blocked story refuses by name and file, nothing created under council/"
mk_open_spec r2m16a 2
set_tier r2m16a 1
printf -- '---\nstory: r2m16a-02\nspec: r2m16a\nstatus: blocked\nwave: 1\n---\n# S2\n' > docs/specs/r2m16a/r2m16a-02-second.md
git add -A && git commit -qm "r2m16a: add a blocked story" >/dev/null
out="$(council open-round docs/specs/r2m16a 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF '"next":"open-round"' \
  && printf '%s' "$out" | grep -qF '"error":"story r2m16a-02 is blocked: docs/specs/r2m16a/r2m16a-02-second.md"' \
  && echo "  ok    exit 2, next:open-round, error names the story id and file" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -d docs/specs/r2m16a/council ] && echo "  ok    nothing was created under council/" \
  || { echo "::error::council/ exists despite the blocked story"; fail=1; }

echo "open-round / status --json: N-m3 - a round dir without its own ROUND file is not open; open-round rewrites it in place (same N), no round-2, no no-op line"
mk_open_spec nm3a 2
set_tier nm3a 1
mkdir -p docs/specs/nm3a/council/round-1
out="$(council status docs/specs/nm3a --json)"
printf '%s' "$out" | jq -e '.open == false and .next == "open-round"' >/dev/null 2>&1 \
  && echo "  ok    status --json: open:false, next:open-round despite the round-1 dir existing" \
  || { echo "::error::status: $out"; fail=1; }
out="$(council open-round docs/specs/nm3a --commit)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"dispatch:review"' \
  && echo "  ok    open-round writes ROUND into round-1 (fresh dispatch, not a no-op line)" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ -f docs/specs/nm3a/council/round-1/ROUND ] && echo "  ok    ROUND file now exists in round-1" \
  || { echo "::error::no ROUND written"; fail=1; }
[ ! -d docs/specs/nm3a/council/round-2 ] && echo "  ok    no round-2 was opened" \
  || { echo "::error::round-2 exists"; fail=1; }

echo "open-round: r2m5/r2m6 - the ceiling block (plain path) carries the RED asks (2,5) of the last judged round"
mk_spec ceilred1 5
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-14/' docs/specs/ceilred1/plan.md
sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/ceilred1#' docs/specs/ceilred1/plan.md
set_tier ceilred1 3
mkdir -p docs/specs/ceilred1/council
printf '1\n' > docs/specs/ceilred1/council/CEILING
git add -A && git commit -qm "ceilred1: branch, ceiling 1" >/dev/null
rd_cr="$(mk_round ceilred1 1 1)"
write_seat "$rd_cr" haiku GRGGR
write_seat "$rd_cr" sonnet GGGGG
write_seat "$rd_cr" opus GGGGG
write_review "$rd_cr" PASS
printf '{"ts":"%s","spec":"ceilred1","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":5,"red":[2,5],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"RED","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":4,"escalate":null,"note":""}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
git add -A && git commit -qm "ceilred1: fabricated round 1, already judged RED" >/dev/null
out="$(council open-round docs/specs/ceilred1 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | tail -n1 | jq -e '{ok, verb, exit, next} == {ok:true, verb:"open-round", exit:6, next:"escalated"}' >/dev/null 2>&1 \
  && echo "  ok    ceiling exit 6, last line is exactly ok:true/verb:open-round/exit:6/next:escalated" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
row_cr="$(grep '"spec":"ceilred1"' memory/stats/council.jsonl | grep '"verdict":"ESCALATE"')"
printf '%s' "$row_cr" | grep -qF '"red":[2,5]' && echo "  ok    the ESCALATE row carries red:[2,5], computed live from the seat files" \
  || { echo "::error::row: $row_cr"; fail=1; }
grep -qF -- '- ask 2: RED - see' docs/specs/ceilred1/plan.md && grep -qF -- '- ask 5: RED - see' docs/specs/ceilred1/plan.md \
  && echo "  ok    ## Needs a human has one - ask 2: and one - ask 5: line with the evidence clause" \
  || { echo "::error::plan.md: $(grep -A8 '^## Needs a human' docs/specs/ceilred1/plan.md)"; fail=1; }
grep -qF "seats: $rd_cr/" docs/specs/ceilred1/plan.md && echo "  ok    seats: names the round directory" \
  || { echo "::error::plan.md: $(grep -A8 '^## Needs a human' docs/specs/ceilred1/plan.md)"; fail=1; }

echo "open-round: a STALE fold at ceiling 1 no longer counts toward the ceiling (convergent-judge-05, flipped) - round 2 opens"
mk_open_spec ceilstale1 5
set_tier ceilstale1 3
mkdir -p docs/specs/ceilstale1/council
printf '1\n' > docs/specs/ceilstale1/council/CEILING
git add -A && git commit -qm "ceilstale1: ceiling 1" >/dev/null
rd_cs="$(mk_open_round ceilstale1 1 1)"
write_seat "$rd_cs" haiku GRGGR
write_seat "$rd_cs" sonnet GGGGG
write_seat "$rd_cs" opus GGGGG
write_review "$rd_cs" PASS
echo "real code change" > ceilstale1-code.txt
git add -A && git commit -qm "real code change while ceilstale1 round 1 is open" >/dev/null
out="$(council open-round docs/specs/ceilstale1 --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ -f docs/specs/ceilstale1/council/round-2/ROUND ] \
  && grep '"spec":"ceilstale1"' memory/stats/council.jsonl | grep '"round":1,' | grep -qF '"verdict":"STALE"' \
  && ! grep '"spec":"ceilstale1"' memory/stats/council.jsonl | grep -qF '"verdict":"ESCALATE"' \
  && echo "  ok    STALE round 1 does not count: exit 0, round 2 opened, no ESCALATE row" \
  || { echo "::error::ceilstale1: exit=$ex out=$out"; fail=1; }

echo "open-round: r2m5/r2m6 - the ceiling block (STALE-fold path) carries the same RED asks (2,5)"
# convergent-judge-05: the STALE-fold path reaches the ceiling only when judged rounds already
# fill it - here round 1 is judged RED (ceiling 1) and round 2, with seats, goes stale.
mk_open_spec ceilstale2 5
set_tier ceilstale2 3
mkdir -p docs/specs/ceilstale2/council
printf '1\n' > docs/specs/ceilstale2/council/CEILING
mk_round ceilstale2 1 1 >/dev/null
printf '{"ts":"%s","spec":"ceilstale2","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":5,"red":[1],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"RED","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":3,"escalate":null,"note":""}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
git add -A && git commit -qm "ceilstale2: ceiling 1, round 1 judged RED" >/dev/null
rd_cs="$(mk_open_round ceilstale2 2 1)"
write_seat "$rd_cs" haiku GRGGR
write_seat "$rd_cs" sonnet GGGGG
write_seat "$rd_cs" opus GGGGG
write_review "$rd_cs" PASS
echo "real code change" > ceilstale2-code.txt
git add -A && git commit -qm "real code change while ceilstale2 round 2 is open" >/dev/null
out="$(council open-round docs/specs/ceilstale2 --commit 2>&1)"; ex=$?
[ "$ex" -eq 6 ] && printf '%s' "$out" | tail -n1 | jq -e '{ok, verb, exit, next} == {ok:true, verb:"open-round", exit:6, next:"escalated"}' >/dev/null 2>&1 \
  && echo "  ok    STALE-fold ceiling: exit 6, exact four-key last line" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
row_cs="$(grep '"spec":"ceilstale2"' memory/stats/council.jsonl | grep '"verdict":"ESCALATE"')"
printf '%s' "$row_cs" | grep -qF '"red":[2,5]' && echo "  ok    STALE-fold ESCALATE row carries red:[2,5] too" \
  || { echo "::error::row: $row_cs"; fail=1; }
grep -qF -- '- ask 2: RED - see' docs/specs/ceilstale2/plan.md && grep -qF -- '- ask 5: RED - see' docs/specs/ceilstale2/plan.md \
  && echo "  ok    STALE-fold ## Needs a human has the same ask 2 / ask 5 lines" \
  || { echo "::error::plan.md: $(grep -A8 '^## Needs a human' docs/specs/ceilstale2/plan.md)"; fail=1; }
grep -qF "seats: $rd_cs/" docs/specs/ceilstale2/plan.md && echo "  ok    STALE-fold seats: names the round directory" \
  || { echo "::error::plan.md: $(grep -A8 '^## Needs a human' docs/specs/ceilstale2/plan.md)"; fail=1; }

echo "open-round: r2m7/N-m2 - a failing court reduction commit exits 2 naming it, and removes the round/court (never handed to a seat)"
mk_open_spec r2m7a 2
set_tier r2m7a 3
out="$(GIT_AUTHOR_NAME='' GIT_AUTHOR_EMAIL='' GIT_COMMITTER_NAME='' GIT_COMMITTER_EMAIL='' council open-round docs/specs/r2m7a --commit 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF '"error":"court reduction commit failed"' \
  && echo "  ok    exit 2, error names the reduction commit" \
  || { echo "::error::exit=$ex out=$out"; fail=1; }
[ ! -d docs/specs/r2m7a/council/round-1 ] && echo "  ok    the round directory (and its court) is gone, never handed to a seat" \
  || { echo "::error::round-1 still present: $(ls docs/specs/r2m7a/council/round-1 2>&1)"; fail=1; }

echo "open-round: r2m7/N-m2 - by structure, the reduction commit uses -c commit.gpgsign=false and --no-verify, with no || true"
redline="$(grep -n 'reduce the court to brief.md' scripts/cycle.sh | head -1 | cut -d: -f1)"
ctx="$(sed -n "$((redline-3)),$((redline+1))p" scripts/cycle.sh)"
printf '%s' "$ctx" | grep -qF -- '--no-verify' && echo "  ok    --no-verify is present on the reduction commit" \
  || { echo "::error::$ctx"; fail=1; }
printf '%s' "$ctx" | grep -qF 'commit.gpgsign=false' && echo "  ok    -c commit.gpgsign=false is present" \
  || { echo "::error::$ctx"; fail=1; }
printf '%s' "$ctx" | grep -qF '|| true' && { echo "::error::the reduction commit still has a || true: $ctx"; fail=1; } \
  || echo "  ok    no || true masks a failing reduction commit"

echo "r2m4/N-m1: structural - every 'emit false' call site carries a non-empty error argument"
n_all="$(grep -c 'emit false' scripts/cycle.sh)"
n_bad="$(grep -cE 'emit false [^ ]+ [0-9]+ [^ ]+( "")?$' scripts/cycle.sh)"
[ "$n_bad" -eq 0 ] && echo "  ok    no 'emit false' line is missing its error argument (all $n_all sites carry one)" \
  || { echo "::error::$n_bad site(s) missing error: $(grep -nE 'emit false [^ ]+ [0-9]+ [^ ]+( "")?$' scripts/cycle.sh)"; fail=1; }

echo "r2m4/N-m1: structural - every exit-6 site means ok:true/next:escalated, never ok:false (exit 6 means one thing everywhere)"
n_lit6="$(grep -cE 'exit 6$' scripts/cycle.sh)"
n_lit6ok="$(grep -B1 -E 'exit 6$' scripts/cycle.sh | grep -cE 'emit true .* 6 escalated$')"
[ "$n_lit6" -eq 3 ] && [ "$n_lit6ok" -eq 3 ] && echo "  ok    all 3 literal exit-6 sites (escalate, both open-round ceiling gates) emit ok:true/next:escalated" \
  || { echo "::error::lit6=$n_lit6 lit6ok=$n_lit6ok"; fail=1; }
grep -qF 'emit true "$VERBLABEL" "$exit_code" "$next_val"' scripts/cycle.sh \
  && echo "  ok    judge's own ESCALATE (exit_code=6) path shares the same unconditional emit true call - never emit false" \
  || { echo "::error::judge's emit call not found in the expected literal shape"; fail=1; }

# --- regression proof: the same six checks replayed against b9f36e8's cycle.sh vs. the branch's,
# reusing run_wall_probes (extended above with a variadic extra-probe list) rather than a second
# runner - a second scratch git repo per version, the branch's own working tree untouched. ------

probe_r2m3() {
  mk_open_spec pr2m3 2; set_tier pr2m3 3 >/dev/null
  touch .git/index.lock
  council open-round docs/specs/pr2m3 --commit >/dev/null 2>&1
  rm -f .git/index.lock
  council open-round docs/specs/pr2m3 --commit >/dev/null 2>&1
  [ -z "$(git status --porcelain -- docs/specs/pr2m3)" ] && echo ok || echo FAIL
}
probe_r2m16() {
  mk_open_spec pr2m16 2; set_tier pr2m16 1 >/dev/null
  printf -- '---\nstory: pr2m16-02\nspec: pr2m16\nstatus: blocked\nwave: 1\n---\n# S2\n' > docs/specs/pr2m16/pr2m16-02-second.md
  git add -A && git commit -qm "blocked story" >/dev/null
  local out ex; out="$(council open-round docs/specs/pr2m16 2>&1)"; ex=$?
  [ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'is blocked:' && echo ok || echo FAIL
}
probe_nm3() {
  mk_open_spec pnm3 2; set_tier pnm3 1 >/dev/null
  mkdir -p docs/specs/pnm3/council/round-1
  local out; out="$(council status docs/specs/pnm3 --json)"
  printf '%s' "$out" | jq -e '.open == false' >/dev/null 2>&1 && echo ok || echo FAIL
}
probe_ceiling() {
  mk_spec pceil 5
  sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, x/' docs/specs/pceil/plan.md
  sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/pceil#' docs/specs/pceil/plan.md
  set_tier pceil 3 >/dev/null
  mkdir -p docs/specs/pceil/council
  printf '1\n' > docs/specs/pceil/council/CEILING
  git add -A && git commit -qm "pceil setup" >/dev/null
  local rd; rd="$(mk_round pceil 1 1)"
  write_seat "$rd" haiku GRGGR
  write_seat "$rd" sonnet GGGGG
  write_seat "$rd" opus GGGGG
  write_review "$rd" PASS
  printf '{"ts":"%s","spec":"pceil","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":5,"red":[2,5],"red_unevidenced":[],"na":0,"review":"PASS","haiku":"RED","haiku_model":"m","sonnet":"GREEN","sonnet_model":"m","opus":"GREEN","opus_model":"m","attempts":4,"escalate":null,"note":""}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
  git add -A && git commit -qm "pceil fabricated round 1" >/dev/null
  council open-round docs/specs/pceil >/dev/null 2>&1
  local row; row="$(grep '"spec":"pceil"' memory/stats/council.jsonl | grep '"verdict":"ESCALATE"')"
  printf '%s' "$row" | grep -qF '"red":[2,5]' && echo ok || echo FAIL
}
probe_courtcommit() {
  mk_open_spec pcourt 2; set_tier pcourt 3 >/dev/null
  local out; out="$(GIT_AUTHOR_NAME='' GIT_AUTHOR_EMAIL='' GIT_COMMITTER_NAME='' GIT_COMMITTER_EMAIL='' council open-round docs/specs/pcourt --commit 2>&1)"
  # Exit 2 alone is not distinctive here: the tainted identity env can also break the outer
  # commit_paperwork call (a different site, same exit code) - only the "court reduction
  # commit failed" error names the fix this probe is for (the old `|| true` masks the court's
  # own commit failure and lets build_round continue to exit 0/6 instead).
  printf '%s' "$out" | grep -qF '"error":"court reduction commit failed"' && echo ok || echo FAIL
}
probe_exit6uniform() {
  mk_spec puni 2
  sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, x/' docs/specs/puni/plan.md
  sed -i 's#^\*\*Branch:\*\* <.*#**Branch:** vulyk/puni#' docs/specs/puni/plan.md
  set_tier puni 1 >/dev/null
  mkdir -p docs/specs/puni/council
  printf '1\n' > docs/specs/puni/council/CEILING
  git add -A && git commit -qm "puni setup" >/dev/null
  mk_round puni 1 1 >/dev/null
  printf '{"ts":"%s","spec":"puni","round":1,"verdict":"RED","head":"%s","pack":"demo-pack","asks":2,"red":[1],"red_unevidenced":[],"na":0,"review":"","haiku":"","haiku_model":"unknown","sonnet":"RED","sonnet_model":"m","opus":"","opus_model":"unknown","attempts":1,"escalate":null,"note":""}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HEAD7" >> memory/stats/council.jsonl
  git add -A && git commit -qm "puni fabricated round 1" >/dev/null
  local out; out="$(council open-round docs/specs/puni 2>&1)"
  printf '%s' "$out" | tail -n1 | jq -e '.ok == true' >/dev/null 2>&1 && echo ok || echo FAIL
}

OLDCYCLE2="$(mktemp)"
PIN_MUST_FAIL=""
if pin_cycle b9f36e8 "$OLDCYCLE2"; then
  run_wall_probes "b9f36e8" "$OLDCYCLE2" probe_r2m3 probe_r2m16 probe_nm3 probe_ceiling probe_courtcommit probe_exit6uniform
  rm -f "$OLDCYCLE2"
fi
run_wall_probes "branch"  "$SRC/scripts/cycle.sh" probe_r2m3 probe_r2m16 probe_nm3 probe_ceiling probe_courtcommit probe_exit6uniform

# ============================================================================================
# Story 16: one wall probe per story 08 fix (M3/ADR-006 returned:, r2m2, LR31, r2m9), replayed
# against eb3203a's cycle.sh (the commit immediately before story 08's own) vs. the branch's,
# reusing run_wall_probes exactly as stories 14/15 did - a third pinned version, not a third
# runner.
# ============================================================================================

probe_returned() {
  mk_open_spec pret 2; set_tier pret 1 >/dev/null
  cat > docs/specs/pret/pret-02-second.md <<'EOF'
---
story: pret-02
spec: pret
status: todo
wave: 1
---
# Ret

## Verification
`true`
EOF
  git add -A && git commit -qm "pret: second story, no returned:" >/dev/null
  local out ex; out="$(council close-story docs/specs/pret/pret-02-second.md 2>&1)"; ex=$?
  [ "$ex" -eq 4 ] && printf '%s' "$out" | grep -qF 'returned: missing' && echo ok || echo FAIL
}
probe_r2m2wall() {
  mk_open_spec pr2m2 2; set_tier pr2m2 1 >/dev/null
  cat > docs/specs/pr2m2/pr2m2-02-second.md <<'EOF'
---
story: pr2m2-02
spec: pr2m2
status: todo
returned: DONE
wave: 1
---
# Lock

## Verification
`true`
EOF
  git add -A && git commit -qm "pr2m2: second story" >/dev/null
  touch .git/index.lock
  council close-story docs/specs/pr2m2/pr2m2-02-second.md --commit >/dev/null 2>&1
  rm -f .git/index.lock
  grep -q '^status: todo' docs/specs/pr2m2/pr2m2-02-second.md && echo ok || echo FAIL
}
probe_lr31wall() { # mirrors the `lr31w` scenario above: a ready todo A and a not-ready todo B
  # (blocked_by a not-done C) share wave 1; only A must be listed. Pre-fix (eb3203a) lists all
  # todo wave files regardless of blocked_by, so this is FAIL there and ok on the branch.
  mkdir -p docs/specs/plr31
  cat > docs/specs/plr31/plr31-01-a.md <<'EOF'
---
story: plr31-01
spec: plr31
status: todo
wave: 1
---
# A (ready)

## Verification
`true`
EOF
  cat > docs/specs/plr31/plr31-02-c.md <<'EOF'
---
story: plr31-02
spec: plr31
status: blocked
wave: 1
---
# C (the blocker)

## Verification
`true`
EOF
  cat > docs/specs/plr31/plr31-03-b.md <<'EOF'
---
story: plr31-03
spec: plr31
status: todo
wave: 1
blocked_by: [plr31-02]
---
# B (not ready)

## Verification
`true`
EOF
  git add -A && git commit -qm "plr31: fixture" >/dev/null
  local out; out="$(council status docs/specs/plr31 --json)"
  printf '%s' "$out" | jq -e '(.wave_stories | length) == 1 and .wave_stories[0].story == "plr31-01"' >/dev/null 2>&1 && echo ok || echo FAIL
}
probe_r2m9wall() {
  mkdir -p docs/specs/pr2m9
  cat > docs/specs/pr2m9/pr2m9-01-first.md <<'EOF'
---
story: pr2m9-01
spec: pr2m9
status: todo
returned: DONE
wave: 1
---
# R2M9

## Verification
`sh -c 'true && true'`
EOF
  git add -A && git commit -qm "pr2m9: fixture" >/dev/null
  local out ex; out="$(council close-story docs/specs/pr2m9/pr2m9-01-first.md 2>&1)"; ex=$?
  [ "$ex" -eq 0 ] && echo ok || echo FAIL
}

OLDCYCLE3="$(mktemp)"
PIN_MUST_FAIL="probe_lr31wall"
if pin_cycle eb3203a "$OLDCYCLE3"; then
  run_wall_probes "eb3203a" "$OLDCYCLE3" probe_returned probe_r2m2wall probe_lr31wall probe_r2m9wall
  rm -f "$OLDCYCLE3"
fi
PIN_MUST_FAIL=""
run_wall_probes "branch"  "$SRC/scripts/cycle.sh" probe_returned probe_r2m2wall probe_lr31wall probe_r2m9wall

# ============================================================================================
# Story 17: one scenario per story 11 criterion - the DRIVER semaphore (ADR-004/K3): claim,
# release, pause/resume release, --stamp on open-round/record-seat/judge/close-story. The code
# is already on the branch (story 11); this proves it, plus wall probes against the pre-story
# cycle.sh (the commit immediately before story 11's own).
# ============================================================================================

echo "=== Story 17: DRIVER semaphore (claim/release, --stamp on four verbs) ==="

echo "claim: first claim exits 0 with stamp=/claimed=; same stamp again exits 0; a different stamp exits 2 held by <first>; PAUSE exits 3"
mk_spec driverc1 2
out="$(council claim docs/specs/driverc1 aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"claimed"' && echo "  ok    first claim exits 0, next:claimed" \
  || { echo "::error::first claim: exit=$ex out=$out"; fail=1; }
grep -q '^stamp=aaaa1111$' docs/specs/driverc1/DRIVER 2>/dev/null && grep -q '^claimed=' docs/specs/driverc1/DRIVER 2>/dev/null \
  && echo "  ok    DRIVER holds stamp= and claimed= lines" || { echo "::error::DRIVER: $(cat docs/specs/driverc1/DRIVER 2>&1)"; fail=1; }
[ -z "$(git status --porcelain)" ] && echo "  ok    git status is empty after a claim (the fixture .gitignore covers DRIVER)" \
  || { echo "::error::git status not clean after claim: $(git status --porcelain)"; fail=1; }
out="$(council claim docs/specs/driverc1 aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    same stamp again exits 0" || { echo "::error::same-stamp claim: exit=$ex out=$out"; fail=1; }
out="$(council claim docs/specs/driverc1 bbbb2222 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && printf '%s' "$out" | grep -qF 'cycle.sh release' \
  && echo "  ok    a different stamp exits 2, error names the holder and the release command" \
  || { echo "::error::conflict claim: exit=$ex out=$out"; fail=1; }
printf 'owner \xc2\xb7 pinned \xc2\xb7 2020-01-01T00:00:00Z\nhead=unknown\n' > docs/specs/driverc1/PAUSE
out="$(council claim docs/specs/driverc1 cccc3333 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    claim under PAUSE exits 3, next:paused" \
  || { echo "::error::paused claim: exit=$ex out=$out"; fail=1; }
rm -f docs/specs/driverc1/PAUSE

echo "release: matching stamp -> exit 0, file gone; absent file -> exit 0; mismatch -> exit 2 held by <other>, file kept"
mk_spec driverr1 2
council claim docs/specs/driverr1 aaaa1111 >/dev/null 2>&1
out="$(council release docs/specs/driverr1 aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && [ ! -f docs/specs/driverr1/DRIVER ] && echo "  ok    matching stamp releases, file gone" \
  || { echo "::error::release match: exit=$ex out=$out"; fail=1; }
out="$(council release docs/specs/driverr1 aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    release on an absent file exits 0" || { echo "::error::release absent: exit=$ex out=$out"; fail=1; }
council claim docs/specs/driverr1 aaaa1111 >/dev/null 2>&1
out="$(council release docs/specs/driverr1 bbbb2222 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ -f docs/specs/driverr1/DRIVER ] \
  && echo "  ok    mismatch exits 2 held by <other>, file kept" || { echo "::error::release mismatch: exit=$ex out=$out"; fail=1; }

echo "release: not pause_guard-gated (C4/ADR-001 D2) - a claimed then paused spec still releases; a foreign stamp under PAUSE still exits 2 held by; claim under PAUSE is untouched (exit 3)"
mk_spec driverrp1 2
council claim docs/specs/driverrp1 aaaa1111 >/dev/null 2>&1
printf 'owner \xc2\xb7 pinned \xc2\xb7 2020-01-01T00:00:00Z\nhead=unknown\n' > docs/specs/driverrp1/PAUSE
out="$(council release docs/specs/driverrp1 aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"ok":true' && [ ! -f docs/specs/driverrp1/DRIVER ] \
  && echo "  ok    release under PAUSE exits 0, ok:true, DRIVER gone" \
  || { echo "::error::release under pause: exit=$ex out=$out"; fail=1; }
printf 'stamp=cccc3333\nclaimed=2020-01-01T00:00:00Z\n' > docs/specs/driverrp1/DRIVER  # claim is itself PAUSE-gated; write DRIVER directly
out="$(council release docs/specs/driverrp1 dddd4444 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by cccc3333' && [ -f docs/specs/driverrp1/DRIVER ] \
  && echo "  ok    release under PAUSE with a foreign stamp still exits 2 held by, file kept" \
  || { echo "::error::release foreign under pause: exit=$ex out=$out"; fail=1; }
out="$(council claim docs/specs/driverrp1 eeee5555 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && echo "  ok    claim under PAUSE still exits 3, next:paused (untouched)" \
  || { echo "::error::claim under pause: exit=$ex out=$out"; fail=1; }
rm -f docs/specs/driverrp1/PAUSE

echo "pause/resume: each removes an existing DRIVER and journal.md gains a driver released line"
mk_spec driverp1 2
council claim docs/specs/driverp1 aaaa1111 >/dev/null 2>&1
[ -f docs/specs/driverp1/DRIVER ] || { echo "::error::setup: DRIVER missing before pause"; fail=1; }
council pause docs/specs/driverp1 "testing" >/dev/null 2>&1
[ ! -f docs/specs/driverp1/DRIVER ] && grep -qF 'driver released' docs/specs/driverp1/journal.md \
  && echo "  ok    pause removes DRIVER and journals 'driver released'" \
  || { echo "::error::pause: driver present=$([ -f docs/specs/driverp1/DRIVER ] && echo yes || echo no)"; fail=1; }
printf 'stamp=aaaa1111\nclaimed=2020-01-01T00:00:00Z\n' > docs/specs/driverp1/DRIVER  # PAUSE already active; write DRIVER directly, claim is itself PAUSE-gated
before="$(grep -c 'driver released' docs/specs/driverp1/journal.md)"
council resume docs/specs/driverp1 >/dev/null 2>&1
after="$(grep -c 'driver released' docs/specs/driverp1/journal.md)"
[ ! -f docs/specs/driverp1/DRIVER ] && [ "$after" -gt "$before" ] \
  && echo "  ok    resume removes DRIVER and journals another 'driver released' line" \
  || { echo "::error::resume: driver present=$([ -f docs/specs/driverp1/DRIVER ] && echo yes || echo no) before=$before after=$after"; fail=1; }

echo "gated verbs: open-round, record-seat, judge, close-story each exit 2 held by <holder> without --stamp or with a wrong --stamp, no new file/row/commit; matching --stamp proceeds; PAUSE+DRIVER exits 3, not held by"
mk_open_spec gatedv1 3
set_tier gatedv1 1
council claim docs/specs/gatedv1 aaaa1111 >/dev/null 2>&1

out="$(council open-round docs/specs/gatedv1 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ ! -d docs/specs/gatedv1/council ] \
  && echo "  ok    open-round refused without --stamp, no council/ dir created" \
  || { echo "::error::open-round no-stamp: exit=$ex out=$out"; fail=1; }
out="$(council open-round docs/specs/gatedv1 --stamp bbbb2222 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ ! -d docs/specs/gatedv1/council ] \
  && echo "  ok    open-round refused with a wrong --stamp, no council/ dir created" \
  || { echo "::error::open-round wrong-stamp: exit=$ex out=$out"; fail=1; }
out="$(council open-round docs/specs/gatedv1 --stamp aaaa1111 2>&1)"; ex=$?
[ "$ex" -ne 2 ] && [ -d docs/specs/gatedv1/council/round-1 ] \
  && echo "  ok    open-round proceeds with the matching --stamp (round-1 created)" \
  || { echo "::error::open-round right-stamp: exit=$ex out=$out"; fail=1; }

out="$(printf 'VERDICT: PASS\nfine\n' | council record-seat docs/specs/gatedv1 1 review 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ ! -f docs/specs/gatedv1/council/round-1/review.md ] \
  && echo "  ok    record-seat refused without --stamp, no seat file written" \
  || { echo "::error::record-seat no-stamp: exit=$ex out=$out"; fail=1; }
out="$(printf 'VERDICT: PASS\nfine\n' | council record-seat docs/specs/gatedv1 1 review --stamp bbbb2222 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ ! -f docs/specs/gatedv1/council/round-1/review.md ] \
  && echo "  ok    record-seat refused with a wrong --stamp, no seat file written" \
  || { echo "::error::record-seat wrong-stamp: exit=$ex out=$out"; fail=1; }
out="$(printf 'VERDICT: PASS\nfine\n' | council record-seat docs/specs/gatedv1 1 review --stamp aaaa1111 2>&1)"; ex=$?
[ "$ex" -ne 2 ] && [ -f docs/specs/gatedv1/council/round-1/review.md ] \
  && echo "  ok    record-seat proceeds with the matching --stamp (seat file written)" \
  || { echo "::error::record-seat right-stamp: exit=$ex out=$out"; fail=1; }

jsonl_before="$(grep -c '"spec":"gatedv1"' memory/stats/council.jsonl 2>/dev/null)"; jsonl_before="${jsonl_before:-0}"
out="$(council judge docs/specs/gatedv1 2>&1)"; ex=$?
jsonl_after="$(grep -c '"spec":"gatedv1"' memory/stats/council.jsonl 2>/dev/null)"; jsonl_after="${jsonl_after:-0}"
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ "$jsonl_after" -eq "$jsonl_before" ] \
  && ! grep -qE '^\*\*Council:\*\* (GREEN|RED|ESCALATE|STALE) round' docs/specs/gatedv1/plan.md \
  && echo "  ok    judge refused without --stamp, no jsonl row, no plan.md Council line" \
  || { echo "::error::judge no-stamp: exit=$ex out=$out jsonl before=$jsonl_before after=$jsonl_after"; fail=1; }
out="$(council judge docs/specs/gatedv1 --stamp bbbb2222 2>&1)"; ex=$?
jsonl_after2="$(grep -c '"spec":"gatedv1"' memory/stats/council.jsonl 2>/dev/null)"; jsonl_after2="${jsonl_after2:-0}"
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && [ "$jsonl_after2" -eq "$jsonl_before" ] \
  && echo "  ok    judge refused with a wrong --stamp, no jsonl row" \
  || { echo "::error::judge wrong-stamp: exit=$ex out=$out"; fail=1; }
out="$(council judge docs/specs/gatedv1 --stamp aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"green"' \
  && echo "  ok    judge proceeds with the matching --stamp (GREEN)" \
  || { echo "::error::judge right-stamp: exit=$ex out=$out"; fail=1; }

cat > docs/specs/gatedv1/gatedv1-02-second.md <<'EOF'
---
story: gatedv1-02
spec: gatedv1
status: todo
returned: DONE
wave: 1
---
# Second

## Verification
`true`
EOF
git add -A && git commit -qm "gatedv1: second story" >/dev/null
out="$(council close-story docs/specs/gatedv1/gatedv1-02-second.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && grep -q '^status: todo' docs/specs/gatedv1/gatedv1-02-second.md \
  && echo "  ok    close-story refused without --stamp, story left todo" \
  || { echo "::error::close-story no-stamp: exit=$ex out=$out"; fail=1; }
out="$(council close-story docs/specs/gatedv1/gatedv1-02-second.md --stamp bbbb2222 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111' && grep -q '^status: todo' docs/specs/gatedv1/gatedv1-02-second.md \
  && echo "  ok    close-story refused with a wrong --stamp, story left todo" \
  || { echo "::error::close-story wrong-stamp: exit=$ex out=$out"; fail=1; }
out="$(council close-story docs/specs/gatedv1/gatedv1-02-second.md --stamp aaaa1111 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^status: done' docs/specs/gatedv1/gatedv1-02-second.md \
  && echo "  ok    close-story proceeds with the matching --stamp, story now done" \
  || { echo "::error::close-story right-stamp: exit=$ex out=$out"; fail=1; }

printf 'owner \xc2\xb7 pinned \xc2\xb7 2020-01-01T00:00:00Z\nhead=unknown\n' > docs/specs/gatedv1/PAUSE
out="$(council open-round docs/specs/gatedv1 2>&1)"; ex=$?
[ "$ex" -eq 3 ] && printf '%s' "$out" | grep -qF '"next":"paused"' && ! printf '%s' "$out" | grep -qF 'held by' \
  && echo "  ok    a paused spec with a held DRIVER answers exit 3, not held-by" \
  || { echo "::error::pause+driver: exit=$ex out=$out"; fail=1; }
rm -f docs/specs/gatedv1/PAUSE

echo "no DRIVER: open-round, record-seat, judge, close-story proceed with or without --stamp"
mk_open_spec gatedv2 2
set_tier gatedv2 1
out="$(council open-round docs/specs/gatedv2 2>&1)"; ex=$?
[ "$ex" -ne 2 ] && [ -d docs/specs/gatedv2/council/round-1 ] && echo "  ok    open-round proceeds without --stamp when no DRIVER exists" \
  || { echo "::error::open-round no-driver no-stamp: exit=$ex out=$out"; fail=1; }
out="$(printf 'VERDICT: PASS\nfine\n' | council record-seat docs/specs/gatedv2 1 review --stamp unrelated9999 2>&1)"; ex=$?
[ "$ex" -ne 2 ] && [ -f docs/specs/gatedv2/council/round-1/review.md ] \
  && echo "  ok    record-seat proceeds with an unrelated --stamp when no DRIVER exists" \
  || { echo "::error::record-seat no-driver with-stamp: exit=$ex out=$out"; fail=1; }
out="$(council judge docs/specs/gatedv2 --stamp unrelated9999 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF '"next":"green"' \
  && echo "  ok    judge proceeds with an unrelated --stamp when no DRIVER exists" \
  || { echo "::error::judge no-driver with-stamp: exit=$ex out=$out"; fail=1; }
cat > docs/specs/gatedv2/gatedv2-02-second.md <<'EOF'
---
story: gatedv2-02
spec: gatedv2
status: todo
returned: DONE
wave: 1
---
# Second

## Verification
`true`
EOF
git add -A && git commit -qm "gatedv2: second story" >/dev/null
out="$(council close-story docs/specs/gatedv2/gatedv2-02-second.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -q '^status: done' docs/specs/gatedv2/gatedv2-02-second.md \
  && echo "  ok    close-story proceeds without --stamp when no DRIVER exists" \
  || { echo "::error::close-story no-driver no-stamp: exit=$ex out=$out"; fail=1; }

echo "wall probes: DRIVER semaphore against the pre-story-11 cycle.sh vs. the branch"
probe_claim() {
  mk_spec pclaim1 2
  council claim docs/specs/pclaim1 aaaa1111 >/dev/null 2>&1; local ex1=$?
  council claim docs/specs/pclaim1 aaaa1111 >/dev/null 2>&1; local ex2=$?
  local out3; out3="$(council claim docs/specs/pclaim1 bbbb2222 2>&1)"; local ex3=$?
  [ "$ex1" -eq 0 ] && [ -f docs/specs/pclaim1/DRIVER ] && [ "$ex2" -eq 0 ] && [ "$ex3" -eq 2 ] \
    && printf '%s' "$out3" | grep -qF 'held by aaaa1111' && echo ok || echo FAIL
}
probe_release() {
  mk_spec prelease1 2
  council claim docs/specs/prelease1 aaaa1111 >/dev/null 2>&1
  council release docs/specs/prelease1 aaaa1111 >/dev/null 2>&1; local ex1=$?
  local gone1=false; [ -f docs/specs/prelease1/DRIVER ] || gone1=true
  council release docs/specs/prelease1 aaaa1111 >/dev/null 2>&1; local ex2=$?
  council claim docs/specs/prelease1 aaaa1111 >/dev/null 2>&1
  local out3; out3="$(council release docs/specs/prelease1 bbbb2222 2>&1)"; local ex3=$?
  [ "$ex1" -eq 0 ] && $gone1 && [ "$ex2" -eq 0 ] && [ "$ex3" -eq 2 ] && [ -f docs/specs/prelease1/DRIVER ] \
    && printf '%s' "$out3" | grep -qF 'held by aaaa1111' && echo ok || echo FAIL
}
probe_pauserelease() {
  mk_spec ppause1 2
  council claim docs/specs/ppause1 aaaa1111 >/dev/null 2>&1
  council pause docs/specs/ppause1 "why" >/dev/null 2>&1
  local ok=true
  [ -f docs/specs/ppause1/DRIVER ] && ok=false
  grep -q 'driver released' docs/specs/ppause1/journal.md 2>/dev/null || ok=false
  printf 'stamp=aaaa1111\nclaimed=now\n' > docs/specs/ppause1/DRIVER
  council resume docs/specs/ppause1 >/dev/null 2>&1
  [ -f docs/specs/ppause1/DRIVER ] && ok=false
  local jcnt; jcnt="$(grep -c 'driver released' docs/specs/ppause1/journal.md 2>/dev/null)"; jcnt="${jcnt:-0}"
  [ "$jcnt" -eq 2 ] || ok=false
  $ok && echo ok || echo FAIL
}
probe_gated() {
  mk_open_spec pgated1 2; set_tier pgated1 1 >/dev/null
  council claim docs/specs/pgated1 aaaa1111 >/dev/null 2>&1
  local ok=true out ex
  out="$(council open-round docs/specs/pgated1 2>&1)"; ex=$?
  { [ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111'; } || ok=false
  out="$(council open-round docs/specs/pgated1 --stamp bbbb2222 2>&1)"; ex=$?
  { [ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'held by aaaa1111'; } || ok=false
  out="$(council open-round docs/specs/pgated1 --stamp aaaa1111 2>&1)"; ex=$?
  { [ "$ex" -ne 2 ] && [ -d docs/specs/pgated1/council/round-1 ]; } || ok=false
  $ok && echo ok || echo FAIL
}

SHA11="$(git -C "$SRC" log -1 --format=%h --grep='story(v0-12-0-remainders-11)')"
OLDCYCLE4="$(mktemp)"
PIN_MUST_FAIL=""
if [ -z "$SHA11" ]; then
  echo "  [pre-story-11] unavailable: no commit matches story(v0-12-0-remainders-11)"
  fail=1
  PRESHA11=""
else
  PRESHA11="$SHA11^"
  if pin_cycle "$PRESHA11" "$OLDCYCLE4"; then
    run_wall_probes "$PRESHA11" "$OLDCYCLE4" probe_claim probe_release probe_pauserelease probe_gated
  else
    PRESHA11=""
  fi
fi
rm -f "$OLDCYCLE4"
run_wall_probes "branch"    "$SRC/scripts/cycle.sh" probe_claim probe_release probe_pauserelease probe_gated

echo "=== Story driver-hardening-03: the five mutating verbs carry the post-verb status --json (C5) ==="
# One well-formed spec walked branch -> close-story -> open-round -> record-seat -> judge, each
# verb's exit-0 line compared against a `status <spec> --json` call made immediately after it.
c5_check() { # c5_check <label> <spec> <verb-stdout>
  local label="$1" spec="$2" out="$3" last njson after
  njson="$(printf '%s\n' "$out" | grep -c '^{')"
  last="$(printf '%s\n' "$out" | tail -1)"
  after="$(council status "$spec" --json)"
  [ "$njson" -eq 1 ] || { echo "::error::$label: $njson JSON lines on stdout, expected exactly 1: $out"; fail=1; return; }
  printf '%s' "$last" | jq -e . >/dev/null 2>&1 || { echo "::error::$label: last line is not JSON: $last"; fail=1; return; }
  [ "$(printf '%s' "$last" | jq -S .status)" = "$(printf '%s' "$after" | jq -S .)" ] \
    || { echo "::error::$label: carried status differs from status --json right after: $last vs $after"; fail=1; return; }
  [ "$(printf '%s' "$last" | jq -r .next)" = "$(printf '%s' "$last" | jq -r .status.next)" ] \
    || { echo "::error::$label: next is not .status.next: $last"; fail=1; return; }
  [ "$(printf '%s' "$last" | jq -r 'keys_unsorted | join(",")')" = "ok,verb,exit,next,status" ] \
    || { echo "::error::$label: key order is not ok,verb,exit,next,status: $last"; fail=1; return; }
  # C5 addendum (Minor 10): the carried status is a status object, never an error envelope -
  # an envelope is recognisable by its `ok` key, which `status --json` never emits.
  printf '%s' "$last" | jq -e '.status | has("ok") | not' >/dev/null 2>&1 \
    || { echo "::error::$label: carried status has an \"ok\" key (error envelope): $last"; fail=1; return; }
  echo "  ok    $label"
}

mk_spec c5verb 2
set_tier c5verb 1
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-15/' docs/specs/c5verb/plan.md
cat > docs/specs/c5verb/c5verb-02-second.md <<'EOF'
---
story: c5verb-02
spec: c5verb
status: todo
returned: DONE
wave: 1
---
# Second

## Verification
`true`
EOF
git add -A && git commit -qm "c5verb: approved + a todo story" >/dev/null

out="$(council branch docs/specs/c5verb --commit 2>&1)"
c5_check "branch --commit carries the post-commit status" docs/specs/c5verb "$out"
out="$(council close-story docs/specs/c5verb/c5verb-02-second.md --commit 2>&1)"
c5_check "close-story --commit carries the post-commit status" docs/specs/c5verb "$out"

out="$(council open-round docs/specs/c5verb --commit 2>&1)"
c5_check "open-round --commit carries the post-commit status" docs/specs/c5verb "$out"
last="$(printf '%s\n' "$out" | tail -1)"
[ "$(printf '%s' "$last" | jq -r .status.head)" = "$(git rev-parse --short HEAD)" ] \
  && echo "  ok    open-round --commit: status.head is the HEAD the commit just created" \
  || { echo "::error::open-round status.head: $last vs $(git rev-parse --short HEAD)"; fail=1; }
printf '%s' "$last" | jq -e '.status.next == "dispatch:review"' >/dev/null 2>&1 \
  && echo "  ok    open-round --commit: status.next is dispatch:<seats>" \
  || { echo "::error::open-round status.next: $last"; fail=1; }

out="$(printf 'VERDICT: PASS\nall asks hold\n' | council record-seat docs/specs/c5verb 1 review 2>&1)"
c5_check "record-seat carries the post-write status" docs/specs/c5verb "$out"

out="$(council judge docs/specs/c5verb --commit 2>&1)"
c5_check "judge --commit carries the post-commit status" docs/specs/c5verb "$out"
last="$(printf '%s\n' "$out" | tail -1)"
printf '%s' "$last" | jq -e '.status.next == "green" and .status.verdict == "GREEN"' >/dev/null 2>&1 \
  && echo "  ok    judge --commit on a GREEN fixture: status.next green, status.verdict GREEN" \
  || { echo "::error::judge status: $last"; fail=1; }

echo "C5 addendum: a failing cmd_status makes emit_status fall back to the pre-C5 five-key line (Minor 10)"
# Direct: source cycle.sh through a probe whose $0 sits in scripts/ (so lib.sh resolves), then
# stub cmd_status with the usage branch's own envelope and call emit_status.
cat > scripts/c5probe.sh <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/cycle.sh" status "$1" >/dev/null
cmd_status() { printf '{"ok":false,"verb":"status","exit":1,"next":"error","error":"usage"}\n'; return 1; }
emit_status close-story "$1" repair
EOF
out="$(bash scripts/c5probe.sh docs/specs/c5verb 2>&1)"; ex=$?
last="$(printf '%s\n' "$out" | tail -1)"
{ [ "$ex" -eq 0 ] && [ "$last" = '{"ok":true,"verb":"close-story","exit":0,"next":"repair"}' ]; } \
  && echo "  ok    cmd_status fails -> five keys, no status, still exit 0" \
  || { echo "::error::emit_status fallback: exit=$ex last=$last"; fail=1; }
rm -f scripts/c5probe.sh

echo "C5: non-zero exits carry no status key and are unchanged"
cat > docs/specs/c5verb/c5verb-03-wall.md <<'EOF'
---
story: c5verb-03
spec: c5verb
status: todo
returned: WALL
wave: 2
---
# Third

## Verification
`true`
EOF
git add -A && git commit -qm "c5verb: a WALL story" >/dev/null
out="$(council close-story docs/specs/c5verb/c5verb-03-wall.md 2>&1)"; ex=$?
last="$(printf '%s\n' "$out" | tail -1)"
{ [ "$ex" -eq 4 ] && [ "$last" = '{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"returned WALL"}' ]; } \
  && echo "  ok    close-story exit 4 (returned: WALL): no status key, line unchanged" \
  || { echo "::error::close-story WALL: exit=$ex last=$last"; fail=1; }

mk_open_spec c5dirty 2
set_tier c5dirty 1
echo "a dirty non-paperwork file" > c5verb-dirty.txt
out="$(council open-round docs/specs/c5dirty 2>&1)"; ex=$?
last="$(printf '%s\n' "$out" | tail -1)"
{ [ "$ex" -eq 2 ] && [ "$last" = '{"ok":false,"verb":"open-round","exit":2,"next":"error","error":"working tree not clean"}' ]; } \
  && echo "  ok    open-round exit 2 (dirty tree): no status key, line unchanged" \
  || { echo "::error::open-round dirty: exit=$ex last=$last"; fail=1; }
rm -f c5verb-dirty.txt

council pause docs/specs/c5dirty >/dev/null 2>&1
out="$(council open-round docs/specs/c5dirty 2>&1)"; ex=$?
last="$(printf '%s\n' "$out" | tail -1)"
{ [ "$ex" -eq 3 ] && printf '%s' "$last" | jq -e '.next == "paused" and (has("status") | not)' >/dev/null 2>&1; } \
  && echo "  ok    PAUSE + any verb -> exit 3, no status key" \
  || { echo "::error::paused verb: exit=$ex last=$last"; fail=1; }
council resume docs/specs/c5dirty >/dev/null 2>&1


fi # --quick: end of the skip opened at the reopen walk
# ============================================================================================
# 0.18 - Light VULYK (docs/adr/013-light-vulyk.md): the roster and the Client path, the sidecar
# constitution, frozen seats, no-court rounds, carry-forward, reopen -> repair, the repair and
# advance verbs, claim's clean-tree rule, close-story's idempotency and timeout. --quick runs
# every case here.
# ============================================================================================

echo "=== 0.18: Light VULYK (ADR-013) ==="
git add -A >/dev/null 2>&1; git commit -qm "0.18: snapshot what the sections above left" >/dev/null 2>&1
cp "$SRC"/scripts/wave-check.sh "$SRC"/scripts/trace-check.sh scripts/
# The fixture constitution gains a Profile (Client path left as the template's placeholder)
# and a slow ## Commands cell for the timeout case.
sed -i '1a\
\
## Profile\
\
| Field | Value |\
|---|---|\
| Client path | `<fill in - how a person reaches the running thing>` |' CLAUDE.md
printf '| Fixture: slower than VULYK_VERIFY_TIMEOUT=1 | `sleep 3` |\n' >> CLAUDE.md
git add -A && git commit -qm "0.18: fixture Profile + slow cell" >/dev/null

l18_client() { # l18_client <value> - rewrites the fixture constitution's Client path cell, commits
  sed -i "s#^| Client path | .*#| Client path | \`$1\` |#" CLAUDE.md
  git add -A && git commit -qm "constitution: Client path = $1" >/dev/null
}
l18_last() { printf '%s\n' "$1" | tail -1; } # l18_last <verb-output> -> its JSON line

echo "ADR-013 D1: the roster - Tier 1-2 review; Tier 3-4 opus review (a round without seats= reads the live roster)"
for t in 1 2 3 4; do mk_open_spec "r18t$t" 2; set_tier "r18t$t" "$t"; mk_open_round "r18t$t" 1 >/dev/null; done
# (later fixture commits stale these rounds, so `next` reads open-round here - the roster
# decides seats and missing, and those are what is checked)
council status docs/specs/r18t1 --json | jq -c '[.seats, .missing]' | expect "tier 1: seats and missing are [review]" '[["review"],["review"]]'
council status docs/specs/r18t2 --json | jq -c '[.seats, .missing]' | expect "tier 2: seats and missing are [review]" '[["review"],["review"]]'
council status docs/specs/r18t3 --json | jq -c '[.seats, .missing]' | expect "tier 3: opus, review - no sonnet, no haiku without a Client path" '[["opus","review"],["opus","review"]]'
council status docs/specs/r18t4 --json | jq -c '.seats' | expect "tier 4: the same roster as tier 3" '["opus","review"]'

echo "ADR-013 D1: haiku joins at Tier 3-4 only when the Client path is filled - not '<fill...>', not 'none...', any case"
l18_client "http://localhost:3000 with the test login"
council status docs/specs/r18t3 --json | jq -c '.seats' | expect "filled -> tier 3 adds haiku" '["haiku","opus","review"]'
council status docs/specs/r18t4 --json | jq -c '.seats' | expect "filled -> tier 4 adds haiku" '["haiku","opus","review"]'
council status docs/specs/r18t2 --json | jq -c '.seats' | expect "filled -> tier 2 stays review only" '["review"]'
l18_client "None: library only"
council status docs/specs/r18t3 --json | jq -c '.seats' | expect "'None: library only' is not filled" '["opus","review"]'
l18_client "<FILL IN later>"
council status docs/specs/r18t3 --json | jq -c '.seats' | expect "'<FILL IN ...>' is not filled" '["opus","review"]'

echo "ADR-013 D3: open-round freezes the roster into seats= - a later Profile edit leaves the open round alone"
l18_client "http://localhost:3000 with the test login"
mk_open_spec r18fz 2; set_tier r18fz 3
out="$(council open-round docs/specs/r18fz --commit 2>&1)"
grep -qx 'seats=haiku opus review' docs/specs/r18fz/council/round-1/ROUND && echo "  ok    ROUND carries seats=haiku opus review" \
  || { echo "::error::ROUND: $(cat docs/specs/r18fz/council/round-1/ROUND)"; fail=1; }
l18_last "$out" | jq -r .next | expect "open-round's own next names the frozen seats" "dispatch:haiku,opus,review"
l18_client "none: library only"
council status docs/specs/r18fz --json | jq -c '.seats' | expect "the Profile moved on, the open round did not" '["haiku","opus","review"]'

echo "ADR-013 D1: CLAUDE.vulyk.md, when it exists, is the constitution - for the roster and for close-story's ## Commands"
cat > CLAUDE.vulyk.md <<'EOF'
# Sidecar constitution

## Profile

| Field | Value |
|---|---|
| Client path | `bash bin/cli --help` |

## Commands

| Purpose | Command |
|---|---|
| Sidecar-only cell | `echo sidecar-only` |
EOF
council status docs/specs/r18t3 --json | jq -c '.seats' | expect "the sidecar's filled Client path wins over CLAUDE.md's 'none'" '["haiku","opus","review"]'
mkdir -p docs/specs/r18sc
printf -- '---\nstory: r18sc-01\nstatus: todo\nreturned: DONE\nwave: 1\n---\n# Sidecar cell\n\n## Files\n- r18sc-a.txt\n\n## Verification\n`echo sidecar-only`\n' > docs/specs/r18sc/r18sc-01-a.md
printf -- '---\nstory: r18sc-02\nstatus: todo\nreturned: DONE\nwave: 1\n---\n# CLAUDE.md-only cell\n\n## Files\n- r18sc-b.txt\n\n## Verification\n`true`\n' > docs/specs/r18sc/r18sc-02-b.md
git add -A && git commit -qm "r18sc: two stories" >/dev/null
out="$(council close-story docs/specs/r18sc/r18sc-01-a.md 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    a cell only the sidecar has closes the story" || { echo "::error::sidecar cell: exit=$ex out=$out"; fail=1; }
out="$(council close-story docs/specs/r18sc/r18sc-02-b.md 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF "CLAUDE.vulyk.md's ## Commands: true" \
  && echo "  ok    a cell only CLAUDE.md has is refused, naming CLAUDE.vulyk.md" || { echo "::error::CLAUDE.md-only cell: exit=$ex out=$out"; fail=1; }
rm -f CLAUDE.vulyk.md
l18_client "<fill in - how a person reaches the running thing>"

echo "ADR-013 D3: no blind seat required -> no court: court= empty, status court null, judge closes without one"
mk_open_spec r18nc 2; set_tier r18nc 2
out="$(council open-round docs/specs/r18nc --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -qx 'court=' docs/specs/r18nc/council/round-1/ROUND && [ ! -e .vulyk/court/r18nc ] \
  && echo "  ok    open-round exit 0, court= empty, no worktree under .vulyk/court/r18nc" || { echo "::error::no-court open: exit=$ex out=$out"; fail=1; }
council status docs/specs/r18nc --json | jq -c '[.court, .seats, .since]' | expect "status: court null, seats [review], since null on round 1" '[null,["review"],null]'
grep -qF 'round 1 opened, no court' docs/specs/r18nc/journal.md && echo "  ok    the journal says no court" \
  || { echo "::error::journal: $(cat docs/specs/r18nc/journal.md)"; fail=1; }
printf 'VERDICT: PASS\nall asks hold\n' | council record-seat docs/specs/r18nc 1 review >/dev/null 2>&1
out="$(council judge docs/specs/r18nc --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && l18_last "$out" | jq -e '.next == "green"' >/dev/null 2>&1 && echo "  ok    judge GREEN on review alone, no court to remove" \
  || { echo "::error::no-court judge: exit=$ex out=$out"; fail=1; }

echo "ADR-013 D3: round n>1 carries round n-1's GREEN/N/A blind seats - never review, never a RED seat; since= names round n-1's head"
mk_open_spec r18cf 2; set_tier r18cf 3
council open-round docs/specs/r18cf --commit >/dev/null 2>&1
seat_report opus 1 RG   | council record-seat docs/specs/r18cf 1 opus   >/dev/null 2>&1
seat_report sonnet 1 GN | council record-seat docs/specs/r18cf 1 sonnet >/dev/null 2>&1
printf 'VERDICT: PASS\nfine\n' | council record-seat docs/specs/r18cf 1 review >/dev/null 2>&1
council judge docs/specs/r18cf --commit >/dev/null 2>&1
h1="$(sed -n 's/^head=//p' docs/specs/r18cf/council/round-1/ROUND)"
echo "repair" > r18cf-code.txt && git add -A && git commit -qm "r18cf: the repair" >/dev/null
out="$(council open-round docs/specs/r18cf --commit 2>&1)"
rd2=docs/specs/r18cf/council/round-2
head -1 "$rd2/sonnet.md" 2>/dev/null | grep -qE 'carried: round 1 -->$' && echo "  ok    sonnet (GREEN, round 1) carried, header marked inside the comment" \
  || { echo "::error::sonnet carry: $(head -1 "$rd2/sonnet.md" 2>&1)"; fail=1; }
[ ! -f "$rd2/opus.md" ] && [ ! -f "$rd2/review.md" ] && echo "  ok    opus (RED) and review are not carried" \
  || { echo "::error::carried too much: $(ls "$rd2")"; fail=1; }
grep -qx "since=$h1" "$rd2/ROUND" && echo "  ok    ROUND since= is round 1's head" || { echo "::error::ROUND: $(cat "$rd2/ROUND")"; fail=1; }
council status docs/specs/r18cf --json | jq -c '[.missing, .since, .seat_attempt]' \
  | expect "status: missing opus+review, since round 1's head, seat_attempt 1 each" "[[\"opus\",\"review\"],\"$h1\",{\"opus\":1,\"review\":1}]"
grep -qF 'carried from round 1: sonnet' docs/specs/r18cf/journal.md && echo "  ok    the journal names the carried seat" \
  || { echo "::error::journal: $(tail -2 docs/specs/r18cf/journal.md)"; fail=1; }
echo "ADR-013 D3: a round holding only carried seats that goes stale re-stamps in place - no STALE row, no round 3"
echo "hand fix" > r18cf-code2.txt && git add -A && git commit -qm "r18cf: a hand fix" >/dev/null
hfix="$(git rev-parse --short HEAD)"
council open-round docs/specs/r18cf --commit >/dev/null 2>&1
[ ! -d docs/specs/r18cf/council/round-3 ] && ! grep '"spec":"r18cf"' memory/stats/council.jsonl | grep -qF '"round":2,' \
  && echo "  ok    re-stamped round 2 in place" || { echo "::error::round-3 or a STALE row appeared"; fail=1; }
grep -qx "head=$hfix" "$rd2/ROUND" \
  && echo "  ok    round 2's head moved to the fix" || { echo "::error::ROUND: $(cat "$rd2/ROUND")"; fail=1; }
seat_report opus 2 GG | council record-seat docs/specs/r18cf 2 opus >/dev/null 2>&1
printf 'VERDICT: PASS\nthe repair holds\n' | council record-seat docs/specs/r18cf 2 review >/dev/null 2>&1
out="$(council judge docs/specs/r18cf --commit 2>&1)"
row="$(grep '"spec":"r18cf"' memory/stats/council.jsonl | tail -1)"
printf '%s' "$row" | grep -qF '"verdict":"GREEN"' && printf '%s' "$row" | grep -qF '"sonnet":"GREEN"' && printf '%s' "$row" | grep -qF '"attempts":2' \
  && echo "  ok    round 2 GREEN with the carried sonnet counted, attempts 2 (a carried report is no dispatch)" || { echo "::error::row: $row"; fail=1; }

echo "ADR-013 D3: reopen after a ceiling ESCALATE routes to repair; after env, to open-round"
mk_open_spec r18ro 2; set_tier r18ro 1
council open-round docs/specs/r18ro --commit >/dev/null 2>&1
printf 'VERDICT: BLOCK\n## Major\n- [ask 1] ask 1 fails: run: t saw: f\n' | council record-seat docs/specs/r18ro 1 review >/dev/null 2>&1
council judge docs/specs/r18ro --commit >/dev/null 2>&1; ex=$?
[ "$ex" -eq 6 ] && echo "  ok    tier 1, one RED round -> ESCALATE ceiling" || { echo "::error::judge exit $ex"; fail=1; }
out="$(council reopen docs/specs/r18ro "fix ask 1 anyway" --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && l18_last "$out" | jq -e '.next == "repair" and .status.next == "repair"' >/dev/null 2>&1 \
  && echo "  ok    reopen emits next repair and carries the status that says so" || { echo "::error::reopen: exit=$ex out=$out"; fail=1; }
mk_open_spec r18re 2; set_tier r18re 1
council open-round docs/specs/r18re --commit >/dev/null 2>&1
council record-seat docs/specs/r18re 1 review </dev/null >/dev/null 2>&1
council record-seat docs/specs/r18re 1 review </dev/null >/dev/null 2>&1
council judge docs/specs/r18re --commit >/dev/null 2>&1
grep '"spec":"r18re"' memory/stats/council.jsonl | tail -1 | grep -qF '"escalate":"env"' && echo "  ok    review ABSENT -> ESCALATE env" \
  || { echo "::error::r18re row: $(grep '"spec":"r18re"' memory/stats/council.jsonl | tail -1)"; fail=1; }
out="$(council reopen docs/specs/r18re "the reviewer died, run it again" --commit 2>&1)"
l18_last "$out" | jq -r .next | expect "reopen after env -> open-round" "open-round"
council status docs/specs/r18re --json | jq -r .next | expect "status agrees: open-round" "open-round"

echo "ADR-013 D4: repair writes the mechanical story - asks from the row and the seats, findings verbatim, Files and Verification of the done stories"
mkdir -p docs/specs/r18rp
cp "$SRC/templates/plan.md" docs/specs/r18rp/plan.md
printf '# r18rp (brief)\n\n## Request\n> build the thing\n\n## Asks\n1. ask number 1 works\n2. ask number 2 works\n3. ask number 3 works\n' > docs/specs/r18rp/brief.md
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-26/; s#^\*\*Branch:\*\* <.*#**Branch:** vulyk/r18rp#; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' docs/specs/r18rp/plan.md
printf 'a\n' > r18rp-a.txt; printf 'b\n' > r18rp-b.txt
cat > docs/specs/r18rp/r18rp-01-a.md <<'EOF'
---
story: r18rp-01
status: done
wave: 1
---
# A

## Requirements
> build the thing

## Files
- r18rp-a.txt

## Verification
repeat: 2
`true`
EOF
cat > docs/specs/r18rp/r18rp-02-b.md <<'EOF'
---
story: r18rp-02
status: done
wave: 2
---
# B

## Requirements
> build the thing

## Files
- r18rp-b.txt
- r18rp-a.txt

## Verification
`true`
`sh -c 'true && true'`
EOF
git add -A && git commit -qm "r18rp: fixture" >/dev/null
out="$(council repair docs/specs/r18rp 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && printf '%s' "$out" | grep -qF 'next is open-round, not repair' && echo "  ok    repair refuses while status says anything but repair" \
  || { echo "::error::repair precondition: exit=$ex out=$out"; fail=1; }
council open-round docs/specs/r18rp --commit >/dev/null 2>&1
seat_report opus 1 GRG | council record-seat docs/specs/r18rp 1 opus >/dev/null 2>&1
printf 'VERDICT: BLOCK\n## Major\n- [ask 3] ask 3 regressed: run: t saw: f\n- [regression] the old path broke: app.sh:12\n- [unanchored] a naming nit no ask names\n## Minor\n- [ask 1] a minor, never copied\n' \
  | council record-seat docs/specs/r18rp 1 review >/dev/null 2>&1
council judge docs/specs/r18rp --commit >/dev/null 2>&1
council status docs/specs/r18rp --json | jq -r .next | expect "RED round 1 -> next repair" "repair"
out="$(council repair docs/specs/r18rp --commit 2>&1)"; ex=$?
rp=docs/specs/r18rp/r18rp-03-repair-round-1.md
mkdir -p .vulyk # gitignored: the expected text must not dirty the tree it is compared in
cat > .vulyk/r18rp-expected.md <<'EOF'
---
story: r18rp-03
status: todo
returned:
worker: worker-code
model: opus
wave: 3
blocked_by: []
---

# Repair round 1

## Goal
Make the asks and findings council round 1 left RED pass, and change nothing else.

## Requirements
> 2. ask number 2 works
> 3. ask number 3 works

## Findings
ASK 2: RED - ask 2 - run: check-2 saw: fail
- [ask 3] ask 3 regressed: run: t saw: f
- [regression] the old path broke: app.sh:12

## Files
- r18rp-a.txt
- r18rp-b.txt

## Verification
`true`
`sh -c 'true && true'`
EOF
[ "$ex" -eq 0 ] && diff .vulyk/r18rp-expected.md "$rp" >/dev/null 2>&1 && echo "  ok    the repair story is exactly the expected text" \
  || { echo "::error::repair story: exit=$ex out=$out"; diff .vulyk/r18rp-expected.md "$rp" 2>&1 | sed 's/^/        /'; fail=1; }
l18_last "$out" | jq -e '.ok == true and .verb == "repair" and .next == "build:3" and .status.wave == 3' >/dev/null 2>&1 \
  && echo "  ok    last line ok:true, next build:3 (one past the highest wave), carries status" || { echo "::error::repair line: $(l18_last "$out")"; fail=1; }
[ "$(git log -1 --format=%s)" = "vulyk(r18rp): repair round 1" ] && [ -z "$(git status --porcelain)" ] \
  && echo "  ok    --commit commits the story, tree clean" || { echo "::error::commit: $(git log -1 --format=%s) / $(git status --porcelain)"; fail=1; }
before="$(git rev-parse HEAD)"
out="$(council repair docs/specs/r18rp --commit 2>&1)"; ex=$?
n="$(ls docs/specs/r18rp/*-repair-round-1.md | wc -l | tr -d ' ')"
[ "$ex" -eq 0 ] && [ "$n" -eq 1 ] && [ "$(git rev-parse HEAD)" = "$before" ] && printf '%s' "$out" | grep -qF 'already repairs round 1' \
  && echo "  ok    idempotent: a second run writes nothing, commits nothing, exit 0" || { echo "::error::idempotency: exit=$ex n=$n out=$out"; fail=1; }
bash scripts/wave-check.sh docs/specs/r18rp | expect "wave-check: the repair story is dispatchable" "3 stories, dispatchable"
out="$(bash scripts/trace-check.sh docs/specs/r18rp)"
printf '%s' "$out" | expect "trace-check: its > N. quotes trace to ## Asks" "backward: 0 unfound + 0 storyless"

echo "ADR-013 D2: advance - branch and open-round in one call, stop at the first agent boundary, key order fixed"
mk_spec r18ad 2
sed -i 's/^\*\*Approved:\*\* <.*/**Approved:** owner, 2026-09-26/; s/^\(\*\*Tier:\*\* \)<[^>]*>/\12/' docs/specs/r18ad/plan.md
git add -A && git commit -qm "r18ad: approved, tier 2, no branch yet" >/dev/null
out="$(council advance docs/specs/r18ad 2>&1)"; ex=$?
last="$(l18_last "$out")"
[ "$ex" -eq 0 ] && [ "$(printf '%s' "$last" | jq -r 'keys_unsorted | join(",")')" = "ok,verb,exit,next,steps,rejected,status" ] \
  && echo "  ok    exit 0, keys ok,verb,exit,next,steps,rejected,status" || { echo "::error::advance: exit=$ex last=$last"; fail=1; }
printf '%s' "$last" | jq -c '[.steps, .next, .rejected, .status.seat_attempt]' \
  | expect "steps [branch, open-round], next dispatch:review, seat_attempt review 1" '[["branch","open-round"],"dispatch:review",[],{"review":1}]'
[ -z "$(git status --porcelain)" ] && echo "  ok    every step committed its own paperwork" || { echo "::error::dirty: $(git status --porcelain)"; fail=1; }
echo "  sample advance line: $last" | cut -c1-400

echo "ADR-013 D2: advance --ingest records the report the seat wrote, then judges"
mkdir -p .vulyk/reports/r18ad/round-1
printf 'VERDICT: PASS\nall asks hold\n' > .vulyk/reports/r18ad/round-1/review.attempt-1.md
out="$(council advance docs/specs/r18ad --ingest 2>&1)"
l18_last "$out" | jq -c '[.steps, .next, .rejected]' | expect "steps [judge], next green, nothing rejected" '[["judge"],"green",[]]'
[ -f docs/specs/r18ad/council/round-1/review.md ] && echo "  ok    review.md recorded from the file" || { echo "::error::no review.md"; fail=1; }

echo "ADR-013 D2: --ingest - a malformed file is rejected with its reason; a missing file spends the attempt on an empty report"
mk_open_spec r18ig 2; set_tier r18ig 3
council open-round docs/specs/r18ig --commit >/dev/null 2>&1
mkdir -p .vulyk/reports/r18ig/round-1
printf 'not a report\n' > .vulyk/reports/r18ig/round-1/opus.attempt-1.md
out="$(council advance docs/specs/r18ig --ingest 2>&1)"; ex=$?
last="$(l18_last "$out")"
[ "$ex" -eq 0 ] && printf '%s' "$last" | jq -e '.ok and (.steps == []) and .next == "dispatch:opus,review"' >/dev/null 2>&1 \
  && echo "  ok    rejections are not a stop: ok:true, no step, the seats still missing" || { echo "::error::ingest: exit=$ex last=$last"; fail=1; }
printf '%s' "$last" | jq -c '[.rejected[] | [.seat, .attempt, (.error | split(":")[0])]]' \
  | expect "rejected: opus and review, attempt 1, MALFORMED" '[["opus",1,"MALFORMED"],["review",1,"MALFORMED"]]'
printf '%s' "$last" | jq -c '.status.seat_attempt' | expect "seat_attempt moves both to 2" '{"opus":2,"review":2}'
[ -f docs/specs/r18ig/council/round-1/review.attempt-1.md ] && echo "  ok    the missing review file still spent attempt 1" \
  || { echo "::error::no review.attempt-1.md"; fail=1; }
seat_report opus 1 GG > .vulyk/reports/r18ig/round-1/opus.attempt-2.md
printf 'VERDICT: PASS\nfine\n' > .vulyk/reports/r18ig/round-1/review.attempt-2.md
out="$(council advance docs/specs/r18ig --ingest 2>&1)"
l18_last "$out" | jq -c '[.steps, .next, .rejected]' | expect "attempt-2 files recorded, judged GREEN" '[["judge"],"green",[]]'

echo "ADR-013 D2: advance stops on a failing verb - ok:false, its exit/next/error, failed, steps, rejected, no status"
mk_open_spec r18st 2; set_tier r18st 2
echo "stray" > r18st-dirty.txt
out="$(council advance docs/specs/r18st 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && [ "$(l18_last "$out")" = '{"ok":false,"verb":"advance","exit":2,"next":"error","error":"working tree not clean","failed":"open-round","steps":["open-round"],"rejected":[]}' ] \
  && echo "  ok    open-round's refusal is advance's stop line, byte for byte" || { echo "::error::stop: exit=$ex out=$out"; fail=1; }
rm -f r18st-dirty.txt

echo "ADR-013 D2: advance --claim claims first and needs --stamp; a failed claim is the stop; sub-verbs stay DRIVER-guarded"
out="$(council advance docs/specs/r18st --claim 2>&1)"; ex=$?
[ "$ex" -eq 1 ] && echo "  ok    --claim without --stamp -> usage, exit 1" || { echo "::error::exit=$ex out=$out"; fail=1; }
out="$(council advance docs/specs/r18st --stamp aaaa1111 --claim 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && grep -qx 'stamp=aaaa1111' docs/specs/r18st/DRIVER && l18_last "$out" | jq -e '.steps == ["open-round"]' >/dev/null 2>&1 \
  && echo "  ok    claimed, then opened the round under the stamp" || { echo "::error::claim+advance: exit=$ex out=$out"; fail=1; }
out="$(council advance docs/specs/r18st --stamp bbbb2222 --claim 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && l18_last "$out" | jq -e '.failed == "claim" and (.error | startswith("held by aaaa1111")) and (has("status") | not)' >/dev/null 2>&1 \
  && echo "  ok    a foreign stamp's claim fails -> failed:claim, held by" || { echo "::error::foreign claim: exit=$ex out=$out"; fail=1; }
out="$(council advance docs/specs/r18st --ingest 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && l18_last "$out" | jq -e '.failed == "record-seat" and (.error | startswith("held by aaaa1111"))' >/dev/null 2>&1 \
  && echo "  ok    no stamp under a held DRIVER: record-seat refuses, advance stops" || { echo "::error::guard: exit=$ex out=$out"; fail=1; }
council release docs/specs/r18st aaaa1111 >/dev/null 2>&1

echo "ADR-013 D2: Tier 4 - --ingest folds review-top and review-second into one review (the 0.17 driver's foldReviews)"
mk_open_spec r18f4 2; set_tier r18f4 4
council open-round docs/specs/r18f4 --commit >/dev/null 2>&1
mkdir -p .vulyk/reports/r18f4/round-1
seat_report opus 1 GG > .vulyk/reports/r18f4/round-1/opus.attempt-1.md
printf 'VERDICT: PASS\ntop reviewer: fine\n' > .vulyk/reports/r18f4/round-1/review-top.attempt-1.md
printf 'VERDICT: BLOCK\n## Major\n- [ask 2] second reviewer: ask 2 fails: run: t saw: f\n' > .vulyk/reports/r18f4/round-1/review-second.attempt-1.md
out="$(council advance docs/specs/r18f4 --ingest 2>&1)"
rf=docs/specs/r18f4/council/round-1/review.md
head -1 "$rf" 2>/dev/null | grep -qF 'verdict: BLOCK' && grep -qF 'top reviewer: fine' "$rf" && grep -qF 'second reviewer: ask 2 fails' "$rf" \
  && echo "  ok    PASS + BLOCK fold to BLOCK, both bodies kept" || { echo "::error::fold: $(cat "$rf" 2>&1)"; fail=1; }
l18_last "$out" | jq -c '[.steps, .next, .rejected]' | expect "judged RED on the folded review, then straight on to repair" '[["judge","repair"],"build:2",[]]'
grep -qF -- '- [ask 2] second reviewer: ask 2 fails' docs/specs/r18f4/r18f4-02-repair-round-1.md 2>/dev/null \
  && echo "  ok    the repair story quotes the second reviewer's anchored finding" \
  || { echo "::error::repair story: $(cat docs/specs/r18f4/r18f4-02-repair-round-1.md 2>&1)"; fail=1; }
mk_open_spec r18f4n 2; set_tier r18f4n 4
council open-round docs/specs/r18f4n --commit >/dev/null 2>&1
mkdir -p .vulyk/reports/r18f4n/round-1
seat_report opus 1 GG > .vulyk/reports/r18f4n/round-1/opus.attempt-1.md
printf 'VERDICT: PASS\nonly the top reviewer came back\n' > .vulyk/reports/r18f4n/round-1/review-top.attempt-1.md
out="$(council advance docs/specs/r18f4n --ingest 2>&1)"
l18_last "$out" | jq -c '[.rejected[] | [.seat, .attempt]]' | expect "a missing second report -> NO VERDICT -> review attempt 1 rejected" '[["review",1]]'
sed -n '2p' docs/specs/r18f4n/council/round-1/review.attempt-1.md | expect "the kept attempt starts NO VERDICT, naming both first lines" 'NO VERDICT: top=VERDICT: PASS · second=(no report)'

echo "ADR-013 D5: claim refuses a tree dirty outside paperwork; paperwork-only dirt passes; the holder's re-claim is exempt"
mk_spec r18cl 2
echo "stray" > r18cl-stray.txt
out="$(council claim docs/specs/r18cl s18a 2>&1)"; ex=$?
[ "$ex" -eq 2 ] && l18_last "$out" | jq -e '.error == "working tree not clean"' >/dev/null 2>&1 && [ ! -f docs/specs/r18cl/DRIVER ] \
  && echo "  ok    a stray file -> exit 2 working tree not clean, no DRIVER" || { echo "::error::dirty claim: exit=$ex out=$out"; fail=1; }
rm -f r18cl-stray.txt
echo "- a journal note" >> docs/specs/r18cl/journal.md
out="$(council claim docs/specs/r18cl s18a 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    paperwork-only dirt (journal.md) does not block a claim" || { echo "::error::paperwork claim: exit=$ex out=$out"; fail=1; }
echo "stray" > r18cl-stray.txt
out="$(council claim docs/specs/r18cl s18a 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && echo "  ok    the holder's own re-claim on a dirty tree still exits 0" || { echo "::error::re-claim: exit=$ex out=$out"; fail=1; }
rm -f r18cl-stray.txt
council release docs/specs/r18cl s18a >/dev/null 2>&1
git add -A && git commit -qm "r18cl: journal note" >/dev/null

echo "ADR-013 D5: close-story on a done story with a clean tree -> ok:true exit 0, 'already done', carries status"
mkdir -p docs/specs/r18cs
printf -- '---\nstory: r18cs-01\nstatus: todo\nreturned: DONE\nwave: 1\n---\n# Twice\n\n## Files\n- r18cs.txt\n\n## Verification\n`true`\n' > docs/specs/r18cs/r18cs-01-a.md
git add -A && git commit -qm "r18cs: fixture" >/dev/null
council close-story docs/specs/r18cs/r18cs-01-a.md --commit >/dev/null 2>&1
before="$(git rev-parse HEAD)"
out="$(council close-story docs/specs/r18cs/r18cs-01-a.md --commit 2>&1)"; ex=$?
[ "$ex" -eq 0 ] && printf '%s' "$out" | grep -qF 'already done' && l18_last "$out" | jq -e '.ok and .verb == "close-story" and (.status | type == "object")' >/dev/null 2>&1 \
  && [ "$(git rev-parse HEAD)" = "$before" ] && echo "  ok    second close: exit 0, already done, status carried, no commit" \
  || { echo "::error::already done: exit=$ex out=$out"; fail=1; }

echo "ADR-013 D5: close-story runs each command under timeout \$VULYK_VERIFY_TIMEOUT - 124 is exit 4 naming the timeout"
printf -- '---\nstory: r18cs-02\nstatus: todo\nreturned: DONE\nwave: 1\n---\n# Slow\n\n## Files\n- r18cs-slow.txt\n\n## Verification\n`sleep 3`\n' > docs/specs/r18cs/r18cs-02-slow.md
git add -A && git commit -qm "r18cs: a slow story" >/dev/null
out="$(VULYK_VERIFY_TIMEOUT=1 bash scripts/cycle.sh close-story docs/specs/r18cs/r18cs-02-slow.md 2>&1)"; ex=$?
[ "$ex" -eq 4 ] && [ "$(l18_last "$out")" = '{"ok":false,"verb":"close-story","exit":4,"next":"repair","error":"verification timed out after 1s: sleep 3"}' ] \
  && grep -q '^status: todo' docs/specs/r18cs/r18cs-02-slow.md && echo "  ok    exit 4, error names the timeout and the command, story stays todo" \
  || { echo "::error::timeout: exit=$ex out=$out"; fail=1; }

echo "ADR-013 D2: status --json appends since, seat_attempt, seats after every pre-0.18 key"
council status docs/specs/r18nc --json | jq -r 'keys_unsorted | .[-6:] | join(",")' | expect "the last six keys" "round_dir,paused,shipped,since,seat_attempt,seats"

[ "$QUICK" -eq 1 ] && echo "--quick: variant batteries, regression walks and pinned-commit replays skipped; bash tests/council.test.sh is the release gate"
exit $fail
