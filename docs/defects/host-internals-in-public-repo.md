---
id: host-internals-in-public-repo
title: A host project's insides quoted into the public VULYK repository
status: block
check: VULYK_EXTRA_TERMS=docs/defects/host-internals-in-public-repo.terms bash scripts/leak-check.sh <arg>
fixtures: [docs/defects/host-internals-in-public-repo.original.fixture, docs/defects/host-internals-in-public-repo.neighbour.fixture, docs/defects/host-internals-in-public-repo.plainname.fixture]
keys: [клиентского проекта, client folder, public repo]
paths: ["docs/**", "memory/**", "CHANGELOG.md", "cmd:git push"]
---

# A host project's insides quoted into the public VULYK repository
VULYK is public on GitHub. Work in it is often triggered by something that happened in a hive, and the evidence of
that - a session's working folder, a transcript slug, a folder or chat name - names the hive's insides: client
folders, people, chats. Written into a brief, a recon note, a review or a defect card and pushed, it is published,
and a later commit that deletes it does not take it back out of the history or GitHub's caches.

## Owner quotes
- 2026-10-13 · VULYK 0.26.1 on GitHub · handoff-cwd / handoff-ownership briefs — «Вместе с 0.26.1 в репозиторий VULYK на GitHub ушли названия папок клиентского проекта: <client>, <folder> и чат <chat>. ЭТО НЕЛЬЗЯ ДОПУСКУАТЬ ТЫ ЧТО» (names masked here: this card is public too)
- 2026-10-13 · `scripts/leak-check.sh` · the private list — «Новая защита от утечек в VULYK знает только сегодняшние названия. Другие имена клиентов и людей, написанные обычным текстом, она пропустит.»

## Cause
The handoff-cwd recon copied the failing sessions' working folders from a hive's transcripts verbatim into the
briefs, the reviewers' brief and this library's previous card; the three reviewers copied them on into their
reviews; everything was pushed with the release. Purged on 2026-10-13 by rewriting 13 commits and force-pushing
`main` and `v0.26.1`. The first private list held only that day's names; since then a local harvester rebuilds
it from every hive on the machine (direction folders and aliases, their subfolders, spec slugs, Cyrillic proper
nouns of the hives' texts), dropping anything that already occurs in VULYK, and the check matches whole words and
Cyrillic case endings.

## Never
- Write a path that goes inside another project, or its transcript slug, into this repository: describe it by shape
  (`<hive>/docs/specs/<folder>/...`).
- Write a client's, a person's or a chat's name from a hive here, a verbatim owner quote included: mask it
  (`<client>`, `<name>`, `<chat>`) and say so.
- Hand a reviewer or a subagent a brief that carries such names: they copy what they get.

## Allowed
- A hive's root by its name alone, and synthetic stand-ins (`Acme`, `clientco`) in fixtures and tests.
