#!/usr/bin/env bash
# The anomaly telemetry contract, driven through hand-written fixtures - no model calls, no
# network, nothing sent. Covers scripts/telemetry.sh (`enum`, `agents`, `record`, `bundle`,
# `check`, `consent`, `publish`) and scripts/lib.sh's `is_paperwork_path` entry for the new
# stats file. Schemas: docs/specs/anomaly-telemetry/plan.md ## Contracts.
#
#   Usage: bash tests/telemetry.test.sh            # from the VULYK repo root
#
# Mirrors tests/council.test.sh: a throwaway git repo under mktemp -d, `expect()` on stdout
# substrings, a non-zero exit on the first wrong answer, one summary line at the end.
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
fail=0
# Verdicts are tallied on disk, not in a variable: `cmd | expect ...` runs expect in a subshell
# (the right-hand side of a pipe), so a `fail=1` set there would be lost and a red assertion
# would still exit 0. Every helper below is safe to call from either side of a pipe.
LEDGER="$T/checks"; FAILS="$T/fails"; : > "$LEDGER"; : > "$FAILS"
ok()  { printf 'x\n' >> "$LEDGER"; echo "  ok    $1"; }
bad() { printf 'x\n' >> "$LEDGER"; printf 'x\n' >> "$FAILS"; echo "::error::$1"; }

expect() { # expect <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then ok "$label"
  else bad "$label - expected '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'; fi
}

expect_absent() { # expect_absent <label> <needle>   (reads the output to judge from stdin)
  local label="$1" needle="$2" out; out="$(cat)"
  if printf '%s' "$out" | grep -qF -- "$needle"; then
    bad "$label - did NOT expect '$needle' in:"; printf '%s\n' "$out" | sed 's/^/        /'
  else ok "$label"; fi
}

expect_eq() { # expect_eq <label> <expected> <actual>
  local label="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then ok "$label"
  else bad "$label - expected [$want], got [$got]"; fi
}

# --- case 0: syntax ---------------------------------------------------------------------------
# First, always: every case below runs the script, so a syntax error must be named as one.
echo "--- syntax"
for s in scripts/telemetry.sh scripts/lib.sh; do
  if bash -n "$SRC/$s" 2>/dev/null; then ok "bash -n $s"
  else bad "bash -n $s failed"; bash -n "$SRC/$s"; exit 1; fi
done

# --- the fixture hive -------------------------------------------------------------------------
HIVE="$T/hive"
mkdir -p "$HIVE/scripts" "$HIVE/memory/stats" "$HIVE/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$HIVE/scripts/"
cp "$SRC"/.claude/agents/*.md "$HIVE/.claude/agents/"
cat > "$HIVE/CLAUDE.md" <<'EOF'
# Fixture hive

## Profile

| Field | Value |
|---|---|
| Stack | shell |
EOF
git -C "$HIVE" init -q -b main . && git -C "$HIVE" config user.email t@t &&
  git -C "$HIVE" config user.name "Test Owner" && git -C "$HIVE" config core.autocrlf false
git -C "$HIVE" add -A && git -C "$HIVE" commit -qm init >/dev/null

LOG="$HIVE/memory/stats/anomalies.jsonl"
WEEK="$(date -u +%G-W%V)"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
tel() { (cd "$HIVE" && VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }

set_consent() { # set_consent <cell text>   ('' removes the row)
  grep -v '^| Telemetry |' "$HIVE/CLAUDE.md" > "$HIVE/CLAUDE.md.new"
  mv "$HIVE/CLAUDE.md.new" "$HIVE/CLAUDE.md"
  [ -n "${1:-}" ] && printf '| Telemetry | %s |\n' "$1" >> "$HIVE/CLAUDE.md"
  return 0
}

# --- case 1: enum and the agent token set -----------------------------------------------------
echo "--- enum, agents"
tel enum | expect "enum prints context_high" "context_high"
tel enum | expect "enum prints scope_breach"  "scope_breach"
expect_eq "enum is exactly 8 codes" "8" "$(tel enum | grep -c .)"
tel enum | expect_absent "enum prints codes only, no prose" " "
tel agents | expect "agents prints a framework agent" "cycle-clerk"
tel agents | expect "agents prints the catch-all token" "other"
expect_eq "agents = .claude/agents/*.md basenames + other" \
  "$(( $(ls "$HIVE"/.claude/agents/*.md | wc -l) + 1 ))" "$(tel agents | grep -c .)"
tel agents | expect_absent "agents does not print the .md extension" ".md"

# --- case 2: record ---------------------------------------------------------------------------
echo "--- record"
tel record context_high 150000 140000 --ref session:x
expect_eq "record appends one row" "1" "$(grep -c . "$LOG")"
expect_eq "the local row carries the 12 contract keys, in order" \
  '["v","ts","code","value","threshold","vulyk","tier","model","agent","spec","story","ref"]' \
  "$(jq -c 'keys_unsorted' < "$LOG" | head -1)"
expect_eq "agent is empty when --agent is not given" "" "$(jq -r '.agent' < "$LOG" | head -1 | tr -d '\r')"
tel record context_high 150000 140000 --ref session:x
expect_eq "a second identical (code, ref) appends nothing" "1" "$(grep -c . "$LOG")"

tel record agent_prefix_high 60000 50000 --ref agent:a --agent cycle-clerk
expect_eq "a framework agent token lands as given" "cycle-clerk" \
  "$(grep -F '"ref":"agent:a"' "$LOG" | jq -r '.agent')"
tel record agent_prefix_high 60000 50000 --ref agent:b --agent worker-01-core
expect_eq "a dispatch name outside the set lands as other" "other" \
  "$(grep -F '"ref":"agent:b"' "$LOG" | jq -r '.agent')"

BEFORE="$(grep -c . "$LOG")"
ERR="$(tel record not_a_code 1 0 --ref session:z 2>&1 >/dev/null)"; RC=$?
expect_eq "an unknown code exits 1" "1" "$RC"
printf '%s' "$ERR" | expect "an unknown code names itself on stderr" "not_a_code"
expect_eq "an unknown code is one line on stderr" "1" "$(printf '%s\n' "$ERR" | grep -c .)"
expect_eq "an unknown code writes nothing" "$BEFORE" "$(grep -c . "$LOG")"

# --- case 3: bundle - the anonymization guard -------------------------------------------------
echo "--- bundle"
SPEC="secret-spec-slug"
STORY="secret-spec-slug-07-private"
REF="session:/e/Projects/hive/owner@example.com.jsonl"
: > "$LOG"
printf '{"v":1,"ts":"%s","code":"context_high","value":150000,"threshold":140000,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","spec":"%s","story":"%s","ref":"%s"}\n' \
  "$NOW" "$SPEC" "$STORY" "$REF" >> "$LOG"
printf '{"v":1,"ts":"%s","code":"agent_prefix_high","value":60000,"threshold":50000,"vulyk":"0.13.3","tier":3,"model":"sonnet","agent":"cycle-clerk","spec":"%s","story":"%s","ref":"agent:x"}\n' \
  "$NOW" "$SPEC" "$STORY" >> "$LOG"
# A row from a different week must stay behind; a row with an unknown code must not travel.
printf '{"v":1,"ts":"1999-01-04T00:00:00Z","code":"stage_long","value":40,"threshold":24,"vulyk":"0.13.3","tier":3,"model":"","agent":"","spec":"%s","story":"","ref":"stage:1"}\n' "$SPEC" >> "$LOG"

BUNDLE="$T/bundle.jsonl"
tel bundle > "$BUNDLE"
expect_eq "bundle emits this week's rows only" "2" "$(grep -c . "$BUNDLE")"
expect_eq "the bundle row carries the 10 contract keys, in order" \
  '["v","code","value","threshold","vulyk","tier","model","agent","week","hive"]' \
  "$(jq -c 'keys_unsorted' < "$BUNDLE" | head -1)"
cat "$BUNDLE" | expect_absent "the spec slug does not travel"  "$SPEC"
cat "$BUNDLE" | expect_absent "the story id does not travel"   "$STORY"
cat "$BUNDLE" | expect_absent "the ref does not travel"        "session:"
cat "$BUNDLE" | expect_absent "no path separator travels"      "/"
cat "$BUNDLE" | expect_absent "no backslash travels"           "\\"
cat "$BUNDLE" | expect_absent "no address travels"             "@"
cat "$BUNDLE" | expect_absent "no timestamp travels"           "$NOW"
cat "$BUNDLE" | expect "the agent token does travel"           '"agent":"cycle-clerk"'
cat "$BUNDLE" | expect "the ISO week travels"                  "\"week\":\"$WEEK\""
expect_eq "hive is 12 hex" "1" "$(jq -r '.hive' < "$BUNDLE" | head -1 | grep -c '^[0-9a-f]\{12\}$')"

# --- case 4: check ----------------------------------------------------------------------------
echo "--- check"
if tel check "$BUNDLE" >/dev/null 2>&1; then ok "check accepts bundle's own output"
else bad "check rejected bundle's own output:"; tel check "$BUNDLE" 2>&1 | sed 's/^/        /'; fi

reject() { # reject <label> <jq mutation of a valid bundle row> <reason substring>
  local label="$1" mutation="$2" needle="$3" f="$T/bad.jsonl" err rc
  head -1 "$BUNDLE" | jq -c "$mutation" > "$f"
  err="$(tel check "$f" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" -ne 1 ]; then bad "$label - expected exit 1, got $rc"; return; fi
  if printf '%s' "$err" | grep -qF -- "$f:1: " && printf '%s' "$err" | grep -qF -- "$needle"; then
    ok "check rejects $label"
  else bad "check rejects $label - expected '<file>:1: ...$needle' in:"
    printf '%s\n' "$err" | sed 's/^/        /'; fi
}
reject "an extra key"                '. + {"note":"x"}'      "key set"
reject "an unknown code"             '.code = "not_a_code"'  "code is not in the enum"
reject "an agent outside the set"    '.agent = "mystery"'    "agent token set"
reject "a string carrying a path"    '.vulyk = "1.2.3/home"' "path, an address or whitespace"
reject "a hive that is not 12 hex"   '.hive = "nothex"'      "hive is not 12 hex"

# --- case 5: consent --------------------------------------------------------------------------
echo "--- consent"
set_consent ""
expect_eq "no Telemetry row = off"            "off" "$(tel consent)"
set_consent "on - anonymized weekly bundle"
expect_eq "the row's first token wins (on)"   "on"  "$(tel consent)"
set_consent "off - the default"
expect_eq "the row's first token wins (off)"  "off" "$(tel consent)"
set_consent '`on` - backticked'
expect_eq "backticks are tolerated"           "on"  "$(tel consent)"

# --- case 6: publish - prints, never sends ----------------------------------------------------
echo "--- publish"
# A PATH shim in front of git and gh: every invocation is recorded, git still works (telemetry.sh
# needs rev-parse), gh is a no-op. The assertion below is the whole point of the case.
SHIM="$T/shim"; CALLS="$T/calls.txt"; : > "$CALLS"
REALGIT="$(command -v git)"
mkdir -p "$SHIM"
cat > "$SHIM/git" <<EOF
#!/usr/bin/env bash
printf 'git %s\n' "\$*" >> "$CALLS"
exec "$REALGIT" "\$@"
EOF
cat > "$SHIM/gh" <<EOF
#!/usr/bin/env bash
printf 'gh %s\n' "\$*" >> "$CALLS"
exit 0
EOF
chmod +x "$SHIM/git" "$SHIM/gh"
shimmed() { (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }

set_consent "off - the default"
shimmed publish | expect "consent off prints one 'nothing to send' line" "nothing to send"
expect_eq "consent off creates no bundle file" "0" \
  "$(ls "$HIVE/.vulyk/telemetry" 2>/dev/null | grep -c . || true)"

LOCAL="$T/vulyk-local"
mkdir -p "$LOCAL/telemetry/inbox"
git -C "$LOCAL" init -q -b main . && git -C "$LOCAL" config user.email t@t &&
  git -C "$LOCAL" config user.name "Test Owner"
git -C "$LOCAL" add -A 2>/dev/null; git -C "$LOCAL" commit -qm init --allow-empty >/dev/null

set_consent "on - anonymized weekly bundle"
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish) 2>&1 )"
HIVEID="$(jq -r '.hive' < "$BUNDLE" | head -1)"
printf '%s' "$OUT" | expect "a local checkout gets a printed commit command" "git add telemetry/inbox/$WEEK/$HIVEID.jsonl"
expect_eq "the bundle is copied into telemetry/inbox/<week>/<hive>.jsonl" "yes" \
  "$([ -s "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"
if tel check "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" >/dev/null 2>&1
then ok "the copied bundle passes check"; else bad "the copied bundle fails check"; fi

rm -rf "$LOCAL/telemetry/inbox/$WEEK"
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish --dry-run) 2>&1 )"
printf '%s' "$OUT" | expect "--dry-run still prints the commit command" "git add telemetry/inbox/$WEEK/$HIVEID.jsonl"
expect_eq "--dry-run copies nothing" "no" \
  "$([ -e "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"

rm -rf "$LOCAL/telemetry"   # no inbox -> no local checkout -> the PR recipe
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish) 2>&1 )"
printf '%s' "$OUT" | expect "no local checkout gets the PR recipe" "gh pr create"
printf '%s' "$OUT" | expect_absent "the PR recipe does not claim anything was sent" "telemetry: wrote"

# The rule the whole spec rests on (.claude/commands/vulyk-ship.md:11): nothing is sent.
cat "$CALLS" | expect_absent "publish never invokes git push"   " push"
cat "$CALLS" | expect_absent "publish never invokes git commit" " commit"
cat "$CALLS" | expect_absent "publish never invokes gh"         "gh "
cat "$CALLS" | expect_absent "publish never invokes a pr"       "pr create"

# --- case 7: the log is paperwork -------------------------------------------------------------
echo "--- is_paperwork_path"
paper() { ( . "$SRC/scripts/lib.sh"; is_paperwork_path "$1" && echo true || echo false ); }
expect_eq "memory/stats/anomalies.jsonl is paperwork"  "true"  "$(paper memory/stats/anomalies.jsonl)"
expect_eq "memory/stats/other.jsonl is not"            "false" "$(paper memory/stats/other.jsonl)"
expect_eq "the entry stays anchored (no bare basename)" "false" "$(paper anomalies.jsonl)"

# --- case 8: the paperwork the contract names -------------------------------------------------
echo "--- paperwork"
cat "$SRC/CLAUDE.md" | expect "CLAUDE.md ## Commands names this suite" \
  '| Anomaly telemetry contract tests | `bash tests/telemetry.test.sh` |'
tel scan 2>&1 | expect "scan is a fail-open stub until story 02" "not implemented"

# --- detectors (anomaly-telemetry-02) ---------------------------------------------------------
# Story 02 adds the `scan` verb's five detectors, .claude/hooks/anomaly-scan.sh and
# `handoff.py measure`. Its cases belong here, below this marker.

# --- install and consent wiring (anomaly-telemetry-05) ----------------------------------------
# Story 05 adds the Telemetry Profile row, install.sh's /dev/tty question and `wire_hook`.
# Its local cases belong here, below this marker.

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "telemetry.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
