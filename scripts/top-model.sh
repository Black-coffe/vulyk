#!/usr/bin/env bash
# VULYK top-model resolver: which model holds the gate on THIS account, right now.
#
#   scripts/top-model.sh            -> prints one alias: fable | opus
#   scripts/top-model.sh --explain  -> plan, the signal it was read from, and the reason
#   scripts/top-model.sh --apply    -> pins the Queen's model (always opus, v0.16.0) as "model" in
#                                      .claude/settings.local.json so her session starts on it
#   scripts/top-model.sh --check    -> exit 0 if settings.local.json pins the Queen's model, 1 if not
#   scripts/top-model.sh --floor    -> exit 0 if nothing configured here can resolve a family below
#                                      the model floor (scripts/lib.sh, ADR-015), 1 with one line each
#
# The rule (v0.18.0, ADR-013 D3): the resolved alias is the GATE model - the Tier 4
# lead-review (beside the second reviewer), lead-architect, the Tier 4 planner and a missed
# story's retry. lead-review at Tier 1-3, the Queen and every other rung run on their
# frontmatter model (`opus` or `sonnet`, ADR-015), whatever the plan. Fable holds the gate wherever
# the plan includes it, Opus everywhere else. Per Anthropic's plan terms (Sept 2026) that means:
#
#   Max 5x / Max 20x, Team & Enterprise premium seats  -> fable   (up to half the weekly limit
#                                                                  is Fable at no extra cost)
#   Pro, Team standard seats, Enterprise standard seats -> opus    (Fable bills to usage credits
#                                                                  on top of the subscription)
#   API key, unknown, not signed in                     -> opus    (the safe floor; pin to change)
#
# Where the plan is read from: the profile Claude Code caches in ~/.claude.json
# (`oauthAccount.organizationType`, `.organizationRateLimitTier`, `.seatTier`). That file
# is Claude Code's own cache of the signed-in account - no token, no credential, nothing
# this script could misuse - and it is the only local place the plan is written down.
# The credentials file is never opened. VULYK touches configuration, not auth.
#
# Resolution order (first hit wins):
#   1. VULYK_TOP_MODEL=<alias>            env override, this shell only
#   2. `TOP_MODEL = <alias>` in CLAUDE.md  the constitution's pin; `auto` (the default) defers
#   3. the plan, as above
#   4. opus
#
# Fails open, always: any missing file, unreadable JSON or unknown plan resolves to `opus`
# and says why under --explain. A resolver that could break a session start is worse than
# one that picks the cheaper model.
#
#   VULYK_CLAUDE_CONFIG=/path/to/.claude.json   read the profile from here instead (tests, CI)
#   CLAUDE_CONFIG_DIR                            honoured, as Claude Code honours it
set -u

MODE="print"
case "${1:-}" in
  "")            MODE="print" ;;
  --explain)     MODE="explain" ;;
  --apply)       MODE="apply" ;;
  --check)       MODE="check" ;;
  --floor)       MODE="floor" ;;
  -h|--help)     sed -n '2,41p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *)             echo "error: unknown flag $1 (try --help)" >&2; exit 2 ;;
esac

ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
. "$(dirname "$0")/lib.sh"

# ---------------------------------------------------------------- the profile

profile_path() {
  if [ -n "${VULYK_CLAUDE_CONFIG:-}" ]; then printf '%s\n' "$VULYK_CLAUDE_CONFIG"; return; fi
  if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && [ -f "$CLAUDE_CONFIG_DIR/.claude.json" ]; then
    printf '%s\n' "$CLAUDE_CONFIG_DIR/.claude.json"; return
  fi
  local home="${HOME:-}"
  [ -n "$home" ] && [ -f "$home/.claude.json" ] && { printf '%s\n' "$home/.claude.json"; return; }
  # Windows shells that reach here without HOME (rare, but a hook is not the place to find out)
  if [ -n "${USERPROFILE:-}" ]; then
    local up="${USERPROFILE//\\//}"
    [ -f "$up/.claude.json" ] && { printf '%s\n' "$up/.claude.json"; return; }
  fi
  printf '%s\n' "${home:-.}/.claude.json"
}

# field <file> <key> - the string value of "key": "..." anywhere in the file, or empty.
# grep/sed rather than jq or python: this runs on every session start, on machines where
# neither may be installed, and the fields it wants are flat strings under oauthAccount.
field() {
  grep -o -E "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$1" 2>/dev/null \
    | head -1 | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*"([^"]*)"$/\1/'
}

PROFILE="$(profile_path)"
PLAN="unknown"; SIGNAL=""; DETAIL=""
if [ -f "$PROFILE" ] && grep -q '"oauthAccount"' "$PROFILE" 2>/dev/null; then
  ORG="$(field "$PROFILE" organizationType)"
  TIER="$(field "$PROFILE" organizationRateLimitTier)"
  SEAT="$(field "$PROFILE" seatTier)"
  SIGNAL="organizationType=${ORG:-?}"
  [ -n "$TIER" ] && SIGNAL="$SIGNAL rateLimitTier=$TIER"
  [ -n "$SEAT" ] && SIGNAL="$SIGNAL seatTier=$SEAT"
  case "$ORG" in
    *max*)
      PLAN="max"
      case "$TIER" in
        *20x*) DETAIL="Max 20x" ;;
        *5x*)  DETAIL="Max 5x" ;;
        *)     DETAIL="Max" ;;
      esac ;;
    *pro*)   PLAN="pro";  DETAIL="Pro" ;;
    *team*|*enterprise*)
      # Premium seats carry Fable inside the plan; standard seats bill it to credits.
      case "$SEAT" in
        *premium*) PLAN="premium-seat"; DETAIL="${ORG} premium seat" ;;
        *)         PLAN="standard-seat"; DETAIL="${ORG} standard seat" ;;
      esac ;;
    "")      PLAN="unknown"; DETAIL="signed in, but no organizationType in the profile" ;;
    *)       PLAN="unknown"; DETAIL="unrecognised organizationType '$ORG'" ;;
  esac
elif [ -n "${ANTHROPIC_API_KEY:-}" ]; then
  PLAN="api"; SIGNAL="ANTHROPIC_API_KEY set"; DETAIL="API key - per-token billing, no plan"
else
  PLAN="unknown"; SIGNAL="no profile at $PROFILE"; DETAIL="not signed in, or Claude Code has not cached the account yet"
fi

# ---------------------------------------------------------------- resolution

constitution_pin() {
  local f
  for f in "$ROOT/CLAUDE.md" "$ROOT/CLAUDE.vulyk.md"; do
    [ -f "$f" ] || continue
    # `]` first and `[` inside the bracket so ERE reads them as members, not delimiters -
    # the alias may carry a `[1m]` suffix.
    grep -m1 -o -E 'TOP_MODEL[[:space:]]*=[[:space:]]*`?[A-Za-z0-9][][A-Za-z0-9._-]*' "$f" 2>/dev/null \
      | sed -E 's/.*=[[:space:]]*`?//' | head -1
    return
  done
}

SOURCE=""; MODEL=""; REASON=""
if [ -n "${VULYK_TOP_MODEL:-}" ]; then
  MODEL="$VULYK_TOP_MODEL"; SOURCE="env"; REASON="VULYK_TOP_MODEL is set in this shell"
else
  PIN="$(constitution_pin)"
  if [ -n "$PIN" ] && [ "$PIN" != "auto" ]; then
    MODEL="$PIN"; SOURCE="constitution"; REASON="CLAUDE.md pins TOP_MODEL = $PIN"
  else
    SOURCE="plan"
    case "$PLAN" in
      max|premium-seat)
        MODEL="fable"; REASON="$DETAIL - Fable is inside the plan (up to half the weekly limit at no extra cost)" ;;
      pro|standard-seat)
        MODEL="opus";  REASON="$DETAIL - Fable bills to usage credits on top of the subscription; Opus is the frontier model the plan includes" ;;
      api)
        MODEL="opus";  REASON="$DETAIL - Opus is the safe gate; pin TOP_MODEL = fable in CLAUDE.md to spend on Fable per token" ;;
      *)
        MODEL="opus";  REASON="$DETAIL - defaulting to the safe floor; pin TOP_MODEL in CLAUDE.md or set VULYK_TOP_MODEL" ;;
    esac
  fi
fi

label() { # label <alias> - human name for the brief: the family and its floor, never a version
  # that would go stale the day a newer model ships (ADR-015)
  local fl
  fl="$(model_floor | while read -r f v _; do [ "$f" = "$1" ] && { printf '%s' "$v"; break; }; done)"
  case "$1" in
    fable|opus|sonnet|haiku) printf '%s%s
' "$(printf '%s' "${1:0:1}" | tr '[:lower:]' '[:upper:]')${1:1}" "${fl:+ >= $fl}" ;;
    *) printf '%s
' "$1" ;;
  esac
}

# The Tier 4 second reviewer must be a DIFFERENT model from lead-review, and one the plan
# carries without credits: the other frontier alias where both are in the plan, sonnet
# where only Opus is.
second_reviewer() {
  case "$1" in
    fable) echo "opus" ;;
    opus)  case "$PLAN" in max|premium-seat) echo "fable" ;; *) echo "sonnet" ;; esac ;;
    *)     echo "opus" ;;
  esac
}

# ---------------------------------------------------------------- the local pin
# The Queen is not the gate: she orchestrates on Opus on every plan (ADR-012, ADR-015) - at
# launch Opus 5.5 matched Fable 5.1 at high for about a third of the cost, with no weekly cap.

QUEEN="opus"
LOCAL="$ROOT/.claude/settings.local.json"
pinned_model() { [ -f "$LOCAL" ] && field "$LOCAL" model; }

# ---------------------------------------------------------------- modes

case "$MODE" in
  print)
    printf '%s\n' "$MODEL" ;;

  explain)
    echo "top model : $MODEL ($(label "$MODEL"))"
    echo "decided by: $SOURCE - $REASON"
    echo "plan      : $PLAN${DETAIL:+ ($DETAIL)}"
    echo "signal    : ${SIGNAL:-none}"
    echo "profile   : $PROFILE"
    echo "second reviewer (Tier 4): $(second_reviewer "$MODEL")"
    echo "dispatched for: the Tier 4 lead-review (beside the second reviewer), lead-architect, a Tier 4 queen-planner, a missed story's retry; lead-review at Tier 1-3 runs on its frontmatter (opus)"
    P="$(pinned_model)"
    if [ -z "$P" ]; then
      echo "queen session: not pinned - the session starts on the account default (Opus since Claude Code 2.1.280). Run: bash scripts/top-model.sh --apply"
    elif [ "$P" = "$QUEEN" ]; then
      echo "queen session: pinned $P in .claude/settings.local.json"
    else
      echo "queen session: pinned $P in .claude/settings.local.json, the Queen runs on $QUEEN - re-run --apply, or keep the pin deliberately"
    fi ;;

  floor)
    # Before the fact (ADR-015): every place an alias can be remapped below the floor. The after-the-
    # fact half is telemetry's `model_below_floor`, read off the model each transcript really ran on.
    FOUND=0
    # Hundreds of story files say `model: sonnet`: each distinct value is judged once, since a fork
    # per line cost 17 s at session start on Windows.
    OK_SEEN=" "
    below() { # below <where> <value> - one line per ID under its family's floor
      local b
      [ -n "$2" ] || return 0
      case "$OK_SEEN" in *" $2 "*) return 0 ;; esac
      b="$(model_below_floor "$2")" || { OK_SEEN="$OK_SEEN$2 "; return 0; }
      set -- "$1" "$2" $b
      if [ "$4" = "alias" ]; then
        echo "below floor: $1 = $2 - no $3 at its floor $5 has shipped, so the alias runs an older one"
      elif [ "$4" = "cc" ] && [ "$6" = "unknown" ]; then
        echo "below floor: $1 = $2 - the Claude Code version is unknown, and only Claude Code $7+ resolves the alias to a $3 at its floor $5"
      elif [ "$4" = "cc" ]; then
        echo "below floor: $1 = $2 - Claude Code $6 resolves the alias to a $3 below its floor $5; $7 is the first that does not. Run: claude update"
      else
        echo "below floor: $1 = $2 is $3 $4, floor $5"
      fi
      FOUND=1
    }
    # The variables that decide what a session or a dispatch runs on. The Haiku remap is in since
    # 0.26.0, when `cycle-clerk` moved to `haiku`; the small/fast model stays out: it is Claude Code's
    # own background model, not a VULYK route.
    VARS="ANTHROPIC_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_SUBAGENT_MODEL"
    for v in $VARS; do below "env $v" "${!v:-}"; done
    # Settings files a session reads: the user's, the project's, the local one. Their `env` blocks
    # set the same variables, and `model` sets the session.
    # One grep over all three files and bash for the rest: this runs at every session start.
    USER_DIR="${CLAUDE_CONFIG_DIR:-${HOME:-.}/.claude}"
    PROVIDER=""; PINS=" "
    for v in CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY; do
      case "${!v:-}" in 1|true|TRUE|yes) PROVIDER="$v" ;; esac
    done
    for v in ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL; do
      [ -n "${!v:-}" ] && PINS="$PINS$v "
    done
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      f="${hit%%:\"*}"; kv="${hit#"$f":}"
      k="${kv#\"}"; k="${k%%\"*}"
      val="${kv%\"}"; val="${val##*\"}"
      case "$k" in
        CLAUDE_CODE_USE_*) case "$val" in 1|true|TRUE|yes) PROVIDER="$k" ;; esac ;;
        *) case "$k" in ANTHROPIC_DEFAULT_OPUS_MODEL|ANTHROPIC_DEFAULT_SONNET_MODEL|ANTHROPIC_DEFAULT_HAIKU_MODEL) [ -n "$val" ] && PINS="$PINS$k " ;; esac
           below "$f $k" "$val" ;;
      esac
    done <<EOF
$(for f in "$USER_DIR/settings.json" "$ROOT/.claude/settings.json" "$ROOT/.claude/settings.local.json"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done | while IFS= read -r f; do
    grep -o -E '"(model|ANTHROPIC_MODEL|ANTHROPIC_DEFAULT_(FABLE|OPUS|SONNET|HAIKU)_MODEL|CLAUDE_CODE_SUBAGENT_MODEL|CLAUDE_CODE_USE_(BEDROCK|VERTEX|FOUNDRY))"[[:space:]]*:[[:space:]]*"[^"]*"' "$f" 2>/dev/null \
      | sed "s|^|$f:|; s/\"[[:space:]]*:[[:space:]]*\"/\":\"/"
  done)
EOF
    # The frontmatter that routes a dispatch: framework agents, the story template, and every story
    # a driver may still dispatch. One grep, not a process per file.
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      f="${hit%%:model:*}"; m="${hit#*:model:}"; m="${m%%#*}"; m="${m//[[:space:]]/}"
      below "${f#"$ROOT"/} model" "$m"
    done <<EOF
$(grep -H -m1 '^model:' "$ROOT"/.claude/agents/*.md "$ROOT/templates/story.md" "$ROOT"/docs/specs/*/*.md 2>/dev/null)
EOF
    # A third-party provider: Claude Code's own table has `sonnet` and even `opus` resolving to
    # 4.x there, and `haiku` to Haiku 4.5. Only a family pin (ANTHROPIC_DEFAULT_<FAMILY>_MODEL)
    # makes the alias safe.
    if [ -n "$PROVIDER" ]; then
      for fam in OPUS SONNET HAIKU; do
        v="ANTHROPIC_DEFAULT_${fam}_MODEL"
        if case "$PINS" in *" $v "*) false ;; *) true ;; esac; then
          echo "below floor risk: $PROVIDER is set and $v is not - the alias can resolve to a 4.x model there; pin it to the provider's ID at or above the floor"
          FOUND=1
        fi
      done
    fi
    SUMMARY="$(model_floor | while read -r f v _; do printf '%s>=%s ' "$f" "$v"; done)"
    if [ "$FOUND" = 0 ]; then
      echo "model floor: ${SUMMARY% } - ok"
      exit 0
    fi
    echo "model floor: ${SUMMARY% } - see the lines above (docs/model-cascade.md#the-model-floor)"
    exit 1 ;;

  check)
    P="$(pinned_model)"
    [ "$P" = "$QUEEN" ] && exit 0
    exit 1 ;;

  apply)
    P="$(pinned_model)"
    if [ "$P" = "$QUEEN" ]; then
      echo "already pinned: model = $QUEEN in $LOCAL"
      exit 0
    fi
    mkdir -p "$ROOT/.claude" 2>/dev/null || true
    if [ ! -f "$LOCAL" ]; then
      printf '{\n  "model": "%s"\n}\n' "$QUEEN" > "$LOCAL" || { echo "error: cannot write $LOCAL" >&2; exit 1; }
      echo "pinned: model = $QUEEN -> created $LOCAL (takes effect on the next launch; /model $QUEEN now if this session must have it)"
      exit 0
    fi
    # Existing file: it carries the owner's permissions and standing approvals, so merge one
    # key and touch nothing else. Python is what the framework already depends on for
    # handoff.py; without it, say exactly what to add rather than rewriting JSON with sed.
    PY="$(command -v python3 || command -v python || command -v py || true)"
    if [ -z "$PY" ]; then
      echo "cannot merge without python: add  \"model\": \"$QUEEN\"  to $LOCAL by hand"
      exit 1
    fi
    if "$PY" - "$LOCAL" "$QUEEN" <<'PYPIN'
import json, sys
path, model = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
except Exception:
    sys.exit(4)
if not isinstance(data, dict):
    sys.exit(4)
data["model"] = model
with open(path, "w", encoding="utf-8") as fh:
    json.dump(data, fh, indent=2)
    fh.write("\n")
PYPIN
    then
      echo "pinned: model = $QUEEN in $LOCAL (was: ${P:-unset}; takes effect on the next launch)"
    else
      echo "cannot parse $LOCAL as JSON - left untouched; add  \"model\": \"$QUEEN\"  by hand"
      exit 1
    fi ;;
esac
exit 0
