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
# Exit status is always 0: this reports, it does not block. Blocking is lead-review's job.

set -u

STORY="${1:-}"
RANGE="${2:-}"

if [ -z "$STORY" ] || [ ! -f "$STORY" ]; then
  echo "scope-check: usage: $0 <story-file> [git-diff-range]" >&2
  exit 0
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "scope-check: not a git repo" >&2; exit 0; }
cd "$ROOT" || exit 0

# --- what the story declared -------------------------------------------------
# The `## Files` block: lines starting with "- " until the next "## " heading.
# HTML comments are skipped so the template's own guidance never counts as a path.
DECLARED="$(awk '
  /^##[[:space:]]+Files[[:space:]]*$/ { inblock=1; next }
  /^##[[:space:]]/                    { inblock=0 }
  inblock && /^<!--/                  { incomment=1 }
  incomment                           { if (/-->/) incomment=0; next }
  inblock && /^-[[:space:]]+/         { sub(/^-[[:space:]]+/, ""); sub(/[[:space:]]+$/, ""); if ($0 != "") print }
' "$STORY")"

DECLARED_N=0
[ -n "$DECLARED" ] && DECLARED_N="$(printf '%s\n' "$DECLARED" | grep -c .)"

if [ "$DECLARED_N" -eq 0 ]; then
  echo "scope-check: $STORY declares no files - the scope gate cannot measure this story." >&2
  echo "             Add repo-relative paths under '## Files', one per '- ' line." >&2
  exit 0
fi

# --- what actually changed ---------------------------------------------------
if [ -n "$RANGE" ]; then
  CHANGED="$(git diff --name-only "$RANGE" 2>/dev/null)"
else
  CHANGED="$(git diff --name-only HEAD 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)"
fi
CHANGED="$(printf '%s\n' "$CHANGED" | grep -v '^$' | sort -u)"

CHANGED_N=0
[ -n "$CHANGED" ] && CHANGED_N="$(printf '%s\n' "$CHANGED" | grep -c .)"

# --- compare -----------------------------------------------------------------
# A changed file is in scope if it matches any declared path or glob. Declaring a
# directory ("src/auth/") covers everything beneath it.
OUT_OF_SCOPE=""
while IFS= read -r file; do
  [ -z "$file" ] && continue
  hit=0
  while IFS= read -r pattern; do
    [ -z "$pattern" ] && continue
    case "$pattern" in */) case "$file" in "$pattern"*) hit=1; break;; esac ;; esac
    # shellcheck disable=SC2254
    case "$file" in $pattern) hit=1; break ;; esac
  done <<EOF
$DECLARED
EOF
  [ "$hit" -eq 0 ] && OUT_OF_SCOPE="${OUT_OF_SCOPE}${file}
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
