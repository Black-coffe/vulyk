#!/usr/bin/env bash
# VULYK trace gate - third deterministic check, alongside scope-check and wave-check.
#
#   Usage: scripts/trace-check.sh docs/specs/<slug>
#
# Verifies that the human's request survives, verbatim, from brief.md into the stories -
# and that no story exists the human never asked for. No model involved, no tokens spent.
#
# BACKWARD trace (the sharp edge - catches invented stories):
#   every `> ` quote in a story's `## Requirements` must appear VERBATIM
#   (whitespace-normalized substring) in brief.md, or in plan.md's `## Plan deltas`
#   section for stories cut after approval. A quote found nowhere, or a story with no
#   quotes at all, is reported.
#
# FORWARD trace (coverage, advisory):
#   every `> ` blockquote line of brief.md is checked for overlap with at least one
#   story quote. Uncovered lines are listed - some are context, not requirements;
#   deciding that is the human's job at the approval stop.
#
# Exit status is always 0: this reports, it does not block. It runs before the approval
# stop, where the human reads the report and decides.

set -u

SPEC="${1:-}"
if [ -z "$SPEC" ] || [ ! -d "$SPEC" ]; then
  echo "trace-check: usage: $0 <spec-dir>   (e.g. docs/specs/oauth)" >&2
  exit 0
fi

BRIEF="$SPEC/brief.md"
PLAN="$SPEC/plan.md"

# Loud cannot-run branch: without a brief there is nothing to trace against.
if [ ! -f "$BRIEF" ]; then
  echo "trace-check: CANNOT RUN - $BRIEF does not exist."
  echo "             The trace gate needs the verbatim request. /vulyk-plan writes it at"
  echo "             Tier 2+; a pre-0.7.0 spec predates the brief and cannot be traced."
  exit 0
fi

# Collapse a stream to single-space-normalized text on one line.
normalize() { tr '\r\n\t' '   ' | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//'; }

# All `> ` blockquote content of brief.md, joined - quotes may span line breaks.
BRIEF_TEXT="$(sed -n 's/^>[[:space:]]\{0,1\}//p' "$BRIEF" | normalize)"
# Each blockquote line separately - the forward-coverage units.
BRIEF_LINES="$(sed -n 's/^>[[:space:]]\{0,1\}//p' "$BRIEF" | while IFS= read -r l; do
  printf '%s\n' "$l" | normalize; echo; done | grep -v '^$')"

# plan.md `## Plan deltas` section - the second legitimate quote source.
DELTA_TEXT=""
if [ -f "$PLAN" ]; then
  DELTA_TEXT="$(awk '/^##[[:space:]]+Plan deltas/{d=1;next} /^##[[:space:]]/{d=0} d' "$PLAN" | normalize)"
fi

STORIES_N=0; QUOTES_N=0; MISS_N=0; EMPTY_N=0

for story in "$SPEC"/*.md; do
  base="$(basename "$story")"
  case "$base" in plan.md|brief.md) continue ;; esac
  grep -q '^story:' "$story" 2>/dev/null || continue
  STORIES_N=$((STORIES_N+1))

  QUOTES="$(awk '
    /^##[[:space:]]+Requirements[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                           { inblock=0 }
    inblock && /^<!--/                         { inc=1 }
    inc                                        { if (/-->/) inc=0; next }
    inblock && /^>[[:space:]]?/                { sub(/^>[[:space:]]?/, ""); print }
  ' "$story")"

  found_any=0
  while IFS= read -r q; do
    [ -z "$q" ] && continue
    qn="$(printf '%s' "$q" | normalize)"
    [ -z "$qn" ] && continue
    case "$qn" in '<'*) continue ;; esac   # template placeholder left in place
    found_any=1
    QUOTES_N=$((QUOTES_N+1))
    case "$BRIEF_TEXT" in *"$qn"*) continue ;; esac
    case "$DELTA_TEXT" in *"$qn"*)
      echo "  ~ $base: quote traces to a plan delta, not the brief: \"$qn\""
      continue ;; esac
    MISS_N=$((MISS_N+1))
    echo "  ! $base: quote found in NEITHER brief.md NOR plan deltas: \"$qn\""
  done <<EOF
$QUOTES
EOF

  if [ "$found_any" -eq 0 ]; then
    EMPTY_N=$((EMPTY_N+1))
    echo "  ! $base: no \`## Requirements\` quotes - nothing ties this story to the request"
  fi
done

if [ "$STORIES_N" -eq 0 ]; then
  echo "trace-check: $SPEC - no story files found, nothing to trace."
  exit 0
fi

# Forward coverage: brief lines with no overlapping story quote.
UNCOVERED=0
ALL_QUOTES="$(for story in "$SPEC"/*.md; do
  base="$(basename "$story")"
  case "$base" in plan.md|brief.md) continue ;; esac
  awk '
    /^##[[:space:]]+Requirements[[:space:]]*$/ { inblock=1; next }
    /^##[[:space:]]/                           { inblock=0 }
    inblock && /^<!--/                         { inc=1 }
    inc                                        { if (/-->/) inc=0; next }
    inblock && /^>[[:space:]]?/                { sub(/^>[[:space:]]?/, ""); print }
  ' "$story" 2>/dev/null
done | while IFS= read -r l; do printf '%s\n' "$l" | normalize; echo; done | grep -v '^$' | grep -v '^<')"

while IFS= read -r bl; do
  [ -z "$bl" ] && continue
  covered=0
  while IFS= read -r q; do
    [ -z "$q" ] && continue
    case "$bl" in *"$q"*) covered=1; break ;; esac
    case "$q" in *"$bl"*) covered=1; break ;; esac
  done <<EOF2
$ALL_QUOTES
EOF2
  if [ "$covered" -eq 0 ]; then
    UNCOVERED=$((UNCOVERED+1))
    [ "$UNCOVERED" -le 12 ] && echo "  ? brief line not quoted by any story: \"$bl\""
  fi
done <<EOF3
$BRIEF_LINES
EOF3
[ "$UNCOVERED" -gt 12 ] && echo "  ? ... and $((UNCOVERED-12)) more uncovered brief lines"

echo "trace-check: $SPEC - $STORIES_N stories, $QUOTES_N quotes; backward: $MISS_N unfound + $EMPTY_N storyless; forward: $UNCOVERED brief lines uncovered"
if [ "$MISS_N" -gt 0 ] || [ "$EMPTY_N" -gt 0 ]; then
  echo "  -> a quote found nowhere means an invented or paraphrased requirement; a story"
  echo "     without quotes is speculative. Both go to the human at the approval stop."
fi
exit 0
