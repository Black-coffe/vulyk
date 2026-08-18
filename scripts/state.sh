#!/usr/bin/env bash
# VULYK build state - a DERIVED view of every spec's story frontmatter.
#
#   Usage: scripts/state.sh            # all specs under docs/specs/
#          scripts/state.sh docs/specs/oauth
#
# Writes `.claude/state.json`. Read it; never write it, never hand-edit it, and never treat
# it as the answer to "what is the status of this story". The truth is the `status:` line in
# the story file, and this is a snapshot of those lines at the moment it ran.
#
# That distinction is the whole design, and it is why this file is GITIGNORED. A derived
# artifact committed alongside its source becomes a second account of the same fact, and the
# two diverge the first time someone edits one - which is failure mode four in the README:
# a record that still reads green about work that has since moved. Regenerating is free
# (deterministic, model-free, no tokens), so there is never a reason to trust a stale copy.
#
# `stale: true` on a spec means exactly one thing: a story file has been modified more
# recently than this snapshot. It is not a verdict about the work.
#
# Exit status is always 0: this reports, it does not block.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "state: CANNOT RUN - not a git repo, so there is no project root to scan." >&2
  exit 0
}
cd "$ROOT" || exit 0

TARGET="${1:-docs/specs}"
[ -e "$TARGET" ] || {
  echo "state: nothing to scan - $TARGET does not exist." >&2
  exit 0
}

# Keep every value JSON-safe the blunt way, and bounded: a `status:` line in an older spec
# can be a whole paragraph of merge notes, and a dashboard field is not where that belongs.
# These are slugs, ids and enum words; a value needing more escaping than this is a
# malformed frontmatter line, and mangling it beats emitting a file nothing can parse.
j() {
  local v="$1"
  v="${v//$'\n'/ }"
  v="${v//$'\r'/}"
  v="${v//\\/}"
  v="${v//\"/\'}"
  printf '%s' "${v:0:120}"
}

field() { # field <file> <name>
  awk -F': *' -v k="$2" '
    $1 == k { v = $2; sub(/[[:space:]]*#.*$/, "", v); gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); print v; exit }
  ' "$1"
}

OUT="$ROOT/.claude/state.json"
mkdir -p "$ROOT/.claude"
TMP="$OUT.tmp$$"

SNAP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HEAD_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

{
  printf '{\n'
  printf '  "derived": true,\n'
  printf '  "source": "story frontmatter under %s - regenerate with scripts/state.sh, never edit",\n' "$(j "$TARGET")"
  printf '  "generated_at": "%s",\n' "$SNAP"
  printf '  "head": "%s",\n' "$HEAD_SHA"
  printf '  "branch": "%s",\n' "$(j "$BRANCH")"
  printf '  "specs": [\n'
} > "$TMP"

# One entry per directory that holds at least one story file directly.
first_spec=1
for dir in $( [ -d "$TARGET" ] && find "$TARGET" -type d | LC_ALL=C sort || dirname "$TARGET" ); do
  stories=""
  for f in "$dir"/*.md; do
    [ -f "$f" ] || continue
    grep -q '^story:' "$f" 2>/dev/null || continue
    stories="$stories $f"
  done
  [ -n "$stories" ] || continue

  total=0; done_n=0; blocked_n=0; progress_n=0; todo_n=0; unknown_n=0
  newest=0
  rows=""
  for f in $stories; do
    total=$((total + 1))
    id="$(field "$f" story)"; st="$(field "$f" status)"
    wv="$(field "$f" wave)"; tr_="$(field "$f" tier)"
    # Only the four words the template defines are counted. Anything else goes to
    # `unrecognised` and is NOT folded into `todo`: a spec written before the convention
    # existed - or one whose status line is a paragraph of merge notes - would otherwise
    # be reported as nothing-done, a derived view actively lying about finished work.
    # Observed on a real repository the first time this ran.
    case "$st" in
      done)        done_n=$((done_n + 1)) ;;
      blocked)     blocked_n=$((blocked_n + 1)) ;;
      in-progress) progress_n=$((progress_n + 1)) ;;
      todo)        todo_n=$((todo_n + 1)) ;;
      *)           unknown_n=$((unknown_n + 1)) ;;
    esac
    mt="$(date -r "$f" +%s 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)"
    [ "$mt" -gt "$newest" ] 2>/dev/null && newest="$mt"
    rows="$rows      {\"story\": \"$(j "${id:-unknown}")\", \"status\": \"$(j "${st:-<missing>}")\", \"wave\": \"$(j "${wv:-}")\", \"tier\": \"$(j "${tr_:-}")\", \"file\": \"$(j "$f")\"},
"
  done

  # A snapshot older than the newest story file it describes is, by definition, behind it.
  snap_epoch="$(date -u -d "$SNAP" +%s 2>/dev/null || echo 0)"
  stale=false
  [ "$snap_epoch" -gt 0 ] && [ "$newest" -gt "$snap_epoch" ] && stale=true

  [ "$first_spec" -eq 1 ] || printf ',\n' >> "$TMP"
  first_spec=0
  {
    printf '    {\n'
    printf '      "spec": "%s",\n' "$(j "$(basename "$dir")")"
    printf '      "path": "%s",\n' "$(j "$dir")"
    printf '      "stories": %s, "done": %s, "in_progress": %s, "blocked": %s, "todo": %s, "unrecognised": %s,\n' \
      "$total" "$done_n" "$progress_n" "$blocked_n" "$todo_n" "$unknown_n"
    printf '      "stale": %s,\n' "$stale"
    printf '      "story_list": [\n'
    printf '%s' "$(printf '%s' "$rows" | sed '$ s/,$//')"
    printf '\n      ]\n'
    printf '    }'
  } >> "$TMP"
done

{
  printf '\n  ]\n'
  printf '}\n'
} >> "$TMP"

mv "$TMP" "$OUT"
echo "state: wrote ${OUT#"$ROOT"/} - derived from story frontmatter, gitignored, regenerate freely."
exit 0
