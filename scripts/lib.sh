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
    memory/stats/anomalies.jsonl|memory/stats/skills.json|VERSION|CHANGELOG.md) return 0 ;;
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

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; } # the one timestamp shape every ledger row uses

slug_of() { basename "$1"; } # slug_of <spec-dir>
