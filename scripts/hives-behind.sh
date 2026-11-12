#!/usr/bin/env bash
# hives-behind.sh - does every local hive carry the local VULYK build? (card public-release-per-change)
# The local hives are VULYK's beta channel: every change merged on the local main reaches each of them,
# and a hive that cannot take it now carries a hold with a reason and an end date.
#
#   bash scripts/hives-behind.sh                  # read the registry and each hive, then judge
#   bash scripts/hives-behind.sh --check <state>  # judge a state file alone (the card's check:)
#   bash scripts/hives-behind.sh --canaries       # print the canary hives' paths, one per line
#   bash scripts/hives-behind.sh --busy <hive>    # is someone working in it? idle (0) | busy <why> (1) | unknown <why> (1)
#   bash scripts/hives-behind.sh --slug <path>    # the folder name Claude Code gives that path under <root>/projects/
#
# --busy (ship step 2a asks it before every hive upgrade and again before the hive commit): busy on a
# docs/specs/*/DRIVER file or on a session transcript (*.jsonl, subagents included) written in the last 60 minutes
# under <root>/projects/<slug>/. Roots: $VULYK_SESSION_ROOTS (space-separated) when set, else
# ${CLAUDE_CONFIG_DIR:-~/.claude} and every ~/.claude* dir with a projects/ folder (a second account). No transcript
# folder under any root is `unknown`, never idle: what cannot be seen is not taken as free. An open session that has
# written nothing for over an hour is not seen (known gap, accepted 2026-11-12).
#
# Registry: ${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}, private, never in the repo. One hive per line:
#   <path>                                   the hive must carry the local VERSION
#   <path> | hold <YYYY-MM-DD> <reason>      held through that day, for that reason
#   <path> | canary                          upgraded and smoke-tested first; the others wait for it
#   <path> | canary | hold ...               both
# Lines starting with '#' and blank lines are skipped.
# State: `local <version>`, then one `hive <installed|none|missing> <path>[ | hold <date> <reason>]` per hive.
# Exit 0: every hive is on the local build or under a live hold. 1: a hive lags, has no version file, is not
# on disk, its hold is expired or malformed, or no hive is registered. 2: the registry, the state or VERSION
# is absent (a missing input is a refusal, never a pass).
set -u
ROOT="${VULYK_SRC:-$(cd "$(dirname "$0")/.." && pwd)}"
TODAY="${VULYK_TODAY:-$(date +%F)}"

HOLD_MAX_DAYS=7   # a hold ends at most this many days ahead, so it cannot become the new "later"

day_number() { # day_number <YYYY-MM-DD> -> days since 0000-03-01, or nothing when it is not a real day
  local y m d dim era yoe mp
  y=$((10#${1%%-*})); m="${1#*-}"; m=$((10#${m%%-*})); d=$((10#${1##*-}))
  [ "$m" -ge 1 ] && [ "$m" -le 12 ] || return 1
  case "$m" in 4|6|9|11) dim=30 ;; 2) dim=28
    if [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; then dim=29; fi ;; *) dim=31 ;; esac
  [ "$d" -ge 1 ] && [ "$d" -le "$dim" ] || return 1
  [ "$m" -le 2 ] && y=$((y - 1))
  era=$((y / 400)); yoe=$((y - era * 400)); mp=$(((m + 9) % 12))
  echo $((era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + (153 * mp + 2) / 5 + d - 1))
}

judge() { # judge <state-file>
  local line want="" n=0 on=0 held=0 red=0 rest have path hold until reason du dt
  dt="$(day_number "$TODAY")" || { echo "hives-behind: today '$TODAY' is not a date"; return 2; }
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      "local "*) want="${line#local }"; want="${want//[[:space:]]/}" ;;
      "hive "*)
        n=$((n + 1)); rest="${line#hive }"; have="${rest%% *}"; path="${rest#* }"; hold=""
        case "$path" in *" | "*) hold="${path#* | }"; path="${path%% | *}" ;; esac
        if [ -n "$want" ] && [ "$have" = "$want" ]; then
          on=$((on + 1)); echo "  ok    $path $have"; continue
        fi
        if [ -n "$hold" ]; then
          until="$(printf '%s' "$hold" | awk '{print $2}')"
          reason="$(printf '%s' "$hold" | awk '{ $1=""; $2=""; sub(/^ +/, ""); print }')"
          case "$hold" in hold\ *) ;; *) until="" ;; esac
          case "$until" in
            [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
            *) red=$((red + 1)); echo "  RED   $path: malformed hold '$hold' (want: hold <YYYY-MM-DD> <reason>)"; continue ;;
          esac
          if [ -z "$reason" ]; then
            red=$((red + 1)); echo "  RED   $path: hold without a reason"; continue
          fi
          du="$(day_number "$until")" || du=""
          if [ -z "$du" ]; then
            red=$((red + 1)); echo "  RED   $path: hold date $until is not a real day"; continue
          fi
          if [ "$du" -lt "$dt" ]; then
            red=$((red + 1)); echo "  RED   $path: hold expired $until ($reason) - roll it out or hold it again"; continue
          fi
          if [ $((du - dt)) -gt "$HOLD_MAX_DAYS" ]; then
            red=$((red + 1)); echo "  RED   $path: hold until $until is more than $HOLD_MAX_DAYS days ahead ($reason)"; continue
          fi
          held=$((held + 1)); echo "  held  $path $have: $reason (until $until)"; continue
        fi
        red=$((red + 1))
        case "$have" in
          missing) echo "  RED   $path: not on disk - fix or remove its registry line" ;;
          none)    echo "  RED   $path: no .claude/vulyk-version - VULYK was never stamped there" ;;
          *)       echo "  RED   $path: $have, local build is $want" ;;
        esac ;;
    esac
  done < "$1"
  if [ -z "$want" ]; then echo "hives-behind: no 'local <version>' line in $1"; return 2; fi
  if [ "$n" -eq 0 ]; then echo "hives-behind: no hive registered - the local build reaches nobody"; return 1; fi
  echo "hives-behind: $n hives, $on on $want, $held held, $red red"
  [ "$red" -eq 0 ]
}

if [ "${1:-}" = "--check" ]; then
  [ -f "${2:-}" ] || { echo "hives-behind: no state file '${2:-}'"; exit 2; }
  judge "$2"; exit $?
fi

norm_path() { # norm_path <path> -> '/' separators, no trailing '/', Git Bash /e/x read as E:/x, drive letter upper-case
  local p; p="$(printf '%s' "$1" | tr '\\' '/')"
  while [ "${#p}" -gt 1 ] && [ "${p%/}" != "$p" ]; do p="${p%/}"; done
  case "$(uname -s 2>/dev/null)" in   # Git Bash spells E:/x as /e/x; Claude Code sees E:\x
    MINGW*|MSYS*|CYGWIN*) case "$p" in /[a-zA-Z]/*|/[a-zA-Z]) p="${p:1:1}:/${p:3}" ;; esac ;;
  esac
  case "$p" in [a-z]:*) p="$(printf '%s' "${p:0:1}" | tr '[:lower:]' '[:upper:]')${p:1}" ;; esac
  printf '%s\n' "$p"
}

hive_slug() { # hive_slug <path> -> every character but a letter or a digit turned into '-', as Claude Code names it
  norm_path "$1" | sed 's/[^A-Za-z0-9]/-/g'
}

fresh_jsonl() { find "$1" -maxdepth 3 -name '*.jsonl' -mmin -60 2>/dev/null; } # transcripts, subagents included

sub_session() { # sub_session <dir> <normalized hive> -> a busy line, exit 0, when a fresh transcript there ran in the hive
  local f c                                              # or below it, or carries no readable cwd; else exit 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    c="$(grep -o -m1 '"cwd":"[^"]*"' "$f" 2>/dev/null | head -1)"
    [ -n "$c" ] || { echo "busy a fresh transcript in ${1##*/} has no readable cwd ($f)"; return 0; }
    c="${c#\"cwd\":\"}"; c="$(norm_path "${c%\"}")"   # JSON's \\ is two backslashes: both become /, then collapse
    c="$(printf '%s' "$c" | sed 's#//*#/#g')"
    case "$c" in "$2"|"$2"/*) echo "busy a session in a subfolder of the hive ($c) wrote in the last 60 minutes ($f)"; return 0 ;; esac
  done <<EOF
$(fresh_jsonl "$1")
EOF
  return 1
}

session_roots() { # one root per line
  local r
  if [ -n "${VULYK_SESSION_ROOTS:-}" ]; then printf '%s\n' "$VULYK_SESSION_ROOTS" | tr ' ' '\n'; return; fi
  printf '%s\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  for r in "$HOME"/.claude*; do [ -d "$r/projects" ] && printf '%s\n' "$r"; done
}

busy() { # busy <hive> -> one line; exit 0 idle, 1 busy or unknown
  local hive="$1" slug nh r d f seen=0
  [ -d "$hive" ] || { echo "unknown $hive: not on disk"; return 1; }
  for f in "$hive"/docs/specs/*/DRIVER; do
    [ -f "$f" ] && {   # a build that died leaves this file behind: the line says how to tell and how to free it
      echo "busy a build driver runs (${f#"$hive"/}; if no build runs there, the file is stale - free it in that hive with" \
        "bash scripts/cycle.sh release $(dirname "${f#"$hive"/}") <stamp from that file>)"; return 1; }
  done
  slug="$(hive_slug "$hive")"; nh="$(norm_path "$hive")"
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    d="$r/projects/$slug"
    if [ -d "$d" ]; then
      seen=1
      f="$(fresh_jsonl "$d" | head -1)"
      [ -z "$f" ] || { echo "busy a session transcript was written in the last 60 minutes ($f)"; return 1; }
    fi
    for d in "$r/projects/$slug"-*; do   # a session started in a subfolder: <slug>-<rest>, or a sibling hive
      [ -d "$d" ] && sub_session "$d" "$nh" && return 1
    done
  done <<EOF
$(session_roots)
EOF
  [ "$seen" = 1 ] || { echo "unknown no session transcripts for $hive (folder $slug) under any root - cannot tell it is idle"; return 1; }
  echo "idle"
}

case "${1:-}" in
  --slug) [ -n "${2:-}" ] || { echo "hives-behind: --slug needs a path"; exit 2; }; hive_slug "$2"; exit 0 ;;
  --busy) [ -n "${2:-}" ] || { echo "hives-behind: --busy needs a hive path"; exit 2; }; busy "$2"; exit $? ;;
esac

reg_line() { # reg_line <line> -> path, tail (" | hold ..." or empty), canary (1 or empty)
  local seg rest; path="$1"; tail=""; canary=""
  case "$1" in *" | "*) path="${1%% | *}"; rest="${1#* | }" ;; *) rest="" ;; esac
  while [ -n "$rest" ]; do
    case "$rest" in *" | "*) seg="${rest%% | *}"; rest="${rest#* | }" ;; *) seg="$rest"; rest="" ;; esac
    seg="$(printf '%s' "$seg" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [ "$seg" = "canary" ]; then canary=1; else tail="$tail | $seg"; fi
  done
  path="$(printf '%s' "$path" | sed 's/[[:space:]]*$//')"
  case "$path" in "~/"*) path="$HOME/${path#\~/}" ;; esac
}

REG="${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}"
[ -f "$REG" ] || { echo "hives-behind: no hive registry at $REG - list the local hives there, one path per line"; exit 2; }
if [ "${1:-}" = "--canaries" ]; then
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"; case "$line" in ''|'#'*) continue ;; esac
    reg_line "$line"; [ -n "$canary" ] && { echo "$path"; n=$((n + 1)); }
  done < "$REG"
  [ "$n" -gt 0 ] || { echo "hives-behind: no canary in $REG - mark one or two hives '<path> | canary'" >&2; exit 1; }
  exit 0
fi
[ -f "$ROOT/VERSION" ] || { echo "hives-behind: no VERSION in $ROOT"; exit 2; }
STATE="$(mktemp)"; trap 'rm -f "$STATE"' EXIT
printf 'local %s\n' "$(tr -d '[:space:]' < "$ROOT/VERSION")" > "$STATE"
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  reg_line "$line"
  if [ ! -d "$path" ]; then have=missing
  else
    have="$(tr -d '[:space:]' < "$path/.claude/vulyk-version" 2>/dev/null || true)"; have="${have:-none}"
  fi
  printf 'hive %s %s%s\n' "$have" "$path" "$tail" >> "$STATE"
done < "$REG"
judge "$STATE"
