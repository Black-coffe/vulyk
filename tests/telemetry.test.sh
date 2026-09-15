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

# --- detectors (anomaly-telemetry-02) ---------------------------------------------------------
# Story 02 adds the `scan` verb's five detectors, .claude/hooks/anomaly-scan.sh and
# `handoff.py measure`. Its cases belong here, below this marker.
PY="$(command -v python3 || command -v python || true)"
mkdir -p "$HIVE/.claude/hooks"
cp "$SRC/.claude/hooks/handoff.py" "$SRC/.claude/hooks/handoff.sh" "$SRC/.claude/hooks/anomaly-scan.sh" \
  "$HIVE/.claude/hooks/"

# --- case 9: handoff.py measure ----------------------------------------------------------------
echo "--- handoff.py measure"
MEASURE="$T/measure"
mkdir -p "$MEASURE/subagents"

cat > "$MEASURE/main.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-fable-5-1","usage":{"input_tokens":1000,"cache_read_input_tokens":500,"cache_creation_input_tokens":2000,"output_tokens":300}}}
EOF
MAIN_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < /dev/null)"
expect_eq "measure tokens equals context_tokens()'s answer" "3800" \
  "$(printf '%s' "$MAIN_OUT" | jq -r '.tokens')"

cat > "$MEASURE/subagents/agent-a1.jsonl" <<'EOF'
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":40000,"cache_creation_input_tokens":15000,"cache_read_input_tokens":0,"output_tokens":50},"content":[{"type":"tool_use","name":"Bash"}]}}
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":2000,"output_tokens":40},"content":[{"type":"text","text":"done"}]}}
EOF
printf '{"agentType":"cycle-clerk"}\n' > "$MEASURE/subagents/agent-a1.meta.json"
SIDE_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/subagents/agent-a1.jsonl" --sidechain < /dev/null)"
expect_eq "measure --sidechain first_prefix is the first turn's input+cache_creation" "55000" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.first_prefix')"
expect_eq "measure --sidechain assistant_turns counts sidechain entries" "2" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.assistant_turns')"
expect_eq "measure --sidechain last_has_text reads the last entry's content" "true" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.last_has_text')"
expect_eq "measure --sidechain agent_type reads the sibling .meta.json" "cycle-clerk" \
  "$(printf '%s' "$SIDE_OUT" | jq -r '.agent_type')"

MISSING_OUT="$("$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/does-not-exist.jsonl" < /dev/null)"; MISSING_RC=$?
expect_eq "measure on a missing file prints {}" "{}" "$MISSING_OUT"
expect_eq "measure on a missing file exits 0" "0" "$MISSING_RC"

STATUS_RC=0
bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null >/dev/null 2>&1 || STATUS_RC=$?
expect_eq "handoff.sh status still exits 0 with measure added" "0" "$STATUS_RC"

# --- case 10: scan - agent_prefix_high / agent_empty --------------------------------------------
echo "--- scan: agent_prefix_high, agent_empty"
SESSION="$T/session1"
mkdir -p "$SESSION/subagents"
cat > "$SESSION/subagents/agent-hi.jsonl" <<'EOF'
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":40000,"cache_creation_input_tokens":20000,"cache_read_input_tokens":0,"output_tokens":10},"content":[{"type":"text","text":"ok"}]}}
EOF
printf '{"agentType":"cycle-clerk"}\n' > "$SESSION/subagents/agent-hi.meta.json"
cat > "$SESSION/subagents/agent-empty.jsonl" <<'EOF'
{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":5},"content":[{"type":"tool_use","name":"Bash"}]}}
EOF
printf '{"agentType":"my-custom-agent"}\n' > "$SESSION/subagents/agent-empty.meta.json"
cat > "$SESSION/main.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
EOF

: > "$LOG"
tel scan --transcript "$SESSION/main.jsonl" >/dev/null 2>&1
expect_eq "scan records exactly one agent_prefix_high row" "1" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG")"
expect_eq "agent_prefix_high carries the cycle-clerk agent token" "cycle-clerk" \
  "$(grep '"code":"agent_prefix_high"' "$LOG" | jq -r '.agent')"
expect_eq "scan records exactly one agent_empty row" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "agent_empty maps a non-framework agentType to other" "other" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.agent')"
expect_eq "agent_empty ref is agent:<basename>" "agent:agent-empty.jsonl" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.ref')"
AGENT_ROWS="$(grep -c . "$LOG")"
tel scan --transcript "$SESSION/main.jsonl" >/dev/null 2>&1
expect_eq "a second scan over the same session appends nothing" "$AGENT_ROWS" "$(grep -c . "$LOG")"

# --- case 11: scan - context_high ----------------------------------------------------------------
echo "--- scan: context_high"
: > "$LOG"
CTX="$T/ctx-main.jsonl"
cat > "$CTX" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-fable-5-1","usage":{"input_tokens":100000,"cache_read_input_tokens":40000,"cache_creation_input_tokens":10000,"output_tokens":5000}}}
EOF
tel scan --transcript "$CTX" >/dev/null 2>&1
expect_eq "scan records one context_high row above the absolute threshold" "1" \
  "$(grep -c '"code":"context_high"' "$LOG")"
expect_eq "context_high maps claude-fable-5-1 to fable" "fable" \
  "$(grep '"code":"context_high"' "$LOG" | jq -r '.model')"
expect_eq "context_high carries an empty agent" "" \
  "$(grep '"code":"context_high"' "$LOG" | jq -r '.agent')"

# --- case 12: scan - council_rounds_high ---------------------------------------------------------
echo "--- scan: council_rounds_high"
mkdir -p "$HIVE/docs/specs/fixture-spec" "$HIVE/docs/specs/low-round-spec"
printf '**Tier:** 2 · **Spec slug:** `fixture-spec`\n' > "$HIVE/docs/specs/fixture-spec/plan.md"
printf '**Tier:** 1 · **Spec slug:** `low-round-spec`\n' > "$HIVE/docs/specs/low-round-spec/plan.md"
COUNCIL_LOG="$HIVE/memory/stats/council.jsonl"
: > "$COUNCIL_LOG"
printf '{"ts":"%s","spec":"fixture-spec","round":3,"verdict":"GREEN"}\n' "$NOW" >> "$COUNCIL_LOG"
printf '{"ts":"%s","spec":"low-round-spec","round":2,"verdict":"GREEN"}\n' "$NOW" >> "$COUNCIL_LOG"

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "council_rounds_high fires for the spec at round 3" "1" \
  "$(grep -c '"code":"council_rounds_high".*"spec":"fixture-spec"' "$LOG")"
expect_eq "council_rounds_high carries the spec's tier from plan.md" "2" \
  "$(grep '"code":"council_rounds_high"' "$LOG" | jq -r '.tier')"
expect_eq "no council_rounds_high row for the spec at round 2" "0" \
  "$(grep -c '"spec":"low-round-spec"' "$LOG")"

# --- case 13: scan - stage_long -------------------------------------------------------------------
echo "--- scan: stage_long"
mkdir -p "$HIVE/docs/specs/stage-long-spec" "$HIVE/docs/specs/stage-short-spec"
cat > "$HIVE/docs/specs/stage-long-spec/journal.md" <<'EOF'
- 2026-01-01T00:00:00Z · 01-spec · start · next: plan
- 2026-01-02T06:00:00Z · 02-plan · planned · next: build
EOF
cat > "$HIVE/docs/specs/stage-short-spec/journal.md" <<'EOF'
- 2026-01-01T00:00:00Z · 01-spec · start · next: plan
- 2026-01-01T02:00:00Z · 02-plan · planned · next: build
EOF

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "stage_long fires for a 30h gap" "1" \
  "$(grep -c '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG")"
expect_eq "stage_long value is the gap in hours" "30" \
  "$(grep '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG" | jq -r '.value')"
expect_eq "stage_long threshold is the configured hours" "24" \
  "$(grep '"code":"stage_long".*"spec":"stage-long-spec"' "$LOG" | jq -r '.threshold')"
expect_eq "no stage_long row for a 2h gap" "0" \
  "$(grep -c '"spec":"stage-short-spec"' "$LOG")"

# --- case 14: scan - scope_breach ------------------------------------------------------------------
echo "--- scan: scope_breach"
SCOPE_LOG="$HIVE/memory/stats/scope.jsonl"
: > "$SCOPE_LOG"
printf '{"ts":"%s","story":"breach-story","declared":1,"changed":3,"out_of_scope":["a/b.sh","c/d.sh"]}\n' "$NOW" >> "$SCOPE_LOG"
printf '{"ts":"%s","story":"clean-story","declared":1,"changed":1,"out_of_scope":[]}\n' "$NOW" >> "$SCOPE_LOG"

: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "scope_breach fires for a non-empty out_of_scope" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"
expect_eq "scope_breach value is the out-of-scope path count" "2" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.value')"
expect_eq "scope_breach carries the story id" "breach-story" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.story')"
expect_eq "no scope_breach row for an empty out_of_scope" "0" \
  "$(grep -c '"story":"clean-story"' "$LOG")"

# --- case 15: scan - kill switch and the no-transcript, no-session-dir path -------------------------
echo "--- scan: kill switch, minimal invocation"
: > "$LOG"
(cd "$HIVE" && VULYK_HIVE="$HIVE" VULYK_TELEMETRY_SCAN=0 bash scripts/telemetry.sh scan --transcript "$CTX") >/dev/null 2>&1
expect_eq "VULYK_TELEMETRY_SCAN=0 writes nothing" "0" "$(grep -c . "$LOG" 2>/dev/null || true)"

: > "$LOG"
SCAN_RC=0
tel scan >/dev/null 2>&1 || SCAN_RC=$?
expect_eq "scan with no transcript and no session dir exits 0" "0" "$SCAN_RC"
expect_eq "scan with no transcript still runs the stats-file detectors" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"

# --- case 16: anomaly-scan.sh - wiring and fail-open ------------------------------------------------
echo "--- anomaly-scan.sh"
expect_eq "anomaly-scan.sh is wired on Stop" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'anomaly-scan.sh')"
expect_eq "anomaly-scan.sh is wired on SessionEnd" "1" \
  "$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'anomaly-scan.sh')"
expect_eq "the existing Stop hook is preserved beside it" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SRC/.claude/settings.json" | grep -c 'handoff.sh stop')"

: > "$LOG"
HOOK_RC=0
echo '{"transcript_path":""}' | CLAUDE_PROJECT_DIR="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  > "$T/hook-out" 2> "$T/hook-err" || HOOK_RC=$?
expect_eq "anomaly-scan.sh exits 0 on the success path" "0" "$HOOK_RC"
expect_eq "anomaly-scan.sh prints nothing on the success path" "" "$(cat "$T/hook-out")"

BASHBIN="$(command -v bash)"
EMPTYPATH="$T/emptybin"; mkdir -p "$EMPTYPATH"
NOJQ_RC=0
echo '{}' | PATH="$EMPTYPATH" CLAUDE_PROJECT_DIR="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOJQ_RC=$?
expect_eq "anomaly-scan.sh exits 0 when jq is missing" "0" "$NOJQ_RC"

JQONLY="$T/jq-only"; mkdir -p "$JQONLY"
cp "$(command -v jq)" "$JQONLY/jq"
NOPY_RC=0
echo '{}' | PATH="$JQONLY" CLAUDE_PROJECT_DIR="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOPY_RC=$?
expect_eq "anomaly-scan.sh exits 0 when python is missing" "0" "$NOPY_RC"

mkdir -p "$T/no-telemetry"
NOSCRIPT_RC=0
echo '{}' | CLAUDE_PROJECT_DIR="$T/no-telemetry" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOSCRIPT_RC=$?
expect_eq "anomaly-scan.sh exits 0 when scripts/telemetry.sh is missing" "0" "$NOSCRIPT_RC"

# --- install and consent wiring (anomaly-telemetry-05) ----------------------------------------
# Story 05 adds the Telemetry Profile row, install.sh's /dev/tty question and `wire_hook`.
# Its local cases belong here, below this marker.

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "telemetry.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
