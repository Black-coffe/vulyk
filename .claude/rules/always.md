# Always-loaded rules

No `paths:` frontmatter: this file loads in every session and in every agent that does not set `omitClaudeMd: true`; whether an `omitClaudeMd` agent still gets it is undocumented. Rules bound to nothing go here, at most 40 lines; rules bound to files keep `paths:` in their own file.
