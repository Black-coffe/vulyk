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

pack_fingerprint() { # pack_fingerprint <spec-dir> - must match every caller exactly
  local dir="$1" names hasher=""
  names="$(
    for f in "$dir"/*.md; do
      [ -f "$f" ] || continue
      grep -q '^story:' "$f" 2>/dev/null || continue
      basename "$f"
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
# `close-story` writes it through scope-check.sh (R4/C-3(b)).
is_paperwork_path() { # is_paperwork_path <repo-relative-path>
  case "$1" in
    docs/specs/*/plan.md|docs/specs/*/journal.md|docs/specs/*/council/*|docs/specs/*/brief.md| \
    memory/stats/human.jsonl|memory/stats/acceptance.jsonl|memory/stats/ship.jsonl|memory/stats/council.jsonl|memory/stats/scope.jsonl| \
    memory/stats/anomalies.jsonl) return 0 ;;
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

now_ts() { date -u +%Y-%m-%dT%H:%M:%SZ; } # the one timestamp shape every ledger row uses

slug_of() { basename "$1"; } # slug_of <spec-dir>
