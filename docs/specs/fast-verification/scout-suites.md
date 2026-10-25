# Scout report: telemetry.test.sh and council.test.sh split points (drone-scout, 2026-10-25)

Counts, not timings: no section was timed.

## Entry points
- tests/telemetry.test.sh: setup 1-114, sections 115-2122, summary 2124-2128 (CHECKS/FAILED from LEDGER/FAILS files on disk, so a subset still summarises).
- tests/council.test.sh: setup and fixture helpers 1-180, `--quick` switch 20-27 (`full()`), exit 4001-4002.
- tests/cycle.test.sh: same style, no part switch, failures in a `$MARK` file (:14, :20-21).

## telemetry.test.sh sections

Setup 1-113: `T`, ccstub (21-34), `VULYK_CLAUDE=$T/no-claude` (35), LEDGER/FAILS (40-42), helpers (44-75), case 0 `bash -n` (77-83), fixture hive `$HIVE` + git repo (85-101), LOG/WEEK/NOW/tel()/set_consent() (103-113). Cheap; every part pays it.

| Lines | Section | Exercises | install.sh runs |
|---|---|---|---|
| 115-129 | case 1 enum/agents | telemetry.sh | 0 |
| 131-157 | case 2 record | telemetry.sh | 0 |
| 159-221 | cases 3-5 bundle/check/consent | telemetry.sh | 0 |
| 222-365 | case 6 publish (SHIM set 226, CALLS 363) | telemetry.sh | 0 |
| 366-386 | cases 7-8 paperwork | lib.sh is_paperwork_path | 0 |
| 387-477 | cases 9, 9b | handoff.py | 0 |
| 478-1005 | cases 10-16 (11b model floor 679-818, 16 hook wiring 916-1005) | anomaly-scan.sh, detectors | 0 |
| 1007-1031 | litopys offer (own $BRIEF) | session-start-brief.sh | 0 |
| 1033-1253 | install and consent wiring | install.sh | ~24 |
| 1254-1339 | --constitution replace | install.sh | ~11 |
| 1340-1398 | retired framework files ($REL tar copy with tags) | install.sh | 6 |
| 1399-1669 | defect library, ysk-offer, rg, mods | install.sh | ~38 |
| 1670-1742 | host hook wrapper (loop 1691-1712) | install.sh | >=5 x loop |
| 1743-1811 | CRLF host files ($DREL/$DH) | install.sh | 7 |
| 1812-1938 | cases 17-18 inbox/bundle (own $INBOX) | telemetry.sh | 0 |
| 1939-2003 | case 19 agent token set (own $FHIVE) | telemetry.sh | 0 |
| 2005-2039 | case 20 drift guard (needs BAKED_AGENTS from case 19) | telemetry.sh | 0 |
| 2041-2103 | case 21 upgrade keeps edits ($REL=$T/rel, HIVE reassigned) | install.sh | 8 |
| 2104-2122 | case 22 example rule | install.sh | 3 |

Cross-section state:
- Cases 1-16 chain through `$HIVE`/`$LOG` (case 2 asserts "one row" at 134; log reset at 1005); case 6's SHIM is reused by case 17 (1835). Keep 1-16 in order.
- Install block 1033-1669 is not independent: `$TGT` created 1051, `$OWNSET` 1075-1077, both read at 1411, 1418, 1426-1430, 1550-1552, 1603; `$T/ownset.out` read 1412-1428. 1254-1339 uses its own CR/SC/NMR/EMPTYH (whether it needs $TGT not verified).
- `$REL` is rebuilt (1346, again 2047); 1670-1811 build their own copies.
- Cases 17-22 make their own repos; case 20 needs case 19.

## Proposed telemetry cut (scout)
- telemetry: 115-1031 + 1812-2039 (zero installs, ~780 lines of script work in 1-16; cost unknown).
- install: 1033-1339 + 1399-1669 (~73 install runs; $TGT dependency keeps it whole unless $TGT/$OWNSET creation moves).
- upgrade: 1340-1398 + 1670-1811 + 2041-2122 (own $REL/$DREL/$CR; need setup + `bash -n` at 1038).
- A part switch needs a variable (like council's QUICK) and an `if part_x; then ... fi` wrapper per range. Install runs (~100 total) are the likely cost: splitting them is the main lever.

## council.test.sh
- Setup 1-180 shared: one git repo in $T (cd at 38, git init 39), CLAUDE.md ## Commands fixture (49-62), HEAD7 (64), helpers council/mk_spec/set_tier/mk_open_spec/mk_round/mk_open_round/seat_report/write_seat/write_review/write_absent (65-180).
- One repo, many commits; history accumulates (mk_open_round exists because HEAD moves past HEAD7, 115-118). Per-part setup rebuild needed; whether a block relies on a spec an earlier block made: not verified.
- `--quick`-skipped blocks: 372-610, 778-825, 986-1183, 1231-1290, 1291-1308, 1656-1886, 2126-2145, 2167-3588. Always-run: 1-371, 611-777, 827-985, 1184-1230, 1309-1655, 1887-2125, 2146-2166, 3589-4002.
- Long skipped block 2167-3588: 2167-2547 reopen/ceilings; 2548-3091 pinned-sha replays; 3092-3211 next replay section; 3212-3588 stories 14-17 and replays. Every cycle.sh call ~1 s on Windows (comment 17-19).
- 0.18 section 3589-4002 runs in both modes, `git add -A` + commit (3597), appends rows to the fixture CLAUDE.md (3601-3609, 3990); plausibly its own part after setup.
- Natural cuts: A setup+1-1655, B 1656-2166, C 2167-3588 (only piece wholly --quick-skipped), D 3589-4002. `--quick` is a cross-file subset selector, orthogonal to a part split.

## Gotchas
- council.test.sh `expect()` (:32-36) sets `fail=1`, lost when called on the right of a pipe; telemetry fixed this with LEDGER/FAILS (37-39), cycle.test.sh uses $MARK. Check council's exit logic before relying on a split (pipe frequency not verified).
- telemetry `bad` tallies and continues; only the `bash -n` guard at 82 exits 1.
- Pinned shas (council 2682-3450, `git -C "$SRC" show <sha>:...` 2695, `git log --grep` 3448) and tags in telemetry (1346-1353, 1610) need the real repo history; a shallow checkout fails them.

## Running two copies at once
- Safe as read: mktemp -d (telemetry :13, council :29), trap rm (:14, :30), council cd "$T"; no fixed ports seen; git config repo-local.
- Real claude binary not reached (VULYK_CLAUDE missing path, :35).
- Both read $SRC (ls-files, show, tags): safe. No writes into $SRC found, but not every line read. telemetry `cd "$SRC" && bash scripts/telemetry.sh consent|agents|check` (1047, 1944, 1990, 2001, 2029, 2035) look read-only; telemetry.sh not read.
- mktemp without -d in council (2694, 2721, 3084, 3203, 3449): unique names, safe. cycle.test.sh `MARK="$(mktemp -u)"` (:14) racy only on a name collision.
- Measured fact (brief): 13 suites in parallel ran in 1070 s wall = telemetry alone, so the split must shrink telemetry's biggest piece.
