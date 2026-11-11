---
id: handoff-offered-too-early
title: A handoff is offered long before the session's real context window is near full
status: block
check: bash scripts/py.sh scripts/handoff-window-check.py <arg>
fixtures: [docs/defects/handoff-offered-too-early.original.fixture, docs/defects/handoff-offered-too-early.neighbour.fixture]
keys: [хенд-офф викликаєш, з 1 мільйону, Ран іше хенд-офф]
paths: [".claude/hooks/handoff.py"]
---

# A handoff is offered long before the session's real context window is near full
The handoff hook told a 1M-token session to checkpoint at 151k tokens («76% of 200k»), and then again at 172k. Each
offer pushes the owner to cut a session that still had most of its room, and a hook that cries early teaches people
to ignore it.

## Owner quotes
- 2026-11-11 · VULYK, the handoff hook's offers in a 1M session (151k «76% of 200k», 172k «86% of 200k») — «Мені здається, що ти неправильно рахуєш відсоток сесії і хенд-офф викликаєш не коли більше половини сесії пройшло з 1 мільйону, а коли пройшло тільки 20% сесії. По-перше, перевір, чи ти розумієш, що сесія зараз має 1 мільйон токенів. По-друге, викликатися і пропонуватися хенд-офф має на 70% сесії, 80% сесії і 90% сесії, тобто 700 тис. токенів, 800 тис. токенів і 900 тис. токенів. Ран іше хенд-офф не пропонується. Якщо це не так, перепиши ці правила і інтегруй їх в абсолютно всі проєкти, які є на цьому комп'ютері.»

## Cause
A hook payload carries no window size. When the statusbar cache held no copy for this session (another window had
rendered last, or the copy was older than 6 h), the hook guessed the stock 200k until the session passed 196k. The
first offers came at 55% and 70% of that guess.

## Check
`bash scripts/py.sh scripts/handoff-window-check.py <handoff.py>` runs the hook through a 151k session that has only a
stale same-model copy of a 1M window, a 650k session on a known 1M window (both must stay silent), and a 710k one
(must offer `/vulyk-handoff`).

## Never
- Offer a handoff, or warn about context, before 70% of the session's real window.
- Measure a session against the stock 200k while this machine has a report of the same model's window.

## How to
- Offer at 70%, 80% and 90% of the window (1M: 700k, 800k, 900k), once per level; a project pin
  (`context_limit`, `thresholds_pct` in `.claude/handoff.config.json`) still wins.

## Allowed
- The stock 200k guess when nothing on the machine knows the model's window.

## Revoked
