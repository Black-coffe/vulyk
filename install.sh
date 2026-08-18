#!/usr/bin/env bash
# VULYK installer: copy the hive into an existing project. Never overwrites your files.
#
#   Install:  ./install.sh /path/to/your/project [--check]
#   Upgrade:  ./install.sh /path/to/your/project --upgrade [--check]
#
# Install copies file-by-file and skips anything that already exists.
# Upgrade additionally REPLACES framework-owned files that changed between versions
# (agents, commands, hooks, meta-skills, bootstrap, templates, scripts) - and still
# never touches what is yours: CLAUDE.md, memory/, docs/specs|adr|wiki, .claude/rules.
# The installed version is stamped into .claude/vulyk-version so an upgrade knows,
# and shows, what it is upgrading from.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="$(cat "$SRC/VERSION" 2>/dev/null || echo unknown)"

DEST=""; CHECK=""; UPGRADE=""
for arg in "$@"; do
  case "$arg" in
    --check)   CHECK="--check" ;;
    --upgrade) UPGRADE=1 ;;
    -*)        echo "error: unknown flag $arg"; echo "Usage: $0 /path/to/project [--upgrade] [--check]"; exit 1 ;;
    *)         DEST="$arg" ;;
  esac
done
[ -n "$DEST" ] || { echo "Usage: $0 /path/to/your/project [--upgrade] [--check]"; exit 1; }
[ -d "$DEST" ] || { echo "error: $DEST is not a directory"; exit 1; }
DEST="$(cd "$DEST" && pwd)"
[ "$DEST" != "$SRC" ] || { echo "error: source and destination are the same"; exit 1; }

# Framework-owned trees: on --upgrade these are synced to the new version (changed files
# replaced). Everything else keeps install semantics: new files copied, existing kept.
OWNED=".claude/agents .claude/commands .claude/hooks .claude/skills/_meta bootstrap templates scripts"
owned() { local f="$1" t; for t in $OWNED; do case "$f" in "$t"/*) return 0 ;; esac; done; return 1; }

# VULYK's own working content never ships: its session learnings, its dev specs, and
# anything Python compiled on the maintainer's machine. What DOES ship from these trees
# is the skeleton - the READMEs that explain what goes where.
shippable() { # shippable <rel-file> - 1 (false) for vulyk-own content
  local f="$1"
  case "$f" in
    */__pycache__/*|*.pyc)        return 1 ;;
    docs/specs/*)                 return 1 ;;   # vulyk's own dev specs (dir is still created)
    memory/learnings/*)           case "$f" in */README.md) return 0 ;; esac; return 1 ;;
  esac
  return 0
}

copy_tree() { # copy_tree <rel> - file-by-file; skip existing, unless upgrading a framework-owned file
  local rel="$1"
  ( cd "$SRC" && find "$rel" -type f ! -name '.gitkeep' -print0 ) | while IFS= read -r -d '' f; do
    shippable "$f" || continue
    if [ -e "$DEST/$f" ]; then
      if [ -n "$UPGRADE" ] && owned "$f" && ! cmp -s "$SRC/$f" "$DEST/$f"; then
        if [ "$CHECK" = "--check" ]; then echo "  would update   $f"
        else cp -p "$SRC/$f" "$DEST/$f"; echo "  update         $f"; fi
      else
        echo "  skip (exists)  $f"
      fi
    else
      if [ "$CHECK" = "--check" ]; then echo "  would copy     $f"
      else mkdir -p "$DEST/$(dirname "$f")"; cp -p "$SRC/$f" "$DEST/$f"; echo "  copy           $f"; fi
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

PREV="$(cat "$DEST/.claude/vulyk-version" 2>/dev/null || echo none)"
if [ -n "$UPGRADE" ]; then
  echo "VULYK upgrade -> $DEST  ($PREV -> $VER) ${CHECK:+(dry run)}"
  [ "$PREV" = "none" ] && echo "  note: no .claude/vulyk-version found - upgrading a pre-0.5.0 install; review the output below with extra care."
else
  echo "VULYK $VER -> $DEST ${CHECK:+(dry run)}"
fi

# `.claude/settings.json` is NOT framework-owned: it carries the owner's permissions and any
# hooks of their own, so a release must never replace it. But a hook script that ships without
# being wired is a hook that silently does nothing - which is how an upgrade notice would fail
# to reach exactly the people who most need it. So: append the one missing entry, in place,
# after taking a backup, and say out loud what was done. Idempotent by inspection of the file.
wire_session_hook() { # wire_session_hook <hook-script-name>
  local script="$1" file="$DEST/.claude/settings.json" py=""
  [ -f "$file" ] || return 0                                   # fresh install: ours was copied whole
  grep -q "$script" "$file" 2>/dev/null && return 0            # already wired
  if [ "$CHECK" = "--check" ]; then
    echo "  would wire     .claude/settings.json -> SessionStart: $script"
    return 0
  fi
  py="$(command -v python3 || command -v python || true)"
  if [ -z "$py" ]; then
    echo ""
    echo "  NOTE: .claude/hooks/$script was installed but could NOT be wired -"
    echo "  no python on PATH to edit .claude/settings.json safely. Add this to your"
    echo "  SessionStart hooks by hand, or the update check will never run:"
    echo "      { \"type\": \"command\", \"command\": \"\$CLAUDE_PROJECT_DIR/.claude/hooks/$script\" }"
    return 0
  fi
  cp -p "$file" "$file.vulyk-bak" 2>/dev/null || true
  if "$py" - "$file" "$script" <<'PYWIRE'
import json, sys
path, script = sys.argv[1], sys.argv[2]
cmd = '$CLAUDE_PROJECT_DIR/.claude/hooks/' + script
try:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(4)                                  # unparseable: leave it entirely alone
if not isinstance(data, dict):
    sys.exit(4)
groups = data.setdefault('hooks', {}).setdefault('SessionStart', [])
if not isinstance(groups, list):
    sys.exit(4)
for group in groups:
    if isinstance(group, dict):
        for hook in group.get('hooks', []) or []:
            if isinstance(hook, dict) and str(hook.get('command', '')).endswith(script):
                sys.exit(3)                      # already there under another spelling
entry = {'type': 'command', 'command': cmd}
if groups and isinstance(groups[0], dict):
    groups[0].setdefault('hooks', []).append(entry)
else:
    groups.append({'hooks': [entry]})
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
    fh.write('\n')
PYWIRE
  then
    echo "  wire           .claude/settings.json -> SessionStart: $script"
    echo "                 (backup at .claude/settings.json.vulyk-bak; the file was re-indented by the edit)"
  else
    case "$?" in
      3) rm -f "$file.vulyk-bak" 2>/dev/null || true ;;   # already wired; nothing happened
      *) rm -f "$file.vulyk-bak" 2>/dev/null || true
         echo ""
         echo "  NOTE: .claude/settings.json could not be parsed as JSON - left untouched."
         echo "  Wire the update check by hand into your SessionStart hooks:"
         echo "      { \"type\": \"command\", \"command\": \"\$CLAUDE_PROJECT_DIR/.claude/hooks/$script\" }" ;;
    esac
  fi
}

for tree in .claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr; do copy_tree "$tree"; done
wire_session_hook vulyk-update-check.sh
mkdir -p "$DEST/memory/learnings" "$DEST/memory/snapshots" "$DEST/docs/wiki" "$DEST/docs/specs" "$DEST/docs/adr" 2>/dev/null || true
[ -f "$DEST/memory/stats/skills.json" ] || { [ "$CHECK" = "--check" ] || { mkdir -p "$DEST/memory/stats"; echo '{}' > "$DEST/memory/stats/skills.json"; }; }

# Constitution: never overwritten - not on install, not on upgrade. A bootstrapped
# constitution is the user's tailored law; merging framework-side changes into it is a
# reading decision, not a copying one.
if [ -f "$DEST/CLAUDE.md" ]; then
  if head -3 "$DEST/CLAUDE.md" 2>/dev/null | grep -q '^# VULYK Constitution' || \
     grep -q 'VULYK:COMMANDS:START' "$DEST/CLAUDE.md" 2>/dev/null; then
    # The project's CLAUDE.md IS a vulyk constitution (installed earlier, possibly edited;
    # note the COMMANDS markers are eaten by reset_commands_table on install, so the title
    # is the durable fingerprint). Writing CLAUDE.vulyk.md next to it would create a
    # second, conflicting constitution.
    echo ""
    echo "  CLAUDE.md is already a VULYK constitution - left untouched."
    if ! cmp -s "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"; then
      echo "  The framework constitution changed in $VER. See what, then merge what you want:"
      echo "      diff \"$DEST/CLAUDE.md\" \"$SRC/CLAUDE.md\""
    fi
  elif [ -e "$DEST/CLAUDE.vulyk.md" ]; then
    echo ""
    echo "  CLAUDE.vulyk.md exists - left untouched."
    if ! cmp -s "$SRC/CLAUDE.md" "$DEST/CLAUDE.vulyk.md"; then
      echo "  The framework constitution changed in $VER. See what, then merge what you want:"
      echo "      git -C \"$SRC\" log --oneline -- CLAUDE.md   # or simply:"
      echo "      diff \"$DEST/CLAUDE.vulyk.md\" \"$SRC/CLAUDE.md\""
    fi
  else
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
  fi
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

# Version stamp - what a future --upgrade reads as "from".
if [ "$CHECK" = "--check" ]; then
  echo "  would stamp    .claude/vulyk-version = $VER"
else
  mkdir -p "$DEST/.claude"
  printf '%s\n' "$VER" > "$DEST/.claude/vulyk-version"
  echo "  stamp          .claude/vulyk-version = $VER"
fi

chmod +x "$DEST"/.claude/hooks/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/git-hooks/post-merge 2>/dev/null || true

echo ""
if [ -n "$UPGRADE" ]; then
  echo "Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched."
  echo "If the constitution changed this release, merge those edits by hand (see note above)."
else
  echo "Done. Next: cd $DEST && claude  ->  /vulyk-bootstrap"
  echo "Optional: cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge"
fi
