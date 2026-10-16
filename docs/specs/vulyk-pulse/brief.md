# Brief: vulyk-pulse

**Date:** 2026-10-16
**Tier:** 3 - cross-cutting: a second VULYK mod (TSX hooks module) shipped by the installer and the root marketplace to
every hive, beside `vulyk-watcher`, with tests and docs
**Source:** the owner's request below; study, live probe and the owner's choices in [study.md](study.md)
(raw: [study-recon-sonnet.md](study-recon-sonnet.md), [study-design-fable.md](study-design-fable.md)).
**Depends on:** `vulyk-watcher` (v0.27.x): its mod layout, `isHive`, marketplace entry and `install_watcher` are the precedent.

## Request (verbatim)

> Можешь изучить возможности Code Club и его влияние на терминал? Что я хочу сделать? Я хочу, чтобы мы добавили какую-то анимацию либо в вводе строки, там, где ввод строки, либо сверху над этой строкой, либо сбоку где-то. Короче, добавить анимацию, когда вуллык работает, чтобы мы показывали, что процессы идут и движение какое-то есть, и чтобы это было понятно по какой-то микроаним ации. И таймер, который будет показывать, сколько мы работаем и сколько токенов мы спалили вместе со всеми агентами взятыми, то есть сабагенты, королева, все-все полностью. Я хочу это красиво, нативно, современно сделать. Можешь заняться ресёрчем, пригласить Fable 5.1, Cynet 5.5 и вместе подумать, как это реализовать и вшить в вуллык-систему?

("Code Club" is speech-to-text for Claude Code, "Cynet 5.5" for Sonnet 5.5.)

## Answers

The study round asked these before `/vulyk-plan` ran (same session, `AskUserQuestion`); the grill did not ask them again.

1. **Вид:** Рой (Рекомендую) - мерцающий ✻ плюс по точке ●/· на каждого агента: `✻ VULYK · build · wave 2 · ●●●· · 12m 04s · ≈1.8M tok`; narrow `✻ build ●●●· · 12m · 1.8M`; closing `Baked for 1h 12m · 9 agents · ≈4.2M tok`.
2. **Отсчёт:** За задачу (Рекомендую) - от сообщения владельца до момента, когда закончил последний агент.
3. **Дальше:** Проба, потом план (Рекомендую) - done; results in study.md "Probe results".
4. **Охват:** Только в ульях (Рекомендую) - in non-VULYK projects the native line stays; the watcher's `isHive` test decides.
5. **Полоса (probe):** Видна, не мерцает - an 8 fps band via `$.clock.every(125)` + `$.ui.invalidate` is steady on the owner's terminal.
6. **Требования:** Верно, покажи план (Рекомендую) - the plan stops for approval.

## Asks

1. While VULYK works, a live micro-animation at the prompt: an animated ✻ and one dot per live agent, plus the phase, wave and round.
2. A timer: how long the task has run, from the owner's message until the last agent ends.
3. Tokens of all agents together (the Queen, subagents, workers), live, weighted as in the weekly token report.
4. Beautiful and native: theme colours, no flicker, the animation can be slowed or turned off in /config.
5. Visible both on the spinner line and above the prompt while a background build runs without the Queen; the total on the "Baked for..." line.
6. Only in VULYK hives; other projects keep the native line.
7. Installed by the installer into every hive beside the watcher.
