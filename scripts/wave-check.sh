#!/usr/bin/env bash
# VULYK story gate - deterministic pre-dispatch check over a whole spec.
#
# Two stories dispatched concurrently that both touch one file is the silent-overwrite
# failure mode of every parallel agent setup: the second write wins, nobody reports it,
# and the diff looks plausible. This script makes that collision visible BEFORE the
# wave is dispatched - and, since v0.8.0, two more defects that only look harmless: a
# story naming a path the tree does not have, and a story whose verification command
# cannot fail for the files it touches. Like scope-check.sh it is deterministic,
# model-free and free.
#
#   Usage: scripts/wave-check.sh <spec-dir>
#          scripts/wave-check.sh docs/specs/oauth
#
# For every story file in the spec dir (frontmatter `story:` present, plan.md excluded)
# it reads `wave:`, `blocked_by:`, the `## Files` block and the `## Verification` block,
# then reports:
#   collision  - two stories in the SAME wave declare overlapping paths
#   order      - a story's wave is not strictly later than each of its blockers' waves
#   dangling   - a `blocked_by:` id that matches no story file in the spec
#   no-files   - a story with an empty `## Files` block (unmeasurable, uncollidable)
#   missing    - a declared path whose own parent directory does not exist: a typo, or a
#                plan that has not noticed it must create that directory first
#   empty-glob - a declared glob matching nothing in the tree right now
#   no-verify  - a story with an empty `## Verification` block: its green means nothing
#   verify-gap - the verification command names paths and none of them intersect this
#                story's `## Files` - the command may not be able to fail for this work
#   repeat     - a `repeat:` line under `## Verification` that is not a positive integer
#
# Limits, stated rather than hidden: a verification command that names NO path (a whole
# suite) cannot be judged here, and a path that resolves but is simply the wrong file
# passes. `missing` is a question about existence, never about correctness. A command
# token counts as a path only when the tree agrees - it exists, or it is a glob - so a
# package name like `@scope/pkg`, a branch name or a URL is not mistaken for one.
#
# Overlap matching mirrors scope-check.sh: exact path, glob, and directory prefix
# ("src/auth/" covers everything beneath it). Globs are compared both ways.
#
# Exit status is always 0: this reports, it does not block. Deciding is the Queen's
# job at plan time and the human's at approval.

set -u
shopt -s nullglob globstar 2>/dev/null || true

SPEC="${1:-}"
if [ -z "$SPEC" ] || [ ! -d "$SPEC" ]; then
  echo "wave-check: usage: $0 <spec-dir>   (e.g. docs/specs/oauth)" >&2
  exit 0
fi

# Declared paths are repo-relative, so they resolve from the repo root. Without a repo
# there is nothing to resolve them against - say so once, and keep every other check.
SPEC_ABS="$(cd "$SPEC" && pwd)"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
RESOLVE=1
if [ -n "$ROOT" ] && cd "$ROOT" 2>/dev/null; then
  case "$SPEC_ABS" in "$ROOT"/*) SPEC="${SPEC_ABS#"$ROOT"/}" ;; esac
else
  RESOLVE=0
fi

# --- gather stories ----------------------------------------------------------
STORIES=""
for f in "$SPEC"/*.md; do
  [ -f "$f" ] || continue
  grep -q '^story:' "$f" 2>/dev/null || continue
  STORIES="${STORIES}${f}
"
done
if [ -z "$STORIES" ]; then
  echo "wave-check: no story files (with 'story:' frontmatter) found in $SPEC" >&2
  exit 0
fi

fm() { # fm <file> <key> - first frontmatter-style "key: value", value printed raw
  awk -v k="$2" -F': *' '$1 == k { sub(/[[:space:]]*#.*$/, "", $2); print $2; exit }' "$1"
}

files_of() { # the `## Files` block, comments skipped (same parser as scope-check.sh)
  awk '
    /^##[[:space:]]+Files[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                    { inblock=0 }
    inblock && /^<!--/                  { incomment=1 }
    incomment                           { if (/-->/) incomment=0; next }
    inblock && /^-[[:space:]]+/         { sub(/^-[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
  ' "$1"
}

verify_of() { # the `## Verification` block, comments and backticks stripped
  awk '
    /^##[[:space:]]+Verification[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                           { inblock=0 }
    inblock && /^<!--/                         { incomment=1 }
    incomment                                  { if (/-->/) incomment=0; next }
    inblock && NF                              { gsub(/`/, ""); sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
  ' "$1"
}

overlap() { # overlap <path-or-glob> <path-or-glob> - 0 if the two can hit one file
  local a="$1" b="$2"
  [ "$a" = "$b" ] && return 0
  case "$a" in */) case "$b" in "$a"*) return 0 ;; esac ;; esac
  case "$b" in */) case "$a" in "$b"*) return 0 ;; esac ;; esac
  # shellcheck disable=SC2254
  case "$b" in $a) return 0 ;; esac
  # shellcheck disable=SC2254
  case "$a" in $b) return 0 ;; esac
  return 1
}

path_status() { # path_status <declared-path> - ok | new | missing | empty-glob
  local p="$1"
  case "$p" in
    */)
      [ -d "$p" ] && { echo ok; return; }
      echo missing; return ;;
    *[*?[]*)
      local m
      # shellcheck disable=SC2206
      m=( $p )
      [ "${#m[@]}" -gt 0 ] && { echo ok; return; }
      echo empty-glob; return ;;
  esac
  [ -e "$p" ] && { echo ok; return; }
  [ -d "$(dirname "$p")" ] && { echo new; return; }
  echo missing
}

PROBLEMS=0
report() { PROBLEMS=$((PROBLEMS+1)); echo "  ! $1"; }

# --- per-story sanity --------------------------------------------------------
for f in $STORIES; do
  id="$(fm "$f" story)"
  [ -n "$id" ] || id="$(basename "$f" .md)"
  declared="$(files_of "$f")"
  [ -n "$declared" ] || report "no-files:  $id declares nothing under '## Files' - neither scope nor collisions can be checked"

  # 1. do the declared paths resolve against the tree?
  if [ "$RESOLVE" -eq 1 ] && [ -n "$declared" ]; then
    while IFS= read -r p; do
      [ -z "$p" ] && continue
      case "$(path_status "$p")" in
        missing)
          report "missing:   $id names '$p' and its parent directory does not exist - a typo, or a directory no story creates" ;;
        empty-glob)
          report "empty-glob: $id names '$p', which matches nothing in the tree - the scope gate will measure an empty set" ;;
      esac
    done <<PATHS_EOF
$declared
PATHS_EOF
  fi

  # 2. can this story's verification turn red for this story?
  verify="$(verify_of "$f")"
  if [ -z "$verify" ]; then
    report "no-verify: $id names no command under '## Verification' - nothing about it can turn red"
  else
    reps="$(printf '%s\n' "$verify" | awk -F': *' '$1 ~ /^repeat$/ { gsub(/[[:space:]]/, "", $2); print $2; exit }')"
    if [ -n "$reps" ]; then
      case "$reps" in
        *[!0-9]*) report "repeat:    $id declares 'repeat: $reps' - must be a positive integer (how many times the command runs)" ;;
        0)        report "repeat:    $id declares 'repeat: 0' - a command run zero times verifies nothing" ;;
      esac
    fi
    if [ -n "$declared" ]; then
      # A token is a PATH only if the tree agrees: it exists, or it is a glob. Plenty of
      # command tokens carry a slash and mean nothing of the sort - `@scope/package`,
      # `feat/branch`, a URL - and treating those as paths reported every story in a
      # pnpm/npm monorepo as a verify-gap (found by the S2.6.5a battle test, 2026-08-18).
      cmd_paths=""
      for tok in $(printf '%s\n' "$verify" | grep -v '^repeat:' | tr ' \t' '\n\n' | grep '/' | grep -v '^-' | tr -d "\"'" | grep -v '^$'); do
        case "$tok" in
          *[*?[]*) cmd_paths="${cmd_paths}${tok}
" ;;
          *) [ -e "$tok" ] && cmd_paths="${cmd_paths}${tok}
" ;;
        esac
      done
      if [ -n "$cmd_paths" ]; then
        hit=0
        while IFS= read -r cp; do
          [ -z "$cp" ] && continue
          while IFS= read -r dp; do
            [ -z "$dp" ] && continue
            if overlap "$cp" "$dp"; then hit=1; break; fi
          done <<DECL_EOF
$declared
DECL_EOF
          [ "$hit" -eq 1 ] && break
        done <<CMDP_EOF
$cmd_paths
CMDP_EOF
        [ "$hit" -eq 0 ] && report "verify-gap: $id's verification names paths that do not intersect its '## Files' - check the command can fail for THIS story (an ignore file or a wrong directory makes green vacuous)"
      fi
    fi
  fi

  wave="$(fm "$f" wave)"; [ -n "$wave" ] || wave=1
  blockers="$(fm "$f" blocked_by | tr -d '[]' | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$' || true)"
  for b in $blockers; do
    bf=""
    for g in $STORIES; do
      [ "$(fm "$g" story)" = "$b" ] && { bf="$g"; break; }
    done
    if [ -z "$bf" ]; then
      report "dangling:  $id is blocked_by '$b', which matches no story in $SPEC"
      continue
    fi
    bwave="$(fm "$bf" wave)"; [ -n "$bwave" ] || bwave=1
    if [ "$wave" -le "$bwave" ] 2>/dev/null; then
      report "order:     $id (wave $wave) is blocked_by $b (wave $bwave) - blocker must be in an earlier wave"
    fi
  done
done

# --- pairwise collisions within each wave ------------------------------------
for f in $STORIES; do
  for g in $STORIES; do
    [ "$f" \< "$g" ] || continue                      # each unordered pair once
    wf="$(fm "$f" wave)"; [ -n "$wf" ] || wf=1
    wg="$(fm "$g" wave)"; [ -n "$wg" ] || wg=1
    [ "$wf" = "$wg" ] || continue
    idf="$(fm "$f" story)"; idg="$(fm "$g" story)"
    while IFS= read -r pa; do
      [ -z "$pa" ] && continue
      while IFS= read -r pb; do
        [ -z "$pb" ] && continue
        if overlap "$pa" "$pb"; then
          report "collision: $idf and $idg (both wave $wf) can both touch '$pb' - concurrent workers on one file silently overwrite each other"
        fi
      done <<EOF2
$(files_of "$g")
EOF2
    done <<EOF1
$(files_of "$f")
EOF1
  done
done

N="$(printf '%s' "$STORIES" | grep -c .)"
[ "$RESOLVE" -eq 1 ] || echo "wave-check: not a git repo - path resolution skipped; every other check ran."
if [ "$PROBLEMS" -eq 0 ]; then
  echo "wave-check: $SPEC - $N stories, dispatchable (no collisions, order holds, paths resolve, every story can turn red)"
else
  echo "wave-check: $SPEC - $N stories, $PROBLEMS problem(s) above."
  echo "  -> Fix at plan time: merge the colliding stories, split the shared file out,"
  echo "     move one story to a later wave, correct the path, or name a command that"
  echo "     actually covers the story's files. Do NOT dispatch a colliding wave."
fi
exit 0
