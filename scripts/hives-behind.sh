#!/usr/bin/env bash
# hives-behind.sh - does every local hive carry the local VULYK build? (card public-release-per-change)
# The local hives are VULYK's beta channel: every change merged on the local main reaches each of them,
# and a hive that cannot take it now carries a hold with a reason and an end date.
#
#   bash scripts/hives-behind.sh                  # read the registry and each hive, then judge
#   bash scripts/hives-behind.sh --check <state>  # judge a state file alone (the card's check:)
#
# Registry: ${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}, private, never in the repo. One hive per line:
#   <path>                                   the hive must carry the local VERSION
#   <path> | hold <YYYY-MM-DD> <reason>      held through that day, for that reason
# Lines starting with '#' and blank lines are skipped.
# State: `local <version>`, then one `hive <installed|none|missing> <path>[ | hold <date> <reason>]` per hive.
# Exit 0: every hive is on the local build or under a live hold. 1: a hive lags, has no version file, is not
# on disk, its hold is expired or malformed, or no hive is registered. 2: the registry, the state or VERSION
# is absent (a missing input is a refusal, never a pass).
set -u
ROOT="${VULYK_SRC:-$(cd "$(dirname "$0")/.." && pwd)}"
TODAY="${VULYK_TODAY:-$(date +%F)}"

judge() { # judge <state-file>
  local line want="" n=0 on=0 held=0 red=0 rest have path hold until reason
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
          if [[ "$until" < "$TODAY" ]]; then
            red=$((red + 1)); echo "  RED   $path: hold expired $until ($reason) - roll it out or hold it again"; continue
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

REG="${VULYK_HIVES_FILE:-$HOME/.vulyk/hives}"
[ -f "$REG" ] || { echo "hives-behind: no hive registry at $REG - list the local hives there, one path per line"; exit 2; }
[ -f "$ROOT/VERSION" ] || { echo "hives-behind: no VERSION in $ROOT"; exit 2; }
STATE="$(mktemp)"; trap 'rm -f "$STATE"' EXIT
printf 'local %s\n' "$(tr -d '[:space:]' < "$ROOT/VERSION")" > "$STATE"
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  path="$line"; tail=""
  case "$line" in *" | "*) path="${line%% | *}"; tail=" | ${line#* | }" ;; esac
  path="$(printf '%s' "$path" | sed 's/[[:space:]]*$//')"
  case "$path" in "~/"*) path="$HOME/${path#\~/}" ;; esac
  if [ ! -d "$path" ]; then have=missing
  else
    have="$(tr -d '[:space:]' < "$path/.claude/vulyk-version" 2>/dev/null || true)"; have="${have:-none}"
  fi
  printf 'hive %s %s%s\n' "$have" "$path" "$tail" >> "$STATE"
done < "$REG"
judge "$STATE"
