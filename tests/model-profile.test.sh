#!/usr/bin/env bash
# Model profile checks (model-profiles-01): scripts/model-profile.sh storage, roles, --set/--chosen/--recommend/--explain;
# top-model.sh --plan and its profile-aware gate and second reviewer; the profile at the end of top-model-brief.sh's
# line; the CLAUDE.md row. Every run gets a temp HOME, a temp config folder and a plan fixture, never the real ones.
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }
expect_eq() { # expect_eq <label> <expected> <actual>
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 - expected [$2], got [$3]"; fi
}
expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$2"; then ok "$1"
  else bad "$1 - expected '$2' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

# Hives: one with the profile machinery, one without model-profile.sh, one on the plan's base top-model.sh.
HIVE="$T/hive"; BARE="$T/bare"; BASE="$T/base"
for h in "$HIVE" "$BARE" "$BASE"; do mkdir -p "$h/scripts"; cp "$SRC/scripts/lib.sh" "$h/scripts/"; done
cp "$SRC/scripts/top-model.sh" "$SRC/scripts/model-profile.sh" "$HIVE/scripts/"
cp "$SRC/scripts/top-model.sh" "$BARE/scripts/"
HAVE_BASE=0
git -C "$SRC" show baa5219:scripts/top-model.sh > "$BASE/scripts/top-model.sh" 2>/dev/null && HAVE_BASE=1

printf '{"oauthAccount":{"organizationType":"claude_max","organizationRateLimitTier":"default_claude_max_20x"}}\n' > "$T/max.json"
printf '{"oauthAccount":{"organizationType":"claude_pro"}}\n' > "$T/pro.json"
H="$T/home"; CFG="$H/.claude"; mkdir -p "$H"
PLANFILE="$T/max.json"

run() { # run <hive> <script> [args]... - with a clean env, the temp HOME and config folder, the plan fixture
  local hive="$1" s="$2"; shift 2
  (cd "$hive" && env -u VULYK_TOP_MODEL -u ANTHROPIC_API_KEY \
    HOME="$H" USERPROFILE="$H" CLAUDE_CONFIG_DIR="$CFG" VULYK_CLAUDE_CONFIG="$PLANFILE" CLAUDE_PROJECT_DIR="$hive" \
    ${EXTRA_ENV:-} bash "$s" "$@")
}
mp() { run "$HIVE" scripts/model-profile.sh "$@"; }
tm() { run "$HIVE" scripts/top-model.sh "$@"; }

ROLES="queen planner review seat worker routine gate architect review-second"
roles_of() { local r out=""; for r in $ROLES; do out="$out $r=$(mp --role "$r")"; done; echo "${out# }"; }

echo "--- no profile file: today's output"
for fx in max pro missing; do
  PLANFILE="$T/$fx.json"
  expect_eq "[$fx] no file prints sonnet-builds" "sonnet-builds" "$(mp)"
  mp --chosen; expect_eq "[$fx] --chosen exits 1 with no file" "1" "$?"
  for mode in "" --explain; do
    expect_eq "[$fx] top-model.sh $mode matches a hive without model-profile.sh" \
      "$(run "$BARE" scripts/top-model.sh $mode)" "$(tm $mode)"
    if [ "$HAVE_BASE" = 1 ]; then
      expect_eq "[$fx] top-model.sh $mode matches the base (baa5219) resolver" \
        "$(run "$BASE" scripts/top-model.sh $mode)" "$(tm $mode | grep -v '^gate: ')"
    fi
  done
done
[ "$HAVE_BASE" = 1 ] || ok "the base resolver comparison skipped: baa5219 not in this clone"
GATE_HINT="gate: the Tier 4 review, the Tier 4 planner, lead-architect (Tier 4, or a story missed twice), a missed story's retry. A hive's own judge: bash scripts/model-profile.sh --role seat, and pass --effort explicitly."
tm --help | expect "top-model.sh --help prints the gate hint (fable-fallback-04; the base comparison drops it)" "$GATE_HINT"
tm --explain | expect "top-model.sh --explain prints the gate hint" "$GATE_HINT"
PLANFILE="$T/max.json"
expect_eq "[max] sonnet-builds column" \
  "queen=opus planner=opus review=opus seat=opus worker=sonnet routine=sonnet gate=fable architect=fable review-second=opus" \
  "$(roles_of)"
PLANFILE="$T/pro.json"
expect_eq "[pro] sonnet-builds column" \
  "queen=opus planner=opus review=opus seat=opus worker=sonnet routine=sonnet gate=opus architect=opus review-second=sonnet" \
  "$(roles_of)"
[ ! -e "$CFG" ] && ok "reading wrote nothing" || bad "reading created $CFG"

echo "--- --set opus-builds / economy"
for fx in max pro; do
  PLANFILE="$T/$fx.json"
  expect_eq "[$fx] --set opus-builds prints the name" "opus-builds" "$(mp --set opus-builds)"
  mp --chosen; expect_eq "[$fx] --chosen exits 0 after --set" "0" "$?"
  expect_eq "[$fx] opus-builds column" \
    "queen=opus planner=fable review=fable seat=fable worker=opus routine=haiku gate=fable architect=fable review-second=sonnet" \
    "$(roles_of)"
  expect_eq "[$fx] top-model.sh under opus-builds" "fable" "$(tm)"
  tm --explain | expect "[$fx] --explain: decided by the profile" "decided by: profile opus-builds"
  tm --explain | expect "[$fx] --explain: second reviewer sonnet" "second reviewer (Tier 4): sonnet"
  expect_eq "[$fx] VULYK_TOP_MODEL wins over the profile" "opus" "$(EXTRA_ENV=VULYK_TOP_MODEL=opus tm)"
  mp --set economy >/dev/null
  expect_eq "[$fx] economy column" \
    "queen=opus planner=opus review=opus seat=opus worker=sonnet routine=haiku gate=opus architect=opus review-second=sonnet" \
    "$(roles_of)"
  expect_eq "[$fx] top-model.sh under economy" "opus" "$(tm)"
  tm --explain | expect "[$fx] --explain: decided by economy" "decided by: profile economy"
  tm --explain | expect "[$fx] --explain: second reviewer sonnet under economy" "second reviewer (Tier 4): sonnet"
  expect_eq "[$fx] VULYK_TOP_MODEL wins over economy" "fable" "$(EXTRA_ENV=VULYK_TOP_MODEL=fable tm)"
done
mp --set opus-builds >/dev/null
printf '# VULYK Constitution\n\n`TOP_MODEL = opus` names the gate model.\n' > "$HIVE/CLAUDE.md"
expect_eq "a constitution TOP_MODEL pin wins over the profile" "opus" "$(tm)"
tm --explain | expect "--explain names the constitution pin" "decided by: constitution - CLAUDE.md pins TOP_MODEL = opus"
printf '# VULYK Constitution\n\n`TOP_MODEL = auto` names the gate model.\n' > "$HIVE/CLAUDE.md"
expect_eq "TOP_MODEL = auto defers to the profile" "fable" "$(tm)"
rm -f "$HIVE/CLAUDE.md"

echo "--- bad input"
cp "$CFG/vulyk-model-profile" "$T/before"
mp --set bogus >/dev/null 2>&1; expect_eq "--set bogus exits 2" "2" "$?"
cmp -s "$T/before" "$CFG/vulyk-model-profile" && ok "--set bogus leaves the file unchanged" || bad "--set bogus changed the file"
mp --set >/dev/null 2>&1; expect_eq "--set with no name exits 2" "2" "$?"
mp --role nobody >/dev/null 2>&1; expect_eq "--role with an unknown role exits 2" "2" "$?"
mp --bogus >/dev/null 2>&1; expect_eq "an unknown flag exits 2" "2" "$?"
printf 'garbage here\n' > "$CFG/vulyk-model-profile"
expect_eq "a garbage file reads as sonnet-builds" "sonnet-builds" "$(mp)"
mp --chosen; expect_eq "--chosen exits 1 for a garbage file" "1" "$?"
printf 'economy\r\n' > "$CFG/vulyk-model-profile"
expect_eq "economy\\r\\n reads as economy" "economy" "$(mp)"
mp --chosen; expect_eq "--chosen exits 0 for economy\\r\\n" "0" "$?"
printf '  opus-builds  \n\n' > "$CFG/vulyk-model-profile"
expect_eq "surrounding whitespace is ignored" "opus-builds" "$(mp)"
rm -f "$CFG/vulyk-model-profile"

echo "--- --recommend and --plan"
PLANFILE="$T/max.json";     expect_eq "--recommend on Max" "opus-builds max" "$(mp --recommend)"
expect_eq "--plan on Max" "max premium" "$(tm --plan)"
PLANFILE="$T/pro.json";     expect_eq "--recommend on Pro" "sonnet-builds pro" "$(mp --recommend)"
expect_eq "--plan on Pro" "pro standard" "$(tm --plan)"
PLANFILE="$T/missing.json"; expect_eq "--recommend with no account file" "sonnet-builds unknown" "$(mp --recommend)"
PLANFILE="$T/max.json"
mp --explain | expect "--explain names the default as not chosen" "profile : sonnet-builds (not chosen"
mp --explain economy | expect "--explain <name> shows the named profile" "routine        haiku"

echo "--- where the file lives"
find "$H" "$T/cfgA" "$T/up" 2>/dev/null | sort > "$T/tree.before"
(cd "$HIVE" && env -u VULYK_TOP_MODEL HOME="$H" USERPROFILE="$H" CLAUDE_CONFIG_DIR="$T/cfgA" \
  bash scripts/model-profile.sh --set economy >/dev/null)
expect_eq "CLAUDE_CONFIG_DIR is honoured" "economy" "$(cat "$T/cfgA/vulyk-model-profile" 2>/dev/null | tr -d '\r')"
find "$H" "$T/cfgA" "$T/up" 2>/dev/null | sort > "$T/tree.after"
expect_eq "--set wrote nothing outside the config folder" \
  "$T/cfgA|$T/cfgA/vulyk-model-profile" "$(comm -13 "$T/tree.before" "$T/tree.after" | paste -sd'|' -)"
expect_eq "the temp HOME holds no file" "" "$(find "$H" -type f 2>/dev/null)"
(cd "$HIVE" && env -u HOME -u CLAUDE_CONFIG_DIR -u VULYK_TOP_MODEL USERPROFILE="$T/up" \
  bash scripts/model-profile.sh --set opus-builds >/dev/null)
expect_eq "the USERPROFILE fallback works with HOME unset" "opus-builds" \
  "$(cat "$T/up/.claude/vulyk-model-profile" 2>/dev/null | tr -d '\r')"
expect_eq "the USERPROFILE fallback reads back" "opus-builds" \
  "$(cd "$HIVE" && env -u HOME -u CLAUDE_CONFIG_DIR USERPROFILE="$T/up" bash scripts/model-profile.sh)"
expect_eq "nothing else appeared under the fallback home" "$T/up/.claude/vulyk-model-profile" \
  "$(find "$T/up" -type f)"

echo "--- top-model-brief.sh"
brief() { run "$HIVE" "$SRC/.claude/hooks/top-model-brief.sh"; }
LINE="$(brief)"
case "$LINE" in *" · models sonnet-builds (not chosen)") ok "the brief ends with the default, not chosen" ;;
  *) bad "the brief does not end with ' · models sonnet-builds (not chosen)': $LINE" ;; esac
mp --set economy >/dev/null
LINE="$(brief)"
case "$LINE" in *" · models economy") ok "the brief ends with the chosen profile" ;;
  *) bad "the brief does not end with ' · models economy': $LINE" ;; esac
printf '%s\n' "$LINE" | expect "the brief says the profile decided the gate" "by profile economy"
rm -f "$CFG/vulyk-model-profile"

echo "--- CLAUDE.md"
grep -qxF '| Model profile tests | `bash tests/model-profile.test.sh` |' "$SRC/CLAUDE.md" \
  && ok "the ## Commands row is there" || bad "the ## Commands row is missing"
if git -C "$SRC" show baa5219:CLAUDE.md > "$T/claude.base" 2>/dev/null; then
  NOW="$(tr -d '\r' < "$SRC/CLAUDE.md" | wc -c | tr -d ' ')"; WAS="$(tr -d '\r' < "$T/claude.base" | wc -c | tr -d ' ')"
  [ "$NOW" -le "$WAS" ] && ok "CLAUDE.md is no bigger than at baa5219 ($NOW <= $WAS B)" \
    || bad "CLAUDE.md grew: $NOW B > $WAS B at baa5219"
else ok "the CLAUDE.md size comparison skipped: baa5219 not in this clone"; fi

N="$(wc -l < "$LEDGER" | tr -d ' ')"; F="$(wc -l < "$FAILS" | tr -d ' ')"
if [ "$F" -gt 0 ]; then echo "model-profile.test.sh: $F of $N checks failed"; exit 1; fi
echo "model-profile.test.sh: $N checks ok"
