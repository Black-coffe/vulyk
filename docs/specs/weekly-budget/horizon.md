# Horizon: weekly-budget

**Terms searched:** "weekly limit", "seven_day", "rate_limits", "limits_state", "burn rate", "pace".
**Where:** `memory/memory.md`, `memory/map/`, `scripts/`, `.claude/hooks/`, `docs/token-economy.md`.
**Result:** zero hits on the capability. Prior work exists only as studies: `docs/specs/fable-budget/` and `fable-fallback/`.
**Lenses:** altitude, depth and range, all three returned.

## Candidates

| Lens | Proposal | Verdict |
|---|---|---|
| altitude P1 | Degradation ladder Fable → opus → sonnet driven by pace, via `top-model.sh`, labelled in reports | kept → H3 (merged with range P2 and depth P3) |
| altitude P2 | Statusline wrapper saves a per-account `rate_limits` snapshot; "no data" when stale | kept → H1 (merged with depth P1) |
| altitude P3 | Pre-run cost estimate in % of week from own history | dropped: needs a calibration series that H1 has to collect first; revisit after H1 has run a few weeks |
| depth P1 | `rate_limits` journal (ts, seven_day, resets_at, five_hour?), burn over 1 h / 24 h / week, per account | merged into H1 |
| depth P2 | Pace formula as a pure function, multi-window burn, table tests | dropped as a proposal: the owner already asks for the formula; its shape goes to the grill and the plan |
| depth P3 | Per-dispatch Δ of weekly %, measured cost per model used in routing | merged into H3 (as its cost input) |
| range P1 | SRE burn rate over two windows (24 h and 1 h), "ends in N h" forecast | dropped as a proposal: the formula itself is the owner's ask; kept as the recommended formula option for the grill |
| range P2 | Daily token bucket with carry-over and a separate Fable bucket (≤50% of week), downgrade when empty | merged into H3 |
| range P3 | Untouchable reserve (~10% of week); below it only critical work; pre-flight check before heavy runs | kept → H2 |

## Kept proposals

### H1: per-account journal of rate_limits snapshots

- **what:** A thin wrapper (tee) on the owner's statusline appends `{ts, seven_day, five_hour?, resets_at}` to a per-account journal. The governor reads only that journal. When the journal is stale or missing, the governor says "no data". It never invents a number.
- **why:** `rate_limits` arrives only on statusline stdin. Hooks do not get it (scout-surfaces: no reader in the repo). A burn rate cannot be computed from one point.
- **cost:** One wrapper script, one install step that must chain any existing statusline (the framework does not own it), journal rotation, two accounts.
- **check:** Replay real stdin with `five_hour`, without it, and with `rate_limits` absent. The journal row and the staleness flag must be right in each case.
- **sources:** lens-cited GH anthropics/claude-code#45133 and wmedia.es. Today's official statusline docs (code.claude.com/docs/en/statusline, read 2026-11-02 by the limits research) say each window "may be independently absent".
- **status:** the schema is confirmed by the docs. "Hooks never get rate_limits" awaits the cc-updates research.
- **kind:** gap. Request fragment: «чтобы он опирался на семидневный лимит, высчитывал, сколько процентов осталось». Without a data source, nothing can be computed.
- **ask line:** Собирать снимки недельного (и 5-часового, где он есть) лимита из статусной строки в журнал по каждому аккаунту; при устаревших данных честно говорить «данных нет».

### H2: untouchable weekly reserve and a pre-flight check

- **what:** Keep a reserve of about 10% of the week. Below it, only critical work starts: release, rollback, repair. Before a heavy run (Workflow, many agents), check whether the remaining budget lasts to the reset. The owner can override, and the override is logged.
- **why:** It directly guards the owner's fear of being out of limit two days after the reset.
- **cost:** A pre-dispatch check, a definition of "critical", and an override.
- **check:** Fixed inputs. Below the reserve, a normal run is blocked, a critical one passes, and the override works.
- **sources:** none (method). **status:** confirmed (repo method).
- **kind:** gap. Request fragment: «чтобы у нас не заканчивался трафик, например, через два дня, как обнулилась семидневная подписка». A warning alone does not guarantee it.
- **ask line:** Держать неприкосновенный резерв недели (~10%); ниже него запускать только критичное, а перед тяжёлым запуском проверять, хватит ли запаса до сброса.

### H3: act, not only warn (downgrade ladder priced by measured cost)

- **what:** When the pace or the Fable share runs over, routing downgrades: Fable → opus → sonnet. The thresholds loosen when the reset is near and the remaining budget is large. The cost of each dispatch is measured as Δ weekly %. Every report names the downgrade and why.
- **why:** In the fable-budget study, Fable took 40% of account 1's spend, and judges at xhigh effort took about 82% of the Fable spend. A warning that routing ignores does not protect the week.
- **cost:** Changes ADR-015 routing (`top-model.sh`, `model-profile.sh`, `vulyk-cycle.js` model args). There is a risk of a silent quality drop, which the label mitigates. Thresholds need measured data from H1.
- **check:** Fixed snapshots (6 days left / 20% used; 2 days left / 50% used) must yield the expected model through `top-model.sh`.
- **sources:** none (repo + fable-budget report). **status:** confirmed (repo).
- **kind:** extension. The owner asks to «жёстко контролировать», and a warning-only design also answers that literally.
- **ask line:** При перерасходе темпа или доли Fable автоматически понижать модель (Fable → Opus → Sonnet) с явной пометкой в отчёте; цену запуска мерить в процентах недели.
