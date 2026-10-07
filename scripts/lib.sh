#!/usr/bin/env bash
# VULYK shared library - functions common to the cycle's gate scripts.
#
#   Usage: . "$(dirname "$0")/lib.sh"
#
# Extracted (autonomous-cycle ADR-001, story 01) from the four scripts that each carried a
# verbatim copy - ship-check.sh, human-check.sh, acceptance-log.sh, release-check.sh - so
# `paperwork_only()`'s whitelist ("every file the cycle writes") is one list that must agree
# with itself, instead of four that must agree by hand. This file only defines functions and
# sets no state, so sourcing it twice - or from two scripts in the same process - is harmless.
#
# Consumers migrate to this file in story 02; it is created here and used here (by cycle.sh)
# only. Not a script in its own right: nothing below runs on its own, so there is no `exit`.
set -u

is_story_file() { # is_story_file <file> -> 0 iff some line starts with `story:` - the same
  # answer `grep -q '^story:'` gives, read in bash: on Windows every grep is a process spawn,
  # and status asks this of every file in the spec several times per call.
  local l
  [ -f "$1" ] || return 1
  while IFS= read -r l || [ -n "$l" ]; do
    case "$l" in story:*) return 0 ;; esac
  done < "$1"
  return 1
}

pack_fingerprint() { # pack_fingerprint <spec-dir> - must match every caller exactly
  local dir="$1" names hasher=""
  names="$(
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      is_story_file "$f" || continue
      printf '%s\n' "${f##*/}"
    done | LC_ALL=C sort | tr '\n' ' '
  )"
  if command -v sha256sum >/dev/null 2>&1; then hasher="sha256sum"
  elif command -v shasum >/dev/null 2>&1; then hasher="shasum -a 256"; fi
  if [ -n "$hasher" ]; then
    printf '%s' "$names" | $hasher | cut -c1-12
  else
    printf 'n%s' "$(printf '%s' "$names" | wc -w | tr -d ' ')"
  fi
}

# is_paperwork_path() is the one whitelist (C1, amended R23/R4, autonomous-cycle-21): every
# caller that must tell the cycle's own writes from the software - paperwork_only() below and
# open-round's own dirty-tree precondition - goes through this single function, so the ADR
# invariant ("paperwork_only() lists every file the cycle writes") cannot drift into two lists
# that quietly disagree. Anchored to docs/specs/*/ (R23/m-2): an unanchored `*/council/*` or
# `*/journal.md` matched any hive path sharing those names, not just the cycle's own. brief.md
# joins the set because `reopen` writes it; scope.jsonl joins the memory/stats series because
# `close-story` writes it through scope-check.sh (R4/C-3(b)). VERSION and CHANGELOG.md join in
# 0.18 (ADR-013 D3): the release commit /vulyk-ship makes must not stale a GREEN round.
is_paperwork_path() { # is_paperwork_path <repo-relative-path>
  case "$1" in
    docs/specs/*/plan.md|docs/specs/*/journal.md|docs/specs/*/council/*|docs/specs/*/brief.md| \
    memory/stats/human.jsonl|memory/stats/acceptance.jsonl|memory/stats/ship.jsonl|memory/stats/council.jsonl|memory/stats/scope.jsonl| \
    memory/stats/anomalies.jsonl|memory/stats/evolve.jsonl|memory/stats/skills.json|VERSION|CHANGELOG.md) return 0 ;;
    memory/learnings/*.md)
      case "${1#memory/learnings/}" in */*) return 1 ;; esac
      return 0 ;;
    *) return 1 ;;
  esac
}

# A commit range is paperwork-only iff every changed path is one the cycle writes itself -
# never the software. See is_paperwork_path() above for the whitelist itself.
paperwork_only() { # paperwork_only <root> <from-commit> <to-commit>
  local changed p
  git -C "$1" merge-base --is-ancestor "$2" "$3" 2>/dev/null || return 1
  changed="$(git -C "$1" diff --name-only "$2" "$3" 2>/dev/null)" || return 1
  [ -n "$changed" ] || return 0
  while IFS= read -r p; do
    is_paperwork_path "$p" || return 1
  done <<EOF
$changed
EOF
  return 0
}

# A marker line is "filled" when it exists and does not still carry the template's `<...>`.
marker() { # marker <plan.md> <Name> -> prints the line's value, empty if absent/placeholder
  local v
  v="$(grep -m1 "^\*\*$2:\*\*" "$1" 2>/dev/null | sed "s/^\*\*$2:\*\*[[:space:]]*//")"
  case "$v" in ''|'<'*) return 0 ;; esac
  printf '%s' "$v"
}

# --- the constitution (ADR-013 D1) -----------------------------------------------------------
# A hive that keeps its own CLAUDE.md and puts VULYK's constitution in a sidecar has
# CLAUDE.vulyk.md; every place VULYK reads the constitution - close-story's ## Commands check,
# wave-check's verification-cell check, the Client path that decides the black-box seat - goes
# through constitution_file(), so a sidecar hive is never checked against the wrong file.
constitution_file() { # constitution_file <root> -> <root>/CLAUDE.vulyk.md if it exists, else <root>/CLAUDE.md
  if [ -f "$1/CLAUDE.vulyk.md" ]; then printf '%s' "$1/CLAUDE.vulyk.md"; else printf '%s' "$1/CLAUDE.md"; fi
}

command_cell_exists() { # command_cell_exists <constitution> <command> -> 0 iff <command> equals,
  # byte for byte, the backticked command cell of some row of the `## Commands` table (a `\|`
  # inside the cell is a literal `|`, R11/C-4). Reads only that one table's rows - nothing else
  # in the constitution - by slicing to the section first.
  local file="$1" want="$2"
  [ -f "$file" ] || return 1
  awk '
    /^## Commands[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/            { if (inblock) exit }
    inblock                     { print }
  ' "$file" \
    | sed -n 's/^|[^|]*|[[:space:]]*`\(.*\)`[[:space:]]*|[[:space:]]*$/\1/p' \
    | sed 's/\\|/|/g' \
    | grep -qxF "$want"
}

verification_segments() { # verification_segments <line> -> one &&-separated segment per line
  # (R11/C-4): every segment of a ## Verification line that is not itself a cell must be one.
  local rest="$1" seg
  while :; do
    case "$rest" in
      *' && '*) seg="${rest%%' && '*}"; printf '%s\n' "$seg"; rest="${rest#*' && '}" ;;
      *) printf '%s\n' "$rest"; break ;;
    esac
  done
}

profile_value() { # profile_value <constitution> <field> -> the value cell of the table row whose
  # first cell is <field> (case-insensitive, `*`/backticks ignored), backticks stripped, `\|`
  # unescaped, trimmed; empty when the row or the file is absent.
  [ -f "$1" ] || return 0
  awk -v want="$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')" '
    /^\|/ {
      line = $0; sub(/^\|/, "", line)
      i = index(line, "|"); if (!i) next
      key = substr(line, 1, i - 1); rest = substr(line, i + 1)
      gsub(/[*`]/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      if (tolower(key) != want) next
      sub(/\|[[:space:]]*$/, "", rest); gsub(/\\\|/, "|", rest); gsub(/`/, "", rest)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", rest)
      print rest; exit
    }' "$1"
}

client_path_filled() { # client_path_filled <constitution> -> 0 iff the Profile's Client path is
  # filled: non-empty, not the template's `<fill ...>`, not an honest `none...` (ADR-013 D1) -
  # the one question that decides whether a round needs the black-box seat.
  local v
  v="$(profile_value "$1" "Client path" | tr '[:upper:]' '[:lower:]')"
  case "$v" in ''|'<fill'*|none*) return 1 ;; esac
  return 0
}

# The model floor (0.20.0, ADR-015). Routing names families only (`opus`, `sonnet`, ...), so a new
# generation arrives with no edit; this list is the one place versions live. No dispatch may run
# below its family's line, whatever an alias, a provider or an env pin resolved to.
# - A newer model ships: raise its family's line.
# - `unreleased` marks a floor no model of that family meets yet, so the bare alias itself resolves
#   below the floor. Delete the word the day one ships.
# - `cc>=<x.y.z>` marks a floor the bare alias reaches only from that Claude Code version on: the
#   alias table ships inside Claude Code, and an older one resolves the alias to the previous model.
#   Haiku 5.5 shipped on 2026-10-07; Claude Code 2.1.292 still ran `haiku` as Haiku 4.5, 2.1.293 as
#   5.5. Drop the flag once no supported Claude Code is older.
# VULYK_MODEL_FLOOR overrides line by line, same shape, lines or `;` (`sonnet 4.5; opus 4.6`), for a
# hive that runs lower on purpose; a family it does not name keeps the default line.
model_floor() { # model_floor -> "<family> <major.minor> [unreleased|cc>=<x.y.z>]" lines
  local defaults='fable 5.1
opus 5.5
sonnet 5.5
haiku 5.5 cc>=2.1.293'
  local over="" f line
  [ -n "${VULYK_MODEL_FLOOR:-}" ] || { printf '%s\n' "$defaults"; return 0; } # the common case, no fork
  over="$(printf '%s\n' "$VULYK_MODEL_FLOOR" | tr ';,' '\n\n' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; /^$/d')"
  printf '%s\n' "$defaults" | while read -r f _; do
    line="$(printf '%s\n' "$over" | while read -r o rest; do [ "$o" = "$f" ] && { printf '%s %s' "$o" "$rest"; break; }; done)"
    if [ -n "$line" ]; then printf '%s\n' "$line"; else printf '%s\n' "$defaults" | grep "^$f "; fi
  done 2>/dev/null # a reader that stops at its family closes the pipe early; EPIPE is not news
}

model_version() { # model_version <model id> -> "<family> <major.minor>"; empty for an alias or an unknown shape
  # claude-sonnet-5-5 -> sonnet 5.5, claude-haiku-4-5-20251001 -> haiku 4.5, claude-opus-5 -> opus 5.0,
  # anthropic.claude-opus-5-5 / claude-opus-4-6@... likewise, claude-3-5-sonnet-20241022 -> sonnet 3.5.
  local id
  id="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$id" =~ claude-(fable|opus|sonnet|haiku)-([0-9]+)(-([0-9]{1,2}))?([^0-9]|$) ]]; then
    printf '%s %s.%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]:-0}"
  elif [[ "$id" =~ claude-([0-9]+)(-([0-9]{1,2}))?-(fable|opus|sonnet|haiku) ]]; then
    printf '%s %s.%s\n' "${BASH_REMATCH[4]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]:-0}"
  fi
}

claude_code_version() { # claude_code_version -> "x.y.z" of the Claude Code that resolves aliases; empty if unknown
  # The running session's own version first: Claude Code sets CLAUDE_CODE_VERSION ("2.1.292 (Claude
  # Code)") for its hooks and tools, and its alias table is the one a dispatch uses even when a newer
  # binary is already on disk. `claude --version` covers a plain terminal.
  local v="${CLAUDE_CODE_VERSION:-}"
  [ -n "$v" ] || v="$(claude --version 2>/dev/null | head -1)"
  v="${v%% *}"
  [[ "$v" =~ ^[0-9]+(\.[0-9]+)*$ ]] && printf '%s\n' "$v"
}

version_lt() { # version_lt <a> <b> - 0 iff dotted version a < b, numerically, missing parts are 0
  local IFS=. i x y
  local -a A=($1) B=($2)
  for ((i = 0; i < ${#A[@]} || i < ${#B[@]}; i++)); do
    x="${A[i]:-0}"; y="${B[i]:-0}"
    [ "$((10#$x))" -lt "$((10#$y))" ] && return 0
    [ "$((10#$x))" -gt "$((10#$y))" ] && return 1
  done
  return 1
}

model_below_floor() { # model_below_floor <model id | alias> -> prints "<family> <version> <floor>", 0 iff below
  # A resolved ID is compared with its family's line. An alias is below when its family's line is
  # `unreleased` (printed as "<family> alias <floor>"), or carries `cc>=<need>` and the Claude Code
  # that resolves it is older or unknown (printed as "<family> cc <floor> <have|unknown> <need>"):
  # an unknown version cannot vouch for the alias. Any other alias, an unknown shape or a family
  # with no line is never below.
  local fv fam ver fl flag a have
  a="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"; a="${a%%[[]*}"
  case "$a" in
    fable|opus|sonnet|haiku)
      read -r fl flag <<EOF
$(model_floor | while read -r f v x; do [ "$f" = "$a" ] && { printf '%s %s' "$v" "$x"; break; }; done)
EOF
      case "${flag:-}" in
        unreleased) printf '%s alias %s\n' "$a" "$fl"; return 0 ;;
        'cc>='*)
          have="$(claude_code_version)"
          if [ -z "$have" ] || version_lt "$have" "${flag#cc>=}"; then
            printf '%s cc %s %s %s\n' "$a" "$fl" "${have:-unknown}" "${flag#cc>=}"
            return 0
          fi ;;
      esac
      return 1 ;;
  esac
  fv="$(model_version "${1:-}")"; [ -n "$fv" ] || return 1
  fam="${fv% *}"; ver="${fv#* }"
  fl="$(model_floor | while read -r f v _; do [ "$f" = "$fam" ] && { printf '%s' "$v"; break; }; done)"
  [ -n "$fl" ] || return 1
  case "$fl" in *.*) ;; *) fl="$fl.0" ;; esac
  local vm="${ver%%.*}" vn="${ver#*.}" fm="${fl%%.*}" fn="${fl#*.}"
  if [ "$vm" -lt "$fm" ] 2>/dev/null || { [ "$vm" -eq "$fm" ] 2>/dev/null && [ "$vn" -lt "$fn" ] 2>/dev/null; }; then
    printf '%s %s %s\n' "$fam" "$ver" "$fl"
    return 0
  fi
  return 1
}

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; } # the one timestamp shape every ledger row uses

slug_of() { basename "$1"; } # slug_of <spec-dir>
