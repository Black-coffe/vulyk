#!/usr/bin/env bash
# VULYK installer: copy the hive into an existing project. Never overwrites your files.
# Usage: ./install.sh /path/to/your/project [--check]
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${1:-}"
[ -n "$DEST" ] || { echo "Usage: $0 /path/to/your/project [--check]"; exit 1; }
[ -d "$DEST" ] || { echo "error: $DEST is not a directory"; exit 1; }
DEST="$(cd "$DEST" && pwd)"
[ "$DEST" != "$SRC" ] || { echo "error: source and destination are the same"; exit 1; }
CHECK="${2:-}"

copied=0; skipped=0
copy_tree() { # copy_tree <rel> - file-by-file, skip anything that already exists
  local rel="$1"
  ( cd "$SRC" && find "$rel" -type f ! -name '.gitkeep' -print0 ) | while IFS= read -r -d '' f; do
    if [ -e "$DEST/$f" ]; then
      echo "  skip (exists)  $f"; skipped=$((skipped+1))
    else
      if [ "$CHECK" = "--check" ]; then echo "  would copy     $f"
      else mkdir -p "$DEST/$(dirname "$f")"; cp -p "$SRC/$f" "$DEST/$f"; echo "  copy           $f"; fi
      copied=$((copied+1))
    fi
  done
}

echo "VULYK -> $DEST ${CHECK:+(dry run)}"
for tree in .claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr; do copy_tree "$tree"; done
mkdir -p "$DEST/memory/learnings" "$DEST/memory/snapshots" "$DEST/docs/wiki" "$DEST/docs/specs" "$DEST/docs/adr" 2>/dev/null || true
[ -f "$DEST/memory/stats/skills.json" ] || { [ "$CHECK" = "--check" ] || { mkdir -p "$DEST/memory/stats"; echo '{}' > "$DEST/memory/stats/skills.json"; }; }

# Constitution: never overwrite
if [ -f "$DEST/CLAUDE.md" ]; then
  if [ "$CHECK" != "--check" ]; then cp -p "$SRC/CLAUDE.md" "$DEST/CLAUDE.vulyk.md"; fi
  echo ""
  echo "  CLAUDE.md exists - wrote CLAUDE.vulyk.md instead."
  echo "  Add this line to your CLAUDE.md to activate VULYK:"
  echo "      @CLAUDE.vulyk.md"
else
  [ "$CHECK" = "--check" ] || cp -p "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
  echo "  copy           CLAUDE.md"
fi
[ -f "$DEST/AGENTS.md" ] || { [ "$CHECK" = "--check" ] || cp -p "$SRC/AGENTS.md" "$DEST/AGENTS.md"; }

chmod +x "$DEST"/.claude/hooks/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/git-hooks/post-merge 2>/dev/null || true

echo ""
echo "Done. Next: cd $DEST && claude  ->  /vulyk-bootstrap"
echo "Optional: cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge"
