#!/usr/bin/env bash
# VULYK wave gate - deterministic pre-dispatch check for parallel builds.
#
# Two stories dispatched concurrently that both touch one file is the silent-overwrite
# failure mode of every parallel agent setup: the second write wins, nobody reports it,
# and the diff looks plausible. This script makes that collision visible BEFORE the
# wave is dispatched. Like scope-check.sh it is deterministic, model-free and free.
#
#   Usage: scripts/wave-check.sh <spec-dir>
#          scripts/wave-check.sh docs/specs/oauth
#
# For every story file in the spec dir (frontmatter `story:` present, plan.md excluded)
# it reads `wave:`, `blocked_by:` and the `## Files` block, then reports:
#   collision  - two stories in the SAME wave declare overlapping paths
#   order      - a story's wave is not strictly later than each of its blockers' waves
#   dangling   - a `blocked_by:` id that matches no story file in the spec
#   no-files   - a story with an empty `## Files` block (unmeasurable, uncollidable)
#
# Overlap matching mirrors scope-check.sh: exact path, glob, and directory prefix
# ("src/auth/" covers everything beneath it). Globs are compared both ways.
#
# Exit status is always 0: this reports, it does not block. Deciding is the Queen's
# job at plan time and the human's at approval.

set -u

SPEC="${1:-}"
if [ -z "$SPEC" ] || [ ! -d "$SPEC" ]; then
  echo "wave-check: usage: $0 <spec-dir>   (e.g. docs/specs/oauth)" >&2
  exit 0
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

PROBLEMS=0
report() { PROBLEMS=$((PROBLEMS+1)); echo "  ! $1"; }

# --- per-story sanity --------------------------------------------------------
for f in $STORIES; do
  id="$(fm "$f" story)"
  [ -n "$id" ] || id="$(basename "$f" .md)"
  [ -n "$(files_of "$f")" ] || report "no-files:  $id declares nothing under '## Files' - neither scope nor collisions can be checked"

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
if [ "$PROBLEMS" -eq 0 ]; then
  echo "wave-check: $SPEC - $N stories, waves are dispatchable (no collisions, order holds)"
else
  echo "wave-check: $SPEC - $N stories, $PROBLEMS problem(s) above."
  echo "  -> Fix at plan time: merge the colliding stories, split the shared file out,"
  echo "     or move one story to a later wave. Do NOT dispatch a colliding wave."
fi
exit 0
