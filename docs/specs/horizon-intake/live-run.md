# Live run: horizon-intake (ask 7)

Date: 2026-10-25 · Claude Code 2.1.310 · run by the Queen (Opus 5.5) on branch `vulyk/horizon-intake`, after
`horizon-intake-01` put `.claude/agents/drone-horizon.md` on disk.

## How it was run

The Queen's session could not dispatch the new agent: Claude Code loads agent types at session start, and the
Agent tool answered `Agent type 'drone-horizon' not found`. So each run is a headless `claude -p --model sonnet`
session in `E:\Projects\vulyk` that dispatches `drone-horizon` with the Agent tool and prints the replies verbatim.
The headless orchestrator relays only; the cut below is the Queen's. Sample briefs live in `.vulyk/live-sample/`
(git-ignored), so no sample enters the spec.

| Run | Sample | Lenses | Permission flags | Session |
|---|---|---|---|---|
| probe | A | altitude, depth, range in parallel | `--setting-sources project --permission-mode default` | `93d92930` |
| control | A | altitude, depth, range in parallel | same + `--allowedTools "Agent Read Grep Glob WebSearch WebFetch"` | `4722e582` |
| web probe | B | depth | as probe | see token table |
| web control | B | depth | as control | see token table |

`--setting-sources project` keeps the owner's user settings out: they run `bypassPermissions`, under which nothing
is ever gated, so without it the probe would prove nothing.

## Sample A: a new command on new ground

> Добавь в VULYK команду /vulyk-export: она берёт готовую спецификацию (бриф, план и вердикт совета) и выгружает её
> одной HTML-страницей, которую я могу отправить клиенту.

**The signal.** Capability terms `vulyk-export`, `html page`, `export.*spec`, `for the client`, searched in
`memory/memory.md`, `memory/map/` and the source (`scripts`, `.claude`, `templates`, `install.sh`): zero capability
hits. The one `export.*spec` hit is a TypeScript keyword (`.claude/mods/vulyk-pulse/hooks/core.ts:210`). The
container `.claude/commands/` exists (14 commands) and does not count. A first try with the term `share` hit 20 files
on ordinary words: a capability term has to name the capability, which the step's wording already requires.

**Announcement the step would print:** «Новая территория: "vulyk-export", "html page", "export spec", "for the
client" — ноль совпадений в memory/, карте и коде. Запускаю три линзы horizon. Они могут попросить доступ к поиску в
сети; если отказать, внешние факты придут с пометкой «не подтверждено».»

**The three returns (control run, verbatim fields abridged to `what` and `kind`):**

| Lens | P1 | P2 | P3 | Dropped by the lens |
|---|---|---|---|---|
| altitude | allowlist of spec fields + a marker scan of the output (gap) | write only to an ignored or external path, refuse a tracked one (gap) | one offline HTML file, print CSS, spec date and commit (extension) | a hosted share link: a server the file-based setup does not have |
| depth | `redact.sh` on the source, then a secret scanner on the HTML (gap) | a deterministic renderer, no model retyping, byte-identical reruns (extension) | provenance on the page; journal and rounds hidden by default (extension) | saving the export into the repo |
| range | noun to verb: "hand a document to an outside party safely" from DLP, records management, single-source publishing; strip internals + scan + ignored folder (gap) | commit + SHA-256 per source file + `manifest.json` (extension) | self-contained file rendered by a script, print stylesheet (extension) | a plain-language rewrite for clients: model text, unverifiable |

The probe run (`93d92930`) returned the same three themes in different words.

**The Queen's cut (nine candidates to three):**

| # | Kept | From | Kind | Verdict on the rest |
|---|---|---|---|---|
| H1 | Build the page from an allowlist of spec sections; run `redact.sh` and a marker/secret scan on the result and fail on a hit | altitude P1, depth P1, range P1 | gap | merged: three lenses, one proposal |
| H2 | Write only to a git-ignored or external path; refuse a tracked one; never stage | altitude P2, part of range P1 | gap | merged |
| H3 | One self-contained HTML file rendered by a script from the source files, with slug, date and commit in the footer | altitude P3, depth P2, depth P3, range P3 | extension | merged; journal hiding folds into H1 |
| - | dropped | range P2 (per-file SHA-256 + manifest) | extension | the commit in H3's footer answers "which version"; a manifest is upkeep the goal does not need |

**How the grill would ask them:** H1 and H2 with «Добавить (Рекомендую)» first, as gaps; H3 with «Не добавлять
(Рекомендую)» first and the proposal second with its cost (a template and a render script). Three horizon questions
plus the fixed last question leaves room for three ordinary questions inside the cap of 7.

## Sample B: web probe

> Сделай мне лендинг для онлайн-курса английского с приёмом оплаты картой. Клиенты из Украины и Польши.

Sample A needed no outside facts: none of its six dispatches called a web tool (every source is `none: repo only`).
Sample B was added so that the permission question is actually asked.

| Run | Web calls | Result | Denials | Agent behaviour |
|---|---|---|---|---|
| web probe (default mode) | 2 × WebSearch, in parallel | both refused: "Claude requested permissions to use WebSearch, but you haven't granted it yet." | 2 | no retry, no WebFetch; every external fact marked `не подтверждено`; three proposals returned |
| web control (granted) | 2 × WebSearch, 0 × WebFetch | both answered | 0 | four proposals (over the cap of three); sources cited with the access date |

Neither lens chose WebFetch on its own (WebSearch first, as the agent is told), so round 1's review asked for WebFetch
to be probed directly. Four more dispatches (round 1 repair, after the `drone-horizon.md` fixes) told the depth lens
to read one named page with WebFetch before any search:

| Run | Page | Result | Denials | Agent behaviour |
|---|---|---|---|---|
| fetch probe (default mode) | `https://docs.stripe.com/payments/blik` | fetched, no prompt, no refusal | 0 | used the page; one source, so `не подтверждено`; dated `undated, read 2026-10-25` |
| fetch control (granted) | same | fetched | 0 | same |
| fetch probe 2 (default mode) | `https://dev.ua/en/news/provaidery-internet-ekvairynhu-1771226277` | refused: "Claude requested permissions to use WebFetch, but you haven't granted it yet." | 1 | no retry, no fallback search; every external fact `не подтверждено` |
| fetch control 2 (granted) | same | fetched | 0 | dated the page by its own date, 16 February 2026 |

So in the default mode WebFetch is gated per page: the Stripe docs page went through without a grant, the news page
did not. Why Claude Code lets one domain through was not checked here; the observation is what VULYK can rely on:
some fetches pass, most outside pages ask.

**What this means for an owner in default mode.** Headless, an ungranted WebSearch, and a WebFetch of an ungranted
page, are refused at once, so nothing stalls. Interactively the same calls are permission prompts, so up to three
lenses can ask at once while they wait. Nothing in VULYK grants the web tools: an owner who wants the lenses to search answers the prompt, or adds
`WebSearch` and `WebFetch` to their own allow list. Without that, the step still returns proposals, marked
`не подтверждено`. The owner's own machine runs `bypassPermissions`, where nothing prompts.

## Tokens

`python scripts/token-report.py . --spec horizon-intake --since 2026-10-25`, read before the round 1 review: 8
`drone-horizon` dispatches, 213 331 raw and 71 619 weighted tokens in the subagents; the four fetch dispatches below
bring it to 12 dispatches and 307 014 raw. Per dispatch, counted from each transcript the same way (unique
`message.id`, the max of each field):

| Run | Lens | API calls | Raw | Output |
|---|---|---|---|---|
| probe | altitude | 3 | 24 536 | 1 629 |
| probe | depth | 3 | 24 530 | 1 504 |
| probe | range | 4 | 36 227 | 2 477 |
| control | altitude | 3 | 25 003 | 1 199 |
| control | depth | 3 | 25 255 | 1 775 |
| control | range | 3 | 24 879 | 1 978 |
| web probe | depth | 3 | 25 279 | 2 073 |
| web control | depth | 3 | 27 622 | 2 946 |
| fetch probe | depth | 3 | 31 746 | 2 203 |
| fetch control | depth | 2 | 19 439 | 2 101 |
| fetch probe 2 | depth | 2 | 16 740 | 2 418 |
| fetch control 2 | depth | 3 | 25 758 | 1 888 |

One lens costs about 25k raw (about 9k weighted, mostly cache reads); the step's three about 75k raw, before the
Queen's cut, which runs in her own context. The per-run `total_cost_usd` of the headless sessions, orchestrator
included, was $0.06-0.30.

## What the run found in the agent

Findings 1-3 were fixed in `drone-horizon.md` inside `horizon-intake-01`, before that story closed; the sample A and
web runs used the agent as it was before the fix, the four fetch runs used the fixed agent (fix 3 shows in their
dates).

1. **`status` was read two ways.** For a proposal resting on the repo alone, altitude wrote `confirmed` and depth and
   range wrote `не подтверждено`. Fixed: `status` is about external facts; a repo-only proposal is `confirmed`
   with `sources: none: repo only`.
2. **The cap of three was broken once in eight dispatches** (web control, four proposals). Fixed: the cap is stated
   as a hard rule, and a fourth goes to `DROPPED:` with its reason.
3. **Dates were access dates.** The web control cited `(2026-10-25)` on every URL, the day it searched. Fixed: the
   date is the page's own (published or updated), or `undated` with the access date.
4. **The lenses overlap.** On sample A all three led with the same security gap. The cut handles it (nine became
   three), and ADR-022 names "the three lenses return the same proposals" as a reason to revisit option B.
5. **The Profile is unfilled in the VULYK repo itself**, so every lens reported "nothing to contradict" and chose the
   language from the brief. In a bootstrapped hive the Profile is filled.

## Not run

- The grill questions themselves. `AskUserQuestion` does not exist under `claude -p`, so the horizon questions, the
  owner's pick and the `(horizon)` ask lines were not run headless. They run on the first real new-ground plan.
- An interactive default-mode session, where the prompts would appear on screen. The headless refusals show WebSearch
  and most WebFetch pages are gated; how three simultaneous prompts look to the owner was not seen, and the first
  real new-ground plan in default mode should be watched for it.
- A hive other than VULYK.
