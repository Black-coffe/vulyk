#!/usr/bin/env bash
# The solo path (ADR-013 D1): at Tier 1-2 the Queen builds the stories herself and drives
# scripts/cycle.sh advance from her own Bash - no driver, no clerk, no court, one reviewer.
# These runs follow /vulyk-build's solo loop step by step against the real cycle.sh in a
# throwaway repo, writing the reviewer's report where the loop tells it to.
#
#   Usage: bash tests/solo.test.sh            # from the VULYK repo root
set -u

SRC="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
fail=0
ok() { if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "::error::$1"; fail=1; fi; }
jl() { printf '%s\n' "$1" | tail -1 | jq -r "$2" 2>/dev/null; } # jl <verb-output> <jq> - its JSON line

mkfix() { # mkfix <dir> <tier>
  mkdir -p "$1" && cd "$1" || exit 1
  git init -q -b main . && git config user.name t && git config user.email t@t
  cp -r "$SRC/scripts" scripts
  cat > CLAUDE.md <<'EOF'
# VULYK Constitution

## Profile

<!-- VULYK:PROFILE:START -->
| Field | Value |
|---|---|
| Client path | `none: library only` |
<!-- VULYK:PROFILE:END -->

## Commands

<!-- VULYK:COMMANDS:START -->
| Purpose | Command |
|---|---|
| App check | `bash check.sh` |
<!-- VULYK:COMMANDS:END -->
EOF
  printf '#!/usr/bin/env bash\ngrep -q fixed app.txt\n' > check.sh
  printf 'broken\n' > app.txt
  printf '.vulyk/\ndocs/specs/*/DRIVER\ndocs/specs/*/PAUSE\n' > .gitignore
  mkdir -p docs/specs/demo memory/stats
  printf '# Brief - demo\n\n## Request (verbatim)\n\n> app.txt says fixed\n\n## Asks\n\n1. app.txt says fixed\n' > docs/specs/demo/brief.md
  printf '# Plan - demo\n\n**Tier:** %s · **Spec slug:** `demo`\n\n**Briefed:** via mini-brief, t, 2026-09-27\n**Branch:** <written by the build>\n**Council:** <written by judge>\n**Shipped:** <written by ship-check>\n' "$2" > docs/specs/demo/plan.md
  printf -- '---\nstory: demo-01\nstatus: todo\nreturned:\nworker: worker-code\nmodel: opus\nwave: 1\nblocked_by: []\n---\n\n# Make app.txt say fixed\n\n## Goal\napp.txt says fixed.\n\n## Requirements\n> app.txt says fixed\n\n## Files\n- app.txt\n\n## Verification\n`bash check.sh`\n' > docs/specs/demo/demo-01-app.md
  git add -A && git commit -q -m init
}
adv() { bash scripts/cycle.sh advance docs/specs/demo "$@" 2>/dev/null; }
build() { # build <story> <app.txt text> - what the Queen does for one story
  printf '%s\n' "$2" > app.txt
  sed -i 's/^returned:.*/returned: DONE/' "$1"
  bash scripts/cycle.sh close-story "$1" --commit 2>/dev/null
}
review() { # review <round> <PASS|BLOCK> - the reviewer's report where the solo loop names it
  mkdir -p ".vulyk/reports/demo/round-$1"
  if [ "$2" = PASS ]; then printf 'VERDICT: PASS\nMODEL: opus\n\n## Minor\nNone.\n'
  else printf 'VERDICT: BLOCK\nMODEL: opus\n\n## Critical\n- [ask 1] app.txt must say really fixed - run: grep really app.txt\n'
  fi > ".vulyk/reports/demo/round-$1/review.attempt-1.md"
}

echo "--- Tier 1, green in one round"
( mkfix "$TMP/pass" 1 )
cd "$TMP/pass" || exit 1
o="$(adv)"; ok "advance cuts the branch and stops at build:1" "$([ "$(jl "$o" .next)" = build:1 ] && [ "$(jl "$o" '.steps|join(",")')" = branch ]; echo $?)"
o="$(build docs/specs/demo/demo-01-app.md fixed)"; ok "close-story without a stamp closes and commits" "$([ "$(jl "$o" .ok)" = true ] && git log -1 --format=%s | grep -q '^story(demo-01)'; echo $?)"
o="$(adv)"
ok "advance opens a review-only round with no court" \
  "$([ "$(jl "$o" .next)" = dispatch:review ] && [ "$(jl "$o" .status.court)" = null ] && [ "$(jl "$o" '.status.seats|join(",")')" = review ] && [ "$(jl "$o" .status.seat_attempt.review)" = 1 ]; echo $?)"
review 1 PASS
o="$(adv --ingest)"; ok "--ingest records the review and judges GREEN" "$([ "$(jl "$o" .next)" = green ]; echo $?)"
ok "the tree is clean and no worktree is left" "$([ -z "$(git status --porcelain)" ] && [ -z "$(git worktree list | sed 1d)" ]; echo $?)"
cd "$SRC" || exit 1

echo "--- Tier 1, an anchored BLOCK escalates at once; reopen routes to a mechanical repair"
( mkfix "$TMP/block" 1 )
cd "$TMP/block" || exit 1
adv >/dev/null; build docs/specs/demo/demo-01-app.md fixed >/dev/null; adv >/dev/null
review 1 BLOCK
o="$(adv --ingest)"; ok "Tier 1's ceiling is one round: RED escalates" "$([ "$(jl "$o" .next)" = escalated ]; echo $?)"
ok "## Needs a human names the ask the reviewer blocked on" \
  "$(sed -n '/^## Needs a human/,$p' docs/specs/demo/plan.md | grep -q '^- ask 1: BLOCK by the reviewer'; echo $?)"
o="$(bash scripts/cycle.sh reopen docs/specs/demo "fix it" --commit 2>/dev/null)"; ok "reopen routes to repair" "$([ "$(jl "$o" .next)" = repair ]; echo $?)"
o="$(adv)"; ok "advance writes the repair story and stops at its wave" "$([ "$(jl "$o" .next)" = build:2 ] && [ -f docs/specs/demo/demo-02-repair-round-1.md ]; echo $?)"
ok "the repair story quotes the ask and carries the finding" \
  "$(grep -qx '> 1. app.txt says fixed' docs/specs/demo/demo-02-repair-round-1.md && grep -q '\[ask 1\] app.txt must say really fixed' docs/specs/demo/demo-02-repair-round-1.md; echo $?)"
o="$(build docs/specs/demo/demo-02-repair-round-1.md 'fixed really')"
o="$(adv)"; ok "round 2 reviews only since round 1's head" "$([ "$(jl "$o" .status.round)" = 2 ] && [ "$(jl "$o" .status.since)" != null ]; echo $?)"
review 2 PASS
o="$(adv --ingest)"; ok "round 2 is GREEN" "$([ "$(jl "$o" .next)" = green ]; echo $?)"
cd "$SRC" || exit 1

echo "--- Tier 2, the owner's REJECTED turns a passing round RED; the repair carries the note"
( mkfix "$TMP/rej" 2 )
cd "$TMP/rej" || exit 1
adv >/dev/null; build docs/specs/demo/demo-01-app.md fixed >/dev/null; adv >/dev/null
sleep 1
bash scripts/human-check.sh docs/specs/demo REJECTED "the owner saw the wrong button" >/dev/null 2>&1
review 1 PASS
o="$(adv --ingest)"; ok "the override makes the round RED and advance cuts a repair" "$([ "$(jl "$o" '.steps|join(",")')" = judge,repair ]; echo $?)"
ok "the repair story's findings carry the owner's note" \
  "$(grep -q '^- owner REJECTED at .*: the owner saw the wrong button$' docs/specs/demo/demo-02-repair-round-1.md; echo $?)"
cd "$SRC" || exit 1

if [ "$fail" -eq 0 ]; then echo "solo.test.sh: all checks passed"; else echo "solo.test.sh: FAILED"; fi
exit "$fail"
