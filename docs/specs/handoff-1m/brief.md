# Brief: handoff-1m

Date: 2026-11-11 · Tier: 1

## Request (verbatim)

The owner's words, this session:

> Мені здається, що ти неправильно рахуєш відсоток сесії і хенд-офф викликаєш не коли більше половини сесії пройшло з 1 мільйону, а коли пройшло тільки 20% сесії. По-перше, перевір, чи ти розумієш, що сесія зараз має 1 мільйон токенів. По-друге, викликатися і пропонуватися хенд-офф має на 70% сесії, 80% сесії і 90% сесії, тобто 700 тис. токенів, 800 тис. токенів і 900 тис. токенів. Ран іше хенд-офф не пропонується. Якщо це не так, перепиши ці правила і інтегруй їх в абсолютно всі проєкти, які є на цьому комп'ютері.

## Recon (2026-11-11)

- The session runs on a 1M window: Claude Code's statusLine input for this machine's Opus 5.5 sessions carries
  `context_window_size: 1000000`.
- `.claude/hooks/handoff.py` `DEFAULTS["thresholds_pct"]` is `[55, 70, 82]`. When the statusbar cache has no copy for
  this session and the global copy belongs to another session or is older than 6 h, `resolve_window` falls back to the
  stock 200k until the session passes 196k. This session got «~151k (76% of 200k)» and «~172k (86% of 200k)».
- The banner (Stop) at level 1 only says "working zone"; the model-facing prompt (UserPromptSubmit) speaks from level 2.
- The owner's personal `context_guard.py` (projects without VULYK) had absolute thresholds 200k/300k/400k; fixed outside
  this repo the same day to 700k/800k/900k.

## Asks

1. The VULYK handoff hook offers a handoff at 70%, 80% and 90% of the session's context window and never earlier: on a
   1M window at 700k, 800k and 900k tokens.
2. A session whose own window is not in the statusbar cache takes the window Claude Code last reported on this machine
   for the same model, instead of guessing 200k.
3. The owner's correction is a defect card with a failing check and an original plus a neighbour fixture.
