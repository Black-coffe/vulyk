#!/usr/bin/env bash
# The anomaly telemetry contract, driven through hand-written fixtures - no model calls, no
# network, nothing sent. Covers scripts/telemetry.sh (`enum`, `agents`, `record`, `bundle`,
# `check`, `consent`, `publish`, `inbox`) and scripts/lib.sh's `is_paperwork_path` entry for the new
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

expect_order() { # expect_order <label> <needle>...   (reads the output to judge from stdin)
  local label="$1"; shift
  local out n line prev=0; out="$(cat)"
  for n in "$@"; do
    line="$(printf '%s\n' "$out" | grep -nF -- "$n" | head -1 | cut -d: -f1)"
    if [ -z "$line" ] || [ "$line" -le "$prev" ]; then
      bad "$label - '$n' is missing or out of order in:"
      printf '%s\n' "$out" | sed 's/^/        /'; return
    fi
    prev="$line"
  done
  ok "$label"
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
reject "a semver with a suffix"      '.vulyk = "1.2.3-x"'    "vulyk is not a semver"

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
printf '%s' "$OUT" | expect "a local checkout gets a printed commit command" "git add 'telemetry/inbox/$WEEK/$HIVEID.jsonl'"
expect_eq "the bundle is copied into telemetry/inbox/<week>/<hive>.jsonl" "yes" \
  "$([ -s "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"
if tel check "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" >/dev/null 2>&1
then ok "the copied bundle passes check"; else bad "the copied bundle fails check"; fi

rm -rf "$LOCAL/telemetry/inbox/$WEEK"
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish --dry-run) 2>&1 )"
printf '%s' "$OUT" | expect "--dry-run still prints the commit command" "git add 'telemetry/inbox/$WEEK/$HIVEID.jsonl'"
expect_eq "--dry-run copies nothing" "no" \
  "$([ -e "$LOCAL/telemetry/inbox/$WEEK/$HIVEID.jsonl" ] && echo yes || echo no)"

rm -rf "$LOCAL/telemetry"   # no inbox -> no local checkout -> the PR recipe
OUT="$( (cd "$HIVE" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE" VULYK_LOCAL="$LOCAL" \
        bash scripts/telemetry.sh publish) 2>&1 )"
printf '%s' "$OUT" | expect "no local checkout gets the PR recipe" "gh pr create"
printf '%s' "$OUT" | expect_absent "the PR recipe does not claim anything was sent" "telemetry: wrote"

# (a) The cross-machine recipe is the whole fork -> PR sequence, in order: pasted as-is it
# ends in an open pull request (council round 1, ask 2). The ordered-needle assertion
# itself lives in (d) below, where a hive with rows in two weeks exercises both blocks.
printf '%s' "$OUT" | expect "the PR is opened against the configured origin slug" \
  "gh pr create --repo 'Black-coffe/vulyk' --head 'telemetry/$WEEK-$HIVEID'"
printf '%s' "$OUT" | expect "the PR body is one sentence with no path" \
  "--body 'An anonymized weekly anomaly bundle - codes and numbers only.'"

# (b) A hive (and a checkout) whose path holds a space and a `#`: every printed path is
# single-quoted, and check's own <file>:<line>: prefix survives the `#` (review finding 14).
HIVE2="$T/sp ace#hive"
LOCAL2="$T/vu lyk#local"
mkdir -p "$HIVE2/scripts" "$HIVE2/memory/stats" "$HIVE2/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$HIVE2/scripts/"
cp "$SRC"/.claude/agents/*.md "$HIVE2/.claude/agents/"
printf '| Telemetry | on - anonymized weekly bundle |\n' > "$HIVE2/CLAUDE.md"
git -C "$HIVE2" init -q -b main . && git -C "$HIVE2" config user.email t@t &&
  git -C "$HIVE2" config user.name "Test Owner" && git -C "$HIVE2" config core.autocrlf false
git -C "$HIVE2" add -A >/dev/null 2>&1; git -C "$HIVE2" commit -qm init >/dev/null
mkdir -p "$LOCAL2/telemetry/inbox"
git -C "$LOCAL2" init -q -b main . && git -C "$LOCAL2" config user.email t@t &&
  git -C "$LOCAL2" config user.name "Test Owner"
git -C "$LOCAL2" commit -qm init --allow-empty >/dev/null

LOG2="$HIVE2/memory/stats/anomalies.jsonl"
PREVWEEK="$(date -u -d '7 days ago' +%G-W%V 2>/dev/null || date -u -v-7d +%G-W%V)"
PREVTS="$(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-7d +%Y-%m-%dT%H:%M:%SZ)"
printf '{"v":1,"ts":"%s","code":"context_high","value":150000,"threshold":140000,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","spec":"s","story":"t","ref":"session:a"}\n' \
  "$NOW" >> "$LOG2"
printf '{"v":1,"ts":"%s","code":"stage_long","value":40,"threshold":24,"vulyk":"0.13.3","tier":2,"model":"","agent":"","spec":"s","story":"t","ref":"stage:b"}\n' \
  "$PREVTS" >> "$LOG2"
tel2()      { (cd "$HIVE2" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE2" bash scripts/telemetry.sh "$@"); }
tel2local() { (cd "$HIVE2" && PATH="$SHIM:$PATH" VULYK_HIVE="$HIVE2" VULYK_LOCAL="$LOCAL2" \
               bash scripts/telemetry.sh "$@"); }
HIVEID2="$(tel2 bundle --week "$WEEK" | jq -r '.hive' | head -1 | tr -d '\r')"

OUT="$(tel2local publish --week "$WEEK" 2>&1)"
# git prints the checkout's own toplevel form (on Windows a C:/... path), which is what the
# recipe quotes - the space and the `#` are in it either way.
LOCAL2TOP="$(git -C "$LOCAL2" rev-parse --show-toplevel)"
printf '%s' "$OUT" | expect "a checkout path with a space and a # is single-quoted" "cd '$LOCAL2TOP'"
printf '%s' "$OUT" | expect "the local git add line is quoted" \
  "git add 'telemetry/inbox/$WEEK/$HIVEID2.jsonl'"
OUT="$(tel2 publish --week "$WEEK" 2>&1)"
printf '%s' "$OUT" | expect "the cp line quotes a bundle path with a space and a #" \
  "cp '$HIVE2/.vulyk/telemetry/$WEEK-$HIVEID2.jsonl'"

BADF="$T/ba d#bundle.jsonl"
tel2 bundle --week "$WEEK" | head -1 | jq -c '.code = "not_a_code"' > "$BADF"
ERR="$(tel2 check "$BADF" 2>&1 >/dev/null)"
printf '%s' "$ERR" | expect "check's <file>:<line>: prefix survives a # in the path" "$BADF:1: "

# (c) A15: with no --week, publish covers the previous ISO week and the current one.
OUT="$(tel2local publish --dry-run 2>&1)"
printf '%s' "$OUT" | expect "a bare publish names the current week"  "telemetry/inbox/$WEEK/$HIVEID2.jsonl"
printf '%s' "$OUT" | expect "a bare publish names the previous week" "telemetry/inbox/$PREVWEEK/$HIVEID2.jsonl"
expect_eq "each week gets its own bundle file" "yes" \
  "$([ -s "$HIVE2/.vulyk/telemetry/$PREVWEEK-$HIVEID2.jsonl" ] && echo yes || echo no)"
OUT="$(tel2local publish --week "$WEEK" --dry-run 2>&1)"
printf '%s' "$OUT" | expect_absent "--week selects exactly one week" "$PREVWEEK"
tel2 publish --week 1999-W01 2>&1 | expect "a week with no rows is skipped" "nothing to send"

# (d) Two weeks, no local checkout (review finding 8): ONE fork and ONE cd, and every week's
# block starts back at the clone's default branch, so each PR carries exactly one week.
OUT="$(tel2 publish 2>&1)"
printf '%s' "$OUT" | expect_order "the PR recipe runs fork, branch, copy, add, commit, push, PR - twice, in order" \
  "gh repo fork" "cd 'vulyk-telemetry'" 'base="$(git rev-parse --abbrev-ref HEAD)"' \
  "git switch -c 'telemetry/$PREVWEEK-$HIVEID2'" "mkdir -p 'telemetry/inbox/$PREVWEEK'" \
  "git add 'telemetry/inbox/$PREVWEEK/$HIVEID2.jsonl'" \
  "git commit -m 'telemetry($PREVWEEK): $HIVEID2'" \
  "git push -u origin 'telemetry/$PREVWEEK-$HIVEID2'" "gh pr create --repo" \
  "git switch -c 'telemetry/$WEEK-$HIVEID2'" "mkdir -p 'telemetry/inbox/$WEEK'" \
  "git add 'telemetry/inbox/$WEEK/$HIVEID2.jsonl'" \
  "git commit -m 'telemetry($WEEK): $HIVEID2'" \
  "git push -u origin 'telemetry/$WEEK-$HIVEID2'"
expect_eq "the fork and clone step is printed once for both weeks" "1" \
  "$(printf '%s\n' "$OUT" | grep -c 'gh repo fork')"
expect_eq "each week's block starts from the clone's default branch" "2" \
  "$(printf '%s\n' "$OUT" | grep -B1 "git switch -c 'telemetry/" | grep -cF 'git switch "$base"')"
expect_eq "each week gets its own PR" "2" \
  "$(printf '%s\n' "$OUT" | grep -c 'gh pr create --repo')"

# The rule the whole spec rests on (.claude/commands/vulyk-ship.md:11): nothing is sent.
cat "$CALLS" | expect_absent "publish never invokes git push"   " push"
cat "$CALLS" | expect_absent "publish never invokes git commit" " commit"
cat "$CALLS" | expect_absent "publish never invokes gh"         "gh "
cat "$CALLS" | expect_absent "publish never invokes a pr"       "pr create"
cat "$CALLS" | expect_absent "publish never invokes git clone"  " clone"
cat "$CALLS" | expect_absent "publish never invokes a fork"     "fork"

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

# Review finding 16: `measure` is a direct call, so it must return with a terminal (or any
# never-written pipe) on stdin - the hook-payload read used to block it forever.
TTY_RC=0; TTY_OUT=""
if { : < /dev/tty; } 2>/dev/null; then
  TTY_OUT="$(timeout 5 "$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < /dev/tty 2>/dev/null)" || TTY_RC=$?
else
  FIFO="$T/measure.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"
  sleep 10 > "$FIFO" &            # a writer that never writes: a blind read would never return
  FIFO_PID=$!
  TTY_OUT="$(timeout 5 "$PY" "$SRC/.claude/hooks/handoff.py" measure "$MEASURE/main.jsonl" < "$FIFO" 2>/dev/null)" || TTY_RC=$?
  kill "$FIFO_PID" 2>/dev/null; wait "$FIFO_PID" 2>/dev/null || true
fi
expect_eq "measure with a terminal on stdin returns instead of blocking" "0" "$TTY_RC"
expect_eq "measure with a terminal on stdin still prints its measurement" "3800" \
  "$(printf '%s' "$TTY_OUT" | jq -r '.tokens')"

STATUS_RC=0
bash "$SRC/.claude/hooks/handoff.sh" status < /dev/null >/dev/null 2>&1 || STATUS_RC=$?
expect_eq "handoff.sh status still exits 0 with measure added" "0" "$STATUS_RC"

# --- case 10: scan - agent_prefix_high / agent_empty --------------------------------------------
echo "--- scan: agent_prefix_high, agent_empty"
# The layout Claude Code actually writes (recon/hooks-and-stats.md §6, review Critical 1):
# `<dir>/<session-id>.jsonl` beside `<dir>/<session-id>/subagents/`, plain dispatches directly
# there and workflow ones under `workflows/<wf>/`. `<dir>/subagents/` - where the detector used
# to look - is the control: a file there is above threshold and must yield no row at all.
PROJ="$T/proj"
SESSION="$PROJ/sid1"
mkdir -p "$SESSION/subagents/workflows/wf1" "$PROJ/subagents"
agent_file() { # agent_file <path> <prefix tokens> <text|tool_use> <agentType>
  local block
  if [ "$3" = "text" ]; then block='{"type":"text","text":"done"}'; else block='{"type":"tool_use","name":"Bash"}'; fi
  printf '{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10},"content":[%s]}}\n' \
    "$2" "$block" > "$1"
  printf '{"agentType":"%s"}\n' "$4" > "${1%.jsonl}.meta.json"
}
agent_file "$SESSION/subagents/agent-a1.jsonl"              60000 text     cycle-clerk
agent_file "$SESSION/subagents/workflows/wf1/agent-a2.jsonl" 70000 tool_use my-custom-agent
agent_file "$PROJ/subagents/agent-a3.jsonl"                  80000 text     cycle-clerk
cat > "$PROJ/sid1.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
EOF

# Every python start is counted: the bound of a Stop-hook scan is "no python for a file whose
# ref is already in the log" (plan A17, review Major 5), which is only visible from outside as
# a process that is never spawned.
PYSHIM="$T/pyshim"; PYCALLS="$T/pycalls.txt"; mkdir -p "$PYSHIM"; : > "$PYCALLS"
cat > "$PYSHIM/python3" <<EOF
#!/usr/bin/env bash
printf 'py\n' >> "$PYCALLS"
exec "$PY" "\$@"
EOF
chmod +x "$PYSHIM/python3"
telpy() { (cd "$HIVE" && PATH="$PYSHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }
pycount() { grep -c . "$PYCALLS" 2>/dev/null | head -1; }

: > "$LOG"; : > "$PYCALLS"
telpy scan --transcript "$PROJ/sid1.jsonl" >/dev/null 2>&1
expect_eq "scan finds the subagent beside the session dir, not beside the transcript" "1" \
  "$(grep -c '"ref":"agent:agent-a1.jsonl"' "$LOG")"
expect_eq "scan finds the workflow subagent one directory deeper" "1" \
  "$(grep -c '"ref":"agent:agent-a2.jsonl"' "$LOG")"
expect_eq "nothing is read from <dirname>/subagents/ beside the transcript" "0" \
  "$(grep -c '"ref":"agent:agent-a3.jsonl"' "$LOG")"
expect_eq "scan records exactly two agent_prefix_high rows" "2" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG")"
expect_eq "agent_prefix_high carries the cycle-clerk agent token" "cycle-clerk" \
  "$(grep -F '"ref":"agent:agent-a1.jsonl"' "$LOG" | jq -r '.agent')"
expect_eq "agent_prefix_high maps a non-framework agentType to other" "other" \
  "$(grep -F '"ref":"agent:agent-a2.jsonl"' "$LOG" | jq -r '.agent')"
# Major 6: at Stop time a subagent whose last entry is a tool_use is mid-turn, not empty.
expect_eq "a plain scan records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "the first scan starts python for the transcript and both subagents" "3" "$(pycount)"

AGENT_ROWS="$(grep -c . "$LOG")"
: > "$PYCALLS"
telpy scan --transcript "$PROJ/sid1.jsonl" >/dev/null 2>&1
expect_eq "a second scan over the same session appends nothing" "$AGENT_ROWS" "$(grep -c . "$LOG")"
expect_eq "a second scan starts no python for an already-recorded subagent" "1" "$(pycount)"

# --final (SessionEnd) is where agent_empty is judged, once.
telpy scan --transcript "$PROJ/sid1.jsonl" --final >/dev/null 2>&1
expect_eq "scan --final records exactly one agent_empty row" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "agent_empty ref is agent:<basename>" "agent:agent-a2.jsonl" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.ref')"
expect_eq "agent_empty maps a non-framework agentType to other" "other" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.agent')"
FINAL_ROWS="$(grep -c . "$LOG")"
telpy scan --transcript "$PROJ/sid1.jsonl" --final >/dev/null 2>&1
expect_eq "a second --final scan appends nothing" "$FINAL_ROWS" "$(grep -c . "$LOG")"

# Major 5, the other half of the bound: with no --transcript there is no session to scope to,
# so no subagent file is read even though one is above threshold.
: > "$LOG"; : > "$PYCALLS"
telpy scan >/dev/null 2>&1
expect_eq "a scan with no --transcript records no agent row" "0" \
  "$(grep -c '"code":"agent_' "$LOG" || true)"
expect_eq "a scan with no --transcript starts no python at all" "0" "$(pycount)"

# --- case 10b: scan - the per-session seen-list (plan A18, round-3 review Critical 1) -----------
echo "--- scan: seen-list bounds the Stop-hook scan"
# The case story 08 could not have passed: 40 subagents UNDER the threshold, so none of them
# ever produces a log row and the log-ref bound never fires. Without the seen-list every Stop
# scan re-measures all forty (the reviewer measured 74 python starts / ~26 s on a real session).
SEENPROJ="$T/seenproj"
SEENSESSION="$SEENPROJ/sid2"
mkdir -p "$SEENSESSION/subagents"
N_SUB=40
i=1
while [ "$i" -le "$N_SUB" ]; do
  agent_file "$SEENSESSION/subagents/agent-s$i.jsonl" 100 text cycle-clerk
  i=$(( i + 1 ))
done
# One subagent that IS an anomaly, and whose last entry is a tool_use: it proves the cached JSON
# drives the detectors, not just the skip - `agent_empty` at SessionEnd must come out of the
# cache with no python started for the file.
agent_file "$SEENSESSION/subagents/agent-big.jsonl" 60000 tool_use cycle-clerk
cat > "$SEENPROJ/sid2.jsonl" <<'EOF'
{"type":"assistant","isSidechain":false,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":50}}}
EOF

# A shim that logs its argv, not just a tick: "no python for this subagent" is only provable
# from outside as a file name that never reaches an interpreter.
ARGSHIM="$T/argshim"; PYARGS="$T/pyargs.txt"; mkdir -p "$ARGSHIM"; : > "$PYARGS"
cat > "$ARGSHIM/python3" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$PYARGS"
exec "$PY" "\$@"
EOF
chmod +x "$ARGSHIM/python3"
telargs() { (cd "$HIVE" && PATH="$ARGSHIM:$PATH" VULYK_HIVE="$HIVE" bash scripts/telemetry.sh "$@"); }
argcount() { grep -c . "$PYARGS" 2>/dev/null | head -1; }
SEEN_FILE="$HIVE/.vulyk/telemetry/seen/sid2"

: > "$LOG"; : > "$PYARGS"; rm -rf "$HIVE/.vulyk"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the first scan measures every subagent plus the main transcript" "$(( N_SUB + 2 ))" \
  "$(argcount)"
expect_eq "only the over-threshold subagent records a row" "1" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG" || true)"
expect_eq "a plain scan records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG" || true)"
expect_eq "the seen-list holds one line per subagent" "$(( N_SUB + 1 ))" "$(grep -c . "$SEEN_FILE")"
expect_eq "a seen-list line is <basename><TAB><bytes><TAB><measure json>" \
  "agent-s1.jsonl $(wc -c < "$SEENSESSION/subagents/agent-s1.jsonl" | tr -d ' ') {" \
  "$(grep '^agent-s1\.jsonl' "$SEEN_FILE" | awk -F'\t' '{print $1, $2, substr($3,1,1)}')"

: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the second scan starts python at most once (the main transcript's own measure)" "1" \
  "$(argcount)"
expect_eq "no subagent file reaches an interpreter on the second scan" "0" \
  "$(grep -c 'agent-s' "$PYARGS" || true)"
expect_eq "the second scan still holds one line per subagent" "$(( N_SUB + 1 ))" \
  "$(grep -c . "$SEEN_FILE")"

# SessionEnd: agent_empty is judged off the cached JSON of a file nothing has touched since.
: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" --final >/dev/null 2>&1
expect_eq "a --final scan over seen subagents starts python at most once" "1" "$(argcount)"
expect_eq "no subagent file reaches an interpreter on the --final scan" "0" \
  "$(grep -c 'agent-' "$PYARGS" || true)"
expect_eq "agent_empty is recorded from the cached measurement" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
expect_eq "the cached agent_empty row carries the cached agentType" "cycle-clerk" \
  "$(grep '"code":"agent_empty"' "$LOG" | jq -r '.agent')"

# A subagent that grew is measured again - and only it: the key is the byte size, not an age.
printf '{"type":"assistant","isSidechain":true,"message":{"model":"claude-sonnet-4-5","usage":{"input_tokens":100,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":10},"content":[{"type":"text","text":"more"}]}}\n' \
  >> "$SEENSESSION/subagents/agent-s7.jsonl"
GREW_BYTES="$(wc -c < "$SEENSESSION/subagents/agent-s7.jsonl" | tr -d ' ')"
: > "$PYARGS"
telargs scan --transcript "$SEENPROJ/sid2.jsonl" >/dev/null 2>&1
expect_eq "the grown subagent is measured again" "1" "$(grep -c 'agent-s7\.jsonl' "$PYARGS")"
expect_eq "and it is the only subagent measured" "2" "$(argcount)"
expect_eq "its seen-list line is rewritten with the new byte size" "$GREW_BYTES" \
  "$(grep '^agent-s7\.jsonl' "$SEEN_FILE" | awk -F'\t' '{print $2}')"
expect_eq "the seen-list still holds one line per subagent" "$(( N_SUB + 1 ))" \
  "$(grep -c . "$SEEN_FILE")"

# A scan with no --transcript has no session, so it has no seen-list either.
rm -rf "$HIVE/.vulyk"
telargs scan >/dev/null 2>&1
expect_eq "a scan with no --transcript writes no seen-list" "0" \
  "$([ -d "$HIVE/.vulyk" ] && echo 1 || echo 0)"

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

# Review finding 15: a spec read out of council.jsonl is data - it never becomes a path and
# never reaches the row unless it is a plain slug.
printf '{"ts":"%s","spec":"../x","round":4,"verdict":"RED"}\n' "$NOW" >> "$COUNCIL_LOG"
: > "$LOG"
tel scan >/dev/null 2>&1
expect_eq "a spec outside the slug shape still records the anomaly" "1" \
  "$(grep -c '"code":"council_rounds_high","value":4' "$LOG")"
expect_eq "the unsafe spec never reaches the row" "" \
  "$(grep -F '"value":4' "$LOG" | jq -r '.spec')"
expect_eq "the unsafe spec yields tier 0 - no path was built" "0" \
  "$(grep -F '"value":4' "$LOG" | jq -r '.tier')"

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
expect_eq "scope_breach ref is scope:<story>" "scope:breach-story" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.ref')"

# Review finding 11: scope.jsonl holds one row per scope-check RUN, so a story checked twice
# became two anomalies. One row per story, first breach wins (plan A17).
printf '{"ts":"2026-01-01T00:00:00Z","story":"breach-story","declared":1,"changed":5,"out_of_scope":["a/b.sh"]}\n' \
  >> "$SCOPE_LOG"
tel scan >/dev/null 2>&1
expect_eq "a second scope.jsonl row for the same story adds no second anomaly" "1" \
  "$(grep -c '"code":"scope_breach"' "$LOG")"
expect_eq "the first breach wins" "2" \
  "$(grep '"code":"scope_breach"' "$LOG" | jq -r '.value')"

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
echo '{"transcript_path":""}' | CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  > "$T/hook-out" 2> "$T/hook-err" || HOOK_RC=$?
expect_eq "anomaly-scan.sh exits 0 on the success path" "0" "$HOOK_RC"
expect_eq "anomaly-scan.sh prints nothing on the success path" "" "$(cat "$T/hook-out")"

# Plan A17 / review Major 6: the hook reads hook_event_name, and only a SessionEnd scan may
# judge a subagent empty. The session fixture is case 10's.
: > "$LOG"
printf '{"transcript_path":"%s","hook_event_name":"Stop"}\n' "$PROJ/sid1.jsonl" |
  CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
expect_eq "a Stop hook records the prefix anomalies" "2" \
  "$(grep -c '"code":"agent_prefix_high"' "$LOG")"
expect_eq "a Stop hook records no agent_empty row" "0" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"
printf '{"transcript_path":"%s","hook_event_name":"SessionEnd"}\n' "$PROJ/sid1.jsonl" |
  CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" bash "$HIVE/.claude/hooks/anomaly-scan.sh" >/dev/null 2>&1
expect_eq "a SessionEnd hook passes --final, so agent_empty is judged" "1" \
  "$(grep -c '"code":"agent_empty"' "$LOG")"

BASHBIN="$(command -v bash)"
EMPTYPATH="$T/emptybin"; mkdir -p "$EMPTYPATH"
NOJQ_RC=0
echo '{}' | PATH="$EMPTYPATH" CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOJQ_RC=$?
expect_eq "anomaly-scan.sh exits 0 when jq is missing" "0" "$NOJQ_RC"

JQONLY="$T/jq-only"; mkdir -p "$JQONLY"
cp "$(command -v jq)" "$JQONLY/jq"
NOPY_RC=0
echo '{}' | PATH="$JQONLY" CLAUDE_PROJECT_DIR="$HIVE" VULYK_HIVE="$HIVE" "$BASHBIN" "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOPY_RC=$?
expect_eq "anomaly-scan.sh exits 0 when python is missing" "0" "$NOPY_RC"

mkdir -p "$T/no-telemetry"
NOSCRIPT_RC=0
echo '{}' | CLAUDE_PROJECT_DIR="$T/no-telemetry" VULYK_HIVE="$T/no-telemetry" bash "$HIVE/.claude/hooks/anomaly-scan.sh" \
  >/dev/null 2>&1 || NOSCRIPT_RC=$?
expect_eq "anomaly-scan.sh exits 0 when scripts/telemetry.sh is missing" "0" "$NOSCRIPT_RC"

# --- install and consent wiring (anomaly-telemetry-05) ----------------------------------------
# Story 05 adds the Telemetry Profile row, install.sh's /dev/tty question and `wire_hook`.
# Its local cases belong here, below this marker.
echo "--- install.sh: the Telemetry row, the question, wire_hook"

if bash -n "$SRC/install.sh" 2>/dev/null; then ok "bash -n install.sh"
else bad "bash -n install.sh failed"; bash -n "$SRC/install.sh"; fi

rowval() { # rowval <constitution> - the first token of the Telemetry row's value cell
  grep -m1 '^|[[:space:]]*Telemetry[[:space:]]*|' "$1" 2>/dev/null \
    | awk -F'|' '{print $3}' | tr -d '`' | awk '{print $1}'
}
profile_rows() { awk '/VULYK:PROFILE:START/{f=1;next}/VULYK:PROFILE:END/{f=0}f' "$1" | grep '^| '; }

expect_eq "the repo's own constitution consents to nothing" "off" "$(cd "$SRC" && bash scripts/telemetry.sh consent)"

# Every install below names its consent explicitly unless the case is ABOUT the question, so
# no case can block on a prompt when the suite is run from a real terminal.
TGT="$T/hive-install"; mkdir -p "$TGT"
bash "$SRC/install.sh" "$TGT" --telemetry off > "$T/install.out" 2>&1
expect_eq "fresh install writes the Telemetry row as off" "off" "$(rowval "$TGT/CLAUDE.md")"
expect_eq "the row is the last row inside the Profile block" "1" \
  "$(profile_rows "$TGT/CLAUDE.md" | tail -1 | grep -c '^| Telemetry |')"
expect_eq "the installed hive's own consent verb reads it" "off" \
  "$(VULYK_HIVE="$TGT" bash "$TGT/scripts/telemetry.sh" consent)"
expect_eq "the anomaly log is never shipped into a hive" "0" \
  "$([ -e "$TGT/memory/stats/anomalies.jsonl" ] && echo 1 || echo 0)"

# --telemetry on changes that one row's value and nothing else in the constitution
PROF_BEFORE="$(grep -v '^| Telemetry |' "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry on > "$T/up-on.out" 2>&1
expect_eq "--telemetry on flips the row" "on" "$(rowval "$TGT/CLAUDE.md")"
expect_eq "nothing else in the constitution moved" "1" \
  "$([ "$PROF_BEFORE" = "$(grep -v '^| Telemetry |' "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
expect_eq "the row is still there exactly once" "1" "$(grep -c '^| Telemetry |' "$TGT/CLAUDE.md")"

# an answered row survives a plain upgrade byte for byte, and is not asked about again
CONST_BEFORE="$(cat "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade > "$T/up-plain.out" 2>&1
expect_eq "an answered row is byte-identical after --upgrade" "1" \
  "$([ "$CONST_BEFORE" = "$(cat "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
cat "$T/up-plain.out" | expect_absent "no question for a hive that already answered" "Enable telemetry?"

# --check reports the pending insertion and writes nothing
sed -i '/^| Telemetry |/d' "$TGT/CLAUDE.md"
CONST_BEFORE="$(cat "$TGT/CLAUDE.md")"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/up-check.out" 2>&1
expect_eq "--check never writes the row" "1" \
  "$([ "$CONST_BEFORE" = "$(cat "$TGT/CLAUDE.md")" ] && echo 1 || echo 0)"
cat "$T/up-check.out" | expect "--check reports the pending row" "would set      CLAUDE.md Profile row: Telemetry"

# a Profile block with no markers: warn, and never write the row (ADR-005: only exception is
# the Telemetry row itself, and only inside existing markers)
NOMARK="$T/hive-nomarkers"; mkdir -p "$NOMARK"
bash "$SRC/install.sh" "$NOMARK" --telemetry off > "$T/nomark-install.out" 2>&1
sed -i '/VULYK:PROFILE:START/d; /VULYK:PROFILE:END/d' "$NOMARK/CLAUDE.md"
NOMARK_BEFORE="$(cat "$NOMARK/CLAUDE.md")"
VULYK_TELEMETRY=on bash "$SRC/install.sh" "$NOMARK" --upgrade > "$T/nomark-upgrade.out" 2>&1
cat "$T/nomark-upgrade.out" | expect "marker-less Profile: warns and names the row and value" \
  "warning: Profile block has no markers - not writing | Telemetry | on |; add the row by hand"
expect_eq "marker-less Profile: the file is unchanged" "1" \
  "$([ "$NOMARK_BEFORE" = "$(cat "$NOMARK/CLAUDE.md")" ] && echo 1 || echo 0)"

# A run with no controlling terminal: setsid is what makes /dev/tty unopenable even when the
# suite itself is driven from a real one. Without setsid the case is only honest when this
# shell already has no terminal - otherwise it is skipped, loudly.
tty_reachable() { ( exec 3< /dev/tty ) 2>/dev/null; }
NOTTY=""
if command -v setsid >/dev/null 2>&1 && setsid --wait true 2>/dev/null; then NOTTY="setsid --wait"
elif ! tty_reachable; then NOTTY="env"
fi

if [ -n "$NOTTY" ]; then
  # upgrade, row missing, nobody to ask -> appended as off, silently
  $NOTTY bash "$SRC/install.sh" "$TGT" --upgrade > "$T/up-notty.out" 2>&1
  expect_eq "no terminal: the missing row is appended as off" "off" "$(rowval "$TGT/CLAUDE.md")"
  expect_eq "appended exactly once" "1" "$(grep -c '^| Telemetry |' "$TGT/CLAUDE.md")"
  cat "$T/up-notty.out" | expect_absent "no terminal: no question is printed" "Enable telemetry?"
  cat "$T/up-notty.out" | expect_absent "no terminal: no explanation is printed" "Telemetry (optional"

  # a piped `y` on stdin is NOT an answer: stdin is never the answer channel
  PIPED="$T/hive-piped"; mkdir -p "$PIPED"
  echo y | $NOTTY bash "$SRC/install.sh" "$PIPED" > "$T/piped.out" 2>&1
  expect_eq "piped stdin never answers the question" "off" "$(rowval "$PIPED/CLAUDE.md")"
else
  echo "  skip  no-terminal cases: no setsid and this shell has a reachable /dev/tty"
fi

# The real thing, through a pseudo-terminal, when util-linux `script` is on PATH.
if command -v script >/dev/null 2>&1 && script --version 2>&1 | grep -qi 'util-linux'; then
  PTY="$T/hive-pty"; mkdir -p "$PTY"
  printf 'y\n' | script -qec "bash '$SRC/install.sh' '$PTY'" /dev/null > "$T/pty.out" 2>&1 || true
  cat "$T/pty.out" | expect "a terminal gets the explanation, naming off as the default" "Default: off."
  cat "$T/pty.out" | expect "a terminal gets exactly one question" "Enable telemetry? [y/N]"
  expect_eq "answering y lands the row as on" "on" "$(rowval "$PTY/CLAUDE.md")"
else
  echo "  skip  terminal case: no util-linux \`script\` on PATH to drive a pseudo-terminal"
fi

# wire_hook: the two anomaly-scan.sh entries appear once each, preserve what was there, and a
# second upgrade is byte-identical.
SET="$TGT/.claude/settings.json"
jq '.hooks.Stop = [{"hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/handoff.sh stop"}]}] | del(.hooks.SessionEnd)' \
  "$SET" > "$T/set.json" && mv "$T/set.json" "$SET"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/wire.out" 2>&1
cat "$T/wire.out" | expect "wire_hook reports Stop" "wire           .claude/settings.json -> Stop: anomaly-scan.sh"
cat "$T/wire.out" | expect "wire_hook reports SessionEnd" "wire           .claude/settings.json -> SessionEnd: anomaly-scan.sh"
expect_eq "anomaly-scan.sh is wired once on Stop" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SET" | grep -c 'anomaly-scan.sh')"
expect_eq "anomaly-scan.sh is wired once on SessionEnd" "1" \
  "$(jq -r '.hooks.SessionEnd[].hooks[].command' "$SET" | grep -c 'anomaly-scan.sh')"
expect_eq "the existing Stop entry is preserved" "1" \
  "$(jq -r '.hooks.Stop[].hooks[].command' "$SET" | grep -c 'handoff.sh stop')"
expect_eq "SessionStart wiring is untouched" "1" \
  "$(jq -r '.hooks.SessionStart[].hooks[].command' "$SET" | grep -c 'vulyk-update-check.sh')"
SET_BEFORE="$(cat "$SET")"
bash "$SRC/install.sh" "$TGT" --upgrade --telemetry off > "$T/wire2.out" 2>&1
expect_eq "a second upgrade leaves settings.json byte-identical" "1" \
  "$([ "$SET_BEFORE" = "$(cat "$SET")" ] && echo 1 || echo 0)"
cat "$T/wire2.out" | expect_absent "and reports no second wiring" "-> Stop: anomaly-scan.sh"
bash "$SRC/install.sh" "$TGT" --upgrade --check > "$T/wire3.out" 2>&1
cat "$T/wire3.out" | expect_absent "--check reports no wiring for an already-wired hook" "would wire     .claude/settings.json -> Stop"

# --- case 17: inbox - distil, then stage the clear (anomaly-telemetry-07) ----------------------
echo "--- inbox"
# The repo side of the weekly promise: a scratch VULYK-repo-shaped checkout with committed
# bundles, distilled into per-(week, code) counts and cleared as a STAGED deletion - never a
# commit. Run through the same PATH shim as publish, so the never-executed list covers it too.
INBOX="$T/vulyk repo"
mkdir -p "$INBOX/scripts" "$INBOX/.claude/agents" \
         "$INBOX/telemetry/inbox/2026-W37" "$INBOX/telemetry/inbox/2026-W38"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$INBOX/scripts/"
cp "$SRC"/.claude/agents/*.md "$INBOX/.claude/agents/"
printf '# Telemetry inbox\n' > "$INBOX/telemetry/inbox/README.md"
inbox_row() { # inbox_row <code> <week> <hive>
  printf '{"v":1,"code":"%s","value":1,"threshold":0,"vulyk":"0.13.3","tier":3,"model":"opus","agent":"","week":"%s","hive":"%s"}\n' \
    "$1" "$2" "$3"
}
HIVE_A="aaaaaaaaaaaa"; HIVE_B="bbbbbbbbbbbb"
{ inbox_row context_high 2026-W37 "$HIVE_A"; inbox_row stage_long 2026-W37 "$HIVE_A"; } \
  > "$INBOX/telemetry/inbox/2026-W37/$HIVE_A.jsonl"
inbox_row context_high 2026-W37 "$HIVE_B" > "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl"
inbox_row context_high 2026-W38 "$HIVE_A" > "$INBOX/telemetry/inbox/2026-W38/$HIVE_A.jsonl"
git -C "$INBOX" init -q -b main . && git -C "$INBOX" config user.email t@t &&
  git -C "$INBOX" config user.name "Test Owner" && git -C "$INBOX" config core.autocrlf false
git -C "$INBOX" add -A >/dev/null 2>&1; git -C "$INBOX" commit -qm init >/dev/null
telin() { (cd "$INBOX" && PATH="$SHIM:$PATH" VULYK_HIVE="$INBOX" bash scripts/telemetry.sh "$@"); }
TAB="$(printf '\t')"

# (a) the table: one line per (week, code), rows and distinct hives, sorted by week then code
OUT="$(telin inbox 2>&1)"
printf '%s' "$OUT" | expect "a (week, code) two hives share counts both rows and both hives" \
  "2026-W37${TAB}context_high${TAB}2${TAB}2"
printf '%s' "$OUT" | expect "a single-hive (week, code) counts one hive" \
  "2026-W37${TAB}stage_long${TAB}1${TAB}1"
printf '%s' "$OUT" | expect "the second week gets its own row" \
  "2026-W38${TAB}context_high${TAB}1${TAB}1"
printf '%s' "$OUT" | expect_order "the table is sorted by week then code" \
  "2026-W37${TAB}context_high" "2026-W37${TAB}stage_long" "2026-W38${TAB}context_high"
expect_eq "the table is exactly three lines" "3" "$(printf '%s\n' "$OUT" | grep -c .)"
expect_eq "a plain inbox deletes nothing" "" "$(git -C "$INBOX" status --porcelain)"

# (b) --clear stages the deletions and stops there: no commit, README untouched
HEAD_BEFORE="$(git -C "$INBOX" rev-parse HEAD)"
telin inbox --clear | expect "--clear still prints the table first" "2026-W38${TAB}context_high"
expect_eq "--clear stages exactly the three bundles as deletions" \
  "D  telemetry/inbox/2026-W37/$HIVE_A.jsonl
D  telemetry/inbox/2026-W37/$HIVE_B.jsonl
D  telemetry/inbox/2026-W38/$HIVE_A.jsonl" \
  "$(git -C "$INBOX" status --porcelain | LC_ALL=C sort)"
expect_eq "the inbox README survives the clear" "yes" \
  "$([ -f "$INBOX/telemetry/inbox/README.md" ] && echo yes || echo no)"
expect_eq "--clear never commits - HEAD is unchanged" "$HEAD_BEFORE" \
  "$(git -C "$INBOX" rev-parse HEAD)"

# (c) a root with no telemetry/inbox/ (every hive): a notice, exit 0
NOINBOX="$T/hive-no-inbox"; mkdir -p "$NOINBOX/scripts" "$NOINBOX/.claude/agents"
cp "$SRC/scripts/telemetry.sh" "$SRC/scripts/lib.sh" "$NOINBOX/scripts/"
OUT="$( (cd "$NOINBOX" && VULYK_HIVE="$NOINBOX" bash scripts/telemetry.sh inbox 2>&1); echo "rc=$?" )"
printf '%s' "$OUT" | expect "no inbox names the root and calls it nothing to distil" \
  "telemetry: no inbox at $NOINBOX - nothing to distil"
printf '%s' "$OUT" | expect "no inbox is not an error" "rc=0"

# (d) an invalid row: check's lines, exit 1, and nothing deleted
git -C "$INBOX" reset -q --hard HEAD
printf 'not json at all\n' > "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl"
ERR="$(telin inbox --clear 2>&1 >/dev/null)"; RC=$?
printf '%s' "$ERR" | expect "a bad bundle is named <file>:<line>: <reason>" \
  "$INBOX/telemetry/inbox/2026-W37/$HIVE_B.jsonl:1: not valid JSON"
expect_eq "a bad bundle stops inbox --clear" "1" "$RC"
expect_eq "a failed check deletes nothing" "yes" \
  "$([ -f "$INBOX/telemetry/inbox/2026-W38/$HIVE_A.jsonl" ] && echo yes || echo no)"
expect_eq "a failed check stages nothing" "" \
  "$(git -C "$INBOX" status --porcelain | grep '^D' || true)"
git -C "$INBOX" checkout -q -- telemetry/inbox

# (e) the rule the whole spec rests on, now with inbox's own git calls in the ledger too
cat "$CALLS" | expect "the shim recorded inbox's own git rm" " rm -r -q -- telemetry/inbox/"
cat "$CALLS" | expect_absent "nothing in the script invokes git push"   " push"
cat "$CALLS" | expect_absent "nothing in the script invokes git commit" " commit"
cat "$CALLS" | expect_absent "nothing in the script invokes gh"         "gh "
cat "$CALLS" | expect_absent "nothing in the script invokes a pr"       "pr create"
cat "$CALLS" | expect_absent "nothing in the script invokes git clone"  " clone"
cat "$CALLS" | expect_absent "nothing in the script invokes a fork"     "fork"

# --- case 18: bundle - an empty string field keeps every other field in its own key ------------
# Round-4 opus seat, ask 3: the local row used to be read with a tab IFS, and tab is IFS
# whitespace - an empty `model` collapsed with its neighbour and pushed `agent` off the end.
# Those are exactly the rows `detect_agents` writes: it never passes --model.
echo "--- bundle: empty fields keep their slots"
set_consent "on - anonymized weekly bundle"
: > "$LOG"
localrow() { # localrow <model> <agent> <ref>
  printf '{"v":1,"ts":"%s","code":"agent_empty","value":3,"threshold":0,"vulyk":"0.13.3","tier":2,"model":"%s","agent":"%s","spec":"s","story":"","ref":"%s"}\n' \
    "$NOW" "$1" "$2" "$3" >> "$LOG"
}
localrow ""       "worker-code" "agent:no-model"
localrow "sonnet" ""            "agent:no-agent"
localrow ""       ""            "agent:neither"
localrow "sonnet" "cycle-clerk" "agent:both"

EMPTYB="$T/empty-fields.jsonl"
tel bundle --week "$WEEK" --out "$EMPTYB"
expect_eq "four local rows bundle as four rows" "4" "$(grep -c . "$EMPTYB")"
pair() { jq -r '"\(.model)/\(.agent)"' < "$EMPTYB" | tr -d '\r' | sed -n "$1p"; }
expect_eq "an empty model keeps the agent token" "/worker-code"       "$(pair 1)"
expect_eq "an empty agent keeps the model alias" "sonnet/"            "$(pair 2)"
expect_eq "both empty stay empty"                "/"                  "$(pair 3)"
expect_eq "both set are unchanged"               "sonnet/cycle-clerk" "$(pair 4)"
if tel check "$EMPTYB" >/dev/null 2>&1; then ok "check accepts all four rows"
else bad "check rejected the four rows:"; tel check "$EMPTYB" 2>&1 | sed 's/^/        /'; fi

# One emitter, no second parser: publish's own bundle is byte-identical to `bundle --out`.
HIVEID3="$(jq -r '.hive' < "$EMPTYB" | head -1 | tr -d '\r')"
tel publish --week "$WEEK" --dry-run >/dev/null 2>&1
expect_eq "publish --dry-run emits the same rows as bundle --out" "same" \
  "$(cmp -s "$EMPTYB" "$HIVE/.vulyk/telemetry/$WEEK-$HIVEID3.jsonl" && echo same || echo different)"

CHECKS="$(grep -c . "$LEDGER" || true)"
FAILED="$(grep -c . "$FAILS" || true)"
[ "$FAILED" -eq 0 ] || fail=1
echo "telemetry.test.sh: $CHECKS checks, $FAILED failed"
exit $fail
