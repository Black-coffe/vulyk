# Scout report: vulyk-cycle.js clerk relay, clerk cost, worker self-marking (drone-scout, 2026-09-15)

## 1. Clerk relay of `status --json`
- `clerk(cmd)` wrapper, `.claude/workflows/vulyk-cycle.js:72-81` - the ONLY parsing path for every verb:
  ```js
  const clerk = (cmd) => agent(
    `Run exactly: bash scripts/cycle.sh ${cmd}\nReturn the last stdout line verbatim.`,
    { agentType: 'cycle-clerk', effort: 'low' },
  ).then((out) => {
    const line = String(out).trim().split('\n').pop()
    let parsed
    try { parsed = JSON.parse(line) } catch { throw new BadLine(line) }
    if (parsed.exit === 3) throw new Paused(parsed.next)
    return parsed
  })
  ```
  `status` called as `clerk(\`status ${spec} --json\`)` at :143.
- Parse failure: `BadLine` (:54-56) caught only at the outer try/catch (:281-285): `if (e instanceof BadLine) return e.line` - the WHOLE RUN ENDS, no retry, no re-dispatch. Header comments :12-13, :70-71: "A non-JSON last line from any verb ends the whole run; the Queen reads the raw line at wake."
- No retry anywhere: `cycle-clerk.md:18-19` forbids the clerk retrying; `clerk()` has no loop.
- `ok:false` comes from cycle.sh's own JSON `ok` field; the driver branches on `res.ok` (:159, :212, :260) and on `parsed.exit === 3` (Paused).
- Other structured parses: none besides `clerk()` - `close-story` :190 (`.ok/.exit/.error` :191-198), `record-seat` :220/:227 (:228, :246-254), `judge` :259, `open-round`/`branch`/`claim`/`release` - all through the same `JSON.parse`. No string-matching path.
- File reads by the driver: NONE. The script's environment is `args, agent, parallel, pipeline, phase, log` (tests/driver.test.sh:41 `new AsyncFunction(...)`); no `fs`/Read. Disk content reaches the driver only through an `agent()` result. :12: "never parses a dispatch return except to see whether it is empty."

## 2. Clerk call count and cost (Tier 3, one story, four seats, no re-asks)
| Step | clerk calls |
|---|---|
| `claim` | 1 |
| `status` polls (before branch, build, open-round, dispatch, judge, green) | 6 |
| `branch --commit` | 1 |
| `close-story` (1 story) | 1 |
| `open-round --commit` | 1 |
| `record-seat` x4 (`--file`) | 4 |
| `judge --commit` | 1 |
| `release` | 1 |
| total | 16 |
Each MALFORMED re-ask (:245-254) or exit-2 `file:` fallback (:226-230) adds one; a close-story first miss adds one.
- `.claude/agents/cycle-clerk.md` frontmatter: `tools: Bash`, `model: sonnet`, `maxTurns: 5`. Body (:9-26): run the one command verbatim once; read no file; `timeout: 600000` on Bash always; do not retry; the entire final message is the last stdout line verbatim.
- `docs/token-economy.md:51-61`: a subagent gets "its own system prompt, tools and `CLAUDE.md` - but not your conversation"; :74-78: "Add roughly 5 `cycle-clerk` calls" per round (undercounts vs the 16-call iteration above). No 22k/55k figure documented anywhere in token-economy.md; model-cascade.md and CHANGELOG not read.

## 3. Worker self-marking `status: done`
- Driver worker prompt :172-173: "Your story: <file>. Read it fully, including the map slice it names, and implement it per your protocol." (+ retry note). Nothing about `status:`/`returned:`.
- `worker-code.md:18`: "Last edit before you return: set the story's `returned:` frontmatter key to the same word your `STATUS:` line below will carry - DONE, NEEDS_CONTEXT, or WALL. `close-story` and the driver read this key..." (imprecise: the driver never opens the story file). `status:` itself is not mentioned as forbidden.
- Driver close-story handling :187-206: `res.ok` -> continue; `res.exit !== 4` -> `fail(st, asStop(res))` = the run ends immediately (exit 2 `already done` lands here); exit 4 = bounded miss, second miss on the same file ends the run (`Stop`, :284). No "mark blocked, continue the wave" path in this driver (the fallback loop `vulyk-build.md:89-93` has one).

## Test coverage (tests/driver.test.sh)
| Site | Scenarios | Lines |
|---|---|---|
| Non-JSON clerk line (`BadLine`) | not covered | - |
| close-story miss counting / two-miss stop | (d)(e)(f)(g)(v2)(v3) | 217-284, 547-594 |
| `returned:` vs `STATUS:` divergence (ADR-006) | (q)(r)(s) | 439-497 |
| record-seat MALFORMED / exit-2 fallback | (x2)(x3)(y3)(z)(aa)(ab)(ac) | 656-782 |
| clerk call count | not covered | - |
| worker retry prompt | (p) | 413-438 |
| DRIVER semaphore claim/release | (b)(c)(d)(t) | 164-236, 498-513 |
Not read: worker-test.md, docs/model-cascade.md, CHANGELOG.
