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

# The `## Commands` table in CLAUDE.md holds VULYK's OWN verification commands, which are wrong
# for every other project - and a wrong command that still exits 0 reads as a false green far more
# easily than an obvious placeholder does. So blank the table out on the way in and let
# /vulyk-bootstrap fill it. If the markers are gone (edited constitution, older copy), say so
# loudly rather than silently shipping the wrong commands - a silent no-op is the failure mode
# this whole function exists to prevent.
reset_commands_table() { # reset_commands_table <constitution-file>
  local file="$1" name; name="$(basename "$file")"
  if ! grep -q 'VULYK:COMMANDS:START' "$file" 2>/dev/null || \
     ! grep -q 'VULYK:COMMANDS:END' "$file" 2>/dev/null; then
    echo ""
    echo "  WARNING: no VULYK:COMMANDS markers found in $name."
    echo "  Its '## Commands' table was left as-is and may still hold VULYK's own commands"
    echo "  (shell/Python syntax checks), which are wrong for this project. Clear it by hand,"
    echo "  or run /vulyk-bootstrap, which replaces the table."
    echo ""
    return 0
  fi
  if [ "$CHECK" = "--check" ]; then
    echo "  would reset    $name '## Commands' table -> placeholders"
    return 0
  fi
  awk '
    index($0, "VULYK:COMMANDS:START") {
      print "| Purpose | Command |"
      print "|---|---|"
      print "| Single test file | `<fill in - the quiet variant>` |"
      print "| Full test suite | `<fill in>` |"
      print "| Lint | `<fill in>` |"
      print "| Build / typecheck | `<fill in>` |"
      print ""
      print "Filled in by `/vulyk-bootstrap`. Verify each command actually runs before writing it"
      print "down, and write \"none\" where this project genuinely lacks one - a verification that"
      print "always exits 0 is worse than an admitted gap."
      skip = 1; next
    }
    index($0, "VULYK:COMMANDS:END") { skip = 0; next }
    !skip
  ' "$file" > "$file.vulyktmp" && mv "$file.vulyktmp" "$file"
  echo "  reset          $name '## Commands' table -> placeholders"
}

echo "VULYK -> $DEST ${CHECK:+(dry run)}"
for tree in .claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr; do copy_tree "$tree"; done
mkdir -p "$DEST/memory/learnings" "$DEST/memory/snapshots" "$DEST/docs/wiki" "$DEST/docs/specs" "$DEST/docs/adr" 2>/dev/null || true
[ -f "$DEST/memory/stats/skills.json" ] || { [ "$CHECK" = "--check" ] || { mkdir -p "$DEST/memory/stats"; echo '{}' > "$DEST/memory/stats/skills.json"; }; }

# Constitution: never overwrite
if [ -f "$DEST/CLAUDE.md" ]; then
  if [ "$CHECK" != "--check" ]; then
    cp -p "$SRC/CLAUDE.md" "$DEST/CLAUDE.vulyk.md"
    reset_commands_table "$DEST/CLAUDE.vulyk.md"
  else
    reset_commands_table "$SRC/CLAUDE.md"   # dry run: inspect the source, touch nothing
  fi
  echo ""
  echo "  CLAUDE.md exists - wrote CLAUDE.vulyk.md instead."
  echo "  Add this line to your CLAUDE.md to activate VULYK:"
  echo "      @CLAUDE.vulyk.md"
else
  if [ "$CHECK" = "--check" ]; then
    reset_commands_table "$SRC/CLAUDE.md"   # dry run: inspect the source, touch nothing
  else
    cp -p "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
    reset_commands_table "$DEST/CLAUDE.md"
  fi
  echo "  copy           CLAUDE.md"
fi
[ -f "$DEST/AGENTS.md" ] || { [ "$CHECK" = "--check" ] || cp -p "$SRC/AGENTS.md" "$DEST/AGENTS.md"; }

chmod +x "$DEST"/.claude/hooks/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/git-hooks/post-merge 2>/dev/null || true

echo ""
echo "Done. Next: cd $DEST && claude  ->  /vulyk-bootstrap"
echo "Optional: cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge"
