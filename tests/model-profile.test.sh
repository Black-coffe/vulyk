#!/usr/bin/env bash
# Model profile checks (model-profiles-01): scripts/model-profile.sh storage, roles, --set/--chosen/--recommend/--explain;
# top-model.sh --plan and its profile-aware gate and second reviewer; the profile at the end of top-model-brief.sh's
# line; the CLAUDE.md row. Every run gets a temp HOME, a temp config folder and a plan fixture, never the real ones.
#   Usage: bash tests/model-profile.test.sh [--part defaults|set|edges|floor] [--list-parts]
PARTS="defaults set edges floor"
PART=""
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
    *) echo "usage: bash tests/model-profile.test.sh [--part <name>] [--list-parts]" >&2; exit 2 ;;
  esac
  shift
done
part() { [ -z "$PART" ] || [ "$PART" = "$1" ]; }
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
  (cd "$hive" && env -u VULYK_TOP_MODEL -u ANTHROPIC_API_KEY -u CLAUDE_CODE_EFFORT_LEVEL \
    HOME="$H" USERPROFILE="$H" CLAUDE_CONFIG_DIR="$CFG" VULYK_CLAUDE_CONFIG="$PLANFILE" CLAUDE_PROJECT_DIR="$hive" \
    ${EXTRA_ENV:-} bash "$s" "$@")
}
mp() { run "$HIVE" scripts/model-profile.sh "$@"; }
tm() { run "$HIVE" scripts/top-model.sh "$@"; }

ROLES="queen planner review seat worker routine gate architect review-second"
roles_of() { local r out=""; for r in $ROLES; do out="$out $r=$(mp --role "$r")"; done; echo "${out# }"; }

if part defaults; then
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

fi

if part set; then
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

fi

if part edges; then
PLANFILE="$T/max.json"
mp --set opus-builds >/dev/null # what the set part leaves behind: the file the next line copies
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
# ab-run-fixes-01: sonnet-builds on every account shape; opus-builds only through the owner's --set.
printf '{"oauthAccount":{"organizationType":"claude_max","organizationRateLimitTier":"default_claude_ultra"}}
' > "$T/ultra.json"
printf '{"oauthAccount":{"organizationType":"claude_team","seatTier":"premium"}}
' > "$T/premium-seat.json"
printf '{"oauthAccount":{"organizationType":"claude_enterprise","seatTier":"standard"}}
' > "$T/standard-seat.json"
REC_WANT=""; REC_GOT=""
for fx in max ultra premium-seat pro standard-seat api missing; do
  PLANFILE="$T/$fx.json"; KEY=""
  [ "$fx" = api ] && { PLANFILE="$T/missing.json"; KEY="ANTHROPIC_API_KEY=test-key"; }
  REC_WANT="$REC_WANT $fx=sonnet-builds"
  REC_GOT="$REC_GOT $fx=$(EXTRA_ENV="$KEY" mp --recommend | cut -d' ' -f1)"
done
expect_eq "model-profile: --recommend gives sonnet-builds on every plan" "${REC_WANT# }" "${REC_GOT# }"
PLANFILE="$T/max.json";     expect_eq "--recommend on Max keeps the plan word" "sonnet-builds max" "$(mp --recommend)"
expect_eq "--plan on Max" "max premium" "$(tm --plan)"
PLANFILE="$T/pro.json";     expect_eq "--recommend on Pro" "sonnet-builds pro" "$(mp --recommend)"
expect_eq "--plan on Pro" "pro standard" "$(tm --plan)"
PLANFILE="$T/premium-seat.json"; expect_eq "--plan on a premium seat" "premium-seat premium" "$(tm --plan)"
PLANFILE="$T/missing.json"; expect_eq "--recommend with no account file" "sonnet-builds unknown" "$(mp --recommend)"
PLANFILE="$T/missing.json"; expect_eq "--recommend with an API key" "sonnet-builds api" "$(EXTRA_ENV=ANTHROPIC_API_KEY=test-key mp --recommend)"
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
# mass-audit O6: one resolver run (a counting stub in front of top-model.sh), the dispatch sentence only off the default
CNT="$T/count"; mkdir -p "$CNT/scripts"
cp "$SRC/scripts/lib.sh" "$SRC/scripts/model-profile.sh" "$CNT/scripts/"
cp "$SRC/scripts/top-model.sh" "$CNT/scripts/top-model.real.sh"
printf '%s\n' 'printf "x\n" >> "$(dirname "$0")/calls"' 'exec bash "$(dirname "$0")/top-model.real.sh" "$@"' > "$CNT/scripts/top-model.sh"
cbrief() { : > "$CNT/scripts/calls"; run "$CNT" "$SRC/.claude/hooks/top-model-brief.sh"; }
LINE="$(cbrief)"
expect_eq "the brief runs top-model.sh once" "1" "$(wc -l < "$CNT/scripts/calls" | tr -d ' ')"
expect_eq "the default brief (floor ok, profile chosen, no pin) is one line" "1" "$(printf '%s\n' "$LINE" | wc -l | tr -d ' ')"
case "$LINE" in
  *"Dispatch model:"*) bad "the default brief still carries the dispatch sentence: $LINE" ;;
  *) ok "the default brief drops the dispatch sentence" ;; esac
printf '%s\n' "$LINE" | expect "the default brief still names the gate" "gate model: opus"
EXTRA_ENV="VULYK_TOP_MODEL=fable" cbrief | expect "a pinned gate brings the dispatch sentence back" "Dispatch model: fable"
EXTRA_ENV="ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-4-1" cbrief | expect "a floor miss brings the dispatch sentence back" "Dispatch model:"
rm -f "$CFG/vulyk-model-profile"
cbrief | expect "a profile not chosen brings the dispatch sentence back" "Dispatch model:"

echo "--- CLAUDE.md"
grep -qxF '| Models | `bash tests/model-profile.test.sh` |' "$SRC/CLAUDE.md" \
  && ok "the ## Commands row is there" || bad "the ## Commands row is missing"
if git -C "$SRC" show baa5219:CLAUDE.md > "$T/claude.base" 2>/dev/null; then
  NOW="$(tr -d '\r' < "$SRC/CLAUDE.md" | wc -c | tr -d ' ')"; WAS="$(tr -d '\r' < "$T/claude.base" | wc -c | tr -d ' ')"
  [ "$NOW" -le "$WAS" ] && ok "CLAUDE.md is no bigger than at baa5219 ($NOW <= $WAS B)" \
    || bad "CLAUDE.md grew: $NOW B > $WAS B at baa5219"
else ok "the CLAUDE.md size comparison skipped: baa5219 not in this clone"; fi
fi

if part floor; then
PLANFILE="$T/max.json"
rm -f "$CFG/vulyk-model-profile"
echo "--- the model floor follows the newest version (tails-1115-04)"
# fl <model> [VAR=value]... - model_below_floor in a clean env: its line, or ok
fl() { local m="$1"; shift; env -u VULYK_MODEL_FLOOR -u CLAUDE_CODE_VERSION "$@" \
  bash -c '. "$1/scripts/lib.sh"; model_below_floor "$2"' _ "$SRC" "$m" 2>/dev/null || echo ok; }
# tmf [VAR=value]... - top-model.sh --floor in the hive with no model variable from this shell
tmf() { (cd "$HIVE" && env -u VULYK_TOP_MODEL -u ANTHROPIC_API_KEY -u ANTHROPIC_MODEL -u ANTHROPIC_DEFAULT_FABLE_MODEL \
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL -u ANTHROPIC_DEFAULT_HAIKU_MODEL \
  -u CLAUDE_CODE_SUBAGENT_MODEL -u CLAUDE_CODE_USE_BEDROCK -u CLAUDE_CODE_USE_VERTEX -u CLAUDE_CODE_USE_FOUNDRY \
  -u VULYK_MODEL_FLOOR HOME="$H" USERPROFILE="$H" CLAUDE_CONFIG_DIR="$CFG" VULYK_CLAUDE_CONFIG="$PLANFILE" \
  CLAUDE_PROJECT_DIR="$HIVE" CLAUDE_CODE_VERSION=2.1.325 "$@" bash scripts/top-model.sh --floor 2>&1); }
expect_eq "a model one version behind the newest is below the floor: claude-fable-5-1 against fable 5.2" \
  "fable 5.1 5.2" "$(fl claude-fable-5-1)"
expect_eq "the newest fable, claude-fable-5-2, sits on the floor" "ok" "$(fl claude-fable-5-2)"
OUT="$(tmf VULYK_TOP_MODEL=claude-fable-5-1)"; RC=$?
expect_eq "a model one version behind the newest is below the floor: --floor exits 1 on a gate pin to claude-fable-5-1" "1" "$RC"
printf '%s\n' "$OUT" | expect "a model one version behind the newest is below the floor: --floor names the gate pin" \
  "below floor: gate model (env) = claude-fable-5-1 is fable 5.1, floor 5.2"
OUT="$(tmf VULYK_TOP_MODEL=claude-fable-5-2)"; RC=$?
expect_eq "--floor exits 0 on a gate pin to the newest fable" "0" "$RC"
printf '%s\n' "$OUT" | expect "--floor prints the fable 5.2 floor" "fable>=5.2"
# Neighbour: one other family, opus, one version behind its newest (5.5).
expect_eq "claude-opus-5, one version behind the newest opus, is below the floor" "opus 5.0 5.5" "$(fl claude-opus-5)"
expect_eq "the newest opus, claude-opus-5-5, sits on the floor" "ok" "$(fl claude-opus-5-5)"
OUT="$(tmf ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-5)"; RC=$?
expect_eq "--floor exits 1 on an opus pin one version behind" "1" "$RC"
printf '%s\n' "$OUT" | expect "--floor names the opus pin" "env ANTHROPIC_DEFAULT_OPUS_MODEL = claude-opus-5 is opus 5.0, floor 5.5"
# Fails closed on what it cannot read; VULYK_MODEL_FLOOR still wins.
expect_eq "an override line it cannot read keeps the fable 5.2 floor" "fable 5.1 5.2" \
  "$(fl claude-fable-5-1 VULYK_MODEL_FLOOR='fable x.y')"
expect_eq "a malformed cc>= line still fails closed" "haiku cc 5.5 2.1.325 2.1.x" \
  "$(fl haiku VULYK_MODEL_FLOOR='haiku 5.5 cc>=2.1.x' CLAUDE_CODE_VERSION=2.1.325)"
expect_eq "VULYK_MODEL_FLOOR still wins: fable 5.1 admits claude-fable-5-1" "ok" \
  "$(fl claude-fable-5-1 VULYK_MODEL_FLOOR='fable 5.1')"
OUT="$(tmf VULYK_TOP_MODEL=claude-fable-5-1 VULYK_MODEL_FLOOR='fable 5.1')"; RC=$?
expect_eq "--floor exits 0 on claude-fable-5-1 under VULYK_MODEL_FLOOR='fable 5.1'" "0" "$RC"

echo "--- model_version reads every family name (cc-facts F2)"
mv_of() { bash -c '. "$1/scripts/lib.sh"; model_version "$2"' _ "$SRC" "$1"; }
expect_eq "model_version reads fable"  "fable 5.2"  "$(mv_of claude-fable-5-2)"
expect_eq "model_version reads opus"   "opus 5.5"   "$(mv_of claude-opus-5-5)"
expect_eq "model_version reads sonnet" "sonnet 5.5" "$(mv_of claude-sonnet-5-5)"
expect_eq "model_version reads haiku"  "haiku 4.5"  "$(mv_of claude-haiku-4-5-20251001)"
expect_eq "model_version reads mythos" "mythos 5.2" "$(mv_of claude-mythos-5-2)"
expect_eq "an alias is still no version" "" "$(mv_of mythos)"

echo "--- CLAUDE_CODE_EFFORT_LEVEL wins the effort cascade (cc-facts F3)"
EXTRA_ENV="CLAUDE_CODE_EFFORT_LEVEL=high" tm --explain | expect "--explain says a set CLAUDE_CODE_EFFORT_LEVEL wins" \
  "effort    : CLAUDE_CODE_EFFORT_LEVEL=high is set and wins over --effort"
expect_eq "unset, --explain carries no effort line" "" "$(tm --explain | grep '^effort ')"
expect_eq "auto sends no level, so --explain carries no effort line" "" \
  "$(EXTRA_ENV="CLAUDE_CODE_EFFORT_LEVEL=auto" tm --explain | grep '^effort ')"

echo "--- every plan has a branch (cc-facts F12)"
printf '{"oauthAccount":{"organizationType":"claude_ultra"}}\n' > "$T/ultra-org.json"
printf '{"oauthAccount":{"organizationType":"claude_team","seatTier":"standard"}}\n' > "$T/team.json"
printf '{"oauthAccount":{"organizationType":"claude_enterprise","seatTier":"premium"}}\n' > "$T/enterprise.json"
printf '{"oauthAccount":{"organizationType":"claude_galaxy"}}\n' > "$T/galaxy.json"
printf '{"oauthAccount":{"organizationType":"claude_max","organizationRateLimitTier":"default_claude_ultra"}}\n' > "$T/ultra.json"
PLANFILE="$T/pro.json";        expect_eq "plan Pro"        "pro standard"           "$(tm --plan)"
PLANFILE="$T/max.json";        expect_eq "plan Max"        "max premium"            "$(tm --plan)"
PLANFILE="$T/ultra-org.json";  expect_eq "plan Ultra"      "ultra premium"          "$(tm --plan)"
expect_eq "Ultra hands the gate to fable" "fable" "$(tm)"
tm --explain | expect "--explain names Ultra" "plan      : ultra (Ultra)"
PLANFILE="$T/ultra.json";      tm --explain | expect "a Max account on an Ultra rate tier reads as Ultra" "plan      : max (Ultra)"
PLANFILE="$T/team.json";       expect_eq "plan Team"       "standard-seat standard" "$(tm --plan)"
PLANFILE="$T/enterprise.json"; expect_eq "plan Enterprise" "premium-seat premium"   "$(tm --plan)"
PLANFILE="$T/galaxy.json";     expect_eq "an unknown plan still reads as unknown" "unknown standard" "$(tm --plan)"
tm --explain | expect "and says so" "unrecognised organizationType 'claude_galaxy'"
PLANFILE="$T/max.json"
fi

N="$(wc -l < "$LEDGER" | tr -d ' ')"; F="$(wc -l < "$FAILS" | tr -d ' ')"
if [ "$F" -gt 0 ]; then echo "model-profile.test.sh: $F of $N checks failed"; exit 1; fi
echo "model-profile.test.sh: $N checks ok"
