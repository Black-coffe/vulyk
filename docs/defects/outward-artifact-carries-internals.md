---
id: outward-artifact-carries-internals
title: An artifact going outward carries internal or client content beyond names
status: text
check:
fixtures: []
keys: [только имена мало, стригерит]
paths: ["CHANGELOG.md", "README.md", "docs/specs/**", "scripts/telemetry.sh", "telemetry/**", "cmd:gh (release|issue|pr)"]
---

# An artifact going outward carries internal or client content beyond names
Something leaves for a wider audience than the one it was written in: a published video, a document a client's
person will open, a public repository, an anonymised telemetry bundle. Names were masked, but the artifact still
carries what identifies or exposes its source: figures, processes, a list of documents, internal tactics and notes
about the reader. `host-internals-in-public-repo` is the narrow form this repository has a gate for (names of a host's
insides reaching the public VULYK repo, `scripts/leak-check.sh`); this card is the wider class that gate cannot see.

## Owner quotes

## Seen in hives
Not counted as owner quotes: they corrected hive work, not VULYK's (README, *Promoted from hives*). Verbatim, with
people, clients and hives masked.
- 2026-10-15 · a video hive · client material prepared for a video with only names replaced — «Убрать из материалов <hive> и клиентских проектов только имена мало: клиента в ролике могут узнать по цифрам, процессам и набору документов.»
- 2026-10-14 · a consulting hive · a call route written as the owner's notes, to be opened by the client's person too — «вот этот файл будет и у меня и у <name>, ты уверен что там все верно описано по текстам оно не СТРИГЕРИТ <name>»

## Cause
Masking was read literally as "replace the names", and a file was written for one reader without asking who else
will open it. What fingerprints a source (numbers, a process, a set of documents) and what is meant only for the
inside (tactics, judgements of people) is not a word list, so a name filter passes it.

## Check
None beyond `host-internals-in-public-repo`'s term list, and code cannot add one generically: a figure or a process
that identifies one client is ordinary text for another.

## Never
- Send an artifact outward (publish, push, share, a telemetry bundle) without asking who will read it and reading it
  as that reader: strip the internal layer and generalise figures, processes and document lists that point to a source.
- Treat masked names as an anonymised artifact.

## Allowed
- Synthetic stand-ins and rounded, generic figures; an internal layer kept in a separate file that never goes out.
