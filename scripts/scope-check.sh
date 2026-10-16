#!/usr/bin/env bash
# VULYK scope gate - the framework's only objective metric.
#
# Compares what a story DECLARED it would touch (its `## Files` block) against what the
# diff ACTUALLY touched, and records both numbers. Deterministic, no model involved,
# no tokens spent.
#
#   Usage: scripts/scope-check.sh <story-file> [git-diff-range]
#          scripts/scope-check.sh docs/specs/oauth/oauth-01.md
#          scripts/scope-check.sh docs/specs/oauth/oauth-01.md main...HEAD
#
# Default range is the working tree (staged + unstaged) against HEAD. Since v0.5.0 the
# build loop commits per story, so at the moment /vulyk-build runs this - after a worker
# returns, before its story is committed - the default range is exactly that story's
# diff. Earlier stories are already behind HEAD and no longer contaminate the numbers.
# To re-measure a story after its commit, pass its range: `scope-check.sh <story> HEAD~1..HEAD`.
#
# Two numbers are recorded, and the second one is what stops the first from being gamed:
#   out_of_scope  - files changed that the story never named   (lower is better)
#   declared      - how many paths the story named             (a story that lists half
#                   the repo scores a perfect zero and is caught by this number)
#
# The story file itself is never counted: the build loop commits it alongside the code
# (status line, one-commit-per-story), so it is bookkeeping, not scope.
#
# With no range given, a path another story of the same spec declares under `## Files` (or
# that story's own file) is not counted either while that story is not `done` (ADR-013 D5): a
# wave's workers share one working tree, and a sibling's uncommitted diff is its scope, not
# this story's excess. A path this story declares itself is always its own. With an explicit
# range nothing is excluded.
#
# Exit status is always 0: this reports, it does not block. Blocking is lead-review's job.

set -u

STORY="${1:-}"
RANGE="${2:-}"

if [ -z "$STORY" ] || [ ! -f "$STORY" ]; then
  echo "scope-check: usage: $0 <story-file> [git-diff-range]" >&2
  exit 0
fi

# shellcheck source=scripts/lib.sh
. "$(dirname "$0")/lib.sh"   # is_paperwork_path

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "scope-check: not a git repo" >&2; exit 0; }
cd "$ROOT" || exit 0

# --- what the story declared -------------------------------------------------
# The `## Files` block: lines starting with "- " until the next "## " heading.
# HTML comments are skipped so the template's own guidance never counts as a path.
files_of() {
  awk '
    /^##[[:space:]]+Files[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                    { inblock=0 }
    inblock && /^<!--/                  { incomment=1 }
    incomment                           { if (/-->/) incomment=0; next }
    inblock && /^-[[:space:]]+/         { sub(/^-[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
  ' "$1"
}
DECLARED="$(files_of "$STORY")"

matches_any() { # matches_any <file> <newline-separated patterns> - declared path, glob, or dir/
  local file="$1" pattern
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    [ "$file" = "$pattern" ] && return 0   # literal first: `app/[id]/page.tsx` names itself
    case "$pattern" in */) case "$file" in "$pattern"*) return 0 ;; esac ;; esac
    # shellcheck disable=SC2254
    case "$file" in $pattern) return 0 ;; esac
  done <<EOF
$2
EOF
  return 1
}

DECLARED_N=0
[ -n "$DECLARED" ] && DECLARED_N="$(printf '%s\n' "$DECLARED" | grep -c .)"

if [ "$DECLARED_N" -eq 0 ]; then
  echo "scope-check: $STORY declares no files - the scope gate cannot measure this story." >&2
  echo "             Add repo-relative paths under '## Files', one per '- ' line." >&2
  exit 0
fi

# --- what actually changed ---------------------------------------------------
if [ -n "$RANGE" ]; then
  CHANGED="$(git -c core.quotePath=false diff --name-only "$RANGE" 2>/dev/null)"
else
  # quotePath off: a non-ASCII name must come back as itself to match its `## Files` line.
  CHANGED="$(git -c core.quotePath=false diff --name-only HEAD 2>/dev/null; git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null)"
fi
# The story file rides along with every per-story commit (its status line changes) -
# drop it from the measurement entirely so each entry reflects code, not bookkeeping.
# So does this script's own ledger: a second run in the same tree would count it.
STORY_REL="${STORY#./}"
CHANGED="$(printf '%s\n' "$CHANGED" | grep -v '^$' | grep -Fxv -e "$STORY_REL" -e memory/stats/scope.jsonl | sort -u)"

# Paperwork (is_paperwork_path, lib.sh - the hive's own .claude/vulyk-paperwork globs too) is
# written by the cycle and its hooks on their own schedule, never a story's own edit: drop it
# from the diff, unless the story itself names it under '## Files'. skills.json included: the
# owner reversed A18 on 2026-10-16 (ADR-010 amendment) - the Skill counter rewrites it nearly
# every turn, so counting it flagged almost every story.
KEPT=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  is_paperwork_path "$file" && ! matches_any "$file" "$DECLARED" && continue
  KEPT="${KEPT}${file}
"
done <<EOF
$CHANGED
EOF
CHANGED="$(printf '%s' "$KEPT" | grep -v '^$')"

# Siblings (working tree only): every other story file of this spec that is not `done`.
if [ -z "$RANGE" ]; then
  SIBLING_DECLARED=""
  for sib in "$(dirname "$STORY_REL")"/*.md; do
    [ -f "$sib" ] && [ "$sib" != "$STORY_REL" ] || continue
    grep -q '^story:' "$sib" 2>/dev/null || continue
    sst="$(awk -F': *' '$1 == "status" { sub(/[[:space:]]*#.*$/, "", $2); gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$sib")"
    [ "$sst" = done ] && continue
    # the sibling's own story file too: its worker writes `returned:` there, in the same tree
    SIBLING_DECLARED="${SIBLING_DECLARED}${sib}
$(files_of "$sib")
"
  done
  if [ -n "$(printf '%s' "$SIBLING_DECLARED" | tr -d '[:space:]')" ]; then
    KEPT=""
    while IFS= read -r file; do
      [ -z "$file" ] && continue
      if matches_any "$file" "$SIBLING_DECLARED" && ! matches_any "$file" "$DECLARED"; then continue; fi
      KEPT="${KEPT}${file}
"
    done <<EOF
$CHANGED
EOF
    CHANGED="$(printf '%s' "$KEPT" | grep -v '^$')"
  fi
fi

CHANGED_N=0
[ -n "$CHANGED" ] && CHANGED_N="$(printf '%s\n' "$CHANGED" | grep -c .)"

# --- compare -----------------------------------------------------------------
# A changed file is in scope if it matches any declared path or glob. Declaring a
# directory ("src/auth/") covers everything beneath it.
OUT_OF_SCOPE=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  matches_any "$file" "$DECLARED" || OUT_OF_SCOPE="${OUT_OF_SCOPE}${file}
"
done <<EOF
$CHANGED
EOF

OUT_N=0
[ -n "$OUT_OF_SCOPE" ] && OUT_N="$(printf '%s' "$OUT_OF_SCOPE" | grep -c .)"

# --- record ------------------------------------------------------------------
mkdir -p "$ROOT/memory/stats"
STATS="$ROOT/memory/stats/scope.jsonl"
STORY_ID="$(basename "$STORY" .md)"
printf '{"ts":"%s","story":"%s","declared":%s,"changed":%s,"out_of_scope":%s}\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$STORY_ID" "$DECLARED_N" "$CHANGED_N" "$OUT_N" >> "$STATS"

# --- report ------------------------------------------------------------------
echo "scope-check: $STORY_ID - declared $DECLARED_N, changed $CHANGED_N, out of scope $OUT_N"
if [ "$OUT_N" -gt 0 ]; then
  printf '%s' "$OUT_OF_SCOPE" | sed 's/^/  ! /'
  echo "  -> Law 3: these files were touched but never named. Either the story was wrong"
  echo "     or the worker went wide. Both are worth knowing; neither is decided here."
fi
exit 0
