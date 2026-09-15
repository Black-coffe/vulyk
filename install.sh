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

USAGE="Usage: $0 /path/to/your/project [--upgrade] [--check] [--telemetry on|off|ask]"
DEST=""; CHECK=""; UPGRADE=""; BLOCK_INSERTED=""
# Telemetry consent (docs/telemetry.md): the flag wins over the env var, both are optional,
# and `ask` forces the question even for a hive that already answered it once.
TEL_MODE="${VULYK_TELEMETRY:-}"
while [ $# -gt 0 ]; do
  case "$1" in
    --check)     CHECK="--check" ;;
    --upgrade)   UPGRADE=1 ;;
    --telemetry) shift; TEL_MODE="${1:-}"; [ -n "$TEL_MODE" ] || { echo "error: --telemetry needs a value (on|off|ask)"; exit 1; } ;;
    -*)          echo "error: unknown flag $1"; echo "$USAGE"; exit 1 ;;
    *)           DEST="$1" ;;
  esac
  shift
done
case "$TEL_MODE" in
  ""|on|off|ask) ;;
  *) echo "error: --telemetry/VULYK_TELEMETRY must be on, off or ask (got '$TEL_MODE')"; exit 1 ;;
esac
[ -n "$DEST" ] || { echo "$USAGE"; exit 1; }
[ -d "$DEST" ] || { echo "error: $DEST is not a directory"; exit 1; }
DEST="$(cd "$DEST" && pwd)"
[ "$DEST" != "$SRC" ] || { echo "error: source and destination are the same"; exit 1; }

# Framework-owned trees: on --upgrade these are synced to the new version (changed files
# replaced). Everything else keeps install semantics: new files copied, existing kept.
OWNED=".claude/agents .claude/commands .claude/hooks .claude/skills/_meta .claude/workflows bootstrap templates scripts"
owned() { local f="$1" t; for t in $OWNED; do case "$f" in "$t"/*) return 0 ;; esac; done; return 1; }

# VULYK's own working content never ships: its session learnings, its dev specs, and
# anything Python compiled on the maintainer's machine. What DOES ship from these trees
# is the skeleton - the READMEs that explain what goes where.
#
# It also never ships anything VULYK's OWN .gitignore keeps out of git for being
# per-machine or derived on the maintainer's box - the pinned-model file above all. A
# target hive's .gitignore is not vulyk's, so this list is kept explicit here instead of
# read from .gitignore at runtime; keep the two lists in sync by hand when either changes.
# `.claude/vulyk-version` is the one entry with no .gitignore line of its own (a real hive
# DOES commit its stamp) - it is refused anyway because the version stamp below always
# overwrites it with the target's own value right after the copy loop, so shipping the
# maintainer's here would only leak it in the interim.
shippable() { # shippable <rel-file> - 0 (true) to ship; 1 = vulyk's own dev content,
              # 2 = gitignored runtime artifact (copy_tree tells the two apart in --check)
  local f="$1"
  case "$f" in
    */__pycache__/*|*.pyc)        return 1 ;;
    docs/specs/*)                 return 1 ;;   # vulyk's own dev specs (dir is still created)
    docs/adr/*|docs/wiki/*)       case "$f" in */README.md) return 0 ;; esac; return 1 ;;   # vulyk's own ADRs/wiki (dir still created; a skeleton README ships)
    memory/learnings/*)           case "$f" in */README.md) return 0 ;; esac; return 1 ;;
    .claude/settings.local.json|.claude/settings.json.vulyk-bak)
                                   return 2 ;;
    .claude/state.json|.claude/.vulyk-update-cache|.claude/vulyk-version|.claude/vulyk-manifest)
                                   return 2 ;;
    .claude/handoff/*|memory/map/.stale|CLAUDE.local.md)
                                   return 2 ;;
    memory/snapshots/*)           case "$f" in */.gitkeep) return 0 ;; esac; return 2 ;;
    memory/stats/anomalies.jsonl) return 2 ;;   # the maintainer's own anomaly log: runtime, per-hive
  esac
  return 0
}

copy_tree() { # copy_tree <rel> - file-by-file; skip existing, unless upgrading a framework-owned file
  local rel="$1" sc
  ( cd "$SRC" && find "$rel" -type f ! -name '.gitkeep' -print0 ) | while IFS= read -r -d '' f; do
    shippable "$f" && sc=0 || sc=$?
    if [ "$sc" -ne 0 ]; then
      [ "$sc" -eq 2 ] && [ "$CHECK" = "--check" ] && echo "  would skip (runtime) $f"
      continue
    fi
    # Every path this run found shippable - copied, updated or skipped-as-existing alike -
    # joins the manifest (ADR-005 D2), whether or not this is a dry run: --check needs the
    # same set to print an accurate "would write ... (<n> paths)" count.
    printf '%s\n' "$f" >> "$NEW_MANIFEST"
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
# Reset a marker-delimited block in the constitution back to placeholders.
#
# The markers are KEPT. The first version of this ate them, which made the reset a one-shot:
# a later `--upgrade` found no markers, printed a warning, and left whatever was there. A
# block that can only be reset once is a block that cannot be re-reset when the framework's
# placeholders change - so `:START` and `:END` now survive every pass.
#
#   Usage: reset_marked_block <file> <MARKER> <human label>   # replacement text on stdin
reset_marked_block() {
  local file="$1" marker="$2" label="$3" name repl
  name="$(basename "$file")"
  repl="$(cat)"
  if ! grep -q "${marker}:START" "$file" 2>/dev/null ||      ! grep -q "${marker}:END" "$file" 2>/dev/null; then
    echo ""
    echo "  WARNING: no ${marker} markers found in $name."
    echo "  Its '$label' was left as-is and may still hold VULYK's own values, which are"
    echo "  wrong for this project. Clear it by hand, or run /vulyk-bootstrap, which fills it."
    echo ""
    return 0
  fi
  if [ "$CHECK" = "--check" ]; then
    echo "  would reset    $name '$label' -> placeholders"
    return 0
  fi
  awk -v m="$marker" -v repl="$repl" '
    index($0, m ":START") { print; print repl; skip = 1; next }
    index($0, m ":END")   { skip = 0; print; next }
    !skip
  ' "$file" > "$file.vulyktmp" && mv "$file.vulyktmp" "$file"
  echo "  reset          $name '$label' -> placeholders"
}

# The placeholder text for each block lives here, in one function per block, so that
# reset_commands_table (fresh install / re-blank) and ensure_marked_block (--upgrade insert)
# share one source and the CI row-count check covers both.
print_commands_placeholder() {
  cat <<'PLACEHOLDER'
| Purpose | Command |
|---|---|
| Single test file | `<fill in - the quiet variant>` |
| Full test suite | `<fill in>` |
| Lint | `<fill in>` |
| Build / typecheck | `<fill in>` |

Filled in by `/vulyk-bootstrap`. Verify each command actually runs before writing it
down, and write "none" where this project genuinely lacks one - a verification that
always exits 0 is worse than an admitted gap.
PLACEHOLDER
}

# The consent row (docs/telemetry.md). ONE source for it: the fresh-install placeholder below
# and the --upgrade append both call this, so a hive can never end up with two spellings of
# the row `scripts/telemetry.sh consent` reads.
telemetry_row() { # telemetry_row <on|off>
  printf '| Telemetry | %s - anonymized weekly anomaly bundle (codes and numbers only, docs/telemetry.md); on = /vulyk-evolve prints the send command, never sends |\n' "$1"
}

print_profile_placeholder() {
  cat <<'PLACEHOLDER'
| Field | Value |
|---|---|
| Stack | `<fill in>` |
| Package manager / runner | `<fill in>` |
| Where source lives | `<fill in>` |
| Test framework | `<fill in>` |
| Commit convention | `<fill in>` |
| **Configurations that exist today** | `<fill in - single node? multi-process? a database at all? what is deferred and to when>` |
| Client path | `<fill in - how a person reaches the running thing: URL + a test login, a CLI entry point, or a browser runner's quiet command; "none: library only" is an honest answer>` |
| Browser MCP | `<fill in - chrome-devtools \\| claude-in-chrome \\| none; optional, read by the council-haiku seat only, read-only, on a separate test profile - none is the honest default without one>` |
| Release / deploy | `<fill in - default branch; how a version is published (tag + push? npm publish? CI on merge?) and who presses the button>` |
PLACEHOLDER
  telemetry_row off
}

reset_commands_table() { # reset_commands_table <constitution-file>
  print_commands_placeholder | reset_marked_block "$1" "VULYK:COMMANDS" "## Commands table"
  print_profile_placeholder | reset_marked_block "$1" "VULYK:PROFILE" "## Profile block"
}

# ensure_marked_block <file> <MARKER> <label>  (placeholder text on stdin, like reset_marked_block)
#
# Runs on --upgrade against an already-established constitution, where reset_marked_block never
# runs (a filled block must never be touched). Both markers present -> nothing, whatever they
# hold. Exactly one -> WARNING, nothing written. Neither marker, but the source's preceding
# heading already exists in the target -> WARNING (an owner wrote that section by hand; the
# installer does not know which rows are theirs). Neither marker, heading absent -> insert the
# source's whole section (heading, the prose before START, then START/placeholder/END) right
# before the first later source heading that exists verbatim in the target, else at EOF.
ensure_marked_block() {
  local file="$1" marker="$2" label="$3" name repl has_start=0 has_end=0
  name="$(basename "$file")"
  repl="$(cat)"
  grep -q "${marker}:START" "$file" 2>/dev/null && has_start=1
  grep -q "${marker}:END" "$file" 2>/dev/null && has_end=1
  if [ "$has_start" -eq 1 ] && [ "$has_end" -eq 1 ]; then
    return 0
  fi
  if [ "$has_start" -eq 1 ] || [ "$has_end" -eq 1 ]; then
    echo ""
    echo "  WARNING: $name has only one of ${marker}:START/${marker}:END - left as-is."
    echo ""
    return 0
  fi
  local heading
  heading="$(awk -v m="$marker" '/^## / {h=$0} index($0, m ":START"){print h; exit}' "$SRC/CLAUDE.md")"
  [ -n "$heading" ] || return 0   # defensive: source has no such block either
  if grep -qxF "$heading" "$file" 2>/dev/null; then
    echo ""
    echo "  WARNING: $heading exists without ${marker} markers in $name - left as-is."
    echo ""
    return 0
  fi
  if [ "$CHECK" = "--check" ]; then
    echo "  would insert   $name '$label' (placeholders)"
    return 0
  fi
  local block anchor
  block="$(awk -v m="$marker" -v repl="$repl" '
    /^## / { buf = $0; next }
    index($0, m ":START") { print buf; print $0; print repl; skip = 1; next }
    index($0, m ":END")   { skip = 0; print $0; exit }
    skip { next }
    { buf = buf "\n" $0 }
  ' "$SRC/CLAUDE.md")"
  anchor="$(awk -v m="$marker" '
    index($0, m ":END") { done = 1; next }
    done && /^## / { print; exit }
  ' "$SRC/CLAUDE.md")"
  local n=""
  if [ -n "$anchor" ]; then
    n="$(grep -n -F -x "$anchor" "$file" 2>/dev/null | head -1 | cut -d: -f1)" || true
  fi
  if [ -n "$n" ]; then
    { head -n "$((n - 1))" "$file"; printf '%s\n' "$block"; echo ""; tail -n "+$n" "$file"; } \
      > "$file.vulyktmp" && mv "$file.vulyktmp" "$file"
  else
    { echo ""; printf '%s\n' "$block"; } >> "$file"
  fi
  BLOCK_INSERTED=1
  echo "  insert         $name '$label' (placeholders)"
}

# report_fill_status <file> <MARKER> <name> - prints, per block, which rows still hold
# `<fill in`, so an --upgrade tells an owner whether the council can run in this hive.
report_fill_status() {
  local file="$1" marker="$2" name="$3" labels n joined line
  grep -q "${marker}:START" "$file" 2>/dev/null || return 0
  grep -q "${marker}:END" "$file" 2>/dev/null || return 0
  labels="$(awk -v m="$marker" '
    index($0, m ":START") { on = 1; next }
    index($0, m ":END")   { on = 0 }
    on && /<fill in/ {
      line = $0
      sub(/^\| */, "", line)
      sub(/ *\|.*/, "", line)
      gsub(/\*\*/, "", line)
      print line
    }
  ' "$file")"
  if [ -z "$labels" ]; then
    echo "  $name: filled"
    return 0
  fi
  n=0; joined=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    n=$((n + 1))
    if [ -z "$joined" ]; then joined="$line"; else joined="$joined, $line"; fi
  done <<EOF
$labels
EOF
  echo "  $name: $n rows still hold <fill in: $joined"
}

# --- telemetry consent -------------------------------------------------------------------------
# One question, asked once, on the one surface every hive passes through: this installer.
# /vulyk-bootstrap only reports the answer (asking twice would silently overwrite the first one).
#
# The answer is NEVER read from stdin: the copy and manifest loops above are `while read` over
# `find`/`ls` output, and a piped `curl | bash` install has no answer on stdin either. It is read
# from the controlling terminal, and when there is none (CI, pipes, a non-interactive
# vulyk-update.sh) nothing is printed and the row is written as `off`.

telemetry_row_value() { # telemetry_row_value <file> - prints on|off, or nothing when no valid row
  local row value=""
  [ -f "$1" ] || return 0
  row="$(grep -m1 '^|[[:space:]]*Telemetry[[:space:]]*|' "$1" 2>/dev/null || true)"
  [ -n "$row" ] || return 0
  value="$(printf '%s' "$row" | awk -F'|' '{print $3}' | tr -d '`' | awk '{print $1}')"
  case "$value" in on|off) printf '%s' "$value" ;; esac
}

telemetry_constitution() { # the target's constitution as it is BEFORE this run ("" on a fresh install)
  if [ -f "$DEST/CLAUDE.md" ] && { head -3 "$DEST/CLAUDE.md" 2>/dev/null | grep -q '^# VULYK Constitution' || \
       grep -q 'VULYK:COMMANDS:START' "$DEST/CLAUDE.md" 2>/dev/null; }; then
    printf '%s' "$DEST/CLAUDE.md"
  elif [ -f "$DEST/CLAUDE.vulyk.md" ]; then
    printf '%s' "$DEST/CLAUDE.vulyk.md"
  fi
}

# `[ -t 0 ]` alone is not the test: a piped install has no tty on stdin and still has a terminal
# behind /dev/tty. `[ -r /dev/tty ]` alone is not it either - on CI runners the device node is
# readable by mode while opening it fails - so the open is what decides.
telemetry_tty() {
  [ -t 0 ] && return 0
  [ -r /dev/tty ] || return 1
  ( exec 3< /dev/tty ) 2>/dev/null
}

print_telemetry_explanation() {
  echo ""
  echo "  Telemetry (optional, off by default)"
  echo "  VULYK can log anomalies - context blowups, empty agent returns, council rounds, long"
  echo "  stages - into memory/stats/anomalies.jsonl in this project, and bundle a week of them"
  echo "  into codes from a fixed list plus numbers. Never paths, slugs, story names, prompts,"
  echo "  emails or any free text. Nothing is ever sent: /vulyk-evolve prints the command and you"
  echo "  run it. Details: docs/telemetry.md. Default: off."
}

telemetry_decide() { # sets TEL_WANT: on|off to write, "" to leave the row exactly as it is
  local ans=""
  TEL_WANT=""
  if [ "$CHECK" = "--check" ]; then                      # A10 (1): never asks, never writes
    case "$TEL_MODE" in
      on|off) TEL_WANT="$TEL_MODE" ;;
      *)      [ -n "$TEL_PRE" ] || TEL_WANT="off" ;;
    esac
    return 0
  fi
  case "$TEL_MODE" in on|off) TEL_WANT="$TEL_MODE"; return 0 ;; esac   # A10 (2)
  if [ "$TEL_MODE" != "ask" ] && [ -n "$TEL_PRE" ]; then return 0; fi  # A10 (4): already answered
  if ! telemetry_tty; then                                             # A10 (5): nobody to ask
    [ -n "$TEL_PRE" ] || TEL_WANT="off"
    return 0
  fi
  print_telemetry_explanation                                          # A10 (3) and (5)
  printf '  Enable telemetry? [y/N] '
  if [ -r /dev/tty ] && ! [ -t 0 ]; then read -r ans < /dev/tty || ans=""
  else read -r ans || ans=""; fi
  echo ""
  case "$ans" in y|Y|yes|YES|Yes) TEL_WANT="on" ;; *) TEL_WANT="off" ;; esac
}

# The one permitted edit to a filled Profile block (A6): the `| Telemetry |` row - appended when
# missing, its value token replaced when the question was answered. Every other byte stays, and a
# block without markers is left entirely alone (ADR-005 D4.9).
ensure_telemetry_row() { # ensure_telemetry_row <constitution-file>
  local file="$1" name
  [ -n "$file" ] && [ -n "$TEL_WANT" ] || return 0
  name="$(basename "$file")"
  if [ "$CHECK" = "--check" ]; then
    echo "  would set      $name Profile row: Telemetry = $TEL_WANT"
    return 0
  fi
  [ -f "$file" ] || return 0
  grep -q 'VULYK:PROFILE:START' "$file" 2>/dev/null || return 0
  grep -q 'VULYK:PROFILE:END' "$file" 2>/dev/null || return 0
  [ "$(telemetry_row_value "$file")" = "$TEL_WANT" ] && return 0      # already says that
  awk -v val="$TEL_WANT" -v newrow="$(telemetry_row "$TEL_WANT")" '
    index($0, "VULYK:PROFILE:START") { inblock = 1; print; next }
    index($0, "VULYK:PROFILE:END") {
      if (inblock && !seen) { print newrow }
      inblock = 0; print; next
    }
    inblock && $0 ~ /^\|[[:space:]]*Telemetry[[:space:]]*\|/ {
      seen = 1
      n = split($0, cell, "|")
      if (sub(/[A-Za-z]+/, val, cell[3])) {
        line = cell[1]
        for (i = 2; i <= n; i++) line = line "|" cell[i]
        print line
      } else { print newrow }
      next
    }
    { print }
  ' "$file" > "$file.vulyktmp" && mv "$file.vulyktmp" "$file"
  echo "  profile row    $name: Telemetry = $TEL_WANT"
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
#
# Generalised to any event (A13): one script can be wired on Stop and SessionEnd as well, so the
# "already wired" test is per EVENT, not per file - a script present under Stop must still be
# added under SessionEnd. For a single-event script (the two SessionStart ones) this is exactly
# the old behaviour.
py_wire() { # py_wire <settings.json> <script> <event> [--dry]   (exit 3 = already wired there)
  "$PYBIN" - "$@" <<'PYWIRE'
import json, re, sys
path, script, event = sys.argv[1], sys.argv[2], sys.argv[3]
dry = '--dry' in sys.argv[4:]
REL = '$CLAUDE_PROJECT_DIR/.claude/hooks/'
try:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(4)                                  # unparseable: leave it entirely alone
if not isinstance(data, dict):
    sys.exit(4)
# How does THIS project invoke its shell hooks? On Windows a bare `.sh` path is not
# executable, so vulyk installs there wrap every hook in an explicit bash launcher. Copy
# whatever convention the siblings already use, or the entry we add is one that never runs.
prefix, quoted = '', False
for groups_any in (data.get('hooks') or {}).values():
    if not isinstance(groups_any, list):
        continue
    for group in groups_any:
        if not isinstance(group, dict):
            continue
        for hook in group.get('hooks', []) or []:
            if not isinstance(hook, dict):
                continue
            found = re.match(r'^(.*?)("?)' + re.escape(REL) + r'[^"\s]+\.sh"?', str(hook.get('command', '')))
            if found and not prefix:
                prefix, quoted = found.group(1), found.group(2) == '"'
cmd = prefix + ('"' if quoted else '') + REL + script + ('"' if quoted else '')

groups = data.setdefault('hooks', {}).setdefault(event, [])
if not isinstance(groups, list):
    sys.exit(4)
for group in groups:
    if isinstance(group, dict):
        for hook in group.get('hooks', []) or []:
            if isinstance(hook, dict) and script in str(hook.get('command', '')):
                sys.exit(3)                      # already there under any spelling
if dry:
    sys.exit(0)                                  # --check: would wire; nothing written
entry = {'type': 'command', 'command': cmd}
if groups and isinstance(groups[0], dict):
    groups[0].setdefault('hooks', []).append(entry)
else:
    groups.append({'hooks': [entry]})
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
    fh.write('\n')
PYWIRE
}

wire_hook() { # wire_hook <event> <hook-script-name>
  local event="$1" script="$2" file="$DEST/.claude/settings.json"
  [ -f "$file" ] || return 0                                   # fresh install: ours was copied whole
  PYBIN="$(command -v python3 || command -v python || true)"
  if [ -z "$PYBIN" ]; then
    grep -q "$script" "$file" 2>/dev/null && return 0          # no python: file-wide check is all we have
    if [ "$CHECK" = "--check" ]; then
      echo "  would wire     .claude/settings.json -> $event: $script"
      return 0
    fi
    echo ""
    echo "  NOTE: .claude/hooks/$script was installed but could NOT be wired -"
    echo "  no python on PATH to edit .claude/settings.json safely. Add this to your"
    echo "  $event hooks by hand, or that hook will never run:"
    echo "      { \"type\": \"command\", \"command\": \"\$CLAUDE_PROJECT_DIR/.claude/hooks/$script\" }"
    return 0
  fi
  if [ "$CHECK" = "--check" ]; then
    py_wire "$file" "$script" "$event" --dry \
      && echo "  would wire     .claude/settings.json -> $event: $script"
    return 0
  fi
  cp -p "$file" "$file.vulyk-bak" 2>/dev/null || true
  if py_wire "$file" "$script" "$event"; then
    echo "  wire           .claude/settings.json -> $event: $script"
    echo "                 (backup at .claude/settings.json.vulyk-bak; the file was re-indented by the edit)"
  else
    case "$?" in
      3) rm -f "$file.vulyk-bak" 2>/dev/null || true ;;   # already wired; nothing happened
      *) rm -f "$file.vulyk-bak" 2>/dev/null || true
         echo ""
         echo "  NOTE: .claude/settings.json could not be parsed as JSON - left untouched."
         echo "  Wire this hook by hand into your $event hooks:"
         echo "      { \"type\": \"command\", \"command\": \"\$CLAUDE_PROJECT_DIR/.claude/hooks/$script\" }" ;;
    esac
  fi
}

wire_session_hook() { wire_hook SessionStart "$1"; }

# The Workflow driver's clerk (`cycle-clerk.md`) runs every verb by shelling out to
# `scripts/cycle.sh` and `scripts/journal.sh`, and a subagent's Bash tool is deny-by-default -
# without an explicit `permissions.allow` entry every dispatch stalls on a prompt nobody is
# watching. VULYK's OWN settings.json deliberately carries neither rule (only a target hive
# runs the cycle unattended); this helper is what puts them there. Same treatment as
# wire_session_hook: append only what is missing, in place, after a backup, idempotent by
# inspection of the file.
wire_permissions() {
  local file="$DEST/.claude/settings.json" py=""
  [ -f "$file" ] || return 0                                   # nothing to edit
  if grep -q 'Bash(bash scripts/cycle.sh:\*)' "$file" 2>/dev/null && \
     grep -q 'Bash(bash scripts/journal.sh:\*)' "$file" 2>/dev/null; then
    return 0                                                    # already wired
  fi
  if [ "$CHECK" = "--check" ]; then
    echo "  would wire     .claude/settings.json -> permissions.allow: cycle.sh, journal.sh"
    return 0
  fi
  py="$(command -v python3 || command -v python || true)"
  if [ -z "$py" ]; then
    echo ""
    echo "  NOTE: the Workflow driver's clerk needs Bash access but could NOT be wired -"
    echo "  no python on PATH to edit .claude/settings.json safely. Add these to your"
    echo "  permissions.allow by hand, or every cycle-clerk dispatch will stall on a prompt:"
    echo "      \"Bash(bash scripts/cycle.sh:*)\""
    echo "      \"Bash(bash scripts/journal.sh:*)\""
    return 0
  fi
  cp -p "$file" "$file.vulyk-bak" 2>/dev/null || true
  if "$py" - "$file" <<'PYPERM'
import json, sys
path = sys.argv[1]
RULES = ["Bash(bash scripts/cycle.sh:*)", "Bash(bash scripts/journal.sh:*)"]
try:
    with open(path, encoding='utf-8') as fh:
        data = json.load(fh)
except Exception:
    sys.exit(4)                                  # unparseable: leave it entirely alone
if not isinstance(data, dict):
    sys.exit(4)
allow = data.setdefault('permissions', {}).setdefault('allow', [])
if not isinstance(allow, list):
    sys.exit(4)
added = [r for r in RULES if r not in allow]
if not added:
    sys.exit(3)                                  # already there under both spellings
allow.extend(added)
with open(path, 'w', encoding='utf-8') as fh:
    json.dump(data, fh, indent=2)
    fh.write('\n')
PYPERM
  then
    echo "  wire           .claude/settings.json -> permissions.allow: cycle.sh, journal.sh"
    echo "                 (backup at .claude/settings.json.vulyk-bak; the file was re-indented by the edit)"
  else
    case "$?" in
      3) rm -f "$file.vulyk-bak" 2>/dev/null || true ;;   # already wired; nothing happened
      *) rm -f "$file.vulyk-bak" 2>/dev/null || true
         echo ""
         echo "  NOTE: .claude/settings.json could not be parsed as JSON - left untouched."
         echo "  Add these to permissions.allow by hand:"
         echo "      \"Bash(bash scripts/cycle.sh:*)\""
         echo "      \"Bash(bash scripts/journal.sh:*)\"" ;;
    esac
  fi
}

# VULYK ships runtime artifacts - handoffs, snapshots, the update-check cache, the derived
# state view, the installer's own settings backup - and until now shipped no rule for
# ignoring any of them. `.gitignore` is the project's file and is not framework-owned, so it
# is never copied and never replaced; the result was that every installed project committed
# whatever the framework left lying around, or did not, by luck. Same treatment as the hook
# wiring: append only what is missing, in a marked block, and say what was added.
ensure_gitignore() {
  local file="$DEST/.gitignore" missing=0 line
  local wanted=".claude/handoff/ .claude/.vulyk-update-cache .claude/settings.json.vulyk-bak .claude/state.json .claude/settings.local.json CLAUDE.local.md memory/snapshots/ memory/map/.stale __pycache__/ .vulyk/ docs/specs/*/PAUSE docs/specs/*/DRIVER"

  for line in $wanted; do
    grep -qxF "$line" "$file" 2>/dev/null || missing=$((missing + 1))
  done
  [ "$missing" -gt 0 ] || return 0

  if [ "$CHECK" = "--check" ]; then
    echo "  would add      $missing VULYK runtime entries to .gitignore"
    return 0
  fi

  {
    [ -s "$file" ] && echo ""
    echo "# --- VULYK runtime artifacts (added by install.sh; safe to reorder or annotate) ---"
    echo "# Per-machine or derived. Committing any of them creates a second account of"
    echo "# something the repository already holds, which is the failure mode the framework"
    echo "# spends most of its checks preventing."
    for line in $wanted; do
      grep -qxF "$line" "$file" 2>/dev/null || echo "$line"
    done
  } >> "$file"
  echo "  gitignore      added $missing VULYK runtime entries"
}

# The Workflow driver is JavaScript, and the Workflow tool refuses a script with CR bytes. On a
# Windows checkout with core.autocrlf=true every text file without an eol rule comes out CRLF,
# so a hive without this rule cannot launch the driver at all. Same treatment as .gitignore:
# the file is the project's, append only the missing line, say what was added. The working
# copy is re-checked out so the rule takes effect now, not at the next clone.
ensure_gitattributes() {
  local file="$DEST/.gitattributes" rule=".claude/workflows/*.js text eol=lf" f n=0
  if ! grep -qF ".claude/workflows/*.js" "$file" 2>/dev/null; then
    if [ "$CHECK" = "--check" ]; then
      echo "  would add      eol=lf rule for .claude/workflows/*.js to .gitattributes"
    else
      {
        [ -s "$file" ] && echo ""
        echo "# --- VULYK: the Workflow driver must check out with LF (added by install.sh) ---"
        echo "$rule"
      } >> "$file"
      echo "  gitattributes  added eol=lf rule for .claude/workflows/*.js"
    fi
  fi
  # The bytes copy_tree just wrote came from the source checkout, and on Windows that checkout
  # may itself be CRLF (git does not re-smudge an unchanged file when only .gitattributes moved
  # between tags). So the rule alone is not enough: strip CR from the copied drivers, every run.
  [ "$CHECK" = "--check" ] && return 0
  for f in "$DEST"/.claude/workflows/*.js; do
    [ -f "$f" ] || continue
    if grep -q $'' "$f"; then sed -i 's/$//' "$f"; n=$((n + 1)); fi
  done
  [ "$n" -gt 0 ] && echo "  gitattributes  normalized $n driver script(s) to LF"
  return 0
}

NEW_MANIFEST="$(mktemp)"
trap 'rm -f "$NEW_MANIFEST"' EXIT
for tree in .claude memory bootstrap templates scripts docs/wiki docs/specs docs/adr; do copy_tree "$tree"; done
LC_ALL=C sort -u -o "$NEW_MANIFEST" "$NEW_MANIFEST"

# Removal (ADR-005 D2), after the copy loop and before the new manifest is written: a path
# that shipped last run, does not ship this run, and lives under OWNED is deleted outright -
# there is nothing to compare a retired file's content against, the same rule OWNED already
# applies to replacement. A dropout outside OWNED is an owner's own file and is only ever
# reported, never touched. No old manifest at all means this hive predates the manifest:
# delete nothing, just name what an OWNED tree holds that this release no longer ships.
OLD_MANIFEST="$DEST/.claude/vulyk-manifest"
if [ -n "$UPGRADE" ]; then
  if [ -f "$OLD_MANIFEST" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      grep -qxF "$f" "$NEW_MANIFEST" && continue   # still shipped this run
      if owned "$f"; then
        if [ "$CHECK" = "--check" ]; then
          echo "  would remove   $f"
        else
          rm -f "$DEST/$f" 2>/dev/null || true
          echo "  remove         $f"
        fi
      else
        echo "  leave (yours)  $f"
      fi
    done < "$OLD_MANIFEST"
  else
    for t in $OWNED; do
      [ -d "$DEST/$t" ] || continue
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        grep -qxF "$f" "$NEW_MANIFEST" && continue
        echo "  unlisted (kept) $f"
      done < <( cd "$DEST" && find "$t" -type f ! -name '.gitkeep' | LC_ALL=C sort )
    done
  fi
fi

ensure_gitignore
ensure_gitattributes
wire_session_hook vulyk-update-check.sh
wire_session_hook top-model-brief.sh
# The anomaly scan runs at the end of a turn and at the end of a session; an existing hive's
# settings.json knows about neither group until this wires them (A13).
wire_hook Stop anomaly-scan.sh
wire_hook SessionEnd anomaly-scan.sh
wire_permissions
# The empty trees a fresh hive needs. Guarded like every other write: a dry run that
# creates directories is not a dry run, and this one had been leaving seven of them in
# repositories whose owners were only asking what the installer would do.
if [ "$CHECK" = "--check" ]; then
  echo "  would create   memory/ and docs/ trees"
else
  mkdir -p "$DEST/memory/learnings" "$DEST/memory/snapshots" "$DEST/docs/wiki" "$DEST/docs/specs" "$DEST/docs/adr" 2>/dev/null || true
fi
[ -f "$DEST/memory/stats/skills.json" ] || { [ "$CHECK" = "--check" ] || { mkdir -p "$DEST/memory/stats"; echo '{}' > "$DEST/memory/stats/skills.json"; }; }

# Telemetry consent, decided before the constitution is touched: TEL_PRE is the row as this hive
# had it BEFORE this run (empty on a fresh install, or on a hive from before the row existed),
# which is what tells rule (4) - "already answered, leave it" - from rule (5) - "never asked".
TEL_PRE="$(telemetry_row_value "$(telemetry_constitution)")"
telemetry_decide

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
    # Pre-0.10.0 constitutions pin `TOP_MODEL = opus` by default, and the resolver honours a
    # pin over the plan - so an upgraded hive on Max stays on Opus until this line changes.
    # Say so here, once, rather than letting the session brief report "by constitution"
    # forever to an owner who never chose it.
    if grep -q 'TOP_MODEL = opus' "$DEST/CLAUDE.md" 2>/dev/null; then
      echo "  Since 0.10.0 the top model follows the plan (Fable 5.1 on Max, Opus 5 on Pro)."
      echo "  Your constitution still pins \`TOP_MODEL = opus\`; change it to \`TOP_MODEL = auto\` to"
      echo "  enable that, or keep the pin deliberately. \`scripts/top-model.sh --explain\` shows the pick."
    fi
    # The council needs Profile/Commands to exist, not to be filled - an owner who bootstrapped
    # before this release has a constitution with neither block. Insert what's missing; never
    # touch a block whose markers, or whose hand-written heading, are already there.
    print_profile_placeholder | ensure_marked_block "$DEST/CLAUDE.md" "VULYK:PROFILE" "## Profile block"
    print_commands_placeholder | ensure_marked_block "$DEST/CLAUDE.md" "VULYK:COMMANDS" "## Commands table"
    report_fill_status "$DEST/CLAUDE.md" "VULYK:PROFILE" "profile"
    report_fill_status "$DEST/CLAUDE.md" "VULYK:COMMANDS" "commands"
  elif [ -e "$DEST/CLAUDE.vulyk.md" ]; then
    echo ""
    echo "  CLAUDE.vulyk.md exists - left untouched."
    if ! cmp -s "$SRC/CLAUDE.md" "$DEST/CLAUDE.vulyk.md"; then
      echo "  The framework constitution changed in $VER. See what, then merge what you want:"
      echo "      git -C \"$SRC\" log --oneline -- CLAUDE.md   # or simply:"
      echo "      diff \"$DEST/CLAUDE.vulyk.md\" \"$SRC/CLAUDE.md\""
    fi
    # Same treatment as the CLAUDE.md branch above - it's the same constitution under a
    # different filename, and the council reads the same blocks from it. The foreign
    # CLAUDE.md sitting beside the sidecar is never opened.
    print_profile_placeholder | ensure_marked_block "$DEST/CLAUDE.vulyk.md" "VULYK:PROFILE" "## Profile block"
    print_commands_placeholder | ensure_marked_block "$DEST/CLAUDE.vulyk.md" "VULYK:COMMANDS" "## Commands table"
    report_fill_status "$DEST/CLAUDE.vulyk.md" "VULYK:PROFILE" "profile"
    report_fill_status "$DEST/CLAUDE.vulyk.md" "VULYK:COMMANDS" "commands"
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

# The consent row goes into whichever file is this hive's constitution now - the sidecar included.
CONST="$(telemetry_constitution)"
[ -n "$CONST" ] || CONST="$DEST/CLAUDE.md"
ensure_telemetry_row "$CONST"

# Version stamp - what a future --upgrade reads as "from".
if [ "$CHECK" = "--check" ]; then
  echo "  would stamp    .claude/vulyk-version = $VER"
else
  mkdir -p "$DEST/.claude"
  printf '%s\n' "$VER" > "$DEST/.claude/vulyk-version"
  echo "  stamp          .claude/vulyk-version = $VER"
fi

# Manifest - the whole ship set of this run (ADR-005 D2), written beside the stamp for the
# same reason: it is installer state, not shipped content, and is never gitignored (a hive
# commits it, same as the stamp).
MANIFEST_COUNT="$(wc -l < "$NEW_MANIFEST" | tr -d ' ')"
if [ "$CHECK" = "--check" ]; then
  echo "  would write    .claude/vulyk-manifest ($MANIFEST_COUNT paths)"
else
  mkdir -p "$DEST/.claude"
  cp "$NEW_MANIFEST" "$DEST/.claude/vulyk-manifest"
  echo "  write          .claude/vulyk-manifest ($MANIFEST_COUNT paths)"
fi

# Pin the target's own Queen session to the top model the plan resolves to. A resolver that
# ships but is never applied is a session that starts on the account default forever - the
# same reasoning as wire_session_hook, aimed at a decision instead of a hook entry. Skipped
# on a dry run (nothing to apply) and silent when already pinned; any other failure (no
# python, an unparsable settings.local.json) is printed by the resolver itself and must
# never fail the install - pinning a session is a convenience, not a precondition.
if [ "$CHECK" = "--check" ]; then
  echo "  would pin      Queen session to the resolved top model (scripts/top-model.sh --apply)"
elif [ -f "$DEST/scripts/top-model.sh" ]; then
  # top-model.sh resolves its own root from CLAUDE_PROJECT_DIR, falling back to $(pwd) - and
  # install.sh never cd's into $DEST, so without this it would pin whatever directory the
  # installer happened to be run from instead of the target.
  APPLY_OUT="$(CLAUDE_PROJECT_DIR="$DEST" bash "$DEST/scripts/top-model.sh" --apply 2>&1)" || true
  case "$APPLY_OUT" in
    "already pinned:"*) : ;;                       # nothing changed; nothing to report
    *)                   echo "  $APPLY_OUT" ;;
  esac
fi

chmod +x "$DEST"/.claude/hooks/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/*.sh 2>/dev/null || true
chmod +x "$DEST"/scripts/git-hooks/post-merge 2>/dev/null || true

echo ""
if [ -n "$UPGRADE" ]; then
  if [ -n "$BLOCK_INSERTED" ]; then
    echo "Done. Upgraded framework files only; inserted a missing Profile/Commands block into your"
    echo "constitution (see note above). Otherwise your CLAUDE.md, memory/, specs, ADRs and wiki were not touched."
  else
    echo "Done. Upgraded framework files only; your CLAUDE.md, memory/, specs, ADRs and wiki were not touched."
  fi
  echo "If the constitution changed this release, merge those edits by hand (see note above)."
else
  echo "Done. Next: cd $DEST && claude  ->  /vulyk-bootstrap"
  echo "Optional: cp scripts/git-hooks/post-merge .git/hooks/post-merge && chmod +x .git/hooks/post-merge"
fi
